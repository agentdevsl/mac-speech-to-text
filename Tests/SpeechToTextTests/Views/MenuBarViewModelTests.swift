// MenuBarViewModelTests.swift
// macOS Local Speech-to-Text Application
//
// Unit tests for MenuBarViewModel

import XCTest
@testable import SpeechToText

@MainActor
final class MenuBarViewModelTests: XCTestCase {
    // MARK: - Properties

    var sut: MenuBarViewModel!
    var mockStatisticsService: MockStatisticsServiceForMenuBar!
    var mockSettingsService: MockSettingsServiceForMenuBar!
    var notificationObserver: NSObjectProtocol?

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()

        mockStatisticsService = MockStatisticsServiceForMenuBar()
        mockSettingsService = MockSettingsServiceForMenuBar()

        sut = MenuBarViewModel(
            statisticsService: mockStatisticsService,
            settingsService: mockSettingsService
        )

        // Wait for init task to complete
        try await Task.sleep(nanoseconds: 100_000_000)
    }

    override func tearDown() async throws {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
            notificationObserver = nil
        }
        sut = nil
        mockStatisticsService = nil
        mockSettingsService = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func test_initialization_setsDefaultState() {
        // Then
        XCTAssertEqual(sut.wordsToday, 0)
        XCTAssertEqual(sut.sessionsToday, 0)
        XCTAssertFalse(sut.isLoading)
        XCTAssertEqual(sut.currentLanguage, "en")
    }

    func test_initialization_loadsLanguageFromSettings() async throws {
        // Given
        mockSettingsService.mockSettings.language.defaultLanguage = "fr"

        // When
        let viewModel = MenuBarViewModel(
            statisticsService: mockStatisticsService,
            settingsService: mockSettingsService
        )

        // Wait for init task to complete
        try await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertEqual(viewModel.currentLanguage, "fr")
    }

    // MARK: - refreshStatistics Tests

    func test_refreshStatistics_setsIsLoadingDuringRefresh() async {
        // Given
        mockStatisticsService.delay = 100_000_000 // 100ms delay

        // When
        let refreshTask = Task {
            await sut.refreshStatistics()
        }

        // Brief wait to catch loading state
        try? await Task.sleep(nanoseconds: 50_000_000)

        // Then - should be loading during refresh
        XCTAssertTrue(sut.isLoading)

        // Wait for completion
        await refreshTask.value

        // Then - should not be loading after refresh
        XCTAssertFalse(sut.isLoading)
    }

    func test_refreshStatistics_updatesWordsToday() async {
        // Given
        mockStatisticsService.mockStats = UsageStatistics(
            date: Date(),
            totalSessions: 5,
            successfulSessions: 4,
            failedSessions: 1,
            totalWordsTranscribed: 500,
            totalDurationSeconds: 300.0,
            averageConfidence: 0.9,
            languageBreakdown: [],
            errorBreakdown: []
        )

        // When
        await sut.refreshStatistics()

        // Then
        XCTAssertEqual(sut.wordsToday, 500)
    }

    func test_refreshStatistics_updatesSessionsToday() async {
        // Given
        mockStatisticsService.mockStats = UsageStatistics(
            date: Date(),
            totalSessions: 10,
            successfulSessions: 8,
            failedSessions: 2,
            totalWordsTranscribed: 1000,
            totalDurationSeconds: 600.0,
            averageConfidence: 0.85,
            languageBreakdown: [],
            errorBreakdown: []
        )

        // When
        await sut.refreshStatistics()

        // Then
        XCTAssertEqual(sut.sessionsToday, 10)
    }

    func test_refreshStatistics_updatesLastUpdated() async {
        // Given
        let beforeRefresh = sut.lastUpdated

        // Wait a bit to ensure time difference
        try? await Task.sleep(nanoseconds: 10_000_000)

        // When
        await sut.refreshStatistics()

        // Then
        XCTAssertGreaterThan(sut.lastUpdated, beforeRefresh)
    }

    // MARK: - startRecording Tests

    func test_startRecording_postsShowRecordingModalNotification() {
        // Given
        var notificationReceived = false
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .showRecordingModal,
            object: nil,
            queue: .main
        ) { _ in
            notificationReceived = true
        }

        // When
        sut.startRecording()

        // Then
        XCTAssertTrue(notificationReceived)
    }

    // MARK: - openSettings Tests

    func test_openSettings_postsShowSettingsNotification() {
        // Given
        var notificationReceived = false
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .showSettings,
            object: nil,
            queue: .main
        ) { _ in
            notificationReceived = true
        }

        // When
        sut.openSettings()

        // Then
        XCTAssertTrue(notificationReceived)
    }

    // MARK: - loadLanguageSettings Tests

    func test_loadLanguageSettings_updatesCurrentLanguage() async {
        // Given
        mockSettingsService.mockSettings.language.defaultLanguage = "de"
        mockSettingsService.mockSettings.language.recentLanguages = ["de", "fr"]

        // When
        await sut.loadLanguageSettings()

        // Then
        XCTAssertEqual(sut.currentLanguage, "de")
    }

    func test_loadLanguageSettings_updatesRecentLanguages() async {
        // Given
        mockSettingsService.mockSettings.language.defaultLanguage = "en"
        mockSettingsService.mockSettings.language.recentLanguages = ["en", "fr", "de"]

        // When
        await sut.loadLanguageSettings()

        // Then
        XCTAssertEqual(sut.recentLanguages.count, 3)
        XCTAssertEqual(sut.recentLanguages[0].code, "en")
        XCTAssertEqual(sut.recentLanguages[1].code, "fr")
        XCTAssertEqual(sut.recentLanguages[2].code, "de")
    }

    func test_loadLanguageSettings_addsCurrentLanguageIfRecentEmpty() async {
        // Given
        mockSettingsService.mockSettings.language.defaultLanguage = "es"
        mockSettingsService.mockSettings.language.recentLanguages = []

        // When
        await sut.loadLanguageSettings()

        // Then
        XCTAssertEqual(sut.recentLanguages.count, 1)
        XCTAssertEqual(sut.recentLanguages[0].code, "es")
    }

    // MARK: - switchLanguage Tests

    func test_switchLanguage_updatesCurrentLanguage() async {
        // Given
        let frenchLanguage = LanguageModel.supportedLanguages.first { $0.code == "fr" }!

        // When
        await sut.switchLanguage(to: frenchLanguage)

        // Then
        XCTAssertEqual(sut.currentLanguage, "fr")
    }

    func test_switchLanguage_addsToRecentLanguages() async {
        // Given
        sut.recentLanguages = []
        let germanLanguage = LanguageModel.supportedLanguages.first { $0.code == "de" }!

        // When
        await sut.switchLanguage(to: germanLanguage)

        // Then
        XCTAssertTrue(sut.recentLanguages.contains { $0.code == "de" })
    }

    func test_switchLanguage_movesLanguageToFrontIfAlreadyRecent() async {
        // Given
        let english = LanguageModel.supportedLanguages.first { $0.code == "en" }!
        let french = LanguageModel.supportedLanguages.first { $0.code == "fr" }!
        let german = LanguageModel.supportedLanguages.first { $0.code == "de" }!
        sut.recentLanguages = [english, french, german]

        // When - switch to German (already in list)
        await sut.switchLanguage(to: german)

        // Then - German should be at front
        XCTAssertEqual(sut.recentLanguages[0].code, "de")
        XCTAssertEqual(sut.recentLanguages.count, 3)
    }

    func test_switchLanguage_limitsRecentLanguagesToFive() async {
        // Given - add 5 languages first
        let codes = ["en", "fr", "de", "es", "it"]
        sut.recentLanguages = codes.compactMap { code in
            LanguageModel.supportedLanguages.first { $0.code == code }
        }
        XCTAssertEqual(sut.recentLanguages.count, 5)

        // When - add a 6th language
        let portuguese = LanguageModel.supportedLanguages.first { $0.code == "pt" }!
        await sut.switchLanguage(to: portuguese)

        // Then - should still be 5 languages
        XCTAssertEqual(sut.recentLanguages.count, 5)
        XCTAssertEqual(sut.recentLanguages[0].code, "pt")
    }

    func test_switchLanguage_savesSettingsToDisk() async {
        // Given
        let spanishLanguage = LanguageModel.supportedLanguages.first { $0.code == "es" }!

        // When
        await sut.switchLanguage(to: spanishLanguage)

        // Then
        XCTAssertTrue(mockSettingsService.saveWasCalled)
        XCTAssertEqual(mockSettingsService.lastSavedSettings?.language.defaultLanguage, "es")
    }

    func test_switchLanguage_postsSwitchLanguageNotification() async {
        // Given
        var receivedLanguageCode: String?
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .switchLanguage,
            object: nil,
            queue: .main
        ) { notification in
            receivedLanguageCode = notification.userInfo?["languageCode"] as? String
        }

        let italianLanguage = LanguageModel.supportedLanguages.first { $0.code == "it" }!

        // When
        await sut.switchLanguage(to: italianLanguage)

        // Then
        XCTAssertEqual(receivedLanguageCode, "it")
    }

    // MARK: - currentLanguageModel Tests

    func test_currentLanguageModel_returnsCorrectModel() {
        // Given
        sut.currentLanguage = "fr"

        // When
        let model = sut.currentLanguageModel

        // Then
        XCTAssertNotNil(model)
        XCTAssertEqual(model?.code, "fr")
        XCTAssertEqual(model?.name, "French")
    }

    func test_currentLanguageModel_returnsNilForUnsupportedLanguage() {
        // Given
        sut.currentLanguage = "unsupported_language"

        // When
        let model = sut.currentLanguageModel

        // Then
        XCTAssertNil(model)
    }
}

// MARK: - Mock Services

actor MockStatisticsServiceForMenuBar: StatisticsService {
    var mockStats = UsageStatistics(date: Date())
    var delay: UInt64 = 0

    override func getTodayStats() -> UsageStatistics {
        if delay > 0 {
            try? await Task.sleep(nanoseconds: delay)
        }
        return mockStats
    }
}

@MainActor
class MockSettingsServiceForMenuBar: SettingsService {
    var mockSettings = UserSettings.default
    var saveWasCalled = false
    var lastSavedSettings: UserSettings?

    override func load() -> UserSettings {
        return mockSettings
    }

    override func save(_ settings: UserSettings) throws {
        saveWasCalled = true
        lastSavedSettings = settings
        mockSettings = settings
    }
}
