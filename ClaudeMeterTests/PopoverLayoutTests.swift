//
//  PopoverLayoutTests.swift
//  ClaudeMeterTests
//

import AppKit
import SwiftUI
import XCTest
@testable import QuotaMeter

/// Guards the compact grid layout. A regression here is silent — the popover
/// still renders, it just stops fitting anything — so the card's rendered height
/// is asserted directly.
@MainActor
final class PopoverLayoutTests: XCTestCase {
    private static let contentWidth: CGFloat = 320

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

    private func renderedSize(_ account: AccountUsage) throws -> CGSize {
        let view = AccountCardView(account: account, showsAllWindows: false)
            .frame(width: Self.contentWidth)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return try XCTUnwrap(renderer.nsImage).size
    }

    /// Three windows must lay out as 2 + 1, not 3 stacked rows. Stacked, this
    /// card measured ~190pt; as a grid it is ~113pt.
    func test_threeWindowsFitInTwoGridRows() throws {
        let size = try renderedSize(account(windows: [
            ("5-hour session", 0), ("Weekly", 59), ("Weekly Fable", 98),
        ]))

        XCTAssertLessThan(size.height, 135, "Card is taller than a two-row grid should be")
        XCTAssertEqual(size.width, Self.contentWidth, accuracy: 1)
    }

    /// Adding a second window must not add a second row's worth of height.
    func test_secondWindowSharesARowWithTheFirst() throws {
        let one = try renderedSize(account(windows: [("Weekly", 40)]))
        let two = try renderedSize(account(windows: [("Weekly", 40), ("5-hour session", 10)]))

        XCTAssertEqual(one.height, two.height, accuracy: 2, "Second window started a new row")
    }

    /// The whole point of the change: three accounts visible without scrolling.
    /// Renders the real scroll content, spacing and padding included.
    func test_threeAccountsFitInThePopoverWithoutScrolling() throws {
        let accounts = [
            account(label: "one@example.com", windows: [("5-hour session", 0), ("Weekly", 59), ("Weekly Fable", 98)]),
            account(label: "two@example.com", windows: [("5-hour session", 0), ("Weekly", 0), ("Weekly Fable", 0)]),
            account(provider: .codex, label: "three@example.com", windows: [("Weekly", 26)]),
        ]

        let content = VStack(spacing: 6) {
            ForEach(accounts) { AccountCardView(account: $0, showsAllWindows: false) }
        }
        .padding(10)
        .frame(width: 340)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        let height = try XCTUnwrap(renderer.nsImage).size.height

        // 460pt popover minus ~90pt of header, footer and dividers.
        XCTAssertLessThan(height, 370, "Three accounts no longer fit without scrolling")
    }

    func test_longWindowLabelDoesNotStretchTheCard() throws {
        let size = try renderedSize(account(
            provider: .codex,
            windows: [("GPT-5.3-Codex-Spark · Weekly", 0), ("Weekly", 26)]
        ))

        XCTAssertEqual(size.width, Self.contentWidth, accuracy: 1)
        XCTAssertLessThan(size.height, 90)
    }

    func test_compactResetDescriptionStaysShort() {
        let cases: [(TimeInterval, String)] = [
            (45 * 60, "45m"),
            (5 * 3600, "5h"),
            (13 * 3600, "13h"),
            (6 * 86400 + 18 * 3600, "6d 18h"),
            (7 * 86400, "7d"),
        ]

        for (offset, expected) in cases {
            let limit = UsageLimit(utilization: 0, resetAt: Date().addingTimeInterval(offset))
            XCTAssertEqual(limit.compactResetDescription, expected)
        }
    }
}
