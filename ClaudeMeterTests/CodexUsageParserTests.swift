//
//  CodexUsageParserTests.swift
//  ClaudeMeterTests
//

import XCTest
@testable import QuotaMeter

final class CodexUsageParserTests: XCTestCase {
    private func decode(_ json: String) throws -> CodexUsagePayload {
        try JSONDecoder().decode(CodexUsagePayload.self, from: Data(json.utf8))
    }

    /// Trimmed from a real ProLite response. Note `primary_window` is the weekly
    /// one here and `secondary_window` is absent.
    private let liveSample = """
    {
      "user_id": "user-abc",
      "email": "someone@example.com",
      "plan_type": "prolite",
      "rate_limit": {
        "allowed": true,
        "limit_reached": false,
        "primary_window": {
          "used_percent": 14,
          "limit_window_seconds": 604800,
          "reset_after_seconds": 539756,
          "reset_at": 1787013228
        },
        "secondary_window": null
      },
      "additional_rate_limits": [
        {
          "limit_name": "GPT-5.3-Codex-Spark",
          "metered_feature": "codex_bengalfox",
          "rate_limit": {
            "allowed": true,
            "limit_reached": false,
            "primary_window": {
              "used_percent": 0,
              "limit_window_seconds": 604800,
              "reset_after_seconds": 604800,
              "reset_at": 1787078273
            },
            "secondary_window": null
          }
        }
      ]
    }
    """

    func test_labelsWindowFromDurationNotFieldName() throws {
        let windows = try decode(liveSample).toWindows()

        // `primary_window` is a 7-day window on this plan; naming it "5-hour"
        // because of its position would be wrong.
        let primary = try XCTUnwrap(windows.first { $0.id == "primary" })
        XCTAssertEqual(primary.label, "Weekly")
        XCTAssertEqual(primary.limit.utilization, 14)
        XCTAssertTrue(primary.isPrimary)
    }

    func test_labelsFiveHourWindowWhenDurationSaysSo() throws {
        let payload = try decode("""
        { "rate_limit": { "primary_window": { "used_percent": 30, "limit_window_seconds": 18000, "reset_at": 1787013228 } } }
        """)

        XCTAssertEqual(payload.toWindows().first?.label, "5-hour")
    }

    func test_labelsUnusualDurations() throws {
        let payload = try decode("""
        { "rate_limit": {
            "primary_window": { "used_percent": 1, "limit_window_seconds": 86400, "reset_at": 1787013228 },
            "secondary_window": { "used_percent": 2, "limit_window_seconds": 10800, "reset_at": 1787013228 } } }
        """)

        let windows = payload.toWindows()
        XCTAssertEqual(windows.map(\.label), ["Daily", "3-hour"])
    }

    func test_parsesUnixResetTimestamp() throws {
        let windows = try decode(liveSample).toWindows()
        let primary = try XCTUnwrap(windows.first { $0.id == "primary" })

        XCTAssertEqual(primary.limit.resetAt, Date(timeIntervalSince1970: 1_787_013_228))
    }

    func test_fallsBackToRelativeResetWhenTimestampMissing() throws {
        let payload = try decode("""
        { "rate_limit": { "primary_window": { "used_percent": 5, "limit_window_seconds": 604800, "reset_after_seconds": 3600 } } }
        """)

        let window = try XCTUnwrap(payload.toWindows().first)
        XCTAssertEqual(window.limit.resetAt.timeIntervalSinceNow, 3600, accuracy: 5)
    }

    func test_additionalLimitsAreSecondaryAndPrefixed() throws {
        let windows = try decode(liveSample).toWindows()
        let extra = try XCTUnwrap(windows.first { $0.id == "additional_0_primary" })

        XCTAssertEqual(extra.label, "GPT-5.3-Codex-Spark · Weekly")
        XCTAssertFalse(extra.isPrimary)
        XCTAssertEqual(extra.limit.utilization, 0)
    }

    func test_skipsNullSecondaryWindow() throws {
        let windows = try decode(liveSample).toWindows()
        XCTAssertFalse(windows.contains { $0.id == "secondary" })
        XCTAssertEqual(windows.count, 2)
    }

    func test_skipsWindowsMissingUsedPercent() throws {
        let payload = try decode("""
        { "rate_limit": { "primary_window": { "limit_window_seconds": 604800, "reset_at": 1787013228 } } }
        """)

        XCTAssertTrue(payload.toWindows().isEmpty)
    }

    func test_formatsPlanLabel() throws {
        XCTAssertEqual(try decode(liveSample).planLabel, "ProLite")
        XCTAssertEqual(try decode(#"{"plan_type":"plus"}"#).planLabel, "Plus")
        XCTAssertEqual(try decode(#"{"plan_type":"team"}"#).planLabel, "Team")
        XCTAssertEqual(try decode(#"{"plan_type":"mystery"}"#).planLabel, "Mystery")
        XCTAssertNil(try decode("{}").planLabel)
    }

    func test_emptyPayloadYieldsNoWindows() throws {
        XCTAssertTrue(try decode("{}").toWindows().isEmpty)
    }
}
