//
//  PopoverLayoutTests.swift
//  ClaudeMeterTests
//

import AppKit
import SwiftUI
import XCTest
@testable import QuotaMeter

/// Guards the account grid. Layout regressions here are silent — the popover
/// still renders, it just stops fitting — so heights are asserted directly.
///
/// Card heights are computed by `PopoverMetrics` rather than left to the layout
/// system, so the critical test is that the arithmetic still matches what
/// SwiftUI actually draws.
@MainActor
final class PopoverLayoutTests: XCTestCase {
    private static let cardWidth: CGFloat = 197  // one column at 420pt

    private func account(
        provider: QuotaProvider = .claude,
        label: String = "someone@example.com",
        windows: [(String, Double)]
    ) -> AccountUsage {
        AccountUsage(
            id: label,
            provider: provider,
            label: label,
            planLabel: "Max",
            windows: windows.map { name, used in
                UsageWindow(
                    id: name,
                    label: name,
                    limit: UsageLimit(utilization: used, resetAt: Date().addingTimeInterval(13 * 3600)),
                    windowDuration: Constants.Pacing.weeklyWindow,
                    isPrimary: true
                )
            },
            errorMessage: nil
        )
    }

    private func renderedHeight(_ account: AccountUsage, fixedHeight: CGFloat? = nil) throws -> CGFloat {
        let view = AccountCardView(account: account, showsAllWindows: false, fixedHeight: fixedHeight)
            .frame(width: Self.cardWidth)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return try XCTUnwrap(renderer.nsImage).size.height
    }

    // MARK: - Metrics match reality

    /// The whole design depends on the computed height matching the drawn one.
    func test_computedCardHeightMatchesRenderedHeight() throws {
        for count in 1...4 {
            let windows = (0..<count).map { ("Window \($0)", Double($0) * 20) }
            let rendered = try renderedHeight(account(windows: windows))
            let computed = PopoverMetrics.cardHeight(windowCount: count)

            XCTAssertEqual(
                rendered, computed, accuracy: 6,
                "PopoverMetrics drifted from the real layout at \(count) window(s)"
            )
        }
    }

    /// Bars stack inside one container, so each extra bar adds one bar's height.
    func test_eachAdditionalBarAddsOneRowOfHeight() {
        let one = PopoverMetrics.cardHeight(windowCount: 1)
        let two = PopoverMetrics.cardHeight(windowCount: 2)
        let three = PopoverMetrics.cardHeight(windowCount: 3)

        XCTAssertEqual(one, 63, accuracy: 0.5)
        XCTAssertEqual(two - one, 24, accuracy: 0.5)
        XCTAssertEqual(three - two, 24, accuracy: 0.5)
    }

    /// Cards in a row are given the row's height, so they share a bottom edge.
    func test_cardsInARowRenderAtTheSameHeight() throws {
        let rowHeight = PopoverMetrics.cardHeight(windowCount: 3)

        let tall = try renderedHeight(account(windows: [("a", 1), ("b", 2), ("c", 3)]), fixedHeight: rowHeight)
        let short = try renderedHeight(account(windows: [("a", 1)]), fixedHeight: rowHeight)

        XCTAssertEqual(tall, short, accuracy: 1, "Cards in a row stair-step")
    }

    // MARK: - Popover sizing

    func test_popoverGrowsWithMoreRows() {
        let oneRow = PopoverMetrics.popoverHeight(windowCountsPerRow: [3])
        let twoRows = PopoverMetrics.popoverHeight(windowCountsPerRow: [3, 3])

        XCTAssertGreaterThan(twoRows, oneRow)
    }

    /// Two accounts must not leave a screen of empty space.
    func test_smallAccountSetGetsAShortPopover() {
        let height = PopoverMetrics.popoverHeight(windowCountsPerRow: [3])

        XCTAssertLessThan(height, 260)
        XCTAssertGreaterThanOrEqual(height, PopoverMetrics.minPopoverHeight)
    }

    /// Many accounts scroll rather than growing off-screen.
    func test_popoverIsClampedForManyAccounts() {
        let height = PopoverMetrics.popoverHeight(windowCountsPerRow: Array(repeating: 4, count: 20))

        XCTAssertEqual(height, PopoverMetrics.maxPopoverHeight)
    }

    /// Four accounts — two rows — fit without scrolling.
    func test_fourAccountsFitWithoutScrolling() {
        let height = PopoverMetrics.popoverHeight(windowCountsPerRow: [3, 2])

        XCTAssertLessThanOrEqual(height, PopoverMetrics.maxPopoverHeight)
        XCTAssertLessThan(height, 340)
    }

    // MARK: - Header

    /// Middle truncation rendered two accounts on one domain identically; the
    /// local part is what tells them apart.
    func test_shortLabelKeepsTheDistinguishingPart() {
        XCTAssertEqual(AccountCardView.shortLabel(for: "doppelmejoul@gmail.com"), "doppelmejoul")
        XCTAssertEqual(AccountCardView.shortLabel(for: "doppelmejoul1@gmail.com"), "doppelmejoul1")
        XCTAssertNotEqual(
            AccountCardView.shortLabel(for: "doppelmejoul@gmail.com"),
            AccountCardView.shortLabel(for: "doppelmejoul1@gmail.com")
        )
    }

    func test_shortLabelLeavesNonEmailsAlone() {
        XCTAssertEqual(AccountCardView.shortLabel(for: "work-account"), "work-account")
        XCTAssertEqual(AccountCardView.shortLabel(for: "@only-domain"), "@only-domain")
    }

    func test_longWindowLabelDoesNotStretchTheCard() throws {
        let view = AccountCardView(
            account: account(provider: .codex, windows: [("GPT-5.3-Codex-Spark · Weekly", 0), ("Weekly", 26)]),
            showsAllWindows: false,
            fixedHeight: nil
        ).frame(width: Self.cardWidth)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2

        let size = try XCTUnwrap(renderer.nsImage).size
        XCTAssertEqual(size.width, Self.cardWidth, accuracy: 1)
        XCTAssertEqual(size.height, PopoverMetrics.cardHeight(windowCount: 2), accuracy: 6)
    }

    func test_compactResetDescriptionStaysShort() {
        let cases: [(TimeInterval, String)] = [
            (45 * 60, "45m"), (5 * 3600, "5h"), (13 * 3600, "13h"),
            (6 * 86400 + 18 * 3600, "6d 18h"), (7 * 86400, "7d"),
        ]

        for (offset, expected) in cases {
            let limit = UsageLimit(utilization: 0, resetAt: Date().addingTimeInterval(offset))
            XCTAssertEqual(limit.compactResetDescription, expected)
        }
    }
}
