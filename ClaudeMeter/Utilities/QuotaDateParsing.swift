//
//  QuotaDateParsing.swift
//  QuotaMeter
//

import Foundation

/// Providers disagree on how they express a reset instant: Anthropic sends an
/// ISO-8601 string with fractional seconds, OpenAI sends a Unix timestamp. Both
/// funnel through here so the domain model only ever sees a `Date`.
enum QuotaDateParsing {
    private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let plain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// Parses an ISO-8601 instant, tolerating a missing fractional-seconds part.
    static func date(fromISO8601 raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        return fractional.date(from: raw) ?? plain.date(from: raw)
    }

    /// Parses a Unix timestamp in seconds.
    static func date(fromUnixSeconds raw: Double?) -> Date? {
        guard let raw, raw > 0 else { return nil }
        return Date(timeIntervalSince1970: raw)
    }

    /// Human label for a rolling window of the given length.
    ///
    /// Codex reports window length rather than naming it, and the roles are not
    /// fixed — a plan's `primary_window` can be the weekly one — so the label has
    /// to be derived from the duration instead of the field name.
    static func windowLabel(forSeconds seconds: Double?) -> String {
        guard let seconds, seconds > 0 else { return "Usage" }
        switch Int(seconds.rounded()) {
        case 3600: return "Hourly"
        case 18_000: return "5-hour"
        case 86_400: return "Daily"
        case 604_800: return "Weekly"
        case 2_592_000: return "Monthly"
        default:
            let hours = Int((seconds / 3600).rounded())
            if hours % 24 == 0 {
                let days = hours / 24
                return "\(days)-day"
            }
            return "\(hours)-hour"
        }
    }
}
