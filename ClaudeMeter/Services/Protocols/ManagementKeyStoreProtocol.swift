//
//  ManagementKeyStoreProtocol.swift
//  QuotaMeter
//

import Foundation

/// Where a resolved management key came from, for display in Settings.
enum ManagementKeyOrigin: Equatable, Sendable {
    /// `QUOTAMETER_MANAGEMENT_KEY` in the environment.
    case environment
    /// QuotaMeter's own key file.
    case keyFile(path: String)
    /// Discovered alongside the daemon's config.
    case daemonCredentials(path: String)

    var description: String {
        switch self {
        case .environment:
            return "environment variable"
        case .keyFile(let path):
            return (path as NSString).abbreviatingWithTildeInPath
        case .daemonCredentials(let path):
            return (path as NSString).abbreviatingWithTildeInPath
        }
    }
}

struct ResolvedManagementKey: Equatable, Sendable {
    let key: String
    let origin: ManagementKeyOrigin
}

/// Supplies the CLIProxyAPI management key without user interaction.
protocol ManagementKeyStoreProtocol: Actor {
    /// Finds a key from the first available source, or nil if none exists.
    func resolve() async -> ResolvedManagementKey?

    /// Persists a key so it resolves on subsequent launches.
    func save(_ key: String) async throws

    /// Removes QuotaMeter's own copy of the key.
    func clear() async throws
}
