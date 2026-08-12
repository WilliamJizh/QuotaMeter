//
//  AppModelTests.swift
//  ClaudeMeterTests
//

import XCTest
@testable import QuotaMeter

@MainActor
final class AppModelTests: XCTestCase {
    private func makeAppModel(
        usageService: UsageServiceStub,
        keyStore: ManagementKeyStoreFake = ManagementKeyStoreFake(),
        settings: SettingsRepositoryFake = SettingsRepositoryFake(),
        notifications: NotificationServiceSpy? = nil
    ) -> AppModel {
        AppModel(
            settingsRepository: settings,
            keyStore: keyStore,
            usageService: usageService,
            notificationService: notifications ?? NotificationServiceSpy()
        )
    }

    // MARK: - Bootstrap

    func test_bootstrapWithoutResolvableKey_showsSetupState() async {
        let appModel = makeAppModel(
            usageService: UsageServiceStub(fetchUsageResult: .success(UsageFixtures.usageData()))
        )

        await appModel.bootstrap()

        XCTAssertFalse(appModel.isSetupComplete)
        XCTAssertNil(appModel.usageData)
        XCTAssertTrue(appModel.isReady)
    }

    func test_bootstrapWithResolvableKey_loadsUsage() async {
        let expected = UsageFixtures.usageData(percentage: TestConstants.sessionPercentage)
        let appModel = makeAppModel(
            usageService: UsageServiceStub(fetchUsageResult: .success(expected)),
            keyStore: ManagementKeyStoreFake(key: TestConstants.managementKey)
        )

        await appModel.bootstrap()

        XCTAssertTrue(appModel.isSetupComplete)
        XCTAssertEqual(appModel.usageData, expected)
        XCTAssertNil(appModel.errorMessage)
    }

    func test_bootstrapSurfacesFetchFailure() async {
        let appModel = makeAppModel(
            usageService: UsageServiceStub(
                fetchUsageResult: .failure(TestError(message: TestConstants.fetchFailureMessage))
            ),
            keyStore: ManagementKeyStoreFake(key: TestConstants.managementKey)
        )

        await appModel.bootstrap()

        XCTAssertTrue(appModel.isSetupComplete)
        XCTAssertNil(appModel.usageData)
        XCTAssertNotNil(appModel.errorMessage)
    }

    // MARK: - Connect

    func test_connectStoresKeyAndLoadsUsage() async throws {
        let keyStore = ManagementKeyStoreFake()
        let settings = SettingsRepositoryFake()
        let entries = [UsageFixtures.authFile(authIndex: "c1")]
        let appModel = makeAppModel(
            usageService: UsageServiceStub(
                fetchUsageResult: .success(UsageFixtures.usageData()),
                probeResult: .success(entries)
            ),
            keyStore: keyStore,
            settings: settings
        )
        await appModel.bootstrap()

        let discovered = try await appModel.connect(
            address: TestConstants.managementAddress,
            key: TestConstants.managementKey
        )

        XCTAssertEqual(discovered.map(\.authIndex), ["c1"])
        XCTAssertTrue(appModel.isSetupComplete)
        XCTAssertNotNil(appModel.usageData)
        let storedKey = await keyStore.key
        XCTAssertEqual(storedKey, TestConstants.managementKey)
    }

    func test_connectNormalisesAddressBeforeSaving() async throws {
        let appModel = makeAppModel(
            usageService: UsageServiceStub(
                fetchUsageResult: .success(UsageFixtures.usageData()),
                probeResult: .success([])
            )
        )
        await appModel.bootstrap()

        _ = try await appModel.connect(address: "127.0.0.1:8317/v0/management", key: "k")

        XCTAssertEqual(appModel.settings.managementAddress, "http://127.0.0.1:8317")
    }

    func test_connectWithEmptyKeyThrowsAndStaysInSetup() async {
        let keyStore = ManagementKeyStoreFake()
        let appModel = makeAppModel(
            usageService: UsageServiceStub(fetchUsageResult: .success(UsageFixtures.usageData())),
            keyStore: keyStore
        )
        await appModel.bootstrap()

        do {
            _ = try await appModel.connect(address: TestConstants.managementAddress, key: "   ")
            XCTFail("Expected notConfigured")
        } catch AppError.notConfigured {
            // expected
        } catch {
            XCTFail("Unexpected error \(error)")
        }

        XCTAssertFalse(appModel.isSetupComplete)
        let stored = await keyStore.key
        XCTAssertNil(stored)
    }

    /// A rejected key must not be persisted.
    func test_connectWithRejectedKeyDoesNotPersist() async {
        let keyStore = ManagementKeyStoreFake()
        let appModel = makeAppModel(
            usageService: UsageServiceStub(
                fetchUsageResult: .success(UsageFixtures.usageData()),
                probeResult: .failure(ManagementError.upstreamStatus(code: 401, body: ""))
            ),
            keyStore: keyStore
        )
        await appModel.bootstrap()

        do {
            _ = try await appModel.connect(address: TestConstants.managementAddress, key: "bad")
            XCTFail("Expected failure")
        } catch {
            // expected
        }

        XCTAssertFalse(appModel.isSetupComplete)
        let stored = await keyStore.key
        XCTAssertNil(stored)
    }

    func test_disconnectReturnsToSetupState() async throws {
        let keyStore = ManagementKeyStoreFake(key: TestConstants.managementKey)
        let appModel = makeAppModel(
            usageService: UsageServiceStub(fetchUsageResult: .success(UsageFixtures.usageData())),
            keyStore: keyStore
        )
        await appModel.bootstrap()
        XCTAssertTrue(appModel.isSetupComplete)

        try await appModel.disconnect()

        XCTAssertFalse(appModel.isSetupComplete)
        XCTAssertNil(appModel.usageData)
        XCTAssertNil(appModel.errorMessage)
        let stored = await keyStore.key
        XCTAssertNil(stored)
    }

    // MARK: - Refresh

    func test_refreshClearsPreviousError() async {
        let expected = UsageFixtures.usageData(percentage: TestConstants.sessionPercentage)
        let appModel = makeAppModel(
            usageService: UsageServiceStub(fetchUsageResult: .success(expected)),
            keyStore: ManagementKeyStoreFake(key: TestConstants.managementKey)
        )
        await appModel.bootstrap()
        appModel.errorMessage = TestConstants.previousErrorMessage

        await appModel.refreshUsage(forceRefresh: true)

        XCTAssertEqual(appModel.usageData, expected)
        XCTAssertNil(appModel.errorMessage)
    }

    func test_refreshWithoutSetupClearsUsage() async {
        let appModel = makeAppModel(
            usageService: UsageServiceStub(fetchUsageResult: .success(UsageFixtures.usageData()))
        )
        await appModel.bootstrap()
        appModel.usageData = UsageFixtures.usageData(percentage: TestConstants.cachedPercentage)

        await appModel.refreshUsage()

        XCTAssertNil(appModel.usageData)
    }

    func test_refreshForwardsUsageToNotificationService() async {
        let notifications = NotificationServiceSpy()
        let expected = UsageFixtures.usageData()
        let appModel = makeAppModel(
            usageService: UsageServiceStub(fetchUsageResult: .success(expected)),
            keyStore: ManagementKeyStoreFake(key: TestConstants.managementKey),
            notifications: notifications
        )

        await appModel.bootstrap()

        XCTAssertEqual(notifications.lastEvaluatedUsageData, expected)
    }
}
