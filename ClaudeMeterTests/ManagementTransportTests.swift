//
//  ManagementTransportTests.swift
//  ClaudeMeterTests
//

import XCTest
@testable import QuotaMeter

final class ManagementEnvelopeTests: XCTestCase {
    private func unwrap(_ json: String) throws -> Data {
        try ManagementTransport.unwrapEnvelope(Data(json.utf8))
    }

    func test_extractsNestedObjectBody() throws {
        let data = try unwrap(#"{"status_code":200,"header":{},"body":{"five_hour":{"utilization":42}}}"#)
        let payload = try JSONDecoder().decode(ClaudeUsagePayload.self, from: data)

        XCTAssertEqual(payload.fiveHour?.utilization, 42)
    }

    func test_extractsStringEncodedBody() throws {
        let data = try unwrap(#"{"status_code":200,"body":"{\"five_hour\":{\"utilization\":7}}"}"#)
        let payload = try JSONDecoder().decode(ClaudeUsagePayload.self, from: data)

        XCTAssertEqual(payload.fiveHour?.utilization, 7)
    }

    /// The passthrough answers HTTP 200 even when the provider refused, so a
    /// non-2xx inner status must surface as an error rather than a decode failure.
    func test_throwsRateLimitedOnInnerRateLimitDespiteOuterSuccess() throws {
        XCTAssertThrowsError(try unwrap(#"{"status_code":429,"body":"{\"error\":\"slow down\"}"}"#)) { error in
            guard case ManagementError.rateLimited = error else {
                return XCTFail("Expected rateLimited, got \(error)")
            }
        }
    }

    /// The provider's own `Retry-After` is what the cooldown is built on.
    func test_extractsRetryAfterFromEnvelopeHeaders() throws {
        XCTAssertThrowsError(
            try unwrap(#"{"status_code":429,"header":{"Retry-After":["1647"]},"body":"{}"}"#)
        ) { error in
            XCTAssertEqual((error as? ManagementError)?.retryAfter, 1647)
        }
    }

    func test_extractsRetryAfterCaseInsensitively() throws {
        XCTAssertThrowsError(
            try unwrap(#"{"status_code":429,"header":{"retry-after":"90"},"body":"{}"}"#)
        ) { error in
            XCTAssertEqual((error as? ManagementError)?.retryAfter, 90)
        }
    }

    func test_rateLimitWithoutRetryAfterHasNoHint() throws {
        XCTAssertThrowsError(try unwrap(#"{"status_code":429,"body":"{}"}"#)) { error in
            XCTAssertNil((error as? ManagementError)?.retryAfter)
        }
    }

    /// Retrying a 429 in-process is the one thing guaranteed to prolong it.
    func test_rateLimitIsNotRetriedInProcess() throws {
        XCTAssertFalse(ManagementError.rateLimited(retryAfter: 60).isTransient)
        XCTAssertTrue(ManagementError.upstreamStatus(code: 503, body: "").isTransient)
    }

    func test_authFailureIsNotTransient() throws {
        XCTAssertFalse(ManagementError.upstreamStatus(code: 401, body: "").isTransient)
        XCTAssertFalse(ManagementError.upstreamStatus(code: 404, body: "").isTransient)
    }

    func test_throwsOnMissingBody() throws {
        XCTAssertThrowsError(try unwrap(#"{"status_code":200}"#)) { error in
            guard case ManagementError.missingBody = error else {
                return XCTFail("Expected missingBody, got \(error)")
            }
        }
    }

    func test_throwsOnNonJSONResponse() throws {
        XCTAssertThrowsError(try unwrap("not json"))
    }
}

final class ManagementEndpointTests: XCTestCase {
    func test_addsSchemeToBareHostAndPort() throws {
        let endpoint = try ManagementEndpoint(rawAddress: "localhost:8317", key: "k")
        XCTAssertEqual(endpoint.baseURL.absoluteString, "http://localhost:8317")
    }

    func test_stripsManagementSuffix() throws {
        let endpoint = try ManagementEndpoint(rawAddress: "http://127.0.0.1:8317/v0/management", key: "k")
        XCTAssertEqual(endpoint.baseURL.absoluteString, "http://127.0.0.1:8317")
    }

    func test_stripsTrailingSlashes() throws {
        let endpoint = try ManagementEndpoint(rawAddress: "https://example.com:8317//", key: "k")
        XCTAssertEqual(endpoint.baseURL.absoluteString, "https://example.com:8317")
    }

    func test_preservesHTTPS() throws {
        let endpoint = try ManagementEndpoint(rawAddress: "https://remote.example.com", key: "k")
        XCTAssertEqual(endpoint.baseURL.absoluteString, "https://remote.example.com")
    }

    func test_buildsAPIPath() throws {
        let endpoint = try ManagementEndpoint(rawAddress: "127.0.0.1:8317", key: "k")
        XCTAssertEqual(
            endpoint.url(forPath: "v0/management/api-call").absoluteString,
            "http://127.0.0.1:8317/v0/management/api-call"
        )
    }

    func test_rejectsEmptyAddress() {
        XCTAssertThrowsError(try ManagementEndpoint(rawAddress: "   ", key: "k"))
    }
}
