//
//  CircularGaugeIcon.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-12-28.
//

import SwiftUI

/// Circular gauge (donut) style menu bar icon
struct CircularGaugeIcon: View {
    let remaining: Double
    let status: UsageStatus
    let isLoading: Bool
    let isStale: Bool

    private let lineWidth: CGFloat = 3
    private let size: CGFloat = 18

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: lineWidth)

            // Progress arc
            Circle()
                .trim(from: 0, to: min(remaining / 100, 1.0))
                .stroke(statusColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            // Center remaining or loading indicator
            if isLoading {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(statusColor)
            } else {
                Text("\(Int(remaining))")
                    .font(.system(size: 7, weight: .bold, design: .rounded))
                    .foregroundColor(statusColor)
            }
        }
        .frame(width: size, height: size)
        .overlay(alignment: .topTrailing) {
            if isStale && !isLoading {
                Circle()
                    .fill(Color.gray)
                    .frame(width: 4, height: 4)
                    .offset(x: 2, y: -2)
            }
        }
        .frame(height: 22)
        .padding(.horizontal, 4)
        .accessibilityLabel("\(Int(remaining)) percent of quota remaining")
        .accessibilityValue(status.accessibilityDescription)
    }

    private var statusColor: Color {
        isStale ? .gray : status.color
    }
}

#Preview {
    HStack(spacing: 20) {
        CircularGaugeIcon(remaining: 35, status: .safe, isLoading: false, isStale: false)
        CircularGaugeIcon(remaining: 65, status: .warning, isLoading: false, isStale: false)
        CircularGaugeIcon(remaining: 92, status: .critical, isLoading: false, isStale: false)
        CircularGaugeIcon(remaining: 45, status: .safe, isLoading: true, isStale: false)
        CircularGaugeIcon(remaining: 45, status: .safe, isLoading: false, isStale: true)
    }
    .padding()
}
