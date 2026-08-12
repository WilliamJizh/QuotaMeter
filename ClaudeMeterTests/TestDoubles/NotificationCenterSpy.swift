//
//  NotificationCenterSpy.swift
//  ClaudeMeterTests
//
//  Created by Edd on 2026-01-09.
//

import UserNotifications
@testable import QuotaMeter

@MainActor
final class NotificationCenterSpy: UserNotificationCenterProtocol {
    var delegate: UNUserNotificationCenterDelegate?
    var authorizationStatus: UNAuthorizationStatus = .authorized
    var shouldGrantAuthorization: Bool = true
    private(set) var requestedAuthorizationOptions: UNAuthorizationOptions?
    private(set) var addedRequests: [UNNotificationRequest] = []

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        requestedAuthorizationOptions = options
        return shouldGrantAuthorization
    }

    func add(_ request: UNNotificationRequest) async throws {
        addedRequests.append(request)
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        authorizationStatus
    }
}
