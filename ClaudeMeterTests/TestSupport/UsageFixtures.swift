//
//  UsageFixtures.swift
//  ClaudeMeterTests
//

import Foundation
@testable import QuotaMeter

enum UsageFixtures {
    static func window(
        id: String = "five_hour",
        label: String = "5-hour session",
        percentage: Double,
        resetIn: TimeInterval = TestConstants.oneHourInterval,
        duration: TimeInterval? = Constants.Pacing.sessionWindow,
        isPrimary: Bool = true
    ) -> UsageWindow {
        UsageWindow(
            id: id,
            label: label,
            limit: UsageLimit(utilization: percentage, resetAt: Date().addingTimeInterval(resetIn)),
            windowDuration: duration,
            isPrimary: isPrimary
        )
    }

    static func account(
        id: String = "account-1",
        provider: QuotaProvider = .claude,
        label: String = "someone@example.com",
        planLabel: String? = "Max",
        windows: [UsageWindow]? = nil,
        percentage: Double = TestConstants.sessionPercentage,
        errorMessage: String? = nil
    ) -> AccountUsage {
        AccountUsage(
            id: id,
            provider: provider,
            label: label,
            planLabel: planLabel,
            windows: windows ?? [window(percentage: percentage)],
            errorMessage: errorMessage
        )
    }

    static func usageData(
        accounts: [AccountUsage]? = nil,
        percentage: Double = TestConstants.sessionPercentage,
        lastUpdated: Date = Date()
    ) -> UsageData {
        UsageData(
            accounts: accounts ?? [account(percentage: percentage)],
            lastUpdated: lastUpdated
        )
    }

    static func authFile(
        authIndex: String = "idx-1",
        provider: String = "claude",
        label: String = "someone@example.com",
        disabled: Bool = false
    ) -> AuthFileEntry {
        AuthFileEntry(
            authIndex: authIndex,
            provider: provider,
            label: label,
            email: label,
            status: "active",
            disabled: disabled
        )
    }
}
