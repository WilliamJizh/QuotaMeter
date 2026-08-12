//
//  RemainingDisplayTests.swift
//  ClaudeMeterTests
//

import XCTest
@testable import QuotaMeter

/// The providers report consumption; the UI counts down. These pin the inversion
/// so a future change can't silently flip the meaning of the number on screen.
final class RemainingDisplayTests: XCTestCase {
    func test_remainingIsInverseOfUtilization() {
        let limit = UsageLimit(utilization: 75, resetAt: Date())

        XCTAssertEqual(limit.percentage, 75)
        XCTAssertEqual(limit.remaining, 25)
    }

    func test_remainingIsZeroWhenExhausted() {
        XCTAssertEqual(UsageLimit(utilization: 100, resetAt: Date()).remaining, 0)
    }

    /// Utilization can exceed 100 once a limit is blown through; remaining must
    /// clamp rather than go negative and render a backwards bar.
    func test_remainingClampsWhenOverLimit() {
        XCTAssertEqual(UsageLimit(utilization: 137, resetAt: Date()).remaining, 0)
    }

    func test_remainingIsFullWhenUnused() {
        XCTAssertEqual(UsageLimit(utilization: 0, resetAt: Date()).remaining, 100)
    }

    /// Status stays driven by consumption even though the display inverts, so
    /// "almost out" is still red.
    func test_statusStillTracksConsumptionNotRemaining() {
        let nearlyOut = UsageLimit(utilization: 95, resetAt: Date())

        XCTAssertEqual(nearlyOut.remaining, 5)
        XCTAssertEqual(nearlyOut.status, .critical)
    }

    // MARK: - Aggregate

    func test_headlineRemainingTracksTightestWindow() {
        let data = UsageFixtures.usageData(accounts: [
            UsageFixtures.account(id: "a", windows: [UsageFixtures.window(percentage: 12)]),
            UsageFixtures.account(id: "b", windows: [UsageFixtures.window(percentage: 76)]),
        ])

        XCTAssertEqual(data.headlinePercentage, 76)
        XCTAssertEqual(data.headlineRemaining, 24)
    }

    /// An empty state should read as a full tank, not an empty one.
    func test_headlineRemainingDefaultsToFullWhenNoWindows() {
        let data = UsageData(accounts: [], lastUpdated: Date())

        XCTAssertEqual(data.headlineRemaining, 100)
        XCTAssertEqual(data.runnerUpRemaining, 100)
    }

    // MARK: - Export

    func test_exportIncludesRemainingAlongsideUtilization() throws {
        let data = UsageFixtures.usageData(accounts: [
            UsageFixtures.account(windows: [UsageFixtures.window(percentage: 40)])
        ])

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let json = try JSONSerialization.jsonObject(with: encoder.encode(data)) as? [String: Any]

        let accounts = try XCTUnwrap(json?["accounts"] as? [[String: Any]])
        let windows = try XCTUnwrap(accounts.first?["windows"] as? [[String: Any]])
        let limit = try XCTUnwrap(windows.first?["limit"] as? [String: Any])

        XCTAssertEqual(limit["utilization"] as? Double, 40)
        XCTAssertEqual(limit["remaining"] as? Double, 60)
    }

    /// The extra key must not break decoding of a previously written cache.
    func test_decodingIgnoresRemainingKey() throws {
        let json = Data(#"{"utilization": 40, "reset_at": "2026-08-11T18:40:00Z", "remaining": 60}"#.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let limit = try decoder.decode(UsageLimit.self, from: json)

        XCTAssertEqual(limit.utilization, 40)
        XCTAssertEqual(limit.remaining, 60)
    }

    func test_notificationBodyCountsDown() {
        let body = UsageThresholdType.warning.body(
            windowTitle: "Claude · Weekly",
            percentage: 76,
            resetTime: Date().addingTimeInterval(3600)
        )

        XCTAssertTrue(body.contains("24% left"), "Unexpected copy: \(body)")
        XCTAssertFalse(body.contains("76"))
    }
}
