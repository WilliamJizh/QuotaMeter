//
//  MenuBarIconSnapshotRenderer.swift
//  ClaudeMeterTests
//
//  Created by Edd on 2026-01-09.
//

import AppKit
import SwiftUI
@testable import QuotaMeter

@MainActor
enum MenuBarIconSnapshotRenderer {
    static func render(
        remaining: Double,
        secondaryRemaining: Double,
        status: UsageStatus,
        isLoading: Bool,
        isStale: Bool,
        iconStyle: IconStyle
    ) -> NSImage {
        let view = MenuBarIconView(
            remaining: remaining,
            status: status,
            isLoading: isLoading,
            isStale: isStale,
            iconStyle: iconStyle,
            secondaryRemaining: secondaryRemaining
        )
        .fixedSize()

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0
        renderer.isOpaque = false

        guard let image = renderer.nsImage else {
            return NSImage(
                systemSymbolName: "exclamationmark.triangle",
                accessibilityDescription: "Snapshot render failed"
            ) ?? NSImage()
        }

        image.isTemplate = false
        return image
    }
}
