//
//  QuotaProvider.swift
//  QuotaMeter
//

import SwiftUI

/// A subscription provider whose plan quota we can read.
enum QuotaProvider: String, Codable, Sendable, CaseIterable {
    case claude
    case codex

    /// Provider identifiers as reported by CLIProxyAPI's auth-files listing.
    init?(authFileProvider: String) {
        switch authFileProvider.lowercased() {
        case "claude", "anthropic": self = .claude
        case "codex", "openai": self = .codex
        default: return nil
        }
    }

    var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .codex: return "Codex"
        }
    }

    /// Asset-catalog name of the provider's own logo. These are the real marks,
    /// vendored from the management panel's icon set, not stand-in SF Symbols.
    var assetName: String {
        switch self {
        case .claude: return "ProviderClaude"
        case .codex: return "ProviderCodex"
        }
    }

    /// Badge tint sampled from each logo: Claude's brand clay, and the midpoint
    /// of the Codex glyph's blue-violet gradient.
    var accentColor: Color {
        switch self {
        case .claude: return Color(red: 0.851, green: 0.467, blue: 0.341)  // #D97757
        case .codex: return Color(red: 0.478, green: 0.616, blue: 1.0)     // #7A9DFF
        }
    }

    /// Display order in the popover.
    var sortIndex: Int {
        switch self {
        case .claude: return 0
        case .codex: return 1
        }
    }
}
