//
//  MenuBarIconRenderer.swift
//  ClaudeMeter
//
//  Created by Edd on 2026-01-09.
//

import AppKit
import SwiftUI

/// Renders SwiftUI MenuBarIconView to NSImage using ImageRenderer.
@MainActor
struct MenuBarIconRenderer {
    func render(
        remaining: Double,
        status: UsageStatus,
        isLoading: Bool,
        isStale: Bool,
        iconStyle: IconStyle,
        secondaryRemaining: Double = 0,
        isColored: Bool = true
    ) -> NSImage {
        let iconView = MenuBarIconView(
            remaining: remaining,
            status: status,
            isLoading: isLoading,
            isStale: isStale,
            iconStyle: iconStyle,
            secondaryRemaining: secondaryRemaining
        )

        let renderer = ImageRenderer(content: iconView)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0

        guard let nsImage = renderer.nsImage else {
            return NSImage(
                systemSymbolName: "exclamationmark.triangle",
                accessibilityDescription: "Error"
            ) ?? NSImage()
        }

        nsImage.isTemplate = !isColored
        return nsImage
    }
}
