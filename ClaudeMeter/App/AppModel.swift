//
//  AppModel.swift
//  QuotaMeter
//

import AppKit
import Foundation
import Observation

/// Main application model for SwiftUI-first architecture.
@MainActor
@Observable
final class AppModel {
    // MARK: - Published State

    var settings: AppSettings = .default {
        didSet {
            guard hasLoadedSettings else { return }
            scheduleSettingsSave(previous: oldValue)
        }
    }

    var usageData: UsageData?
    var isLoading: Bool = false
    var isRefreshing: Bool = false
    var errorMessage: String?
    var isSetupComplete: Bool = false

    /// Where the active management key was found, shown in Settings.
    var keyOrigin: ManagementKeyOrigin?
    var isReady: Bool = false

    // MARK: - Dependencies

    @ObservationIgnored private let settingsRepository: SettingsRepositoryProtocol
    @ObservationIgnored private let keyStore: ManagementKeyStoreProtocol
    @ObservationIgnored private let usageService: UsageServiceProtocol
    @ObservationIgnored private let notificationService: NotificationServiceProtocol

    // MARK: - Private

    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var settingsSaveTask: Task<Void, Never>?
    @ObservationIgnored private var wakeTask: Task<Void, Never>?
    @ObservationIgnored private var hasLoadedSettings: Bool = false
    @ObservationIgnored private let refreshClock = ContinuousClock()

    // MARK: - Initialization

    init(
        settingsRepository: SettingsRepositoryProtocol = SettingsRepository(),
        keyStore: ManagementKeyStoreProtocol = ManagementKeyStore(),
        usageService: UsageServiceProtocol? = nil,
        notificationService: NotificationServiceProtocol? = nil
    ) {
        self.settingsRepository = settingsRepository
        self.keyStore = keyStore

        let transport = ManagementTransport()
        let cacheRepository = CacheRepository()
        self.usageService = usageService ?? UsageService(
            transport: transport,
            cacheRepository: cacheRepository,
            keyStore: keyStore,
            settingsRepository: settingsRepository
        )
        self.notificationService = notificationService ?? NotificationService(
            settingsRepository: settingsRepository
        )

        self.notificationService.setupDelegate()
    }

    // MARK: - Lifecycle

    func bootstrap() async {
        guard !isReady else { return }
        settings = await settingsRepository.load()
        hasLoadedSettings = true

        let resolved = await keyStore.resolve()
        keyOrigin = resolved?.origin
        isSetupComplete = resolved != nil
        isReady = true

        if isSetupComplete {
            // Ask up front: without this the threshold flags never arm and alerts
            // silently never fire until the user happens to open Settings.
            if settings.hasNotificationsEnabled {
                await requestNotificationPermissionIfNeeded()
            }
            await refreshUsage(forceRefresh: true)
            startRefreshLoop()
        }

        startWakeObserver()
    }

    // MARK: - Usage

    func refreshUsage(forceRefresh: Bool = false) async {
        guard isSetupComplete else {
            usageData = nil
            return
        }
        guard !isRefreshing else { return }

        if usageData == nil {
            isLoading = true
        }
        isRefreshing = true
        errorMessage = nil

        defer {
            isLoading = false
            isRefreshing = false
        }

        do {
            let data = try await usageService.fetchUsage(forceRefresh: forceRefresh)
            usageData = data
            await notificationService.evaluateThresholds(usageData: data, settings: settings)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Connection

    /// Validates an address/key pair against the daemon and, if it works, stores
    /// the key and starts polling.
    /// - Returns: the credentials the daemon exposed, for the setup summary.
    @discardableResult
    func connect(address: String, key: String) async throws -> [AuthFileEntry] {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { throw AppError.notConfigured }

        let endpoint = try ManagementEndpoint(rawAddress: address, key: trimmedKey)
        let entries = try await usageService.probeEndpoint(endpoint)

        try await keyStore.save(trimmedKey)
        await usageService.invalidateCredentialCache()
        keyOrigin = await keyStore.resolve()?.origin

        settings.managementAddress = endpoint.baseURL.absoluteString
        settings.isFirstLaunch = false
        isSetupComplete = true

        await refreshUsage(forceRefresh: true)
        startRefreshLoop()

        return entries
    }

    func loadManagementKey() async -> String? {
        await keyStore.resolve()?.key
    }

    func disconnect() async throws {
        try await keyStore.clear()
        await usageService.invalidateCredentialCache()
        keyOrigin = nil
        settings.isFirstLaunch = true
        isSetupComplete = false
        usageData = nil
        errorMessage = nil
        refreshTask?.cancel()
    }

    /// Opens the daemon's bundled web panel, which is where credential problems
    /// actually get fixed.
    func openManagementPanel() {
        guard let base = URL(string: settings.managementAddress),
              let url = URL(string: Constants.Management.panelPath, relativeTo: base) else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Notifications

    func requestNotificationPermissionIfNeeded() async {
        let hasPermission = await notificationService.checkNotificationPermissions()
        if !hasPermission {
            _ = try? await notificationService.requestAuthorization()
        }
    }

    func checkNotificationPermissions() async -> Bool {
        await notificationService.checkNotificationPermissions()
    }

    func sendTestNotification() async throws {
        try await notificationService.sendThresholdNotification(
            title: "Claude · 5-hour session",
            percentage: 85.0,
            threshold: .warning,
            resetTime: Date().addingTimeInterval(3600)
        )
    }

    // MARK: - Private

    private func scheduleSettingsSave(previous: AppSettings) {
        settingsSaveTask?.cancel()
        settingsSaveTask = Task {
            try? await settingsRepository.save(settings)
        }

        if previous.refreshInterval != settings.refreshInterval {
            startRefreshLoop()
        }
    }

    private func startRefreshLoop() {
        refreshTask?.cancel()
        guard isSetupComplete else { return }

        let interval = Duration.seconds(Int(settings.refreshInterval))
        refreshTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await self.refreshClock.sleep(for: interval)
                await self.refreshUsage()
            }
        }
    }

    private func startWakeObserver() {
        wakeTask?.cancel()
        wakeTask = Task { [weak self] in
            guard let self else { return }
            for await _ in NSWorkspace.shared.notificationCenter.notifications(named: NSWorkspace.didWakeNotification) {
                await self.refreshUsage(forceRefresh: true)
            }
        }
    }
}
