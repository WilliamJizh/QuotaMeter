//
//  ManagementKeyStoreFake.swift
//  ClaudeMeterTests
//

import Foundation
@testable import QuotaMeter

actor ManagementKeyStoreFake: ManagementKeyStoreProtocol {
    var key: String?
    var origin: ManagementKeyOrigin
    var saveError: Error?

    private(set) var savedKeys: [String] = []
    private(set) var clearCallCount: Int = 0

    init(key: String? = nil, origin: ManagementKeyOrigin = .keyFile(path: "/tmp/management-key")) {
        self.key = key
        self.origin = origin
    }

    func resolve() async -> ResolvedManagementKey? {
        guard let key else { return nil }
        return ResolvedManagementKey(key: key, origin: origin)
    }

    func save(_ key: String) async throws {
        if let saveError { throw saveError }
        savedKeys.append(key)
        self.key = key
    }

    func clear() async throws {
        clearCallCount += 1
        key = nil
    }
}
