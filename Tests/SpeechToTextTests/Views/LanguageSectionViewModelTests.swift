// LanguageSectionViewModelTests.swift
// macOS Local Speech-to-Text Application
//
// Unit tests for LanguageSectionViewModel

import XCTest
@testable import SpeechToText

@MainActor
final class LanguageSectionViewModelTests: XCTestCase {
    // MARK: - Properties

    var sut: LanguageSectionViewModel!
    var mockSettingsService: MockSettingsServiceForLanguage!
    var testUserDefaults: UserDefaults!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()

        // Create isolated UserDefaults for testing
        testUserDefaults = UserDefaults(suiteName: "LanguageSectionViewModelTests")!
        testUserDefaults.removePersistentDomain(forName: "LanguageSectionViewModelTests")
        testUserDefaults.synchronize()

        mockSettingsService = MockSettingsServiceForLanguage(userDefaults: testUserDefaults)
        sut = LanguageSectionViewModel(settingsService: mockSettingsService)
    }

    override func tearDown() async throws {
        sut = nil
        mockSettingsService = nil
        testUserDefaults?.removePersistentDomain(forName: "LanguageSectionViewModelTests")
        testUserDefaults?.synchronize()
        testUserDefaults = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func test_initialization_loadsSelectedLanguageFromSettings() {
        // Given - default settings have "en" as default language
        // Then
        XCTAssertEqual(sut.selectedLanguageCode, "en")
    }

    func test_initialization_loadsAutoDetectFromSettings() {
        // Given - default settings have autoDetect false
        // Then
        XCTAssertFalse(sut.autoDetectEnabled)
    }

    func test_initialization_loadsRecentLanguagesFromSettings() {
        // Given - default settings have ["en"] in recent
        // Then
        XCTAssertFalse(sut.recentLanguages.isEmpty)
    }

    func test_initialization_loadsDownloadedModelsFromSettings() {
        // Given - default settings have ["en"] downloaded
        // Then
        XCTAssertFalse(sut.downloadedModels.isEmpty)
        XCTAssertTrue(sut.downloadedModels.contains("en"))
    }

    func test_initialization_withCustomSettings_loadsCorrectly() async throws {
        // Given
        var customSettings = UserSettings.default
        customSettings.language.defaultLanguage = "fr"
        customSettings.language.autoDetectEnabled = true
        customSettings.language.recentLanguages = ["fr", "de", "es"]
        customSettings.language.downloadedModels = ["fr", "de"]
        try mockSettingsService.save(customSettings)

        // When
        let viewModel = LanguageSectionViewModel(settingsService: mockSettingsService)

        // Then
        XCTAssertEqual(viewModel.selectedLanguageCode, "fr")
        XCTAssertTrue(viewModel.autoDetectEnabled)
        XCTAssertEqual(viewModel.recentLanguages.count, 3)
        XCTAssertEqual(viewModel.downloadedModels.count, 2)
    }

    // MARK: - currentLanguageName Tests

    func test_currentLanguageName_returnsCorrectNameForEnglish() {
        // Given
        sut.selectedLanguageCode = "en"

        // Then
        XCTAssertEqual(sut.currentLanguageName, "English")
    }

    func test_currentLanguageName_returnsCorrectNameForFrench() {
        // Given
        sut.selectedLanguageCode = "fr"

        // Then
        XCTAssertEqual(sut.currentLanguageName, "Fran\u{00E7}ais")
    }

    func test_currentLanguageName_returnsCorrectNameForGerman() {
        // Given
        sut.selectedLanguageCode = "de"

        // Then
        XCTAssertEqual(sut.currentLanguageName, "Deutsch")
    }

    func test_currentLanguageName_returnsCorrectNameForSpanish() {
        // Given
        sut.selectedLanguageCode = "es"

        // Then
        XCTAssertEqual(sut.currentLanguageName, "Espa\u{00F1}ol")
    }

    func test_currentLanguageName_returnsUnknownForInvalidCode() {
        // Given
        sut.selectedLanguageCode = "invalid"

        // Then
        XCTAssertEqual(sut.currentLanguageName, "Unknown")
    }

    // MARK: - currentLanguageFlag Tests

    func test_currentLanguageFlag_returnsCorrectFlagForEnglish() {
        // Given
        sut.selectedLanguageCode = "en"

        // Then
        XCTAssertEqual(sut.currentLanguageFlag, "\u{1F1EC}\u{1F1E7}")
    }

    func test_currentLanguageFlag_returnsCorrectFlagForFrench() {
        // Given
        sut.selectedLanguageCode = "fr"

        // Then
        XCTAssertEqual(sut.currentLanguageFlag, "\u{1F1EB}\u{1F1F7}")
    }

    func test_currentLanguageFlag_returnsCorrectFlagForGerman() {
        // Given
        sut.selectedLanguageCode = "de"

        // Then
        XCTAssertEqual(sut.currentLanguageFlag, "\u{1F1E9}\u{1F1EA}")
    }

    func test_currentLanguageFlag_returnsGlobeForInvalidCode() {
        // Given
        sut.selectedLanguageCode = "invalid"

        // Then
        XCTAssertEqual(sut.currentLanguageFlag, "\u{1F310}")
    }

    // MARK: - isCurrentLanguageDownloaded Tests

    func test_isCurrentLanguageDownloaded_returnsTrueWhenDownloaded() {
        // Given
        sut.selectedLanguageCode = "en"
        sut.downloadedModels = ["en", "fr"]

        // Then
        XCTAssertTrue(sut.isCurrentLanguageDownloaded)
    }

    func test_isCurrentLanguageDownloaded_returnsFalseWhenNotDownloaded() {
        // Given
        sut.selectedLanguageCode = "de"
        sut.downloadedModels = ["en", "fr"]

        // Then
        XCTAssertFalse(sut.isCurrentLanguageDownloaded)
    }

    func test_isCurrentLanguageDownloaded_returnsFalseWhenNoModelsDownloaded() {
        // Given
        sut.selectedLanguageCode = "en"
        sut.downloadedModels = []

        // Then
        XCTAssertFalse(sut.isCurrentLanguageDownloaded)
    }

    // MARK: - downloadedModelsCount Tests

    func test_downloadedModelsCount_returnsCorrectCount() {
        // Given
        sut.downloadedModels = ["en", "fr", "de"]

        // Then
        XCTAssertEqual(sut.downloadedModelsCount, 3)
    }

    func test_downloadedModelsCount_returnsZeroWhenEmpty() {
        // Given
        sut.downloadedModels = []

        // Then
        XCTAssertEqual(sut.downloadedModelsCount, 0)
    }

    // MARK: - downloadedModelsSize Tests

    func test_downloadedModelsSize_returnsCorrectSizeInMB() {
        // Given
        sut.downloadedModels = ["en"]

        // Then
        XCTAssertEqual(sut.downloadedModelsSize, "500 MB")
    }

    func test_downloadedModelsSize_returnsCorrectSizeInGB() {
        // Given
        sut.downloadedModels = ["en", "fr"]

        // Then
        XCTAssertEqual(sut.downloadedModelsSize, "1.0 GB")
    }

    func test_downloadedModelsSize_returnsCorrectSizeForMultipleModels() {
        // Given
        sut.downloadedModels = ["en", "fr", "de", "es"]

        // Then
        XCTAssertEqual(sut.downloadedModelsSize, "2.0 GB")
    }

    func test_downloadedModelsSize_returnsZeroMBWhenEmpty() {
        // Given
        sut.downloadedModels = []

        // Then
        XCTAssertEqual(sut.downloadedModelsSize, "0 MB")
    }

    // MARK: - selectLanguage Tests

    func test_selectLanguage_updatesSelectedLanguageCode() {
        // Given
        let frenchModel = LanguageModel.supportedLanguages.first { $0.code == "fr" }!

        // When
        sut.selectLanguage(frenchModel)

        // Then
        XCTAssertEqual(sut.selectedLanguageCode, "fr")
    }

    func test_selectLanguage_addsToRecentLanguages() {
        // Given
        sut.recentLanguages = []
        let germanModel = LanguageModel.supportedLanguages.first { $0.code == "de" }!

        // When
        sut.selectLanguage(germanModel)

        // Then
        XCTAssertTrue(sut.recentLanguages.contains { $0.code == "de" })
    }

    func test_selectLanguage_movesLanguageToFrontOfRecent() {
        // Given
        let englishModel = LanguageModel.supportedLanguages.first { $0.code == "en" }!
        let frenchModel = LanguageModel.supportedLanguages.first { $0.code == "fr" }!
        let germanModel = LanguageModel.supportedLanguages.first { $0.code == "de" }!

        sut.selectLanguage(englishModel)
        sut.selectLanguage(frenchModel)
        sut.selectLanguage(germanModel)

        // When - select French again
        sut.selectLanguage(frenchModel)

        // Then - French should be first
        XCTAssertEqual(sut.recentLanguages.first?.code, "fr")
    }

    func test_selectLanguage_limitsRecentLanguagesToFour() {
        // Given
        let languages = LanguageModel.supportedLanguages.prefix(6)

        // When
        for lang in languages {
            sut.selectLanguage(lang)
        }

        // Then
        XCTAssertLessThanOrEqual(sut.recentLanguages.count, 4)
    }

    func test_selectLanguage_doesNotDuplicateInRecent() {
        // Given
        let englishModel = LanguageModel.supportedLanguages.first { $0.code == "en" }!

        // When
        sut.selectLanguage(englishModel)
        sut.selectLanguage(englishModel)
        sut.selectLanguage(englishModel)

        // Then
        let englishCount = sut.recentLanguages.filter { $0.code == "en" }.count
        XCTAssertEqual(englishCount, 1)
    }

    // MARK: - autoDetectEnabled Tests

    func test_autoDetectEnabled_defaultsToFalse() {
        // Then
        XCTAssertFalse(sut.autoDetectEnabled)
    }

    func test_autoDetectEnabled_canBeToggled() {
        // When
        sut.autoDetectEnabled = true

        // Then
        XCTAssertTrue(sut.autoDetectEnabled)

        // When
        sut.autoDetectEnabled = false

        // Then
        XCTAssertFalse(sut.autoDetectEnabled)
    }

    // MARK: - LanguageModel Static Properties Tests

    func test_supportedLanguages_containsExpectedCount() {
        // Then - SupportedLanguage has 25 cases
        XCTAssertEqual(LanguageModel.supportedLanguages.count, 25)
    }

    func test_supportedLanguages_containsEnglish() {
        // Then
        XCTAssertTrue(LanguageModel.supportedLanguages.contains { $0.code == "en" })
    }

    func test_supportedLanguages_containsFrench() {
        // Then
        XCTAssertTrue(LanguageModel.supportedLanguages.contains { $0.code == "fr" })
    }

    func test_supportedLanguages_containsGerman() {
        // Then
        XCTAssertTrue(LanguageModel.supportedLanguages.contains { $0.code == "de" })
    }

    func test_supportedLanguages_containsSpanish() {
        // Then
        XCTAssertTrue(LanguageModel.supportedLanguages.contains { $0.code == "es" })
    }

    // MARK: - Edge Cases

    func test_selectLanguage_handlesEmptyRecentList() {
        // Given
        sut.recentLanguages = []
        let englishModel = LanguageModel.supportedLanguages.first { $0.code == "en" }!

        // When
        sut.selectLanguage(englishModel)

        // Then
        XCTAssertEqual(sut.recentLanguages.count, 1)
        XCTAssertEqual(sut.recentLanguages.first?.code, "en")
    }

    func test_recentLanguages_maintainsOrder() {
        // Given
        sut.recentLanguages = []

        let englishModel = LanguageModel.supportedLanguages.first { $0.code == "en" }!
        let frenchModel = LanguageModel.supportedLanguages.first { $0.code == "fr" }!
        let germanModel = LanguageModel.supportedLanguages.first { $0.code == "de" }!

        // When
        sut.selectLanguage(englishModel)
        sut.selectLanguage(frenchModel)
        sut.selectLanguage(germanModel)

        // Then - most recent first
        XCTAssertEqual(sut.recentLanguages[0].code, "de")
        XCTAssertEqual(sut.recentLanguages[1].code, "fr")
        XCTAssertEqual(sut.recentLanguages[2].code, "en")
    }

    func test_downloadedModels_canBeUpdated() {
        // Given
        sut.downloadedModels = ["en"]

        // When
        sut.downloadedModels.append("fr")

        // Then
        XCTAssertEqual(sut.downloadedModels.count, 2)
        XCTAssertTrue(sut.downloadedModels.contains("fr"))
    }
}

// MARK: - Mock Settings Service

@MainActor
class MockSettingsServiceForLanguage: SettingsService {
    var saveCalled = false
    var loadCalled = false
    private var storedSettings: UserSettings

    override init(userDefaults: UserDefaults = .standard) {
        self.storedSettings = .default
        super.init(userDefaults: userDefaults)
    }

    override func load() -> UserSettings {
        loadCalled = true
        return storedSettings
    }

    override func save(_ settings: UserSettings) throws {
        saveCalled = true
        storedSettings = settings
    }
}
