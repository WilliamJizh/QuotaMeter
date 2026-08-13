//
//  PopoverMetrics.swift
//  QuotaMeter
//

import CoreGraphics

/// Fixed layout arithmetic for the account grid.
///
/// Card heights are computed rather than left to the layout system: neither
/// `LazyVGrid` nor `Grid` stretches a short card to its row's height, so cards
/// in a row stair-step unless they are all given the same explicit height. The
/// same numbers size the popover itself, so the two cannot drift apart.
enum PopoverMetrics {
    static let width: CGFloat = 420
    static let columnCount = 2

    static let gridPadding: CGFloat = 9
    static let gridSpacing: CGFloat = 7

    /// Header, footer and dividers around the scrolling grid.
    static let chrome: CGFloat = 92

    static let minPopoverHeight: CGFloat = 200
    static let maxPopoverHeight: CGFloat = 520

    // Calibrated against real renders (see PopoverLayoutTests): one bar is 63pt
    // of card, and every additional bar adds exactly 24pt.
    private static let cardPadding: CGFloat = 9
    private static let headerHeight: CGFloat = 20
    private static let headerToBars: CGFloat = 6
    /// One window: label line + gap + bar.
    private static let windowHeight: CGFloat = 19
    private static let windowSpacing: CGFloat = 5

    /// Height of a card showing `windowCount` bars.
    static func cardHeight(windowCount: Int) -> CGFloat {
        let bars = max(windowCount, 1)
        let barsHeight = CGFloat(bars) * windowHeight + CGFloat(bars - 1) * windowSpacing
        return cardPadding * 2 + headerHeight + headerToBars + barsHeight
    }

    /// Total popover height for rows described by their tallest card.
    static func popoverHeight(windowCountsPerRow: [Int]) -> CGFloat {
        guard !windowCountsPerRow.isEmpty else { return minPopoverHeight + 60 }

        let cards = windowCountsPerRow.reduce(CGFloat.zero) { $0 + cardHeight(windowCount: $1) }
        let gaps = CGFloat(max(0, windowCountsPerRow.count - 1)) * gridSpacing
        let content = cards + gaps + gridPadding * 2

        return min(maxPopoverHeight, max(minPopoverHeight, chrome + content))
    }
}
