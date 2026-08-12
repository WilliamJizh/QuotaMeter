//
//  SetupWizardView.swift
//  QuotaMeter
//

import AppKit
import SwiftUI

/// First-run connection screen. QuotaMeter reads quota through a local
/// CLIProxyAPI daemon, so all it needs is that daemon's address and key.
struct SetupWizardView: View {
    @Bindable var appModel: AppModel

    @State private var address: String = Constants.Management.defaultAddress
    @State private var key: String = ""
    @State private var isConnecting: Bool = false
    @State private var errorMessage: String?
    @State private var discovered: [AuthFileEntry] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            VStack(alignment: .leading, spacing: 8) {
                Text("Server address")
                    .font(.callout)
                    .fontWeight(.medium)
                TextField(Constants.Management.defaultAddress, text: $address)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isConnecting)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Management key")
                    .font(.callout)
                    .fontWeight(.medium)
                SecureField("Your remote-management secret-key", text: $key)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isConnecting)
                    .onSubmit { connect() }
                Text("From `remote-management.secret-key` in the daemon's config.yaml.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !discovered.isEmpty {
                Label(
                    "Found \(discovered.count) credential\(discovered.count == 1 ? "" : "s")",
                    systemImage: "checkmark.circle.fill"
                )
                .font(.caption)
                .foregroundColor(.green)
            }

            Spacer(minLength: 0)

            HStack {
                Button("Open Panel") { openPanel() }
                    .buttonStyle(.plain)
                    .help("Open the daemon's web management panel")

                Spacer()

                if isConnecting {
                    ProgressView().controlSize(.small)
                }

                Button("Connect") { connect() }
                    .buttonStyle(.borderedProminent)
                    .disabled(key.trimmingCharacters(in: .whitespaces).isEmpty || isConnecting)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 340, height: 400)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "gauge.with.dots.needle.67percent")
                .font(.system(size: 28))
                .foregroundColor(.accentColor)
            Text("Connect to CLIProxyAPI")
                .font(.title3)
                .fontWeight(.bold)
            Text("QuotaMeter reads Claude and Codex plan usage through your local CLIProxyAPI daemon.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func connect() {
        guard !isConnecting else { return }
        isConnecting = true
        errorMessage = nil
        discovered = []

        Task {
            do {
                discovered = try await appModel.connect(address: address, key: key)
                if discovered.isEmpty {
                    errorMessage = "Connected, but no Claude or Codex credentials are configured."
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isConnecting = false
        }
    }

    private func openPanel() {
        guard let base = URL(string: address.contains("://") ? address : "http://\(address)"),
              let url = URL(string: Constants.Management.panelPath, relativeTo: base) else { return }
        NSWorkspace.shared.open(url)
    }
}
