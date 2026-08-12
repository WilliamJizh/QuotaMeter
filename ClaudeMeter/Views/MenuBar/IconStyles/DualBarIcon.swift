//
//  DualBarIcon.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-12-28.
//

import SwiftUI

/// Dual bar menu bar icon showing session (top) and weekly (bottom) usage
struct DualBarIcon: View {
    let remaining: Double        // Session remaining
    let secondaryRemaining: Double  // Weekly remaining
    let status: UsageStatus
    let isLoading: Bool
    let isStale: Bool

    private let barWidth: CGFloat = 32
    private let barHeight: CGFloat = 5
    private let barSpacing: CGFloat = 2

    var body: some View {
        HStack(spacing: 4) {
            if isLoading {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(statusColor)
            } else {
                // Two stacked progress bars
                VStack(spacing: barSpacing) {
                    // Session bar (top) - blue/cyan
                    ProgressBar(
                        remaining: remaining,
                        color: sessionBarColor,
                        isStale: isStale
                    )
                    .frame(width: barWidth, height: barHeight)

                    // Weekly bar (bottom) - purple
                    ProgressBar(
                        remaining: secondaryRemaining,
                        color: weeklyBarColor,
                        isStale: isStale
                    )
                    .frame(width: barWidth, height: barHeight)
                }

                // Show session remaining (primary metric)
                Text("\(Int(remaining))%")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(statusColor)
            }

            if isStale && !isLoading {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 8))
                    .foregroundColor(.gray)
            }
        }
        .frame(height: 22)
        .padding(.horizontal, 4)
        .accessibilityLabel("\(Int(remaining)) percent remaining, \(Int(secondaryRemaining)) percent remaining on the next limit")
        .accessibilityValue(status.accessibilityDescription)
    }

    private var statusColor: Color {
        isStale ? .gray : status.color
    }

    private var sessionBarColor: Color {
        if isStale { return .gray }
        // Use status color for session bar
        return status.color
    }

    private var weeklyBarColor: Color {
        if isStale { return .gray }
        // Purple/violet for weekly to distinguish from session
        return .purple
    }
}

/// Individual progress bar component
private struct ProgressBar: View {
    let remaining: Double
    let color: Color
    let isStale: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.gray.opacity(0.3))

                // Fill
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(color)
                    .frame(width: geo.size.width * min(remaining / 100, 1.0))
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 20) {
            DualBarIcon(remaining: 35, secondaryRemaining: 20, status: .safe, isLoading: false, isStale: false)
            DualBarIcon(remaining: 65, secondaryRemaining: 45, status: .warning, isLoading: false, isStale: false)
            DualBarIcon(remaining: 92, secondaryRemaining: 78, status: .critical, isLoading: false, isStale: false)
        }
        HStack(spacing: 20) {
            DualBarIcon(remaining: 45, secondaryRemaining: 30, status: .safe, isLoading: true, isStale: false)
            DualBarIcon(remaining: 45, secondaryRemaining: 30, status: .safe, isLoading: false, isStale: true)
        }
    }
    .padding()
}
