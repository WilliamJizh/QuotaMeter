//
//  ManagementTransport.swift
//  QuotaMeter
//

import Foundation
import os

/// Actor-isolated client for CLIProxyAPI's `/v0/management` API.
actor ManagementTransport: ManagementTransportProtocol {
    private static let logger = Logger(subsystem: "com.quotameter", category: "ManagementTransport")
    private let session: URLSession

    init(configuration: URLSessionConfiguration = .ephemeral) {
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        // The daemon is local; don't serve a stale body from the URL cache.
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: configuration)
    }

    func authFiles(endpoint: ManagementEndpoint) async throws -> [AuthFileEntry] {
        let data = try await send(
            url: endpoint.url(forPath: "v0/management/auth-files"),
            method: .get,
            body: nil,
            key: endpoint.key
        )

        let response = try JSONDecoder().decode(AuthFilesResponse.self, from: data)
        return response.files
    }

    func apiCall<T: Decodable>(
        endpoint: ManagementEndpoint,
        request: APICallRequest,
        as type: T.Type
    ) async throws -> T {
        let encoder = JSONEncoder()
        let body = try encoder.encode(request)

        let data = try await send(
            url: endpoint.url(forPath: "v0/management/api-call"),
            method: .post,
            body: body,
            key: endpoint.key
        )

        let payload = try Self.unwrapEnvelope(data)
        return try JSONDecoder().decode(T.self, from: payload)
    }

    // MARK: - Envelope

    /// The passthrough answers HTTP 200 even when the upstream provider failed,
    /// wrapping the real result as `{status_code, header, body}`. Treating the
    /// outer status as the truth would silently turn a 429 into "success", so the
    /// inner code is what we validate.
    static func unwrapEnvelope(_ data: Data) throws -> Data {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ManagementError.missingBody
        }

        let statusCode = (root["status_code"] as? NSNumber)?.intValue ?? 0
        let rawBody = root["body"] ?? root["bodyText"]

        // `body` arrives either as a nested JSON object or as a string holding
        // encoded JSON, depending on the provider's content type.
        let bodyData: Data?
        switch rawBody {
        case let text as String:
            bodyData = text.data(using: .utf8)
        case let object as [String: Any]:
            bodyData = try? JSONSerialization.data(withJSONObject: object)
        case let array as [Any]:
            bodyData = try? JSONSerialization.data(withJSONObject: array)
        default:
            bodyData = nil
        }

        guard (200...299).contains(statusCode) else {
            let description = bodyData.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            if statusCode == 429 {
                throw ManagementError.rateLimited(retryAfter: retryAfterSeconds(in: root))
            }
            throw ManagementError.upstreamStatus(code: statusCode, body: description)
        }

        guard let bodyData, !bodyData.isEmpty else {
            throw ManagementError.missingBody
        }

        return bodyData
    }

    /// Pulls `Retry-After` out of the envelope's captured response headers.
    ///
    /// The daemon reports header values as arrays, and header names are
    /// case-insensitive upstream, so both are handled here.
    static func retryAfterSeconds(in root: [String: Any]) -> TimeInterval? {
        guard let headers = root["header"] as? [String: Any] else { return nil }

        for (name, value) in headers where name.lowercased() == "retry-after" {
            let raw: String?
            switch value {
            case let list as [Any]: raw = list.first.map { String(describing: $0) }
            case let text as String: raw = text
            default: raw = String(describing: value)
            }
            if let raw, let seconds = TimeInterval(raw.trimmingCharacters(in: .whitespaces)), seconds > 0 {
                return seconds
            }
        }
        return nil
    }

    // MARK: - Private

    private func send(url: URL, method: HTTPMethod, body: Data?, key: String) async throws -> Data {
        guard !key.isEmpty else { throw ManagementError.notConfigured }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            Self.logger.error("Transport failure for \(url.path, privacy: .public): \(error.localizedDescription)")
            throw ManagementError.panelUnreachable(underlying: error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw ManagementError.missingBody
        }

        guard (200...299).contains(http.statusCode) else {
            Self.logger.error("Management API \(http.statusCode) from \(url.path, privacy: .public)")
            throw ManagementError.upstreamStatus(
                code: http.statusCode,
                body: String(data: data, encoding: .utf8) ?? ""
            )
        }

        return data
    }
}
