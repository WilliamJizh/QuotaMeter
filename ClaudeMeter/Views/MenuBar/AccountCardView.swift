//
//  AccountCardView.swift
//  QuotaMeter
//

import SwiftUI

/// One credential's container: provider badge, plan tier, and every quota bar
/// for that account stacked inside a single card.
///
/// The cards themselves are what gets gridded — see `UsagePopoverView`.
struct AccountCardView: View {
    let account: AccountUsage
    let showsAllWindows: Bool
    /// Supplied by the grid so cards in a row match; nil sizes to content.
    var fixedHeight: CGFloat?

    private var visibleWindows: [UsageWindow] {
        showsAllWindows ? account.windows : account.primaryWindows
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header

            if let errorMessage = account.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            } else if visibleWindows.isEmpty {
                Text("No quota windows reported.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(visibleWindows) { window in
                        WindowRowView(window: window)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: fixedHeight, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(9)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(account.provider.displayName) account \(account.label)")
    }

    /// Drops the domain from an email so two accounts differing only by their
    /// local part stay distinguishable in a narrow card. Full address on hover.
    static func shortLabel(for label: String) -> String {
        guard let at = label.firstIndex(of: "@") else { return label }
        let local = String(label[label.startIndex..<at])
        return local.isEmpty ? label : local
    }

    private var header: some View {
        HStack(spacing: 5) {
            ProviderLogoView(provider: account.provider, size: 12)

            Text(Self.shortLabel(for: account.label))
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)
                .help(account.label)

            Spacer(minLength: 3)

            if let planLabel = account.planLabel {
                Text(planLabel)
                    .font(.system(size: 9, weight: .medium))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(account.provider.accentColor.opacity(0.15))
                    .foregroundColor(account.provider.accentColor)
                    .cornerRadius(4)
                    .fixedSize()
            }
        }
    }
}

/// A single quota window: label, countdown, percentage, and its bar.
///
/// Deliberately has no background of its own — the account card is the
/// container, so the bars read as one grouped set rather than separate tiles.
struct WindowRowView: View {
    let window: UsageWindow

    private var limit: UsageLimit { window.limit }

    private var isAtRisk: Bool {
        guard let duration = window.windowDuration else { return false }
        return limit.isAtRisk(windowDuration: duration)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(window.label)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if isAtRisk {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.orange)
                        .accessibilityLabel("At risk of hitting limit")
                }

                Spacer(minLength: 2)

                Text(limit.compactResetDescription)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.7))
                    .fixedSize()

                Text("\(Int(limit.remaining))%")
                    .font(.system(size: 10, weight: .semibold))
                    .monospacedDigit()
                    .foregroundColor(limit.status.color)
                    .fixedSize()
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
        }
        .help("\(window.label) — resets \(limit.resetDescription) (\(limit.resetTimeFormatted))")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(window.label): \(Int(limit.remaining))% remaining, \(limit.status.accessibilityDescription)")
        .accessibilityValue("Resets \(limit.resetDescription)")
    }
}

// MARK: - Preview

#Preview {
    let windows = [
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
    ]

    return LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 8)], spacing: 8) {
        AccountCardView(
            account: AccountUsage(
                id: "a", provider: .claude, label: "someone@example.com",
                planLabel: "Max", windows: windows, errorMessage: nil
            ),
            showsAllWindows: false
        )
        AccountCardView(
            account: AccountUsage(
                id: "b", provider: .codex, label: "someone@example.com",
                planLabel: "ProLite", windows: Array(windows.prefix(1)), errorMessage: nil
            ),
            showsAllWindows: false
        )
    }
    .padding()
    .frame(width: 420)
}
