//
//  AccountCardView.swift
//  QuotaMeter
//

import SwiftUI

/// One credential's card: provider badge, plan tier, and a grid of its windows.
struct AccountCardView: View {
    let account: AccountUsage
    let showsAllWindows: Bool

    /// Two columns at the popover's width, more if it ever gets wider. Stacking
    /// windows full-width meant barely two accounts fit on screen.
    private let columns = [GridItem(.adaptive(minimum: 132), spacing: 6)]

    private var visibleWindows: [UsageWindow] {
        showsAllWindows ? account.windows : account.primaryWindows
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header

            if let errorMessage = account.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            } else if visibleWindows.isEmpty {
                Text("No quota windows reported.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 5) {
                    ForEach(visibleWindows) { window in
                        WindowCellView(window: window)
                    }
                }
            }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(9)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(account.provider.displayName) account \(account.label)")
    }

    private var header: some View {
        HStack(spacing: 5) {
            ProviderLogoView(provider: account.provider, size: 12)

            Text(account.label)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 4)

            if let planLabel = account.planLabel {
                Text(planLabel)
                    .font(.system(size: 9, weight: .medium))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(account.provider.accentColor.opacity(0.15))
                    .foregroundColor(account.provider.accentColor)
                    .cornerRadius(4)
            }
        }
    }
}

/// A single quota window, compact enough to sit two-up in the popover.
struct WindowCellView: View {
    let window: UsageWindow

    private var limit: UsageLimit { window.limit }

    private var isAtRisk: Bool {
        guard let duration = window.windowDuration else { return false }
        return limit.isAtRisk(windowDuration: duration)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Text(window.label)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 2)

                Text("\(Int(limit.remaining))%")
                    .font(.system(size: 10, weight: .semibold))
                    .monospacedDigit()
                    .foregroundColor(limit.status.color)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.22))
                    Capsule()
                        .fill(limit.status.color)
                        .frame(width: geometry.size.width * min(max(limit.remaining, 0) / 100, 1.0))
                }
            }
            .frame(height: 4)

            HStack(spacing: 2) {
                if isAtRisk {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.orange)
                        .accessibilityLabel("At risk of hitting limit")
                }
                Text(limit.compactResetDescription)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.8))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(6)
        .help("\(window.label) — resets \(limit.resetDescription) (\(limit.resetTimeFormatted))")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(window.label): \(Int(limit.remaining))% remaining, \(limit.status.accessibilityDescription)")
        .accessibilityValue("Resets \(limit.resetDescription)")
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 8) {
        AccountCardView(
            account: AccountUsage(
                id: "a",
                provider: .claude,
                label: "someone@example.com",
                planLabel: "Max",
                windows: [
                    UsageWindow(
                        id: "five_hour", label: "5-hour session",
                        limit: UsageLimit(utilization: 0, resetAt: Date().addingTimeInterval(5 * 3600)),
                        windowDuration: Constants.Pacing.sessionWindow, isPrimary: true
                    ),
                    UsageWindow(
                        id: "seven_day", label: "Weekly",
                        limit: UsageLimit(utilization: 59, resetAt: Date().addingTimeInterval(13 * 3600)),
                        windowDuration: Constants.Pacing.weeklyWindow, isPrimary: true
                    ),
                    UsageWindow(
                        id: "seven_day_fable", label: "Weekly Fable",
                        limit: UsageLimit(utilization: 98, resetAt: Date().addingTimeInterval(13 * 3600)),
                        windowDuration: Constants.Pacing.weeklyWindow, isPrimary: true
                    ),
                ],
                errorMessage: nil
            ),
            showsAllWindows: false
        )
    }
    .padding()
    .frame(width: 340)
}
