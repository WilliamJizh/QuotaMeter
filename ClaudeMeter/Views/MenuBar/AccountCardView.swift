//
//  AccountCardView.swift
//  QuotaMeter
//

import SwiftUI

/// One credential's card: provider badge, plan tier, and a row per window.
struct AccountCardView: View {
    let account: AccountUsage
    let showsAllWindows: Bool

    private var visibleWindows: [UsageWindow] {
        showsAllWindows ? account.windows : account.primaryWindows
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if let errorMessage = account.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            } else if visibleWindows.isEmpty {
                Text("No quota windows reported.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(visibleWindows) { window in
                        WindowRowView(window: window)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(account.provider.displayName) account \(account.label)")
    }

    private var header: some View {
        HStack(spacing: 6) {
            ProviderLogoView(provider: account.provider)

            Text(account.label)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 4)

            if let planLabel = account.planLabel {
                Text(planLabel)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(account.provider.accentColor.opacity(0.15))
                    .foregroundColor(account.provider.accentColor)
                    .cornerRadius(5)
            }
        }
    }
}

/// A single quota window: label, remaining percentage, bar, reset time.
struct WindowRowView: View {
    let window: UsageWindow

    private var limit: UsageLimit { window.limit }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(window.label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                if let duration = window.windowDuration, limit.isAtRisk(windowDuration: duration) {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .help("You may hit this limit before it resets")
                        .accessibilityLabel("At risk of hitting limit")
                }

                Spacer(minLength: 4)

                Text("\(Int(limit.remaining))% left")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundColor(limit.status.color)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                    Capsule()
                        .fill(limit.status.color)
                        .frame(width: geometry.size.width * min(max(limit.remaining, 0) / 100, 1.0))
                }
            }
            .frame(height: 5)

            Text("Resets \(limit.resetDescription)")
                .font(.caption2)
                .foregroundColor(.secondary)
                .help(limit.resetTimeFormatted)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(window.label): \(Int(limit.remaining))% remaining, \(limit.status.accessibilityDescription)")
        .accessibilityValue("Resets \(limit.resetDescription)")
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        AccountCardView(
            account: AccountUsage(
                id: "a",
                provider: .claude,
                label: "someone@example.com",
                planLabel: "Max",
                windows: [
                    UsageWindow(
                        id: "five_hour",
                        label: "5-hour session",
                        limit: UsageLimit(utilization: 95, resetAt: Date().addingTimeInterval(600)),
                        windowDuration: Constants.Pacing.sessionWindow,
                        isPrimary: true
                    ),
                    UsageWindow(
                        id: "seven_day",
                        label: "Weekly",
                        limit: UsageLimit(utilization: 32, resetAt: Date().addingTimeInterval(86400 * 2)),
                        windowDuration: Constants.Pacing.weeklyWindow,
                        isPrimary: true
                    ),
                ],
                errorMessage: nil
            ),
            showsAllWindows: false
        )

        AccountCardView(
            account: AccountUsage(
                id: "b",
                provider: .codex,
                label: "someone@example.com",
                planLabel: "ProLite",
                windows: [],
                errorMessage: "Credential rejected (401). Re-authenticate it in the management panel."
            ),
            showsAllWindows: false
        )
    }
    .padding()
    .frame(width: 340)
}
