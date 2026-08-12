//
//  ClaudeUsagePayload.swift
//  QuotaMeter
//
//  Ported from the CLI Proxy API Management Center's
//  `src/features/quota/providers/claude/data.ts`.
//

import Foundation

/// Response of `GET https://api.anthropic.com/api/oauth/usage`.
struct ClaudeUsagePayload: Decodable, Sendable {
    struct Window: Decodable, Sendable {
        let utilization: Double?
        let resetsAt: String?

        enum CodingKeys: String, CodingKey {
            case utilization
            case resetsAt = "resets_at"
        }
    }

    /// Entries from the newer `limits` array, used for model-scoped caps that
    /// have no dedicated top-level key.
    struct Limit: Decodable, Sendable {
        struct Scope: Decodable, Sendable {
            struct Model: Decodable, Sendable {
                let displayName: String?

                enum CodingKeys: String, CodingKey {
                    case displayName = "display_name"
                }
            }
            let model: Model?
        }

        let kind: String?
        let percent: Double?
        let resetsAt: String?
        let isActive: Bool?
        let scope: Scope?

        enum CodingKeys: String, CodingKey {
            case kind
            case percent
            case resetsAt = "resets_at"
            case isActive = "is_active"
            case scope
        }
    }

    let fiveHour: Window?
    let sevenDay: Window?
    let sevenDayOauthApps: Window?
    let sevenDayOpus: Window?
    let sevenDaySonnet: Window?
    let sevenDayCowork: Window?
    let iguanaNecktie: Window?
    let limits: [Limit]?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDayOauthApps = "seven_day_oauth_apps"
        case sevenDayOpus = "seven_day_opus"
        case sevenDaySonnet = "seven_day_sonnet"
        case sevenDayCowork = "seven_day_cowork"
        case iguanaNecktie = "iguana_necktie"
        case limits
    }
}

/// Response of `GET https://api.anthropic.com/api/oauth/profile`.
struct ClaudeProfilePayload: Decodable, Sendable {
    struct Account: Decodable, Sendable {
        let hasClaudeMax: Bool?
        let hasClaudePro: Bool?

        enum CodingKeys: String, CodingKey {
            case hasClaudeMax = "has_claude_max"
            case hasClaudePro = "has_claude_pro"
        }
    }

    struct Organization: Decodable, Sendable {
        let organizationType: String?
        let subscriptionStatus: String?

        enum CodingKeys: String, CodingKey {
            case organizationType = "organization_type"
            case subscriptionStatus = "subscription_status"
        }
    }

    let account: Account?
    let organization: Organization?
}

// MARK: - Domain mapping

extension ClaudeUsagePayload {
    /// Ordered window descriptors, mirroring `CLAUDE_USAGE_WINDOW_KEYS`.
    private static let windowSpecs: [(id: String, label: String, isPrimary: Bool, duration: TimeInterval)] = [
        ("five_hour", "5-hour session", true, Constants.Pacing.sessionWindow),
        ("seven_day", "Weekly", true, Constants.Pacing.weeklyWindow),
        ("seven_day_opus", "Weekly Opus", false, Constants.Pacing.weeklyWindow),
        ("seven_day_sonnet", "Weekly Sonnet", false, Constants.Pacing.weeklyWindow),
        ("seven_day_cowork", "Weekly Cowork", false, Constants.Pacing.weeklyWindow),
        ("seven_day_oauth_apps", "Weekly API apps", false, Constants.Pacing.weeklyWindow),
        ("iguana_necktie", "Weekly Fable", false, Constants.Pacing.weeklyWindow),
    ]

    private func window(forID id: String) -> Window? {
        switch id {
        case "five_hour": return fiveHour
        case "seven_day": return sevenDay
        case "seven_day_opus": return sevenDayOpus
        case "seven_day_sonnet": return sevenDaySonnet
        case "seven_day_cowork": return sevenDayCowork
        case "seven_day_oauth_apps": return sevenDayOauthApps
        case "iguana_necktie": return iguanaNecktie
        default: return nil
        }
    }

    /// Model-scoped weekly caps, one entry per model, preferring the active one.
    ///
    /// These arrive only through `limits[]` — the matching top-level keys
    /// (`iguana_necktie`, `seven_day_opus`, …) are null in practice. They are real
    /// hard caps and frequently the binding constraint, so they are surfaced as
    /// primary windows rather than hidden behind "show every sub-limit".
    private var scopedWeeklyLimits: [(model: String, limit: Limit)] {
        var result: [(model: String, limit: Limit)] = []

        for limit in limits ?? [] {
            guard limit.kind?.lowercased() == "weekly_scoped", limit.percent != nil else { continue }
            let name = (limit.scope?.model?.displayName ?? "").trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }

            if let index = result.firstIndex(where: { $0.model.lowercased() == name.lowercased() }) {
                if result[index].limit.isActive != true, limit.isActive == true {
                    result[index] = (name, limit)
                }
                continue
            }
            result.append((name, limit))
        }

        return result
    }

    /// Stable id per model, so a rename from "Fable" to "Fable 5" upstream doesn't
    /// orphan the window's notification state.
    private static func scopedWindowID(forModel model: String) -> String {
        let lowered = model.lowercased()
        if lowered.hasPrefix("fable") { return "seven_day_fable" }

        let slug = lowered
            .map { $0.isLetter || $0.isNumber ? $0 : "_" }
            .reduce(into: "") { $0.append($1) }
        return "seven_day_\(slug)"
    }

    func toWindows() -> [UsageWindow] {
        var result: [UsageWindow] = []
        let scoped = scopedWeeklyLimits
        let hasScopedFable = scoped.contains { $0.model.lowercased().hasPrefix("fable") }

        for spec in Self.windowSpecs {
            // The scoped Fable cap supersedes the legacy key when both exist.
            if spec.id == "iguana_necktie", hasScopedFable { continue }
            guard let raw = window(forID: spec.id), let utilization = raw.utilization else { continue }

            result.append(
                UsageWindow(
                    id: spec.id,
                    label: spec.label,
                    limit: UsageLimit(
                        utilization: utilization,
                        resetAt: QuotaDateParsing.date(fromISO8601: raw.resetsAt)
                            ?? Date().addingTimeInterval(spec.duration)
                    ),
                    windowDuration: spec.duration,
                    isPrimary: spec.isPrimary
                )
            )
        }

        for (model, limit) in scoped {
            guard let percent = limit.percent else { continue }
            result.append(
                UsageWindow(
                    id: Self.scopedWindowID(forModel: model),
                    label: "Weekly \(model)",
                    limit: UsageLimit(
                        utilization: percent,
                        resetAt: QuotaDateParsing.date(fromISO8601: limit.resetsAt)
                            ?? Date().addingTimeInterval(Constants.Pacing.weeklyWindow)
                    ),
                    windowDuration: Constants.Pacing.weeklyWindow,
                    isPrimary: true
                )
            )
        }

        return result
    }
}

extension ClaudeProfilePayload {
    /// Plan tier, resolved with the same precedence as the management panel.
    var planLabel: String? {
        if account?.hasClaudeMax == true { return "Max" }
        if account?.hasClaudePro == true { return "Pro" }

        let orgType = organization?.organizationType?.lowercased()
        let subscription = organization?.subscriptionStatus?.lowercased()
        if orgType == "claude_team", subscription == "active" { return "Team" }

        if account?.hasClaudeMax == false, account?.hasClaudePro == false { return "Free" }
        return nil
    }
}
