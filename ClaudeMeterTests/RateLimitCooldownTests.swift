//
//  RateLimitCooldownTests.swift
//  ClaudeMeterTests
//

import XCTest
@testable import QuotaMeter

/// A rate limit must make the app go quiet, not try harder. These pin that.
final class RateLimitCooldownTests: XCTestCase {
    private let claudeUsageJSON = Data("""
    { "five_hour": { "utilization": 20, "resets_at": "2026-08-11T23:10:00Z" } }
    """.utf8)

    private func makeService(_ transport: ManagementTransportStub) -> UsageService {
        UsageService(
            transport: transport,
            cacheRepository: CacheRepositoryFake(),
            keyStore: ManagementKeyStoreFake(key: TestConstants.managementKey),
            settingsRepository: SettingsRepositoryFake()
        )
    }

    private func rateLimitedTransport(retryAfter: TimeInterval?) -> ManagementTransportStub {
        ManagementTransportStub(
            authFileEntries: [UsageFixtures.authFile(authIndex: "c1", provider: "claude")],
            errors: [
                ProviderEndpoints.Claude.usageURL: ManagementError.rateLimited(retryAfter: retryAfter),
                ProviderEndpoints.Claude.profileURL: ManagementError.rateLimited(retryAfter: retryAfter),
            ]
        )
    }

    func test_rateLimitStartsCooldownFromRetryAfter() async throws {
        let service = makeService(rateLimitedTransport(retryAfter: 1647))

        _ = try? await service.fetchUsage(forceRefresh: true)

        let cooldown = await service.rateLimitCooldown
        XCTAssertNotNil(cooldown)
        XCTAssertEqual(cooldown ?? 0, 1647, accuracy: 5)
    }

    func test_rateLimitWithoutRetryAfterUsesConservativeDefault() async throws {
        let service = makeService(rateLimitedTransport(retryAfter: nil))

        _ = try? await service.fetchUsage(forceRefresh: true)

        let cooldown = await service.rateLimitCooldown
        XCTAssertEqual(cooldown ?? 0, Constants.Network.defaultRateLimitCooldown, accuracy: 5)
    }

    /// The core fix: while cooling down, nothing is sent upstream at all.
    func test_noUpstreamCallsAreMadeDuringCooldown() async throws {
        let transport = rateLimitedTransport(retryAfter: 600)
        let service = makeService(transport)

        _ = try? await service.fetchUsage(forceRefresh: true)
        let afterFirst = await transport.apiCallURLs.count

        for _ in 0..<5 {
            _ = try? await service.fetchUsage(forceRefresh: true)
        }

        let afterMany = await transport.apiCallURLs.count
        XCTAssertEqual(afterFirst, afterMany, "Kept calling upstream while rate limited")
    }

    /// Even an explicit user refresh must not punch through the cooldown.
    func test_forceRefreshDoesNotBypassCooldown() async throws {
        let transport = rateLimitedTransport(retryAfter: 600)
        let service = makeService(transport)
        _ = try? await service.fetchUsage(forceRefresh: true)
        let baseline = await transport.authFilesCallCount

        _ = try? await service.fetchUsage(forceRefresh: true)

        let after = await transport.authFilesCallCount
        XCTAssertEqual(baseline, after)
    }

    /// A single rate-limited attempt must not become three.
    func test_rateLimitIsNotRetriedWithinOneAttempt() async throws {
        let transport = rateLimitedTransport(retryAfter: 600)
        let service = makeService(transport)

        _ = try? await service.fetchUsage(forceRefresh: true)

        let usageCalls = await transport.apiCallURLs.filter { $0 == ProviderEndpoints.Claude.usageURL }.count
        XCTAssertEqual(usageCalls, 1, "Rate limit was retried in-process")
    }

    /// Cooling down should keep showing the last good numbers, not blank out.
    func test_cachedDataIsServedWhileCoolingDown() async throws {
        let transport = ManagementTransportStub(
            authFileEntries: [UsageFixtures.authFile(authIndex: "c1", provider: "claude")],
            payloads: [ProviderEndpoints.Claude.usageURL: claudeUsageJSON]
        )
        let service = makeService(transport)

        let fresh = try await service.fetchUsage(forceRefresh: true)
        XCTAssertEqual(fresh.accounts.first?.windows.first?.limit.utilization, 20)

        await transport.setError(
            ManagementError.rateLimited(retryAfter: 600),
            for: ProviderEndpoints.Claude.usageURL
        )
        _ = try? await service.fetchUsage(forceRefresh: true)

        let served = try await service.fetchUsage(forceRefresh: true)
        XCTAssertEqual(served.accounts.first?.windows.first?.limit.utilization, 20)
        XCTAssertFalse(served.accounts.contains(where: \.isFailed))
    }

    func test_errorMessageNamesTheWait() {
        let message = ManagementError.rateLimited(retryAfter: 1647).localizedDescription

        XCTAssertTrue(message.contains("28 min"), "Unexpected copy: \(message)")
    }

    func test_formatsWaitAcrossScales() {
        XCTAssertEqual(ManagementError.formatWait(45), "45s")
        XCTAssertEqual(ManagementError.formatWait(1647), "28 min")
        XCTAssertEqual(ManagementError.formatWait(7200), "2h")
        XCTAssertEqual(ManagementError.formatWait(5400), "1h 30m")
    }
}
