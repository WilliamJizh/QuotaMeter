//
//  ClaudeUsageParserTests.swift
//  ClaudeMeterTests
//

import XCTest
@testable import QuotaMeter

final class ClaudeUsageParserTests: XCTestCase {
    private func decodeUsage(_ json: String) throws -> ClaudeUsagePayload {
        try JSONDecoder().decode(ClaudeUsagePayload.self, from: Data(json.utf8))
    }

    func test_parsesFiveHourAndWeeklyWindowsAsPrimary() throws {
        let payload = try decodeUsage("""
        {
          "five_hour": { "utilization": 95, "resets_at": "2026-08-11T18:40:00.616168+00:00" },
          "seven_day": { "utilization": 32, "resets_at": "2026-08-13T20:00:00.616195+00:00" }
        }
        """)

        let windows = payload.toWindows()

        XCTAssertEqual(windows.count, 2)
        XCTAssertEqual(windows[0].id, "five_hour")
        XCTAssertEqual(windows[0].limit.utilization, 95)
        XCTAssertTrue(windows[0].isPrimary)
        XCTAssertEqual(windows[0].windowDuration, Constants.Pacing.sessionWindow)
        XCTAssertEqual(windows[1].id, "seven_day")
        XCTAssertEqual(windows[1].limit.utilization, 32)
        XCTAssertTrue(windows[1].isPrimary)
    }

    func test_parsesSixDigitFractionalSecondsResetInstant() throws {
        let payload = try decodeUsage("""
        { "five_hour": { "utilization": 10, "resets_at": "2026-08-11T18:40:00.616168+00:00" } }
        """)

        let window = try XCTUnwrap(payload.toWindows().first)
        XCTAssertEqual(
            window.limit.resetAt.timeIntervalSince1970,
            Date(timeIntervalSince1970: 1_786_473_600).timeIntervalSince1970,
            accuracy: 1
        )
    }

    func test_parsesResetInstantWithoutFractionalSeconds() throws {
        let payload = try decodeUsage("""
        { "five_hour": { "utilization": 10, "resets_at": "2026-08-11T18:40:00Z" } }
        """)

        let window = try XCTUnwrap(payload.toWindows().first)
        XCTAssertEqual(
            window.limit.resetAt.timeIntervalSince1970,
            Date(timeIntervalSince1970: 1_786_473_600).timeIntervalSince1970,
            accuracy: 1
        )
    }

    func test_omitsWindowsMissingUtilization() throws {
        let payload = try decodeUsage("""
        {
          "five_hour": { "utilization": 12, "resets_at": null },
          "seven_day_opus": { "resets_at": "2026-08-13T20:00:00Z" }
        }
        """)

        let windows = payload.toWindows()
        XCTAssertEqual(windows.map(\.id), ["five_hour"])
    }

    func test_marksModelScopedWindowsAsSecondary() throws {
        let payload = try decodeUsage("""
        {
          "five_hour": { "utilization": 12, "resets_at": "2026-08-11T18:40:00Z" },
          "seven_day_opus": { "utilization": 40, "resets_at": "2026-08-13T20:00:00Z" },
          "seven_day_sonnet": { "utilization": 20, "resets_at": "2026-08-13T20:00:00Z" }
        }
        """)

        let windows = payload.toWindows()
        let secondary = windows.filter { !$0.isPrimary }.map(\.id)
        XCTAssertEqual(Set(secondary), ["seven_day_opus", "seven_day_sonnet"])
    }

    func test_activeFableLimitReplacesLegacyKey() throws {
        let payload = try decodeUsage("""
        {
          "iguana_necktie": { "utilization": 5, "resets_at": "2026-08-13T20:00:00Z" },
          "limits": [
            {
              "kind": "weekly_scoped",
              "percent": 61,
              "resets_at": "2026-08-14T20:00:00Z",
              "is_active": true,
              "scope": { "model": { "display_name": "Fable 5" } }
            }
          ]
        }
        """)

        let windows = payload.toWindows()
        XCTAssertEqual(windows.map(\.id), ["seven_day_fable"])
        XCTAssertEqual(windows.first?.limit.utilization, 61)
        XCTAssertEqual(windows.first?.label, "Weekly Fable 5")
    }

    /// Scoped caps are hard limits and are often the binding constraint, so they
    /// must be visible by default rather than hidden behind "show every sub-limit".
    func test_scopedLimitsArePrimaryWindows() throws {
        let payload = try decodeUsage("""
        {
          "five_hour": { "utilization": 34, "resets_at": "2026-08-11T23:10:00Z" },
          "limits": [
            { "kind": "weekly_scoped", "percent": 100, "is_active": true,
              "resets_at": "2026-08-14T23:00:00Z",
              "scope": { "model": { "display_name": "Fable" } } }
          ]
        }
        """)

        let fable = try XCTUnwrap(payload.toWindows().first { $0.id == "seven_day_fable" })
        XCTAssertTrue(fable.isPrimary)
        XCTAssertEqual(fable.limit.utilization, 100)
        XCTAssertEqual(fable.limit.remaining, 0)
    }

    /// An exhausted scoped cap has to reach the menu bar, which only considers
    /// primary windows.
    func test_exhaustedScopedLimitBecomesTheHeadline() throws {
        let payload = try decodeUsage("""
        {
          "five_hour": { "utilization": 34, "resets_at": "2026-08-11T23:10:00Z" },
          "seven_day": { "utilization": 80, "resets_at": "2026-08-14T23:00:00Z" },
          "limits": [
            { "kind": "weekly_scoped", "percent": 100, "is_active": true,
              "scope": { "model": { "display_name": "Fable" } } }
          ]
        }
        """)
        let data = UsageData(
            accounts: [
                AccountUsage(
                    id: "a", provider: .claude, label: "a@x", planLabel: "Max",
                    windows: payload.toWindows(), errorMessage: nil
                )
            ],
            lastUpdated: Date()
        )

        XCTAssertEqual(data.tightestWindow?.window.id, "seven_day_fable")
        XCTAssertEqual(data.headlineRemaining, 0)
    }

    /// A model rename upstream must not orphan the window's notification state.
    func test_scopedFableIDIsStableAcrossModelRenames() throws {
        for name in ["Fable", "Fable 5", "fable"] {
            let payload = try decodeUsage("""
            { "limits": [ { "kind": "weekly_scoped", "percent": 10, "is_active": true,
              "scope": { "model": { "display_name": "\(name)" } } } ] }
            """)
            XCTAssertEqual(payload.toWindows().first?.id, "seven_day_fable", "for \(name)")
        }
    }

    func test_scopedLimitsForOtherModelsAreAlsoSurfaced() throws {
        let payload = try decodeUsage("""
        {
          "limits": [
            { "kind": "weekly_scoped", "percent": 61, "is_active": true,
              "scope": { "model": { "display_name": "Opus" } } },
            { "kind": "weekly_scoped", "percent": 22, "is_active": true,
              "scope": { "model": { "display_name": "Fable" } } }
          ]
        }
        """)

        let windows = payload.toWindows()
        XCTAssertEqual(Set(windows.map(\.id)), ["seven_day_opus", "seven_day_fable"])
        XCTAssertTrue(windows.allSatisfy(\.isPrimary))
    }

    /// `session` and `weekly_all` entries duplicate the top-level keys and must
    /// not produce a second copy of the same window.
    func test_ignoresUnscopedLimitEntries() throws {
        let payload = try decodeUsage("""
        {
          "five_hour": { "utilization": 34, "resets_at": "2026-08-11T23:10:00Z" },
          "limits": [
            { "kind": "session", "percent": 34, "is_active": false },
            { "kind": "weekly_all", "percent": 80, "is_active": false }
          ]
        }
        """)

        XCTAssertEqual(payload.toWindows().map(\.id), ["five_hour"])
    }

    func test_prefersActiveFableLimitOverInactiveOne() throws {
        let payload = try decodeUsage("""
        {
          "limits": [
            { "kind": "weekly_scoped", "percent": 10, "is_active": false,
              "scope": { "model": { "display_name": "fable" } } },
            { "kind": "weekly_scoped", "percent": 88, "is_active": true,
              "scope": { "model": { "display_name": "fable" } } }
          ]
        }
        """)

        XCTAssertEqual(payload.toWindows().first?.limit.utilization, 88)
    }

    func test_legacyKeySurvivesWhenScopedLimitIsForAnotherModel() throws {
        let payload = try decodeUsage("""
        {
          "iguana_necktie": { "utilization": 5, "resets_at": "2026-08-13T20:00:00Z" },
          "limits": [
            { "kind": "weekly_scoped", "percent": 61, "is_active": true,
              "scope": { "model": { "display_name": "Opus" } } }
          ]
        }
        """)

        XCTAssertEqual(payload.toWindows().map(\.id), ["iguana_necktie", "seven_day_opus"])
    }

    func test_emptyPayloadYieldsNoWindows() throws {
        XCTAssertTrue(try decodeUsage("{}").toWindows().isEmpty)
    }

    // MARK: - Plan tier

    private func decodeProfile(_ json: String) throws -> ClaudeProfilePayload {
        try JSONDecoder().decode(ClaudeProfilePayload.self, from: Data(json.utf8))
    }

    func test_resolvesMaxPlan() throws {
        let profile = try decodeProfile("""
        { "account": { "has_claude_max": true, "has_claude_pro": false },
          "organization": { "organization_type": "claude_max", "subscription_status": "active" } }
        """)
        XCTAssertEqual(profile.planLabel, "Max")
    }

    func test_resolvesProPlan() throws {
        let profile = try decodeProfile("""
        { "account": { "has_claude_max": false, "has_claude_pro": true } }
        """)
        XCTAssertEqual(profile.planLabel, "Pro")
    }

    func test_resolvesTeamPlanFromOrganization() throws {
        let profile = try decodeProfile("""
        { "organization": { "organization_type": "claude_team", "subscription_status": "active" } }
        """)
        XCTAssertEqual(profile.planLabel, "Team")
    }

    func test_resolvesFreePlanWhenBothFlagsFalse() throws {
        let profile = try decodeProfile("""
        { "account": { "has_claude_max": false, "has_claude_pro": false } }
        """)
        XCTAssertEqual(profile.planLabel, "Free")
    }

    func test_returnsNilPlanWhenUnknown() throws {
        XCTAssertNil(try decodeProfile("{}").planLabel)
    }
}
