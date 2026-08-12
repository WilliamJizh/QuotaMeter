//
//  MenuBarIconView.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-11-14.
//

import SwiftUI

/// SwiftUI view for menu bar icon with configurable style
struct MenuBarIconView: View {
    let remaining: Double
    let status: UsageStatus
    let isLoading: Bool
    let isStale: Bool
    let iconStyle: IconStyle
    var secondaryRemaining: Double = 0  // Optional, used by dualBar style

    var body: some View {
        switch iconStyle {
        case .battery:
            BatteryIcon(remaining: remaining, status: status, isLoading: isLoading, isStale: isStale)
        case .circular:
            CircularGaugeIcon(remaining: remaining, status: status, isLoading: isLoading, isStale: isStale)
        case .minimal:
            MinimalIcon(remaining: remaining, status: status, isLoading: isLoading, isStale: isStale)
        case .segments:
            SegmentedBarIcon(remaining: remaining, status: status, isLoading: isLoading, isStale: isStale)
        case .dualBar:
            DualBarIcon(remaining: remaining, secondaryRemaining: secondaryRemaining, status: status, isLoading: isLoading, isStale: isStale)
        case .gauge:
            GaugeIcon(remaining: remaining, status: status, isLoading: isLoading, isStale: isStale)
        }
    }
}

// MARK: - Preview

#Preview("All Styles") {
    VStack(alignment: .leading, spacing: 12) {
        ForEach(IconStyle.allCases) { style in
            HStack {
                Text(style.displayName)
                    .frame(width: 80, alignment: .leading)
                MenuBarIconView(remaining: 65, status: .warning, isLoading: false, isStale: false, iconStyle: style, secondaryRemaining: 45)
            }
        }
    }
    .padding()
}

#Preview("Battery States") {
    VStack(spacing: 20) {
        MenuBarIconView(remaining: 35, status: .safe, isLoading: false, isStale: false, iconStyle: .battery)
        MenuBarIconView(remaining: 65, status: .warning, isLoading: false, isStale: false, iconStyle: .battery)
        MenuBarIconView(remaining: 92, status: .critical, isLoading: false, isStale: false, iconStyle: .battery)
        MenuBarIconView(remaining: 45, status: .safe, isLoading: true, isStale: false, iconStyle: .battery)
        MenuBarIconView(remaining: 45, status: .safe, isLoading: false, isStale: true, iconStyle: .battery)
    }
    .padding()
}
