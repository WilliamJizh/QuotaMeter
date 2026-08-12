//
//  NotificationService.swift
//  QuotaMeter
//

import Foundation
import UserNotifications

/// Main actor-isolated notification service
@MainActor
final class NotificationService: NSObject, NotificationServiceProtocol, UNUserNotificationCenterDelegate {
    private var center: UserNotificationCenterProtocol
    private let settingsRepository: SettingsRepositoryProtocol

    init(
        settingsRepository: SettingsRepositoryProtocol,
        notificationCenter: UserNotificationCenterProtocol = UNUserNotificationCenter.current()
    ) {
        self.settingsRepository = settingsRepository
        self.center = notificationCenter
        super.init()
    }

    /// Setup notification center delegate
    func setupDelegate() {
        center.delegate = self
    }

    /// Request notification authorization from the user
    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    /// Evaluate usage thresholds and send notifications.
    ///
    /// Only primary windows are considered: model-scoped sub-limits are noisy and
    /// rarely the binding constraint.
    func evaluateThresholds(usageData: UsageData, settings: AppSettings) async {
        let thresholds = settings.notificationThresholds
        var state = await settingsRepository.loadNotificationState()

        let hasPermission = await checkNotificationPermissions()
        let isNotificationEnabled = settings.hasNotificationsEnabled && hasPermission

        let candidates = usageData.allWindows.filter {
            $0.window.isPrimary && !$0.account.isFailed && settings.isVisible($0.account.provider)
        }

        for reference in candidates {
            let key = reference.id
            let percentage = reference.window.limit.percentage
            let title = "\(reference.account.label) · \(reference.window.label)"
            var windowState = state[key]

            let shouldNotifyWarning = windowState.shouldNotify(
                currentPercentage: percentage,
                threshold: thresholds.warningThreshold,
                isWarning: true
            )
            let shouldNotifyCritical = windowState.shouldNotify(
                currentPercentage: percentage,
                threshold: thresholds.criticalThreshold,
                isWarning: false
            )
            let shouldNotifyReset = isNotificationEnabled
                && thresholds.isNotifiedOnReset
                && windowState.shouldNotifyReset(currentPercentage: percentage)

            if isNotificationEnabled && shouldNotifyWarning {
                try? await sendThresholdNotification(
                    title: title,
                    percentage: percentage,
                    threshold: .warning,
                    resetTime: reference.window.limit.resetAt
                )
                windowState.hasWarningBeenNotified = true
            }

            if isNotificationEnabled && shouldNotifyCritical {
                try? await sendThresholdNotification(
                    title: title,
                    percentage: percentage,
                    threshold: .critical,
                    resetTime: reference.window.limit.resetAt
                )
                windowState.hasCriticalBeenNotified = true
            }

            if shouldNotifyReset {
                try? await sendResetNotification(title: title)
            }

            windowState.rearm(
                currentPercentage: percentage,
                warningThreshold: thresholds.warningThreshold,
                criticalThreshold: thresholds.criticalThreshold
            )
            state[key] = windowState
        }

        state.prune(keeping: Set(candidates.map(\.id)))
        try? await settingsRepository.saveNotificationState(state)
    }

    /// Send threshold notification
    func sendThresholdNotification(
        title: String,
        percentage: Double,
        threshold: UsageThresholdType,
        resetTime: Date
    ) async throws {
        guard await shouldSendNotifications() else { return }

        let content = UNMutableNotificationContent()
        content.title = threshold.title
        content.subtitle = title
        content.body = threshold.body(windowTitle: title, percentage: percentage, resetTime: resetTime)
        content.sound = .default
        content.categoryIdentifier = "usage.threshold"
        content.userInfo = ["threshold": threshold.rawValue, "percentage": percentage]

        let request = UNNotificationRequest(
            identifier: "threshold.\(threshold.rawValue).\(UUID())",
            content: content,
            trigger: nil // Deliver immediately
        )

        try await center.add(request)
    }

    /// Send reset notification
    func sendResetNotification(title: String) async throws {
        guard await shouldSendNotifications() else { return }

        let content = UNMutableNotificationContent()
        content.title = UsageThresholdType.reset.title
        content.subtitle = title
        content.body = UsageThresholdType.reset.body(
            windowTitle: title,
            percentage: 0,
            resetTime: Date()
        )
        content.sound = .default
        content.categoryIdentifier = "usage.reset"

        let request = UNNotificationRequest(
            identifier: "reset.\(UUID())",
            content: content,
            trigger: nil
        )

        try await center.add(request)
    }

    /// Check system notification permissions
    func checkNotificationPermissions() async -> Bool {
        await center.authorizationStatus() == .authorized
    }

    // MARK: - Private Methods

    private func shouldSendNotifications() async -> Bool {
        let systemPermission = await checkNotificationPermissions()
        let settings = await settingsRepository.load()
        return systemPermission && settings.hasNotificationsEnabled
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        NotificationCenter.default.post(name: .openUsagePopover, object: nil)
        completionHandler()
    }
}

extension Notification.Name {
    static let openUsagePopover = Notification.Name("openUsagePopover")
}
