//
//  IconCache.swift
//  ClaudeMeter
//
//  Created by Edd on 2026-01-09.
//

import AppKit

/// Simple in-memory cache for rendered menu bar icons.
final class IconCache {
    private let cache = NSCache<NSString, NSImage>()

    init() {
        cache.countLimit = Constants.Cache.maxIconCacheSize
    }

    func get(
        remaining: Double,
        status: UsageStatus,
        isLoading: Bool,
        isStale: Bool,
        iconStyle: IconStyle,
        secondaryRemaining: Double,
        isColored: Bool
    ) -> NSImage? {
        cache.object(forKey: cacheKey(
            remaining: remaining,
            status: status,
            isLoading: isLoading,
            isStale: isStale,
            iconStyle: iconStyle,
            secondaryRemaining: secondaryRemaining,
            isColored: isColored
        ))
    }

    func set(
        _ image: NSImage,
        remaining: Double,
        status: UsageStatus,
        isLoading: Bool,
        isStale: Bool,
        iconStyle: IconStyle,
        secondaryRemaining: Double,
        isColored: Bool
    ) {
        cache.setObject(
            image,
            forKey: cacheKey(
                remaining: remaining,
                status: status,
                isLoading: isLoading,
                isStale: isStale,
                iconStyle: iconStyle,
                secondaryRemaining: secondaryRemaining,
                isColored: isColored
            )
        )
    }

    private func cacheKey(
        remaining: Double,
        status: UsageStatus,
        isLoading: Bool,
        isStale: Bool,
        iconStyle: IconStyle,
        secondaryRemaining: Double,
        isColored: Bool
    ) -> NSString {
        let primary = String(format: "%.2f", remaining)
        let secondary = String(format: "%.2f", secondaryRemaining)
        return "\(primary)|\(secondary)|\(status.rawValue)|\(isLoading)|\(isStale)|\(iconStyle.rawValue)|\(isColored)" as NSString
    }
}
