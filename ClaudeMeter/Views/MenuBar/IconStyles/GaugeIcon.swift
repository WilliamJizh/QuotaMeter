//
//  GaugeIcon.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-12-28.
//

import SwiftUI

/// Gauge-style menu bar icon using SF Symbols
struct GaugeIcon: View {
    let remaining: Double
    let status: UsageStatus
    let isLoading: Bool
    let isStale: Bool

    var body: some View {
        HStack(spacing: 4) {
            if isLoading {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(statusColor)
            } else {
                Image(systemName: symbolName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(statusColor)
                    .symbolRenderingMode(.hierarchical)
            }

            if isStale && !isLoading {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 8))
                    .foregroundColor(.gray)
            }
        }
        .frame(height: 22)
        .padding(.horizontal, 4)
        .accessibilityLabel("\(Int(remaining)) percent of quota remaining")
        .accessibilityValue(status.accessibilityDescription)
    }

    /// Needle position reflects how much quota is left: full tank at 100%
    /// remaining, empty at 0%. Colour still comes from `status`, which is driven
    /// by consumption, so the two stay consistent.
    private var symbolName: String {
        switch remaining {
        case ..<10:
            return "gauge.with.dots.needle.0percent"
        case ..<40:
            return "gauge.with.dots.needle.33percent"
        case ..<60:
            return "gauge.with.dots.needle.50percent"
        case ..<85:
            return "gauge.with.dots.needle.67percent"
        default:
            return "gauge.with.dots.needle.100percent"
        }
    }

    private var statusColor: Color {
        isStale ? .gray : status.color
    }
}

#Preview {
    HStack(spacing: 20) {
        GaugeIcon(remaining: 10, status: .safe, isLoading: false, isStale: false)
        GaugeIcon(remaining: 30, status: .safe, isLoading: false, isStale: false)
        GaugeIcon(remaining: 50, status: .warning, isLoading: false, isStale: false)
        GaugeIcon(remaining: 70, status: .warning, isLoading: false, isStale: false)
        GaugeIcon(remaining: 90, status: .critical, isLoading: false, isStale: false)
        GaugeIcon(remaining: 45, status: .safe, isLoading: true, isStale: false)
        GaugeIcon(remaining: 45, status: .safe, isLoading: false, isStale: true)
    }
    .padding()
}
