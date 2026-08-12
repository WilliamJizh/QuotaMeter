//
//  UsageService.swift
//  QuotaMeter
//

import Foundation
import os

/// Aggregates plan quota for every Claude and Codex credential the daemon holds.
actor UsageService: UsageServiceProtocol {
    private static let logger = Logger(subsystem: "com.quotameter", category: "UsageService")

    private let transport: ManagementTransportProtocol
    private let cacheRepository: CacheRepositoryProtocol
    private let keyStore: ManagementKeyStoreProtocol
    private let settingsRepository: SettingsRepositoryProtocol

    private let maxRetries = Constants.Network.maxRetries

    /// The management key, held after the first successful read.
    ///
    /// Resolved once per launch rather than on every refresh, and dropped
    /// explicitly whenever the stored credential changes.
    private var cachedKey: String?

    /// Suppresses every upstream call until this instant.
    ///
    /// Anthropic answers a rate limit with `Retry-After` (~27 minutes in
    /// practice). Continuing to poll through that window does not get data any
    /// sooner and keeps the limit alive, so nothing is sent until it expires.
    private var rateLimitedUntil: Date?

    /// How long the current cooldown still has to run, if any.
    var rateLimitCooldown: TimeInterval? {
        guard let rateLimitedUntil else { return nil }
        let remaining = rateLimitedUntil.timeIntervalSinceNow
        return remaining > 0 ? remaining : nil
    }

    init(
        transport: ManagementTransportProtocol,
        cacheRepository: CacheRepositoryProtocol,
        keyStore: ManagementKeyStoreProtocol,
        settingsRepository: SettingsRepositoryProtocol
    ) {
        self.transport = transport
        self.cacheRepository = cacheRepository
        self.keyStore = keyStore
        self.settingsRepository = settingsRepository
    }

    // MARK: - Public

    func fetchUsage(forceRefresh: Bool) async throws -> UsageData {
        let endpoint = try await resolveEndpoint()

        // A cooldown outranks forceRefresh: the user tapping refresh must not be
        // able to keep the rate limit alive.
        if let cooldown = rateLimitCooldown {
            if let lastKnown = await cacheRepository.getLastKnown() {
                Self.logger.info("rate limited, serving cached data for another \(cooldown, privacy: .public)s")
                return lastKnown
            }
            throw ManagementError.rateLimited(retryAfter: cooldown)
        }

        if forceRefresh {
            await cacheRepository.invalidate()
        }
        if let cached = await cacheRepository.get() {
            return cached
        }

        let entries: [AuthFileEntry]
        do {
            entries = try await withRetry { try await self.transport.authFiles(endpoint: endpoint) }
        } catch {
            noteRateLimitIfNeeded(error)
            // Listing failed, so we know nothing about any account. Fall back to
            // the last good snapshot rather than blanking the menu bar.
            if let lastKnown = await cacheRepository.getLastKnown() {
                Self.logger.warning("auth-files listing failed, serving cached snapshot")
                return lastKnown
            }
            throw error
        }

        let supported = entries.filter { $0.isUsable && QuotaProvider(authFileProvider: $0.provider) != nil }
        guard !supported.isEmpty else {
            throw AppError.noAccounts
        }

        let accounts = await withTaskGroup(of: AccountUsage.self) { group -> [AccountUsage] in
            for entry in supported {
                group.addTask { await self.fetchAccount(entry: entry, endpoint: endpoint) }
            }
            var collected: [AccountUsage] = []
            for await account in group {
                collected.append(account)
            }
            return collected
        }

        if accounts.allSatisfy(\.isFailed), rateLimitCooldown != nil,
           let lastKnown = await cacheRepository.getLastKnown() {
            return lastKnown
        }

        let data = UsageData(accounts: accounts, lastUpdated: Date())
        await cacheRepository.set(data)
        return data
    }

    func probeEndpoint(_ endpoint: ManagementEndpoint) async throws -> [AuthFileEntry] {
        let entries = try await transport.authFiles(endpoint: endpoint)
        return entries.filter { $0.isUsable && QuotaProvider(authFileProvider: $0.provider) != nil }
    }

    // MARK: - Per-account fetch

    /// Never throws: a failing account is rendered as an error row so healthy
    /// accounts still display.
    private func fetchAccount(entry: AuthFileEntry, endpoint: ManagementEndpoint) async -> AccountUsage {
        guard let provider = QuotaProvider(authFileProvider: entry.provider) else {
            return AccountUsage(
                id: entry.authIndex,
                provider: .claude,
                label: entry.displayLabel,
                planLabel: nil,
                windows: [],
                errorMessage: "Unsupported provider \(entry.provider)"
            )
        }

        do {
            switch provider {
            case .claude:
                return try await fetchClaude(entry: entry, endpoint: endpoint)
            case .codex:
                return try await fetchCodex(entry: entry, endpoint: endpoint)
            }
        } catch {
            noteRateLimitIfNeeded(error)
            Self.logger.error("\(entry.displayLabel, privacy: .public): \(error.localizedDescription)")
            return AccountUsage(
                id: entry.authIndex,
                provider: provider,
                label: entry.displayLabel,
                planLabel: nil,
                windows: [],
                errorMessage: error.localizedDescription
            )
        }
    }

    private func fetchClaude(entry: AuthFileEntry, endpoint: ManagementEndpoint) async throws -> AccountUsage {
        let usage: ClaudeUsagePayload = try await withRetry {
            try await self.transport.apiCall(
                endpoint: endpoint,
                request: APICallRequest(
                    authIndex: entry.authIndex,
                    method: HTTPMethod.get.rawValue,
                    url: ProviderEndpoints.Claude.usageURL,
                    header: ProviderEndpoints.Claude.headers
                ),
                as: ClaudeUsagePayload.self
            )
        }

        // The plan tier is a nice-to-have; a failure here must not cost us the
        // usage numbers we already have.
        let profile = try? await transport.apiCall(
            endpoint: endpoint,
            request: APICallRequest(
                authIndex: entry.authIndex,
                method: HTTPMethod.get.rawValue,
                url: ProviderEndpoints.Claude.profileURL,
                header: ProviderEndpoints.Claude.headers
            ),
            as: ClaudeProfilePayload.self
        )

        return AccountUsage(
            id: entry.authIndex,
            provider: .claude,
            label: entry.displayLabel,
            planLabel: profile?.planLabel,
            windows: usage.toWindows(),
            errorMessage: nil
        )
    }

    private func fetchCodex(entry: AuthFileEntry, endpoint: ManagementEndpoint) async throws -> AccountUsage {
        let usage: CodexUsagePayload = try await withRetry {
            try await self.transport.apiCall(
                endpoint: endpoint,
                request: APICallRequest(
                    authIndex: entry.authIndex,
                    method: HTTPMethod.get.rawValue,
                    url: ProviderEndpoints.Codex.usageURL,
                    header: ProviderEndpoints.Codex.headers
                ),
                as: CodexUsagePayload.self
            )
        }

        let label = [usage.email, entry.displayLabel]
            .compactMap { $0 }
            .first { !$0.isEmpty } ?? entry.authIndex

        return AccountUsage(
            id: entry.authIndex,
            provider: .codex,
            label: label,
            planLabel: usage.planLabel,
            windows: usage.toWindows(),
            errorMessage: nil
        )
    }

    // MARK: - Retry

    /// Retries only errors that could plausibly resolve themselves. A 401 or 404
    /// is permanent until the user acts, so retrying just delays the message.
    private func withRetry<T: Sendable>(_ operation: () async throws -> T) async throws -> T {
        var lastError: Error?

        for attempt in 0..<maxRetries {
            do {
                return try await operation()
            } catch let error as ManagementError where error.isTransient {
                lastError = error
                let delay = pow(Constants.Network.backoffBase, Double(attempt))
                Self.logger.warning("Transient failure, retrying in \(delay, privacy: .public)s")
                try? await Task.sleep(for: .seconds(delay))
            } catch {
                throw error
            }
        }

        throw lastError ?? ManagementError.missingBody
    }

    func invalidateCredentialCache() {
        cachedKey = nil
    }

    /// Starts (or extends) the cooldown when the provider reports a rate limit.
    ///
    /// Without a `Retry-After` we still stand down for a conservative default —
    /// polling blind through an unknown limit is what causes it to persist.
    private func noteRateLimitIfNeeded(_ error: Error) {
        guard let managementError = error as? ManagementError,
              case .rateLimited(let retryAfter) = managementError else { return }

        let wait = retryAfter ?? Constants.Network.defaultRateLimitCooldown
        let deadline = Date().addingTimeInterval(wait)
        if let existing = rateLimitedUntil, existing > deadline { return }

        rateLimitedUntil = deadline
        Self.logger.warning("rate limited, pausing all upstream calls for \(wait, privacy: .public)s")
    }

    private func resolveEndpoint() async throws -> ManagementEndpoint {
        let key: String
        if let cachedKey {
            key = cachedKey
        } else {
            guard let resolved = await keyStore.resolve() else {
                throw AppError.notConfigured
            }
            key = resolved.key
            cachedKey = key
        }

        let settings = await settingsRepository.load()
        return try ManagementEndpoint(rawAddress: settings.managementAddress, key: key)
    }
}
