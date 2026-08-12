//
//  UsageServiceTests.swift
//  ClaudeMeterTests
//

import XCTest
@testable import QuotaMeter

final class UsageServiceTests: XCTestCase {
    private let claudeUsageJSON = Data("""
    { "five_hour": { "utilization": 95, "resets_at": "2026-08-11T18:40:00Z" },
      "seven_day": { "utilization": 32, "resets_at": "2026-08-13T20:00:00Z" } }
    """.utf8)

    private let claudeProfileJSON = Data("""
    { "account": { "has_claude_max": true, "has_claude_pro": false } }
    """.utf8)

    private let codexUsageJSON = Data("""
    { "email": "codex@example.com", "plan_type": "prolite",
      "rate_limit": { "primary_window": { "used_percent": 14, "limit_window_seconds": 604800, "reset_at": 1787013228 } } }
    """.utf8)

    private func makeService(
        transport: ManagementTransportStub,
        key: String? = TestConstants.managementKey
    ) -> UsageService {
        UsageService(
            transport: transport,
            cacheRepository: CacheRepositoryFake(),
            keyStore: ManagementKeyStoreFake(key: key),
            settingsRepository: SettingsRepositoryFake()
        )
    }

    func test_aggregatesClaudeAndCodexAccounts() async throws {
        let transport = ManagementTransportStub(
            authFileEntries: [
                UsageFixtures.authFile(authIndex: "c1", provider: "claude", label: "claude@example.com"),
                UsageFixtures.authFile(authIndex: "x1", provider: "codex", label: "codex@example.com"),
            ],
            payloads: [
                ProviderEndpoints.Claude.usageURL: claudeUsageJSON,
                ProviderEndpoints.Claude.profileURL: claudeProfileJSON,
                ProviderEndpoints.Codex.usageURL: codexUsageJSON,
            ]
        )

        let data = try await makeService(transport: transport).fetchUsage(forceRefresh: true)

        XCTAssertEqual(data.accounts.count, 2)

        let claude = try XCTUnwrap(data.accounts.first { $0.provider == .claude })
        XCTAssertEqual(claude.planLabel, "Max")
        XCTAssertEqual(claude.windows.count, 2)

        let codex = try XCTUnwrap(data.accounts.first { $0.provider == .codex })
        XCTAssertEqual(codex.planLabel, "ProLite")
        XCTAssertEqual(codex.label, "codex@example.com")
    }

    /// One dead credential must not blank out the healthy ones.
    func test_failingAccountIsIsolatedFromHealthyAccounts() async throws {
        let transport = ManagementTransportStub(
            authFileEntries: [
                UsageFixtures.authFile(authIndex: "c1", provider: "claude"),
                UsageFixtures.authFile(authIndex: "x1", provider: "codex"),
            ],
            payloads: [
                ProviderEndpoints.Claude.usageURL: claudeUsageJSON,
                ProviderEndpoints.Claude.profileURL: claudeProfileJSON,
            ],
            errors: [
                ProviderEndpoints.Codex.usageURL: ManagementError.upstreamStatus(code: 401, body: "expired"),
            ]
        )

        let data = try await makeService(transport: transport).fetchUsage(forceRefresh: true)

        XCTAssertEqual(data.accounts.count, 2)
        XCTAssertEqual(data.healthyAccounts.count, 1)

        let codex = try XCTUnwrap(data.accounts.first { $0.provider == .codex })
        XCTAssertTrue(codex.isFailed)
        XCTAssertTrue(codex.errorMessage?.contains("401") == true)
        XCTAssertFalse(data.isFullyFailed)
    }

    /// A missing profile costs the plan badge, not the usage numbers.
    func test_claudeProfileFailureStillYieldsWindows() async throws {
        let transport = ManagementTransportStub(
            authFileEntries: [UsageFixtures.authFile(authIndex: "c1", provider: "claude")],
            payloads: [ProviderEndpoints.Claude.usageURL: claudeUsageJSON],
            errors: [ProviderEndpoints.Claude.profileURL: ManagementError.missingBody]
        )

        let data = try await makeService(transport: transport).fetchUsage(forceRefresh: true)
        let claude = try XCTUnwrap(data.accounts.first)

        XCTAssertNil(claude.planLabel)
        XCTAssertEqual(claude.windows.count, 2)
        XCTAssertFalse(claude.isFailed)
    }

    func test_ignoresDisabledAndUnsupportedCredentials() async throws {
        let transport = ManagementTransportStub(
            authFileEntries: [
                UsageFixtures.authFile(authIndex: "c1", provider: "claude"),
                UsageFixtures.authFile(authIndex: "g1", provider: "gemini"),
                UsageFixtures.authFile(authIndex: "c2", provider: "claude", disabled: true),
            ],
            payloads: [
                ProviderEndpoints.Claude.usageURL: claudeUsageJSON,
                ProviderEndpoints.Claude.profileURL: claudeProfileJSON,
            ]
        )

        let data = try await makeService(transport: transport).fetchUsage(forceRefresh: true)

        XCTAssertEqual(data.accounts.map(\.id), ["c1"])
    }

    func test_throwsWhenNoSupportedCredentialsExist() async {
        let transport = ManagementTransportStub(
            authFileEntries: [UsageFixtures.authFile(authIndex: "g1", provider: "gemini")]
        )

        do {
            _ = try await makeService(transport: transport).fetchUsage(forceRefresh: true)
            XCTFail("Expected noAccounts")
        } catch AppError.noAccounts {
            // expected
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func test_throwsNotConfiguredWhenNoKeyResolves() async {
        let transport = ManagementTransportStub()

        do {
            _ = try await makeService(transport: transport, key: nil).fetchUsage(forceRefresh: true)
            XCTFail("Expected notConfigured")
        } catch AppError.notConfigured {
            // expected
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func test_probeReturnsOnlySupportedCredentials() async throws {
        let transport = ManagementTransportStub(
            authFileEntries: [
                UsageFixtures.authFile(authIndex: "c1", provider: "claude"),
                UsageFixtures.authFile(authIndex: "g1", provider: "gemini"),
            ]
        )
        let endpoint = try ManagementEndpoint(rawAddress: TestConstants.managementAddress, key: "k")

        let entries = try await makeService(transport: transport).probeEndpoint(endpoint)

        XCTAssertEqual(entries.map(\.authIndex), ["c1"])
    }
}
