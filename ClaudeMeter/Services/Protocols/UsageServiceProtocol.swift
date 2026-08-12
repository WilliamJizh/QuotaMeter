//
//  UsageServiceProtocol.swift
//  QuotaMeter
//

import Foundation

/// Protocol for aggregating plan quota across every configured credential.
protocol UsageServiceProtocol: Actor {
    /// Fetch usage for all supported accounts.
    /// - Parameter forceRefresh: If true, clears cache before fetching new data.
    func fetchUsage(forceRefresh: Bool) async throws -> UsageData

    /// Verify a management endpoint and report the credentials it exposes.
    /// Used by setup before anything is persisted.
    func probeEndpoint(_ endpoint: ManagementEndpoint) async throws -> [AuthFileEntry]

    /// Drop the in-memory copy of the management key, forcing the next fetch to
    /// re-read it. Call whenever the stored credential changes.
    func invalidateCredentialCache() async
}
