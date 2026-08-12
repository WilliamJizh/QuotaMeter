//
//  SettingsRepositoryTests.swift
//  ClaudeMeterTests
//

import XCTest
@testable import QuotaMeter

final class SettingsRepositoryTests: XCTestCase {
    func test_settingsPersistAcrossLaunches() async throws {
        let suiteName = "SettingsRepositoryTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)
        defer { userDefaults?.removePersistentDomain(forName: suiteName) }

        let repository = SettingsRepository(userDefaults: userDefaults ?? .standard)
        var settings = AppSettings.default
        settings.refreshInterval = 600
        settings.hasNotificationsEnabled = false
        settings.isFirstLaunch = false
        settings.managementAddress = "http://192.168.1.10:8317"
        settings.areAllWindowsShown = true
        settings.hiddenProviders = [.codex]
        settings.iconStyle = .segments
        settings.isColoredIcon = false

        try await repository.save(settings)
        let loaded = await repository.load()

        XCTAssertEqual(loaded, settings)
    }

    func test_settingsDecodingWithoutIsColoredIcon_usesDefault() throws {
        let data = Data("""
        {
          "refresh_interval": 300,
          "notifications_enabled": false,
          "notification_thresholds": {
            "warning_threshold": 70,
            "critical_threshold": 90,
            "notify_on_reset": false
          },
          "is_first_launch": false,
          "icon_style": "segments"
        }
        """.utf8)

        let settings = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertTrue(settings.isColoredIcon)
        XCTAssertEqual(settings.managementAddress, Constants.Management.defaultAddress)
        XCTAssertFalse(settings.areAllWindowsShown)
        XCTAssertTrue(settings.hiddenProviders.isEmpty)
    }

    /// Settings written before the rate-limit floor was raised must not keep
    /// polling every 60s and earning 429s.
    func test_settingsDecodingClampsStaleRefreshInterval() throws {
        let data = Data(#"{"refresh_interval": 60}"#.utf8)

        let settings = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertEqual(settings.refreshInterval, Constants.Refresh.minimum)
    }

    func test_notificationStatePersistsAcrossLaunches() async throws {
        let suiteName = "SettingsRepositoryTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)
        defer { userDefaults?.removePersistentDomain(forName: suiteName) }

        let repository = SettingsRepository(userDefaults: userDefaults ?? .standard)
        var state = NotificationState()
        state["account-1/five_hour"] = NotificationState.Window(
            hasWarningBeenNotified: true,
            hasCriticalBeenNotified: true,
            lastPercentage: 85
        )

        try await repository.saveNotificationState(state)
        let loaded = await repository.loadNotificationState()

        XCTAssertEqual(loaded, state)
    }

    /// Each window tracks its own flags, so a noisy account can't mute another.
    func test_notificationStateIsIsolatedPerWindow() {
        var state = NotificationState()
        state["a/five_hour"] = NotificationState.Window(hasWarningBeenNotified: true, lastPercentage: 90)

        XCTAssertTrue(state["a/five_hour"].hasWarningBeenNotified)
        XCTAssertFalse(state["b/five_hour"].hasWarningBeenNotified)
    }

    func test_notificationStatePrunesRemovedWindows() {
        var state = NotificationState()
        state["a/five_hour"] = NotificationState.Window(lastPercentage: 10)
        state["b/five_hour"] = NotificationState.Window(lastPercentage: 20)

        state.prune(keeping: ["a/five_hour"])

        XCTAssertEqual(Array(state.windows.keys), ["a/five_hour"])
    }
}
