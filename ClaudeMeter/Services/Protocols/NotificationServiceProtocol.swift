//
//  NotificationServiceProtocol.swift
//  QuotaMeter
//

import Foundation

/// Types of usage threshold notifications
/// Raw values are used for notification identifiers (not the actual threshold percentages)
enum UsageThresholdType: String {
    case warning
    case critical
    case reset

    var title: String {
        switch self {
        case .warning: return "Running Low"
        case .critical: return "Almost Out"
        case .reset: return "Quota Reset"
        }
    }

    /// - Parameter percentage: consumption, as the providers report it. The copy
    ///   counts down to match the rest of the UI.
    func body(windowTitle: String, percentage: Double, resetTime: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let resetString = formatter.localizedString(for: resetTime, relativeTo: Date())
        let remaining = Int(min(100, max(0, 100 - percentage)))

        switch self {
        case .warning, .critical:
            return "\(windowTitle): \(remaining)% left. Resets \(resetString)."
        case .reset:
            return "\(windowTitle) has reset. Fresh capacity available."
        }
    }
}

/// Protocol for notification operations
@MainActor
protocol NotificationServiceProtocol {
    /// Setup notification center delegate
    func setupDelegate()

    /// Request notification authorization from the user
    func requestAuthorization() async throws -> Bool

    /// Evaluate thresholds and send notifications for new usage data
    func evaluateThresholds(
        usageData: UsageData,
        settings: AppSettings
    ) async

    /// Send threshold notification
    func sendThresholdNotification(
        title: String,
        percentage: Double,
        threshold: UsageThresholdType,
        resetTime: Date
    ) async throws

    /// Send reset notification
    func sendResetNotification(title: String) async throws

    /// Check system notification permissions
    func checkNotificationPermissions() async -> Bool
}
