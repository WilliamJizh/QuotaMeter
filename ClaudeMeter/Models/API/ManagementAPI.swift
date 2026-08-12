//
//  ManagementAPI.swift
//  QuotaMeter
//
//  Wire types for CLIProxyAPI's `/v0/management` endpoints.
//

import Foundation

/// One credential as listed by `GET /v0/management/auth-files`.
struct AuthFileEntry: Decodable, Equatable, Sendable {
    let authIndex: String
    let provider: String
    let label: String?
    let email: String?
    let status: String?
    let disabled: Bool?

    enum CodingKeys: String, CodingKey {
        case authIndex = "auth_index"
        case provider
        case label
        case email
        case status
        case disabled
    }

    /// Best available human-readable name.
    var displayLabel: String {
        let candidates = [label, email].compactMap { $0 }
        return candidates.first { !$0.isEmpty } ?? authIndex
    }

    var isUsable: Bool { disabled != true }
}

struct AuthFilesResponse: Decodable, Sendable {
    let files: [AuthFileEntry]
}

/// Request body for `POST /v0/management/api-call`.
///
/// The daemon substitutes `$TOKEN$` in headers with a freshly refreshed access
/// token for the given credential, so the app never handles OAuth itself.
struct APICallRequest: Encodable, Sendable {
    let authIndex: String
    let method: String
    let url: String
    let header: [String: String]

    enum CodingKeys: String, CodingKey {
        case authIndex
        case method
        case url
        case header
    }
}

/// Errors specific to the management passthrough.
enum ManagementError: LocalizedError {
    case notConfigured
    case invalidBaseURL(String)
    case panelUnreachable(underlying: Error)
    case missingBody
    /// The passthrough itself succeeded but the upstream provider returned non-2xx.
    case upstreamStatus(code: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "No management key set. Open Settings to connect."
        case .invalidBaseURL(let raw):
            return "\"\(raw)\" is not a valid server address."
        case .panelUnreachable:
            return "Can't reach CLIProxyAPI. Is the daemon running?"
        case .missingBody:
            return "The server returned an empty response."
        case .upstreamStatus(let code, _):
            switch code {
            case 401, 403:
                return "Credential rejected (\(code)). Re-authenticate it in the management panel."
            case 404:
                return "Usage endpoint not found (404). The daemon may need updating."
            case 429:
                return "Provider rate limit hit (429). Backing off."
            default:
                return "Provider returned status \(code)."
            }
        }
    }

    /// Whether retrying without user intervention could plausibly help.
    var isTransient: Bool {
        switch self {
        case .panelUnreachable:
            return true
        case .upstreamStatus(let code, _):
            return code == 429 || (500...599).contains(code)
        case .notConfigured, .invalidBaseURL, .missingBody:
            return false
        }
    }
}
