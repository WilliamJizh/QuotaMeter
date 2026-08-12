//
//  NotificationServiceSpy.swift
//  ClaudeMeterTests
//

import Foundation
@testable import QuotaMeter

@MainActor
final class NotificationServiceSpy: NotificationServiceProtocol {
    private(set) var lastEvaluatedUsageData: UsageData?
    var hasPermission: Bool = true
    private(set) var requestAuthorizationCallCount: Int = 0
    private(set) var sentThresholdTitle: String?
    private(set) var sentThresholdPercentage: Double?
    private(set) var sentThresholdType: UsageThresholdType?

    func setupDelegate() {}

    func requestAuthorization() async throws -> Bool {
        requestAuthorizationCallCount += 1
        return true
    }

    func evaluateThresholds(usageData: UsageData, settings: AppSettings) async {
        lastEvaluatedUsageData = usageData
    }

    func sendThresholdNotification(
        title: String,
        percentage: Double,
        threshold: UsageThresholdType,
        resetTime: Date
    ) async throws {
        sentThresholdTitle = title
        sentThresholdPercentage = percentage
        sentThresholdType = threshold
    }

    func sendResetNotification(title: String) async throws {}

    func checkNotificationPermissions() async -> Bool {
        hasPermission
    }
}
