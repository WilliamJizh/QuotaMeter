//
//  NotificationState.swift
//  QuotaMeter
//

import Foundation

/// Tracks which notification thresholds have been triggered, per window.
///
/// With several accounts in play a single set of flags would let the noisiest
/// account suppress alerts for every other one, so state is keyed by
/// `account/window`.
struct NotificationState: Codable, Equatable, Sendable {
    struct Window: Codable, Equatable, Sendable {
        var hasWarningBeenNotified: Bool = false
        var hasCriticalBeenNotified: Bool = false

        /// Last known usage percentage, used to detect a reset.
        var lastPercentage: Double = 0

        enum CodingKeys: String, CodingKey {
            case hasWarningBeenNotified = "warning_notified"
            case hasCriticalBeenNotified = "critical_notified"
            case lastPercentage = "last_percentage"
        }
    }

    var windows: [String: Window] = [:]

    enum CodingKeys: String, CodingKey {
        case windows
    }

    init(windows: [String: Window] = [:]) {
        self.windows = windows
    }

    /// Tolerates state written by an earlier single-window schema.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        windows = try container.decodeIfPresent([String: Window].self, forKey: .windows) ?? [:]
    }
}

extension NotificationState {
    subscript(key: String) -> Window {
        get { windows[key] ?? Window() }
        set { windows[key] = newValue }
    }

    /// Drops state for windows that no longer exist so the file can't grow forever.
    mutating func prune(keeping keys: Set<String>) {
        windows = windows.filter { keys.contains($0.key) }
    }
}

extension NotificationState.Window {
    /// Check if a threshold should trigger a notification.
    func shouldNotify(currentPercentage: Double, threshold: Double, isWarning: Bool) -> Bool {
        if isWarning {
            return !hasWarningBeenNotified && currentPercentage >= threshold
        }
        return !hasCriticalBeenNotified && currentPercentage >= threshold
    }

    /// Check if a reset should trigger a notification.
    func shouldNotifyReset(currentPercentage: Double) -> Bool {
        lastPercentage > 0 && currentPercentage == 0
    }

    /// Re-arm the flags once usage falls back below each threshold.
    mutating func rearm(currentPercentage: Double, warningThreshold: Double, criticalThreshold: Double) {
        if currentPercentage < warningThreshold {
            hasWarningBeenNotified = false
        }
        if currentPercentage < criticalThreshold {
            hasCriticalBeenNotified = false
        }
        lastPercentage = currentPercentage
    }
}
