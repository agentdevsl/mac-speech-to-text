// PrivacySectionViewModelTests.swift
// macOS Local Speech-to-Text Application
//
// Unit tests for PrivacySectionViewModel

import XCTest
@testable import SpeechToText

@MainActor
final class PrivacySectionViewModelTests: XCTestCase {
    // MARK: - Properties

    var sut: PrivacySectionViewModel!
    var mockSettingsService: MockSettingsServiceForPrivacy!
    var testUserDefaults: UserDefaults!
    var testSuiteName: String!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()

        // Create isolated UserDefaults for testing - use unique name per test to avoid parallel test interference
        testSuiteName = "PrivacySectionViewModelTests.\(UUID().uuidString)"
        testUserDefaults = UserDefaults(suiteName: testSuiteName)!
        testUserDefaults.removePersistentDomain(forName: testSuiteName)

        mockSettingsService = MockSettingsServiceForPrivacy(userDefaults: testUserDefaults)
        sut = PrivacySectionViewModel(settingsService: mockSettingsService)
    }

    override func tearDown() async throws {
        sut = nil
        mockSettingsService = nil
        if let suiteName = testSuiteName {
            testUserDefaults?.removePersistentDomain(forName: suiteName)
        }
        testUserDefaults = nil
        testSuiteName = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func test_initialization_loadsCollectAnonymousStatsFromSettings() {
        // Given - default settings have collectAnonymousStats true
        // Then
        XCTAssertTrue(sut.collectAnonymousStats)
    }

    func test_initialization_loadsStoragePolicyFromSettings() {
        // Given - default settings have storagePolicy .sessionOnly
        // Then
        XCTAssertEqual(sut.storagePolicy, .sessionOnly)
    }

    func test_initialization_loadsDataRetentionDaysFromSettings() {
        // Given - default settings have dataRetentionDays 7
        // Then
        XCTAssertEqual(sut.dataRetentionDays, 7)
    }

    func test_initialization_withCustomSettings_loadsCorrectly() async throws {
        // Given
        var customSettings = UserSettings.default
        customSettings.privacy.collectAnonymousStats = false
        customSettings.privacy.storagePolicy = .persistent
        customSettings.privacy.dataRetentionDays = 14
        try mockSettingsService.save(customSettings)

        // When
        let viewModel = PrivacySectionViewModel(settingsService: mockSettingsService)

        // Then
        XCTAssertFalse(viewModel.collectAnonymousStats)
        XCTAssertEqual(viewModel.storagePolicy, .persistent)
        XCTAssertEqual(viewModel.dataRetentionDays, 14)
    }

    // MARK: - collectAnonymousStats Tests

    func test_collectAnonymousStats_canBeToggledOn() {
        // Given
        sut.collectAnonymousStats = false

        // When
        sut.collectAnonymousStats = true

        // Then
        XCTAssertTrue(sut.collectAnonymousStats)
    }

    func test_collectAnonymousStats_canBeToggledOff() {
        // Given
        sut.collectAnonymousStats = true

        // When
        sut.collectAnonymousStats = false

        // Then
        XCTAssertFalse(sut.collectAnonymousStats)
    }

    func test_collectAnonymousStats_savesCalled_whenToggled() async throws {
        // Given
        mockSettingsService.saveCalled = false

        // When
        sut.collectAnonymousStats = !sut.collectAnonymousStats

        // Allow save task to complete (500ms to ensure async Task completes)
        try await Task.sleep(nanoseconds: 500_000_000)

        // Then
        XCTAssertTrue(mockSettingsService.saveCalled)
    }

    func test_collectAnonymousStats_persistsAfterToggle() async throws {
        // Given
        let initialValue = sut.collectAnonymousStats

        // When
        sut.collectAnonymousStats = !initialValue
        try await Task.sleep(nanoseconds: 500_000_000)

        // Then - reload and check
        let newViewModel = PrivacySectionViewModel(settingsService: mockSettingsService)
        XCTAssertEqual(newViewModel.collectAnonymousStats, !initialValue)
    }

    // MARK: - storagePolicy Tests

    func test_storagePolicy_defaultsToSessionOnly() {
        // Then
        XCTAssertEqual(sut.storagePolicy, .sessionOnly)
    }

    func test_storagePolicy_canBeSetToNone() {
        // When
        sut.storagePolicy = .none

        // Then
        XCTAssertEqual(sut.storagePolicy, .none)
    }

    func test_storagePolicy_canBeSetToSessionOnly() {
        // Given
        sut.storagePolicy = .none

        // When
        sut.storagePolicy = .sessionOnly

        // Then
        XCTAssertEqual(sut.storagePolicy, .sessionOnly)
    }

    func test_storagePolicy_canBeSetToPersistent() {
        // When
        sut.storagePolicy = .persistent

        // Then
        XCTAssertEqual(sut.storagePolicy, .persistent)
    }

    func test_storagePolicy_savesCalled_whenChanged() async throws {
        // Given
        mockSettingsService.saveCalled = false

        // When
        sut.storagePolicy = .persistent
        try await Task.sleep(nanoseconds: 500_000_000)

        // Then
        XCTAssertTrue(mockSettingsService.saveCalled)
    }

    func test_storagePolicy_persistsAfterChange() async throws {
        // When
        sut.storagePolicy = .persistent
        try await Task.sleep(nanoseconds: 500_000_000)

        // Then - reload and check
        let newViewModel = PrivacySectionViewModel(settingsService: mockSettingsService)
        XCTAssertEqual(newViewModel.storagePolicy, .persistent)
    }

    // MARK: - dataRetentionDays Tests

    func test_dataRetentionDays_defaultsTo7() {
        // Then
        XCTAssertEqual(sut.dataRetentionDays, 7)
    }

    func test_dataRetentionDays_canBeSetToMinimum() {
        // When
        sut.dataRetentionDays = 1

        // Then
        XCTAssertEqual(sut.dataRetentionDays, 1)
    }

    func test_dataRetentionDays_canBeSetToMaximum() {
        // When
        sut.dataRetentionDays = 30

        // Then
        XCTAssertEqual(sut.dataRetentionDays, 30)
    }

    func test_dataRetentionDays_canBeSetToMiddleValue() {
        // When
        sut.dataRetentionDays = 15

        // Then
        XCTAssertEqual(sut.dataRetentionDays, 15)
    }

    func test_dataRetentionDays_savesCalled_whenChanged() async throws {
        // Given
        mockSettingsService.saveCalled = false

        // When
        sut.dataRetentionDays = 14
        try await Task.sleep(nanoseconds: 500_000_000)

        // Then
        XCTAssertTrue(mockSettingsService.saveCalled)
    }

    func test_dataRetentionDays_persistsAfterChange() async throws {
        // When
        sut.dataRetentionDays = 21
        try await Task.sleep(nanoseconds: 500_000_000)

        // Then - reload and check
        let newViewModel = PrivacySectionViewModel(settingsService: mockSettingsService)
        XCTAssertEqual(newViewModel.dataRetentionDays, 21)
    }

    // MARK: - StoragePolicy Extension Tests

    func test_storagePolicy_allCases_containsThreePolicies() {
        // Then
        XCTAssertEqual(StoragePolicy.allCases.count, 3)
    }

    func test_storagePolicy_allCases_containsNone() {
        // Then
        XCTAssertTrue(StoragePolicy.allCases.contains(.none))
    }

    func test_storagePolicy_allCases_containsSessionOnly() {
        // Then
        XCTAssertTrue(StoragePolicy.allCases.contains(.sessionOnly))
    }

    func test_storagePolicy_allCases_containsPersistent() {
        // Then
        XCTAssertTrue(StoragePolicy.allCases.contains(.persistent))
    }

    func test_storagePolicy_displayName_none() {
        // Then
        XCTAssertEqual(StoragePolicy.none.displayName, "Don't store")
    }

    func test_storagePolicy_displayName_sessionOnly() {
        // Then
        XCTAssertEqual(StoragePolicy.sessionOnly.displayName, "Session only")
    }

    func test_storagePolicy_displayName_persistent() {
        // Then
        XCTAssertEqual(StoragePolicy.persistent.displayName, "Keep history")
    }

    func test_storagePolicy_description_none() {
        // Then
        XCTAssertEqual(StoragePolicy.none.description, "Transcriptions are discarded immediately")
    }

    func test_storagePolicy_description_sessionOnly() {
        // Then
        XCTAssertEqual(StoragePolicy.sessionOnly.description, "Kept until you quit the app")
    }

    func test_storagePolicy_description_persistent() {
        // Then
        XCTAssertEqual(StoragePolicy.persistent.description, "Saved locally for quick access")
    }

    func test_storagePolicy_icon_none() {
        // Then
        XCTAssertEqual(StoragePolicy.none.icon, "trash")
    }

    func test_storagePolicy_icon_sessionOnly() {
        // Then
        XCTAssertEqual(StoragePolicy.sessionOnly.icon, "clock")
    }

    func test_storagePolicy_icon_persistent() {
        // Then
        XCTAssertEqual(StoragePolicy.persistent.icon, "internaldrive")
    }

    // MARK: - Combined Settings Tests

    func test_multipleSettingsChanges_allPersist() async throws {
        // When
        sut.collectAnonymousStats = false
        sut.storagePolicy = .persistent
        sut.dataRetentionDays = 30
        try await Task.sleep(nanoseconds: 500_000_000)

        // Then - reload and check all values
        let newViewModel = PrivacySectionViewModel(settingsService: mockSettingsService)
        XCTAssertFalse(newViewModel.collectAnonymousStats)
        XCTAssertEqual(newViewModel.storagePolicy, .persistent)
        XCTAssertEqual(newViewModel.dataRetentionDays, 30)
    }

    func test_rapidSettingsChanges_lastValueWins() async throws {
        // When - rapid changes
        sut.dataRetentionDays = 5
        sut.dataRetentionDays = 10
        sut.dataRetentionDays = 15
        sut.dataRetentionDays = 20
        try await Task.sleep(nanoseconds: 500_000_000)

        // Then
        XCTAssertEqual(sut.dataRetentionDays, 20)
    }

    // MARK: - Edge Cases

    func test_dataRetentionDays_handlesZero() {
        // When
        sut.dataRetentionDays = 0

        // Then
        XCTAssertEqual(sut.dataRetentionDays, 0)
    }

    func test_dataRetentionDays_handlesNegative() {
        // When
        sut.dataRetentionDays = -1

        // Then - negative values are stored but UI should prevent this
        XCTAssertEqual(sut.dataRetentionDays, -1)
    }

    func test_dataRetentionDays_handlesLargeValue() {
        // When
        sut.dataRetentionDays = 365

        // Then - large values are stored but UI should limit to 30
        XCTAssertEqual(sut.dataRetentionDays, 365)
    }
}

// MARK: - Mock Settings Service

@MainActor
class MockSettingsServiceForPrivacy: SettingsService {
    var saveCalled = false
    var loadCalled = false

    override func load() -> UserSettings {
        loadCalled = true
        return super.load()
    }

    override func save(_ settings: UserSettings) throws {
        saveCalled = true
        try super.save(settings)
    }
}
