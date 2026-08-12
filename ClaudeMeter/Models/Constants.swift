//
//  Constants.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-11-17.
//

import Foundation

/// Application-wide constants
enum Constants {
    /// CLIProxyAPI management API configuration
    enum Management {
        /// Default daemon address. The panel binds localhost by default.
        static let defaultAddress = "http://127.0.0.1:8317"

        /// Environment override for the management key.
        static let environmentVariable = "QUOTAMETER_MANAGEMENT_KEY"

        /// QuotaMeter's own key file, relative to the home directory.
        static let keyDirectoryName = ".quotameter"
        static let keyFileName = "management-key"

        /// Home-relative locations where the daemon's setup may have recorded the
        /// plaintext key. Its own config.yaml is useless here: the value there is
        /// bcrypt-hashed on first start.
        static let daemonCredentialPaths = [
            "cliproxyapi/credentials.txt",
            ".cli-proxy-api/credentials.txt",
        ]

        /// Path of the bundled web panel, offered as a shortcut from the UI.
        static let panelPath = "/management.html"
    }

    /// Cache configuration
    enum Cache {
        /// Memory cache time-to-live (slightly less than minimum refresh interval)
        static let ttl: TimeInterval = 55

        /// Maximum number of cached icons
        static let maxIconCacheSize = 100
    }

    /// Network configuration
    enum Network {
        /// Maximum number of retry attempts for failed requests
        static let maxRetries = 3

        /// Base delay multiplier for exponential backoff (network errors)
        static let backoffBase: Double = 2.0

        /// Base delay multiplier for rate limit backoff (more aggressive)
        static let rateLimitBackoffBase: Double = 3.0
    }

    /// Refresh intervals (in seconds)
    enum Refresh {
        /// Minimum refresh interval.
        ///
        /// Anthropic's usage endpoint rate-limits aggressively, so polling faster
        /// than this earns 429s rather than fresher numbers.
        static let minimum: TimeInterval = 300

        /// Maximum refresh interval
        static let maximum: TimeInterval = 600

        /// Staleness threshold (2x max refresh interval to account for retries/delays)
        static let stalenessThreshold: TimeInterval = 1200
    }

    /// Pacing/risk calculation configuration
    enum Pacing {
        /// 5-hour session window duration
        static let sessionWindow: TimeInterval = 5 * 60 * 60

        /// 7-day weekly window duration
        static let weeklyWindow: TimeInterval = 7 * 24 * 60 * 60

        /// Ratio threshold for "at risk" status (using faster than sustainable)
        static let riskThreshold: Double = 1.2
    }

    /// Usage threshold configuration
    enum Thresholds {
        /// Visual status boundaries (fixed, for icon colors)
        /// These determine when the icon color changes from green → orange → red
        enum Status {
            /// Percentage where warning status begins (orange) - safe is 0..<warningStart
            static let warningStart: Double = 50
            /// Percentage where critical status begins (red) - warning is warningStart..<criticalStart
            static let criticalStart: Double = 80
        }

        /// Notification threshold configuration (user-configurable)
        enum Notification {
            /// Default warning notification threshold
            static let warningDefault: Double = 75
            /// Default critical notification threshold
            static let criticalDefault: Double = 90

            /// Slider bounds for warning threshold setting
            static let warningMin: Double = 50
            static let warningMax: Double = 90

            /// Slider bounds for critical threshold setting
            static let criticalMin: Double = 75
            static let criticalMax: Double = 100

            /// Slider step increment
            static let step: Double = 5
        }
    }
}
