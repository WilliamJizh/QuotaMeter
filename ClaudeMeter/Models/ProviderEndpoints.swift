//
//  ProviderEndpoints.swift
//  QuotaMeter
//
//  Upstream usage endpoints, mirroring the management panel's
//  `src/utils/quota/constants.ts`. `$TOKEN$` is substituted by the daemon.
//

import Foundation

enum ProviderEndpoints {
    enum Claude {
        static let usageURL = "https://api.anthropic.com/api/oauth/usage"
        static let profileURL = "https://api.anthropic.com/api/oauth/profile"

        static let headers: [String: String] = [
            "Authorization": "Bearer $TOKEN$",
            "Content-Type": "application/json",
            "anthropic-beta": "oauth-2025-04-20",
        ]
    }

    enum Codex {
        static let usageURL = "https://chatgpt.com/backend-api/wham/usage"

        /// The upstream rejects unrecognised clients, so this pins the same user
        /// agent the daemon uses for Codex traffic.
        static let headers: [String: String] = [
            "Authorization": "Bearer $TOKEN$",
            "Content-Type": "application/json",
            "User-Agent": "codex_cli_rs/0.76.0 (Debian 13.0.0; x86_64) WindowsTerminal",
        ]
    }
}
