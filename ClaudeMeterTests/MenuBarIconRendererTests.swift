//
//  MenuBarIconRendererTests.swift
//  ClaudeMeterTests
//
//  Created by Edd on 2026-01-09.
//

import XCTest
@testable import QuotaMeter

@MainActor
final class MenuBarIconRendererTests: XCTestCase {
    func test_menuBarIconRendersForAllStyles() {
        let renderer = MenuBarIconRenderer()

        for style in IconStyle.allCases {
            let image = renderer.render(
                remaining: TestConstants.iconRemaining,
                status: .safe,
                isLoading: false,
                isStale: false,
                iconStyle: style,
                secondaryRemaining: TestConstants.secondaryRemaining
            )

            XCTAssertGreaterThan(image.size.width, 0)
            XCTAssertGreaterThan(image.size.height, 0)
        }
    }

    func test_menuBarIconRendersWhenLoadingOrStale() {
        let renderer = MenuBarIconRenderer()

        let loadingImage = renderer.render(
            remaining: TestConstants.iconRemaining,
            status: .safe,
            isLoading: true,
            isStale: false,
            iconStyle: .battery,
            secondaryRemaining: TestConstants.secondaryRemaining
        )

        let staleImage = renderer.render(
            remaining: TestConstants.iconRemaining,
            status: .safe,
            isLoading: false,
            isStale: true,
            iconStyle: .battery,
            secondaryRemaining: TestConstants.secondaryRemaining
        )

        XCTAssertGreaterThan(loadingImage.size.width, 0)
        XCTAssertGreaterThan(loadingImage.size.height, 0)
        XCTAssertGreaterThan(staleImage.size.width, 0)
        XCTAssertGreaterThan(staleImage.size.height, 0)
    }

    func test_menuBarIconIsRenderedAsNonTemplateImage() {
        let renderer = MenuBarIconRenderer()

        let image = renderer.render(
            remaining: TestConstants.iconRemaining,
            status: .safe,
            isLoading: false,
            isStale: false,
            iconStyle: .battery,
            secondaryRemaining: TestConstants.secondaryRemaining
        )

        XCTAssertFalse(image.isTemplate)
    }

    func test_menuBarIconIsRenderedAsTemplateImageWhenMonochromeModeSelected() {
        let renderer = MenuBarIconRenderer()

        let image = renderer.render(
            remaining: TestConstants.iconRemaining,
            status: .safe,
            isLoading: false,
            isStale: false,
            iconStyle: .battery,
            secondaryRemaining: TestConstants.secondaryRemaining,
            isColored: false
        )

        XCTAssertTrue(image.isTemplate)
    }

    func test_menuBarIconIsRenderedAsNonTemplateImageWhenColorModeSelected() {
        let renderer = MenuBarIconRenderer()

        let image = renderer.render(
            remaining: TestConstants.iconRemaining,
            status: .safe,
            isLoading: false,
            isStale: false,
            iconStyle: .battery,
            secondaryRemaining: TestConstants.secondaryRemaining,
            isColored: true
        )

        XCTAssertFalse(image.isTemplate)
    }
}
