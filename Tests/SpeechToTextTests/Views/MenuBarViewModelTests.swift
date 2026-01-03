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
    var notificationObserver: NSObjectProtocol?

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        // Create with default services - can't mock actor-based StatisticsService
        sut = MenuBarViewModel()

        // Wait for init task to complete
        try await Task.sleep(nanoseconds: 100_000_000)
    }

    override func tearDown() async throws {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
            notificationObserver = nil
        }
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func test_initialization_setsDefaultState() {
        // Note: Using default services since StatisticsService is an actor and can't be mocked via inheritance
        let viewModel = MenuBarViewModel()

        // Then - check initial state
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertEqual(viewModel.currentLanguage, "en")
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
    }

    func test_currentLanguageModel_returnsNilForUnsupportedLanguage() {
        // Given
        sut.currentLanguage = "unsupported_language"

        // When
        let model = sut.currentLanguageModel

        // Then
        XCTAssertNil(model)
    }

    // MARK: - refreshStatistics Tests

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

    func test_refreshStatistics_setsIsLoadingFalseAfterCompletion() async {
        // When
        await sut.refreshStatistics()

        // Then - should not be loading after refresh
        XCTAssertFalse(sut.isLoading)
    }
}
