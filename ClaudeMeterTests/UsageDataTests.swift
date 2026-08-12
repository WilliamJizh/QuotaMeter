//
//  UsageDataTests.swift
//  ClaudeMeterTests
//

import XCTest
@testable import QuotaMeter

final class UsageDataTests: XCTestCase {
    private func account(
        id: String,
        provider: QuotaProvider,
        label: String,
        primary: [(String, Double)],
        secondary: [(String, Double)] = []
    ) -> AccountUsage {
        let windows = primary.map {
            UsageFixtures.window(id: $0.0, label: $0.0, percentage: $0.1, isPrimary: true)
        } + secondary.map {
            UsageFixtures.window(id: $0.0, label: $0.0, percentage: $0.1, isPrimary: false)
        }
        return UsageFixtures.account(id: id, provider: provider, label: label, windows: windows)
    }

    /// The menu bar reports the binding constraint across every account, which is
    /// the whole point of showing several plans in one place.
    func test_tightestWindowIsHighestUtilisationAcrossAccounts() {
        let data = UsageFixtures.usageData(accounts: [
            account(id: "a", provider: .claude, label: "a@x", primary: [("five_hour", 12), ("seven_day", 40)]),
            account(id: "b", provider: .claude, label: "b@x", primary: [("five_hour", 95), ("seven_day", 32)]),
            account(id: "c", provider: .codex, label: "c@x", primary: [("primary", 14)]),
        ])

        let tightest = data.tightestWindow
        XCTAssertEqual(tightest?.account.id, "b")
        XCTAssertEqual(tightest?.window.id, "five_hour")
        XCTAssertEqual(data.headlinePercentage, 95)
        XCTAssertEqual(data.primaryStatus, .critical)
    }

    /// A model-scoped sub-limit shouldn't hijack the icon just because it's high.
    func test_secondaryWindowsAreIgnoredForHeadlineWhenPrimariesExist() {
        let data = UsageFixtures.usageData(accounts: [
            account(
                id: "a", provider: .claude, label: "a@x",
                primary: [("five_hour", 20)],
                secondary: [("seven_day_opus", 99)]
            )
        ])

        XCTAssertEqual(data.tightestWindow?.window.id, "five_hour")
        XCTAssertEqual(data.headlinePercentage, 20)
    }

    func test_fallsBackToSecondaryWindowWhenNoPrimariesExist() {
        let data = UsageFixtures.usageData(accounts: [
            account(id: "a", provider: .claude, label: "a@x", primary: [], secondary: [("seven_day_opus", 55)])
        ])

        XCTAssertEqual(data.tightestWindow?.window.id, "seven_day_opus")
    }

    /// The dual-bar icon should say something new with its second bar.
    func test_runnerUpPrefersADifferentAccount() {
        let data = UsageFixtures.usageData(accounts: [
            account(id: "a", provider: .claude, label: "a@x", primary: [("five_hour", 95), ("seven_day", 80)]),
            account(id: "b", provider: .codex, label: "b@x", primary: [("primary", 40)]),
        ])

        XCTAssertEqual(data.runnerUpWindow?.account.id, "b")
        XCTAssertEqual(data.runnerUpPercentage, 40)
    }

    func test_runnerUpFallsBackToSameAccountWhenAlone() {
        let data = UsageFixtures.usageData(accounts: [
            account(id: "a", provider: .claude, label: "a@x", primary: [("five_hour", 95), ("seven_day", 80)])
        ])

        XCTAssertEqual(data.runnerUpWindow?.window.id, "seven_day")
    }

    func test_sortsClaudeBeforeCodexThenByLabel() {
        let data = UsageFixtures.usageData(accounts: [
            account(id: "z", provider: .codex, label: "aaa@x", primary: [("primary", 1)]),
            account(id: "b", provider: .claude, label: "zzz@x", primary: [("five_hour", 1)]),
            account(id: "a", provider: .claude, label: "aaa@x", primary: [("five_hour", 1)]),
        ])

        XCTAssertEqual(data.sortedAccounts.map(\.id), ["a", "b", "z"])
    }

    func test_failedAccountsAreExcludedFromHealthyButStillListed() {
        let failed = UsageFixtures.account(id: "bad", windows: [], errorMessage: "401")
        let data = UsageFixtures.usageData(accounts: [
            account(id: "good", provider: .claude, label: "g@x", primary: [("five_hour", 10)]),
            failed,
        ])

        XCTAssertEqual(data.accounts.count, 2)
        XCTAssertEqual(data.healthyAccounts.map(\.id), ["good"])
        XCTAssertFalse(data.isFullyFailed)
    }

    func test_isFullyFailedWhenEveryAccountErrors() {
        let data = UsageFixtures.usageData(accounts: [
            UsageFixtures.account(id: "a", windows: [], errorMessage: "401"),
            UsageFixtures.account(id: "b", windows: [], errorMessage: "429"),
        ])

        XCTAssertTrue(data.isFullyFailed)
    }

    func test_stalenessReflectsLastUpdated() {
        let fresh = UsageFixtures.usageData(lastUpdated: Date())
        let old = UsageFixtures.usageData(
            lastUpdated: Date().addingTimeInterval(-Constants.Refresh.stalenessThreshold - 60)
        )

        XCTAssertFalse(fresh.isStale)
        XCTAssertTrue(old.isStale)
    }

    func test_roundTripsThroughJSONForExternalExport() throws {
        let data = UsageFixtures.usageData(accounts: [
            account(id: "a", provider: .claude, label: "a@x", primary: [("five_hour", 42)])
        ])

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(UsageData.self, from: encoder.encode(data))

        XCTAssertEqual(decoded.accounts.first?.windows.first?.limit.utilization, 42)
        XCTAssertEqual(decoded.accounts.first?.provider, .claude)
    }
}
