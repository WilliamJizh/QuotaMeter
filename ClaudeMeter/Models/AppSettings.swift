//
//  AppSettings.swift
//  QuotaMeter
//

import Foundation

/// User preferences and app configuration
struct AppSettings: Codable, Equatable, Sendable {
    /// Refresh interval in seconds
    var refreshInterval: TimeInterval

    /// Whether notifications are enabled
    var hasNotificationsEnabled: Bool

    /// Notification thresholds
    var notificationThresholds: NotificationThresholds

    /// Whether this is first launch
    var isFirstLaunch: Bool

    /// Address of the CLIProxyAPI daemon, e.g. `http://127.0.0.1:8317`.
    var managementAddress: String

    /// Show model-scoped sub-limits (Opus, Sonnet, Codex-Spark) alongside the
    /// primary windows.
    var areAllWindowsShown: Bool

    /// Providers to display. Empty means "all".
    var hiddenProviders: Set<QuotaProvider>

    /// Menu bar icon display style
    var iconStyle: IconStyle

    /// Whether menu bar icons are shown in color instead of monochrome.
    var isColoredIcon: Bool

    static let `default` = AppSettings(
        refreshInterval: Constants.Refresh.minimum,
        hasNotificationsEnabled: true,
        notificationThresholds: .default,
        isFirstLaunch: true,
        managementAddress: Constants.Management.defaultAddress,
        areAllWindowsShown: false,
        hiddenProviders: [],
        iconStyle: .battery,
        isColoredIcon: true
    )

    enum CodingKeys: String, CodingKey {
        case refreshInterval = "refresh_interval"
        case hasNotificationsEnabled = "notifications_enabled"
        case notificationThresholds = "notification_thresholds"
        case isFirstLaunch = "is_first_launch"
        case managementAddress = "management_address"
        case areAllWindowsShown = "show_all_windows"
        case hiddenProviders = "hidden_providers"
        case iconStyle = "icon_style"
        case isColoredIcon = "is_colored_icon"
    }
}

extension AppSettings {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings.default

        refreshInterval = try container.decodeIfPresent(TimeInterval.self, forKey: .refreshInterval) ?? defaults.refreshInterval
        hasNotificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .hasNotificationsEnabled) ?? defaults.hasNotificationsEnabled
        notificationThresholds = try container.decodeIfPresent(NotificationThresholds.self, forKey: .notificationThresholds) ?? defaults.notificationThresholds
        isFirstLaunch = try container.decodeIfPresent(Bool.self, forKey: .isFirstLaunch) ?? defaults.isFirstLaunch
        managementAddress = try container.decodeIfPresent(String.self, forKey: .managementAddress) ?? defaults.managementAddress
        areAllWindowsShown = try container.decodeIfPresent(Bool.self, forKey: .areAllWindowsShown) ?? defaults.areAllWindowsShown
        hiddenProviders = try container.decodeIfPresent(Set<QuotaProvider>.self, forKey: .hiddenProviders) ?? defaults.hiddenProviders
        iconStyle = try container.decodeIfPresent(IconStyle.self, forKey: .iconStyle) ?? defaults.iconStyle
        isColoredIcon = try container.decodeIfPresent(Bool.self, forKey: .isColoredIcon) ?? defaults.isColoredIcon

        // A settings file written before the rate-limit floor was raised can carry
        // an interval that now gets us throttled.
        refreshInterval = Self.clampRefreshInterval(refreshInterval)
    }
}

extension AppSettings {
    static func clampRefreshInterval(_ interval: TimeInterval) -> TimeInterval {
        max(Constants.Refresh.minimum, min(Constants.Refresh.maximum, interval))
    }

    /// Validate refresh interval is within bounds
    mutating func setRefreshInterval(_ interval: TimeInterval) {
        refreshInterval = Self.clampRefreshInterval(interval)
    }

    func isVisible(_ provider: QuotaProvider) -> Bool {
        !hiddenProviders.contains(provider)
    }
}
