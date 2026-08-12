//
//  UsagePopoverView.swift
//  QuotaMeter
//

import AppKit
import SwiftUI

/// Popover listing every account's quota, tightest constraint first.
struct UsagePopoverView: View {
    @Bindable var appModel: AppModel
    let onRequestClose: (() -> Void)?
    @Environment(\.openSettings) private var openSettings

    private var visibleAccounts: [AccountUsage] {
        (appModel.usageData?.sortedAccounts ?? [])
            .filter { appModel.settings.isVisible($0.provider) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if let errorMessage = appModel.errorMessage {
                errorBanner(errorMessage)
                Divider()
            }

            content

            Divider()
            footer
        }
        .frame(width: 340, height: 480)
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Quota Dashboard")
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Quota")
                    .font(.title3)
                    .fontWeight(.bold)

                if let usageData = appModel.usageData {
                    Text("Updated \(usageData.freshnessDescription)")
                        .font(.caption2)
                        .foregroundColor(usageData.isStale ? .orange : .secondary)
                }
            }

            Spacer()

            Button(action: {
                Task { await appModel.refreshUsage(forceRefresh: true) }
            }) {
                if appModel.isRefreshing {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .buttonStyle(.plain)
            .disabled(appModel.isRefreshing)
            .help("Refresh usage data")
            .keyboardShortcut("r", modifiers: .command)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var content: some View {
        if appModel.isLoading && appModel.usageData == nil {
            VStack(spacing: 12) {
                ProgressView()
                Text("Loading quota…")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if visibleAccounts.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("No accounts to show")
                    .font(.callout)
                Text("Add Claude or Codex credentials in the management panel, or re-enable a provider in Settings.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Button("Open Management Panel") { appModel.openManagementPanel() }
                    .buttonStyle(.bordered)
                    .padding(.top, 4)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(visibleAccounts) { account in
                        AccountCardView(
                            account: account,
                            showsAllWindows: appModel.settings.areAllWindowsShown
                        )
                    }
                }
                .padding(12)
            }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(message)
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Button("Retry") {
                    Task { await appModel.refreshUsage(forceRefresh: true) }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Open Panel") { appModel.openManagementPanel() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
    }

    private var footer: some View {
        HStack {
            Button("Settings") { openSettingsFront() }
                .buttonStyle(.plain)
                .keyboardShortcut(",", modifiers: .command)
                .accessibilityLabel("Open settings window")

            Spacer()

            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .keyboardShortcut("q", modifiers: .command)
                .accessibilityLabel("Quit application")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func openSettingsFront() {
        onRequestClose?()
        if let keyWindow = NSApp.keyWindow, keyWindow.level != .normal {
            keyWindow.orderOut(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
        openSettings()
    }
}
