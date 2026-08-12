//
//  ManagementTransportProtocol.swift
//  QuotaMeter
//

import Foundation

/// HTTP methods supported by the transport.
enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
}

/// Connection details for a CLIProxyAPI management endpoint.
struct ManagementEndpoint: Equatable, Sendable {
    let baseURL: URL
    let key: String

    /// Normalises the user-entered address the same way the web panel does:
    /// bare host/port gets a scheme, and a trailing `/v0/management` is stripped.
    init(rawAddress: String, key: String) throws {
        var trimmed = rawAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ManagementError.invalidBaseURL(rawAddress) }

        if !trimmed.contains("://") {
            trimmed = "http://\(trimmed)"
        }
        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        if trimmed.hasSuffix("/v0/management") {
            trimmed.removeLast("/v0/management".count)
        }

        guard let url = URL(string: trimmed), url.host != nil else {
            throw ManagementError.invalidBaseURL(rawAddress)
        }

        self.baseURL = url
        self.key = key
    }

    init(baseURL: URL, key: String) {
        self.baseURL = baseURL
        self.key = key
    }

    func url(forPath path: String) -> URL {
        baseURL.appendingPathComponent(path)
    }
}

/// Talks to CLIProxyAPI's management API.
protocol ManagementTransportProtocol: Actor {
    /// Lists the credentials the daemon currently holds.
    func authFiles(endpoint: ManagementEndpoint) async throws -> [AuthFileEntry]

    /// Performs an upstream request using a stored credential, returning the
    /// decoded provider payload. The daemon injects a fresh access token.
    func apiCall<T: Decodable>(
        endpoint: ManagementEndpoint,
        request: APICallRequest,
        as type: T.Type
    ) async throws -> T
}
