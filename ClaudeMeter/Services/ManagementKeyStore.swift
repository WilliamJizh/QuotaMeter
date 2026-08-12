//
//  ManagementKeyStore.swift
//  QuotaMeter
//

import Foundation
import os

/// Resolves the management key from local files instead of asking the user.
///
/// The daemon bcrypt-hashes `secret-key` in its own `config.yaml` on first start,
/// so the usable plaintext cannot be recovered from there — it has to come from
/// somewhere the key was recorded verbatim.
///
/// Sources are tried in order:
///   1. `QUOTAMETER_MANAGEMENT_KEY` in the environment
///   2. QuotaMeter's own key file, `~/.quotameter/management-key`
///   3. The daemon's `credentials.txt`, as written when the server was set up
///
/// A key found via (3) is promoted into (2) so the app becomes self-contained.
actor ManagementKeyStore: ManagementKeyStoreProtocol {
    private static let logger = Logger(subsystem: "com.quotameter", category: "ManagementKeyStore")

    private let fileManager: FileManager
    private let environment: [String: String]
    private let keyFileURL: URL
    private let daemonCredentialURLs: [URL]

    init(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.fileManager = fileManager
        self.environment = environment

        let home = fileManager.homeDirectoryForCurrentUser
        self.keyFileURL = home
            .appendingPathComponent(Constants.Management.keyDirectoryName, isDirectory: true)
            .appendingPathComponent(Constants.Management.keyFileName)
        self.daemonCredentialURLs = Constants.Management.daemonCredentialPaths.map {
            home.appendingPathComponent($0)
        }
    }

    // MARK: - Resolution

    func resolve() async -> ResolvedManagementKey? {
        if let raw = environment[Constants.Management.environmentVariable],
           let key = Self.sanitize(raw) {
            return ResolvedManagementKey(key: key, origin: .environment)
        }

        if let key = readKeyFile() {
            return ResolvedManagementKey(key: key, origin: .keyFile(path: keyFileURL.path))
        }

        for url in daemonCredentialURLs {
            guard let key = readDaemonCredentials(at: url) else { continue }
            // Promote it so the app no longer depends on the daemon's file.
            try? writeKeyFile(key)
            return ResolvedManagementKey(key: key, origin: .daemonCredentials(path: url.path))
        }

        return nil
    }

    func save(_ key: String) async throws {
        guard let sanitized = Self.sanitize(key) else { throw AppError.notConfigured }
        try writeKeyFile(sanitized)
    }

    func clear() async throws {
        guard fileManager.fileExists(atPath: keyFileURL.path) else { return }
        try fileManager.removeItem(at: keyFileURL)
    }

    // MARK: - Sources

    private func readKeyFile() -> String? {
        guard let contents = try? String(contentsOf: keyFileURL, encoding: .utf8) else { return nil }
        return Self.sanitize(contents)
    }

    /// Parses `MANAGEMENT_KEY=<value>` out of the daemon's credentials file.
    private func readDaemonCredentials(at url: URL) -> String? {
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return nil }

        for line in contents.split(separator: "\n") {
            let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2,
                  parts[0].trimmingCharacters(in: .whitespaces) == "MANAGEMENT_KEY" else { continue }
            return Self.sanitize(String(parts[1]))
        }
        return nil
    }

    // MARK: - Writing

    private func writeKeyFile(_ key: String) throws {
        let directory = keyFileURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )

        try Data(key.utf8).write(to: keyFileURL, options: [.atomic])
        // Owner-only, matching how the daemon stores its own credentials.
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: keyFileURL.path)
        Self.logger.info("Management key written to \(self.keyFileURL.path, privacy: .public)")
    }

    /// Trims whitespace and surrounding quotes; returns nil for anything empty.
    private static func sanitize(_ raw: String) -> String? {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") {
            value = String(value.dropFirst().dropLast())
        }
        value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
