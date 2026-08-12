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
    /// The provider rate-limited us. `retryAfter` is its own `Retry-After`, in
    /// seconds, when it supplied one.
    case rateLimited(retryAfter: TimeInterval?)
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
        case .rateLimited(let retryAfter):
            guard let retryAfter, retryAfter > 0 else {
                return "Provider rate limit reached. Waiting before retrying."
            }
            return "Provider rate limit reached. Retrying in \(Self.formatWait(retryAfter))."
        case .upstreamStatus(let code, _):
            switch code {
            case 401, 403:
                return "Credential rejected (\(code)). Re-authenticate it in the management panel."
            case 404:
                return "Usage endpoint not found (404). The daemon may need updating."
            default:
                return "Provider returned status \(code)."
            }
        }
    }

    /// Whether an immediate in-process retry could plausibly help.
    ///
    /// Deliberately excludes rate limiting: retrying a 429 seconds later is the
    /// one thing guaranteed to prolong it. That case is handled by a cooldown
    /// instead, honouring the provider's `Retry-After`.
    var isTransient: Bool {
        switch self {
        case .panelUnreachable:
            return true
        case .upstreamStatus(let code, _):
            return (500...599).contains(code)
        case .rateLimited, .notConfigured, .invalidBaseURL, .missingBody:
            return false
        }
    }

    /// How long the provider asked us to wait, if it said.
    var retryAfter: TimeInterval? {
        guard case .rateLimited(let retryAfter) = self else { return nil }
        return retryAfter
    }

    static func formatWait(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        if total < 60 { return "\(total)s" }
        let minutes = Int((seconds / 60).rounded(.up))
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
    }
}
