//
//  ProviderLogoTests.swift
//  ClaudeMeterTests
//

import AppKit
import XCTest
@testable import QuotaMeter

/// Asset-catalog SVGs fail quietly: a mark that `actool` can't compile shows up
/// as a missing image, and a gradient it can't resolve renders flat black. These
/// tests rasterise each logo and inspect the pixels so neither slips through.
final class ProviderLogoTests: XCTestCase {
    private struct AverageColor {
        let red: Double
        let green: Double
        let blue: Double
        let coverage: Double
    }

    /// Mean colour over opaque pixels, plus what fraction of the canvas is opaque.
    ///
    /// Deliberately draws into a private `CGContext` rather than setting
    /// `NSGraphicsContext.current`: that global is shared across the parallel test
    /// workers, and mutating it here corrupts the menu-bar snapshot renders.
    private func averageColor(of image: NSImage) throws -> AverageColor {
        let side = 64
        var rect = NSRect(x: 0, y: 0, width: side, height: side)
        let cgImage = try XCTUnwrap(image.cgImage(forProposedRect: &rect, context: nil, hints: nil))

        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let context = try XCTUnwrap(
            CGContext(
                data: &pixels,
                width: side,
                height: side,
                bitsPerComponent: 8,
                bytesPerRow: side * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))

        var totals = (r: 0.0, g: 0.0, b: 0.0)
        var opaque = 0

        for index in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Double(pixels[index + 3]) / 255
            guard alpha > 0.5 else { continue }
            // Un-premultiply so a semi-transparent edge doesn't drag the mean toward black.
            totals.r += Double(pixels[index]) / 255 / alpha
            totals.g += Double(pixels[index + 1]) / 255 / alpha
            totals.b += Double(pixels[index + 2]) / 255 / alpha
            opaque += 1
        }

        guard opaque > 0 else {
            return AverageColor(red: 0, green: 0, blue: 0, coverage: 0)
        }

        return AverageColor(
            red: totals.r / Double(opaque),
            green: totals.g / Double(opaque),
            blue: totals.b / Double(opaque),
            coverage: Double(opaque) / Double(side * side)
        )
    }

    func test_bothProviderLogosExistInAssetCatalog() {
        for provider in QuotaProvider.allCases {
            XCTAssertNotNil(
                NSImage(named: provider.assetName),
                "Missing asset \(provider.assetName) for \(provider.displayName)"
            )
        }
    }

    func test_logosRasteriseToVisiblePixels() throws {
        for provider in QuotaProvider.allCases {
            let image = try XCTUnwrap(NSImage(named: provider.assetName))
            let average = try averageColor(of: image)

            XCTAssertGreaterThan(
                average.coverage, 0.05,
                "\(provider.displayName) logo rendered essentially blank"
            )
        }
    }

    /// Claude's mark is brand clay #D97757 — red-dominant, blue-weakest.
    func test_claudeLogoKeepsBrandClayColour() throws {
        let image = try XCTUnwrap(NSImage(named: QuotaProvider.claude.assetName))
        let average = try averageColor(of: image)

        XCTAssertGreaterThan(average.red, average.green)
        XCTAssertGreaterThan(average.green, average.blue)
        XCTAssertGreaterThan(average.red - average.blue, 0.15)
    }

    /// The Codex glyph carries a blue-violet gradient. If `actool` dropped the
    /// gradient the fill collapses to black, which this would catch.
    func test_codexLogoKeepsBlueGradient() throws {
        let image = try XCTUnwrap(NSImage(named: QuotaProvider.codex.assetName))
        let average = try averageColor(of: image)

        XCTAssertGreaterThan(average.blue, average.red)
        XCTAssertGreaterThan(average.blue, 0.3, "Gradient looks flattened to black")
    }

    /// The white backing tile was stripped so the mark sits on the card the same
    /// way Claude's does; a re-added tile would push coverage toward 100%.
    func test_codexLogoHasNoOpaqueBackingTile() throws {
        let image = try XCTUnwrap(NSImage(named: QuotaProvider.codex.assetName))
        let average = try averageColor(of: image)

        XCTAssertLessThan(average.coverage, 0.9, "Codex mark still has a solid background tile")
    }

    func test_logosPreserveVectorRepresentation() throws {
        for provider in QuotaProvider.allCases {
            let image = try XCTUnwrap(NSImage(named: provider.assetName))
            XCTAssertFalse(image.representations.isEmpty)
            XCTAssertGreaterThan(image.size.width, 0)
            XCTAssertGreaterThan(image.size.height, 0)
        }
    }
}
