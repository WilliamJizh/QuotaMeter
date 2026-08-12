//
//  ManagementTransportStub.swift
//  ClaudeMeterTests
//

import Foundation
@testable import QuotaMeter

/// Serves canned provider payloads keyed by upstream URL, so a stubbed run can
/// exercise the same fan-out the real service performs.
actor ManagementTransportStub: ManagementTransportProtocol {
    var authFileEntries: [AuthFileEntry]
    var authFilesError: Error?

    /// Upstream URL → raw JSON payload.
    var payloads: [String: Data]
    /// Upstream URL → error to throw instead of returning a payload.
    var errors: [String: Error]

    private(set) var authFilesCallCount: Int = 0
    private(set) var apiCallURLs: [String] = []

    init(
        authFileEntries: [AuthFileEntry] = [],
        authFilesError: Error? = nil,
        payloads: [String: Data] = [:],
        errors: [String: Error] = [:]
    ) {
        self.authFileEntries = authFileEntries
        self.authFilesError = authFilesError
        self.payloads = payloads
        self.errors = errors
    }

    func setError(_ error: Error, for url: String) {
        errors[url] = error
    }

    func authFiles(endpoint: ManagementEndpoint) async throws -> [AuthFileEntry] {
        authFilesCallCount += 1
        if let authFilesError {
            throw authFilesError
        }
        return authFileEntries
    }

    func apiCall<T: Decodable>(
        endpoint: ManagementEndpoint,
        request: APICallRequest,
        as type: T.Type
    ) async throws -> T {
        apiCallURLs.append(request.url)

        if let error = errors[request.url] {
            throw error
        }
        guard let data = payloads[request.url] else {
            throw ManagementError.missingBody
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
