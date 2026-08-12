//
//  CodexUsagePayload.swift
//  QuotaMeter
//
//  Ported from the CLI Proxy API Management Center's
//  `src/features/quota/providers/codex/data.ts`.
//

import Foundation

/// Response of `GET https://chatgpt.com/backend-api/wham/usage`.
struct CodexUsagePayload: Decodable, Sendable {
    struct Window: Decodable, Sendable {
        let usedPercent: Double?
        let limitWindowSeconds: Double?
        let resetAfterSeconds: Double?
        let resetAt: Double?

        enum CodingKeys: String, CodingKey {
            case usedPercent = "used_percent"
            case limitWindowSeconds = "limit_window_seconds"
            case resetAfterSeconds = "reset_after_seconds"
            case resetAt = "reset_at"
        }
    }

    struct RateLimit: Decodable, Sendable {
        let limitReached: Bool?
        let primaryWindow: Window?
        let secondaryWindow: Window?

        enum CodingKeys: String, CodingKey {
            case limitReached = "limit_reached"
            case primaryWindow = "primary_window"
            case secondaryWindow = "secondary_window"
        }
    }

    struct AdditionalRateLimit: Decodable, Sendable {
        let limitName: String?
        let rateLimit: RateLimit?

        enum CodingKeys: String, CodingKey {
            case limitName = "limit_name"
            case rateLimit = "rate_limit"
        }
    }

    let email: String?
    let planType: String?
    let rateLimit: RateLimit?
    let additionalRateLimits: [AdditionalRateLimit]?

    enum CodingKeys: String, CodingKey {
        case email
        case planType = "plan_type"
        case rateLimit = "rate_limit"
        case additionalRateLimits = "additional_rate_limits"
    }
}

// MARK: - Domain mapping

extension CodexUsagePayload.Window {
    /// Resolves the reset instant, preferring the absolute timestamp and falling
    /// back to the relative countdown.
    var resetDate: Date? {
        if let absolute = QuotaDateParsing.date(fromUnixSeconds: resetAt) {
            return absolute
        }
        if let after = resetAfterSeconds, after > 0 {
            return Date().addingTimeInterval(after)
        }
        return nil
    }

    func asUsageWindow(id: String, labelPrefix: String? = nil, isPrimary: Bool) -> UsageWindow? {
        guard let usedPercent else { return nil }

        // Codex names windows `primary`/`secondary` but their actual length varies
        // by plan, so the label comes from `limit_window_seconds`.
        let base = QuotaDateParsing.windowLabel(forSeconds: limitWindowSeconds)
        let label = labelPrefix.map { "\($0) · \(base)" } ?? base
        let fallbackDuration = limitWindowSeconds ?? Constants.Pacing.weeklyWindow

        return UsageWindow(
            id: id,
            label: label,
            limit: UsageLimit(
                utilization: usedPercent,
                resetAt: resetDate ?? Date().addingTimeInterval(fallbackDuration)
            ),
            windowDuration: limitWindowSeconds,
            isPrimary: isPrimary
        )
    }
}

extension CodexUsagePayload {
    func toWindows() -> [UsageWindow] {
        var result: [UsageWindow] = []

        if let primary = rateLimit?.primaryWindow?.asUsageWindow(id: "primary", isPrimary: true) {
            result.append(primary)
        }
        if let secondary = rateLimit?.secondaryWindow?.asUsageWindow(id: "secondary", isPrimary: true) {
            result.append(secondary)
        }

        for (index, additional) in (additionalRateLimits ?? []).enumerated() {
            let name = additional.limitName?.trimmingCharacters(in: .whitespaces)
            let prefix = (name?.isEmpty == false) ? name : nil

            if let window = additional.rateLimit?.primaryWindow?.asUsageWindow(
                id: "additional_\(index)_primary",
                labelPrefix: prefix,
                isPrimary: false
            ) {
                result.append(window)
            }
            if let window = additional.rateLimit?.secondaryWindow?.asUsageWindow(
                id: "additional_\(index)_secondary",
                labelPrefix: prefix,
                isPrimary: false
            ) {
                result.append(window)
            }
        }

        return result
    }

    /// Plan tier formatted for display, e.g. `prolite` → "ProLite".
    var planLabel: String? {
        guard let raw = planType?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return nil }
        switch raw.lowercased() {
        case "free": return "Free"
        case "plus": return "Plus"
        case "pro": return "Pro"
        case "prolite", "pro_lite": return "ProLite"
        case "team": return "Team"
        case "business": return "Business"
        case "enterprise": return "Enterprise"
        case "edu": return "Edu"
        default: return raw.capitalized
        }
    }
}
