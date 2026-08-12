//
//  UsageData.swift
//  QuotaMeter
//

import Foundation

/// A single quota window belonging to one account.
struct UsageWindow: Codable, Equatable, Sendable, Identifiable {
    /// Stable key within its account (e.g. `five_hour`, `weekly`).
    let id: String

    /// Human-readable window name (e.g. "5-hour session").
    let label: String

    let limit: UsageLimit

    /// Length of the window, when known. Drives the pacing indicator.
    let windowDuration: TimeInterval?

    /// Primary windows drive the menu bar icon and notifications. Model-scoped
    /// sub-limits (Opus, Sonnet, Codex-Spark) are secondary and hidden by default.
    let isPrimary: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case label
        case limit
        case windowDuration = "window_duration"
        case isPrimary = "is_primary"
    }
}

/// One credential's worth of quota, or the error encountered fetching it.
struct AccountUsage: Codable, Equatable, Sendable, Identifiable {
    /// CLIProxyAPI `auth_index` — stable across refreshes.
    let id: String

    let provider: QuotaProvider

    /// Account label, usually an email address.
    let label: String

    /// Plan tier, e.g. "Max" or "ProLite". Nil when the lookup failed.
    let planLabel: String?

    let windows: [UsageWindow]

    /// Set when this account failed while others succeeded. Rendering continues
    /// for healthy accounts rather than blanking the whole popover.
    let errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case id
        case provider
        case label
        case planLabel = "plan_label"
        case windows
        case errorMessage = "error"
    }

    var isFailed: Bool { errorMessage != nil }

    /// Windows shown when the user has not opted into every sub-limit.
    var primaryWindows: [UsageWindow] { windows.filter(\.isPrimary) }

    /// Highest-utilisation window, which is the binding constraint for this account.
    var tightestWindow: UsageWindow? {
        windows.max { $0.limit.utilization < $1.limit.utilization }
    }
}

/// Complete usage data across every configured account.
struct UsageData: Codable, Equatable, Sendable {
    let accounts: [AccountUsage]

    /// Timestamp of when this data was fetched.
    let lastUpdated: Date

    enum CodingKeys: String, CodingKey {
        case accounts
        case lastUpdated = "last_updated"
    }
}

/// An account/window pair, so the UI can talk about "this window on that account".
struct WindowReference: Identifiable, Equatable, Sendable {
    let account: AccountUsage
    let window: UsageWindow

    var id: String { "\(account.id)/\(window.id)" }
}

extension UsageData {
    /// Accounts in a stable display order: provider first, then label.
    var sortedAccounts: [AccountUsage] {
        accounts.sorted {
            if $0.provider.sortIndex != $1.provider.sortIndex {
                return $0.provider.sortIndex < $1.provider.sortIndex
            }
            return $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
        }
    }

    var healthyAccounts: [AccountUsage] { accounts.filter { !$0.isFailed } }

    /// Every window across every account.
    var allWindows: [WindowReference] {
        accounts.flatMap { account in
            account.windows.map { WindowReference(account: account, window: $0) }
        }
    }

    /// The single window closest to its limit — what the menu bar reports.
    var tightestWindow: WindowReference? {
        allWindows
            .filter(\.window.isPrimary)
            .max { $0.window.limit.utilization < $1.window.limit.utilization }
            ?? allWindows.max { $0.window.limit.utilization < $1.window.limit.utilization }
    }

    /// Runner-up used by the dual-bar icon style: the tightest window that is not
    /// the headline one, preferring a different account so the two bars say
    /// something distinct.
    var runnerUpWindow: WindowReference? {
        guard let tightest = tightestWindow else { return nil }
        let others = allWindows.filter { $0.id != tightest.id && $0.window.isPrimary }
        let differentAccount = others.filter { $0.account.id != tightest.account.id }
        let pool = differentAccount.isEmpty ? others : differentAccount
        return pool.max { $0.window.limit.utilization < $1.window.limit.utilization }
    }

    var headlinePercentage: Double { tightestWindow?.window.limit.percentage ?? 0 }

    var runnerUpPercentage: Double { runnerUpWindow?.window.limit.percentage ?? 0 }

    /// What the menu bar shows: how much of the tightest limit is still available.
    /// Defaults to 100 rather than 0 so an empty state reads as "nothing consumed".
    var headlineRemaining: Double { tightestWindow?.window.limit.remaining ?? 100 }

    var runnerUpRemaining: Double { runnerUpWindow?.window.limit.remaining ?? 100 }

    /// Returns the primary usage level for menu bar display.
    var primaryStatus: UsageStatus { tightestWindow?.window.limit.status ?? .safe }

    /// True when every configured account failed to load.
    var isFullyFailed: Bool { !accounts.isEmpty && healthyAccounts.isEmpty }

    /// Human-readable staleness indicator
    var freshnessDescription: String {
        let elapsed = Date().timeIntervalSince(lastUpdated)
        if elapsed < 60 {
            return "just now"
        } else if elapsed < 3600 {
            let minutes = Int(elapsed / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else {
            let hours = Int(elapsed / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        }
    }

    var isStale: Bool {
        Date().timeIntervalSince(lastUpdated) > Constants.Refresh.stalenessThreshold
    }
}
