//
//  AppError.swift
//  QuotaMeter
//

import Foundation

/// Application-level errors with user-facing messages
enum AppError: LocalizedError {
    case notConfigured
    case noAccounts
    case management(ManagementError)
    case cacheCorrupted

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "No management key found. Add one in Settings, or start CLIProxyAPI so its key can be discovered."
        case .noAccounts:
            return "No Claude or Codex credentials found in CLIProxyAPI."
        case .management(let error):
            return error.localizedDescription
        case .cacheCorrupted:
            return "Cached data is corrupted. Fetching fresh data..."
        }
    }

    /// Whether error is recoverable without user action
    var isRecoverable: Bool {
        switch self {
        case .cacheCorrupted:
            return true
        case .management(let error):
            return error.isTransient
        case .notConfigured, .noAccounts:
            return false
        }
    }

    /// User action to resolve error
    var recoveryAction: String? {
        switch self {
        case .notConfigured:
            return "Connect"
        case .noAccounts:
            return "Open Management Panel"
        case .management(let error):
            return error.isTransient ? "Retry" : "Open Management Panel"
        default:
            return nil
        }
    }
}
