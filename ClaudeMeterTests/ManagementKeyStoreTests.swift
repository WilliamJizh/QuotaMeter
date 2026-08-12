//
//  ManagementKeyStoreTests.swift
//  ClaudeMeterTests
//

import XCTest
@testable import QuotaMeter

final class ManagementKeyStoreTests: XCTestCase {
    private var home: URL!
    private var fileManager: FileManager!

    override func setUpWithError() throws {
        fileManager = FileManager()
        home = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ManagementKeyStoreTests-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: home, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? fileManager.removeItem(at: home)
    }

    /// `FileManager.homeDirectoryForCurrentUser` is what the store reads, so the
    /// tests point it at a scratch directory rather than the real home.
    private final class HomeRedirectingFileManager: FileManager, @unchecked Sendable {
        let redirectedHome: URL
        init(home: URL) {
            self.redirectedHome = home
            super.init()
        }
        override var homeDirectoryForCurrentUser: URL { redirectedHome }
    }

    private func makeStore(environment: [String: String] = [:]) -> ManagementKeyStore {
        ManagementKeyStore(
            fileManager: HomeRedirectingFileManager(home: home),
            environment: environment
        )
    }

    private func write(_ contents: String, to relativePath: String) throws {
        let url = home.appendingPathComponent(relativePath)
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Resolution order

    func test_resolvesNothingWhenNoSourceExists() async {
        let resolved = await makeStore().resolve()
        XCTAssertNil(resolved)
    }

    func test_environmentVariableWinsOverFiles() async throws {
        try write("from-key-file", to: ".quotameter/management-key")
        let store = makeStore(environment: [Constants.Management.environmentVariable: "from-env"])

        let resolved = await store.resolve()

        XCTAssertEqual(resolved?.key, "from-env")
        XCTAssertEqual(resolved?.origin, .environment)
    }

    func test_resolvesFromOwnKeyFile() async throws {
        try write("abc123\n", to: ".quotameter/management-key")

        let resolved = await makeStore().resolve()

        XCTAssertEqual(resolved?.key, "abc123")
        if case .keyFile = resolved?.origin {} else {
            XCTFail("Expected keyFile origin, got \(String(describing: resolved?.origin))")
        }
    }

    func test_resolvesFromDaemonCredentialsFile() async throws {
        try write("MANAGEMENT_KEY=deadbeef\nAPI_KEY=other\n", to: "cliproxyapi/credentials.txt")

        let resolved = await makeStore().resolve()

        XCTAssertEqual(resolved?.key, "deadbeef")
        if case .daemonCredentials = resolved?.origin {} else {
            XCTFail("Expected daemonCredentials origin")
        }
    }

    /// Once discovered via the daemon's file the key is copied into QuotaMeter's
    /// own, so the app keeps working if that file is later cleaned up.
    func test_promotesDaemonCredentialsIntoOwnKeyFile() async throws {
        try write("MANAGEMENT_KEY=deadbeef\n", to: "cliproxyapi/credentials.txt")
        let store = makeStore()

        _ = await store.resolve()
        try fileManager.removeItem(at: home.appendingPathComponent("cliproxyapi/credentials.txt"))

        let resolved = await store.resolve()
        XCTAssertEqual(resolved?.key, "deadbeef")
        if case .keyFile = resolved?.origin {} else {
            XCTFail("Expected the promoted key file to be used")
        }
    }

    func test_ownKeyFileWinsOverDaemonCredentials() async throws {
        try write("own-key", to: ".quotameter/management-key")
        try write("MANAGEMENT_KEY=daemon-key\n", to: "cliproxyapi/credentials.txt")

        let resolved = await makeStore().resolve()

        XCTAssertEqual(resolved?.key, "own-key")
    }

    // MARK: - Parsing

    func test_ignoresBlankAndMalformedSources() async throws {
        try write("   \n", to: ".quotameter/management-key")
        try write("NOT_THE_KEY=value\n", to: "cliproxyapi/credentials.txt")

        let resolved = await makeStore().resolve()

        XCTAssertNil(resolved)
    }

    func test_stripsSurroundingQuotesAndWhitespace() async throws {
        try write("  \"quoted-key\"  \n", to: ".quotameter/management-key")

        let resolved = await makeStore().resolve()

        XCTAssertEqual(resolved?.key, "quoted-key")
    }

    /// A value containing `=` must survive the credentials-file split.
    func test_preservesEqualsSignsInsideKey() async throws {
        try write("MANAGEMENT_KEY=abc==def\n", to: "cliproxyapi/credentials.txt")

        let resolved = await makeStore().resolve()

        XCTAssertEqual(resolved?.key, "abc==def")
    }

    // MARK: - Writing

    func test_saveMakesKeyResolvable() async throws {
        let store = makeStore()

        try await store.save("  saved-key  ")

        let resolved = await store.resolve()
        XCTAssertEqual(resolved?.key, "saved-key")
    }

    func test_saveWritesOwnerOnlyPermissions() async throws {
        let store = makeStore()
        try await store.save("saved-key")

        let path = home.appendingPathComponent(".quotameter/management-key").path
        let attributes = try fileManager.attributesOfItem(atPath: path)
        let permissions = (attributes[.posixPermissions] as? NSNumber)?.intValue

        XCTAssertEqual(permissions, 0o600)
    }

    func test_saveRejectsEmptyKey() async {
        let store = makeStore()

        do {
            try await store.save("   ")
            XCTFail("Expected notConfigured")
        } catch AppError.notConfigured {
            // expected
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func test_clearRemovesOwnKeyFileOnly() async throws {
        try write("MANAGEMENT_KEY=daemon-key\n", to: "cliproxyapi/credentials.txt")
        let store = makeStore()
        try await store.save("own-key")

        try await store.clear()

        // Falls back to the daemon's file rather than resolving to nothing.
        let resolved = await store.resolve()
        XCTAssertEqual(resolved?.key, "daemon-key")
    }

    func test_clearIsIdempotentWhenNoFileExists() async throws {
        try await makeStore().clear()
    }
}
