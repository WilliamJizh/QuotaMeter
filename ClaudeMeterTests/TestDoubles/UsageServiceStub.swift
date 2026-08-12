//
//  UsageServiceStub.swift
//  ClaudeMeterTests
//

import Foundation
@testable import QuotaMeter

actor UsageServiceStub: UsageServiceProtocol {
    let fetchUsageResult: Result<UsageData, Error>
    let probeResult: Result<[AuthFileEntry], Error>

    private(set) var fetchUsageCallCount: Int = 0
    private(set) var probedEndpoints: [ManagementEndpoint] = []
    private(set) var invalidateCredentialCacheCallCount: Int = 0

    init(
        fetchUsageResult: Result<UsageData, Error>,
        probeResult: Result<[AuthFileEntry], Error> = .success([])
    ) {
        self.fetchUsageResult = fetchUsageResult
        self.probeResult = probeResult
    }

    func fetchUsage(forceRefresh: Bool) async throws -> UsageData {
        fetchUsageCallCount += 1
        return try fetchUsageResult.get()
    }

    func probeEndpoint(_ endpoint: ManagementEndpoint) async throws -> [AuthFileEntry] {
        probedEndpoints.append(endpoint)
        return try probeResult.get()
    }

    func invalidateCredentialCache() {
        invalidateCredentialCacheCallCount += 1
    }
}
