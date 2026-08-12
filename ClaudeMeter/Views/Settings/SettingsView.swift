//
//  SettingsView.swift
//  QuotaMeter
//

import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Bindable var appModel: AppModel

    // Connection
    @State private var address: String = ""
    @State private var key: String = ""
    @State private var isKeyShown: Bool = false
    @State private var isConnecting: Bool = false
    @State private var connectionMessage: String?
    @State private var hasConnectionSucceeded: Bool = false

    // Notifications
    @State private var isSendingTestNotification: Bool = false
    @State private var testNotificationMessage: String?
    @State private var hasTestNotificationSucceeded: Bool = false
    @State private var notificationError: String?

    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled

    var body: some View {
        TabView {
            connectionTab
                .tabItem { Label("Connection", systemImage: "network") }
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
            notificationsTab
                .tabItem { Label("Notifications", systemImage: "bell") }
            aboutTab
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 500)
        .onAppear { loadSettings() }
        .onChange(of: appModel.settings.hasNotificationsEnabled) { _, newValue in
            Task {
                if newValue {
                    await appModel.requestNotificationPermissionIfNeeded()
                }
                await refreshNotificationPermissionState()
            }
        }
    }

    // MARK: - Connection

    private var connectionTab: some View {
        Form {
            Section {
                TextField("Server address", text: $address)
                    .disabled(isConnecting)

                HStack(spacing: 6) {
                    Group {
                        if isKeyShown {
                            TextField("Management key", text: $key)
                        } else {
                            SecureField("Management key", text: $key)
                        }
                    }
                    .disabled(isConnecting)

                    Button(action: { isKeyShown.toggle() }) {
                        Image(systemName: isKeyShown ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.plain)
                    .help(isKeyShown ? "Hide management key" : "Show management key")
                }

                HStack(spacing: 8) {
                    Button("Save & Connect") {
                        Task { await connect() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(key.trimmingCharacters(in: .whitespaces).isEmpty || isConnecting)

                    Button("Open Panel") { appModel.openManagementPanel() }

                    if appModel.isSetupComplete {
                        Button("Disconnect", role: .destructive) {
                            Task { await disconnect() }
                        }
                    }

                    if isConnecting {
                        ProgressView().controlSize(.small)
                    }
                }

                if let origin = appModel.keyOrigin, connectionMessage == nil {
                    Label("Key found automatically in \(origin.description)", systemImage: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let connectionMessage {
                    Label(
                        connectionMessage,
                        systemImage: hasConnectionSucceeded ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                    )
                    .font(.caption)
                    .foregroundColor(hasConnectionSucceeded ? .green : .orange)
                    .fixedSize(horizontal: false, vertical: true)
                }
            } header: {
                Text("CLIProxyAPI")
            } footer: {
                Text("QuotaMeter finds this automatically from \(Constants.Management.environmentVariable), ~/.quotameter/management-key, or the daemon's credentials.txt. Set it here only if none of those exist.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let usageData = appModel.usageData, !usageData.accounts.isEmpty {
                Section("Accounts") {
                    ForEach(usageData.sortedAccounts) { account in
                        HStack(spacing: 8) {
                            ProviderLogoView(provider: account.provider, size: 16)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(account.label).font(.callout)
                                Text(account.isFailed ? (account.errorMessage ?? "Failed") : "\(account.provider.displayName)\(account.planLabel.map { " · \($0)" } ?? "")")
                                    .font(.caption)
                                    .foregroundColor(account.isFailed ? .orange : .secondary)
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Section("Refresh") {
                Picker("Interval", selection: refreshIntervalBinding) {
                    Text("5 minutes").tag(TimeInterval(300))
                    Text("10 minutes").tag(TimeInterval(600))
                }
                .pickerStyle(.segmented)

                Text("Anthropic rate-limits its usage endpoint, so QuotaMeter polls no faster than every 5 minutes.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Display") {
                Toggle("Show every sub-limit", isOn: $appModel.settings.areAllWindowsShown)
                    .help("Include model-scoped caps such as Weekly Opus, Weekly Sonnet, and Codex-Spark")

                ForEach(QuotaProvider.allCases, id: \.self) { provider in
                    Toggle("Show \(provider.displayName)", isOn: providerBinding(provider))
                }

                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }
            }

            Section("Menu bar icon") {
                Toggle("Colored icon", isOn: $appModel.settings.isColoredIcon)
                IconStylePicker(
                    selection: $appModel.settings.iconStyle,
                    isColored: appModel.settings.isColoredIcon
                )
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Notifications

    private var notificationsTab: some View {
        Form {
            Section {
                Toggle("Enable notifications", isOn: $appModel.settings.hasNotificationsEnabled)

                if let notificationError {
                    Label(notificationError, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            } footer: {
                Text("Alerts fire per account and per window, so a busy account can't mute the others.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Thresholds") {
                thresholdSlider(
                    title: "Warn below",
                    value: remainingBinding(for: $appModel.settings.notificationThresholds.warningThreshold),
                    range: (100 - Constants.Thresholds.Notification.warningMax)...(100 - Constants.Thresholds.Notification.warningMin)
                )
                thresholdSlider(
                    title: "Critical below",
                    value: remainingBinding(for: $appModel.settings.notificationThresholds.criticalThreshold),
                    range: (100 - Constants.Thresholds.Notification.criticalMax)...(100 - Constants.Thresholds.Notification.criticalMin)
                )
                Toggle("Notify when a window resets", isOn: $appModel.settings.notificationThresholds.isNotifiedOnReset)
            }
            .disabled(!appModel.settings.hasNotificationsEnabled)

            Section {
                HStack(spacing: 8) {
                    Button("Send test notification") {
                        Task { await sendTestNotification() }
                    }
                    .disabled(isSendingTestNotification)

                    if isSendingTestNotification {
                        ProgressView().controlSize(.small)
                    }
                }

                if let testNotificationMessage {
                    Label(
                        testNotificationMessage,
                        systemImage: hasTestNotificationSucceeded ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                    )
                    .font(.caption)
                    .foregroundColor(hasTestNotificationSucceeded ? .green : .orange)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - About

    private var aboutTab: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("QuotaMeter")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("Claude and Codex plan quota in your menu bar.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Text("Usage is read through a local CLIProxyAPI daemon, which handles OAuth refresh for every credential.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Section("Credits") {
                Text("Forked from ClaudeMeter by Edd Mann (MIT).")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Link("github.com/eddmann/ClaudeMeter", destination: URL(string: "https://github.com/eddmann/ClaudeMeter")!)
                    .font(.caption)
                Link("github.com/router-for-me/CLIProxyAPI", destination: URL(string: "https://github.com/router-for-me/CLIProxyAPI")!)
                    .font(.caption)
            }

            Section("Data export") {
                Text("Current usage is written to ~/.quotameter/usage.json for statusline scripts and other tools.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Components

    private func thresholdSlider(title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value.wrappedValue))% left")
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            Slider(
                value: value,
                in: range,
                step: Constants.Thresholds.Notification.step
            )
        }
    }

    // MARK: - Bindings

    private var refreshIntervalBinding: Binding<TimeInterval> {
        Binding(
            get: { AppSettings.clampRefreshInterval(appModel.settings.refreshInterval) },
            set: { appModel.settings.setRefreshInterval($0) }
        )
    }

    /// Thresholds are stored as consumption (what the providers report) but the
    /// UI counts down, so the slider reads and writes the inverse.
    private func remainingBinding(for used: Binding<Double>) -> Binding<Double> {
        Binding(
            get: { 100 - used.wrappedValue },
            set: { used.wrappedValue = 100 - $0 }
        )
    }

    private func providerBinding(_ provider: QuotaProvider) -> Binding<Bool> {
        Binding(
            get: { appModel.settings.isVisible(provider) },
            set: { isVisible in
                var hidden = appModel.settings.hiddenProviders
                if isVisible {
                    hidden.remove(provider)
                } else {
                    hidden.insert(provider)
                }
                appModel.settings.hiddenProviders = hidden
            }
        )
    }

    // MARK: - Actions

    private func loadSettings() {
        address = appModel.settings.managementAddress
        Task {
            key = await appModel.loadManagementKey() ?? ""
            await refreshNotificationPermissionState()
        }
    }

    private func connect() async {
        isConnecting = true
        connectionMessage = nil
        hasConnectionSucceeded = false

        do {
            let entries = try await appModel.connect(address: address, key: key)
            address = appModel.settings.managementAddress
            hasConnectionSucceeded = !entries.isEmpty
            connectionMessage = entries.isEmpty
                ? "Connected, but no Claude or Codex credentials are configured."
                : "Connected. Found \(entries.count) credential\(entries.count == 1 ? "" : "s")."
        } catch {
            hasConnectionSucceeded = false
            connectionMessage = error.localizedDescription
        }

        isConnecting = false
    }

    private func disconnect() async {
        do {
            try await appModel.disconnect()
            key = ""
            connectionMessage = "Disconnected."
            hasConnectionSucceeded = false
        } catch {
            connectionMessage = error.localizedDescription
            hasConnectionSucceeded = false
        }
    }

    private func sendTestNotification() async {
        isSendingTestNotification = true
        testNotificationMessage = nil

        await appModel.requestNotificationPermissionIfNeeded()

        do {
            try await appModel.sendTestNotification()
            hasTestNotificationSucceeded = true
            testNotificationMessage = "Test notification sent."
        } catch {
            hasTestNotificationSucceeded = false
            testNotificationMessage = error.localizedDescription
        }

        await refreshNotificationPermissionState()
        isSendingTestNotification = false
    }

    private func refreshNotificationPermissionState() async {
        let hasPermission = await appModel.checkNotificationPermissions()
        notificationError = (appModel.settings.hasNotificationsEnabled && !hasPermission)
            ? "Notifications are disabled in System Settings for QuotaMeter."
            : nil
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Reflect the real state if the system rejected the change.
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
