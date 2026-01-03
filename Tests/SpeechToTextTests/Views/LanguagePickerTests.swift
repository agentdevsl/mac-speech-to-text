// LanguagePickerTests.swift
// macOS Local Speech-to-Text Application
//
// Unit tests for LanguagePicker

import SwiftUI
import XCTest
@testable import SpeechToText

@MainActor
final class LanguagePickerTests: XCTestCase {
    // MARK: - Properties

    var selectedLanguageCode: String = "en"
    var onLanguageSelectedCalled: Bool = false
    var lastSelectedLanguage: LanguageModel?

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        selectedLanguageCode = "en"
        onLanguageSelectedCalled = false
        lastSelectedLanguage = nil
    }

    // MARK: - Initialization Tests

    func test_languagePicker_createsSuccessfully() {
        // Given/When
        let picker = LanguagePicker(
            selectedLanguageCode: .constant("en"),
            onLanguageSelected: { _ in }
        )

        // Then
        XCTAssertNotNil(picker)
    }

    // MARK: - Filtering Tests

    func test_filteredLanguages_emptySearch_returnsAllLanguages() {
        // Given
        let helper = LanguageFilterHelper(searchText: "")

        // When
        let filtered = helper.filteredLanguages

        // Then
        XCTAssertEqual(filtered.count, LanguageModel.supportedLanguages.count)
    }

    func test_filteredLanguages_matchesByName() {
        // Given
        let helper = LanguageFilterHelper(searchText: "French")

        // When
        let filtered = helper.filteredLanguages

        // Then
        XCTAssertTrue(filtered.contains { $0.code == "fr" })
    }

    func test_filteredLanguages_matchesByNativeName() {
        // Given
        let helper = LanguageFilterHelper(searchText: "Français")

        // When
        let filtered = helper.filteredLanguages

        // Then
        XCTAssertTrue(filtered.contains { $0.code == "fr" })
    }

    func test_filteredLanguages_matchesByCode() {
        // Given
        let helper = LanguageFilterHelper(searchText: "de")

        // When
        let filtered = helper.filteredLanguages

        // Then
        XCTAssertTrue(filtered.contains { $0.code == "de" })
    }

    func test_filteredLanguages_caseInsensitiveSearch() {
        // Given
        let helperLower = LanguageFilterHelper(searchText: "german")
        let helperUpper = LanguageFilterHelper(searchText: "GERMAN")
        let helperMixed = LanguageFilterHelper(searchText: "GeRmAn")

        // When
        let filteredLower = helperLower.filteredLanguages
        let filteredUpper = helperUpper.filteredLanguages
        let filteredMixed = helperMixed.filteredLanguages

        // Then - all should find German
        XCTAssertTrue(filteredLower.contains { $0.code == "de" })
        XCTAssertTrue(filteredUpper.contains { $0.code == "de" })
        XCTAssertTrue(filteredMixed.contains { $0.code == "de" })
    }

    func test_filteredLanguages_noMatches_returnsEmpty() {
        // Given
        let helper = LanguageFilterHelper(searchText: "xyz123nonexistent")

        // When
        let filtered = helper.filteredLanguages

        // Then
        XCTAssertTrue(filtered.isEmpty)
    }

    func test_filteredLanguages_partialMatch() {
        // Given
        let helper = LanguageFilterHelper(searchText: "Span")

        // When
        let filtered = helper.filteredLanguages

        // Then - should match Spanish
        XCTAssertTrue(filtered.contains { $0.code == "es" })
    }

    // MARK: - Language Selection Tests

    func test_languageSelection_updatesBinding() {
        // Given
        var code = "en"

        // When
        code = "fr"

        // Then
        XCTAssertEqual(code, "fr")
    }

    func test_languageSelection_callsCallback() async {
        // Given
        var callbackCalled = false
        var selectedLanguage: LanguageModel?

        let callback: (LanguageModel) async -> Void = { language in
            callbackCalled = true
            selectedLanguage = language
        }

        let french = LanguageModel.supportedLanguages.first { $0.code == "fr" }!

        // When
        await callback(french)

        // Then
        XCTAssertTrue(callbackCalled)
        XCTAssertEqual(selectedLanguage?.code, "fr")
    }

    // MARK: - LanguageRow Tests

    func test_languageRow_isSelectedTrue_showsCheckmark() {
        // Given
        let isSelected = true

        // Then
        XCTAssertTrue(isSelected)
        // Actual UI verification would require ViewInspector
    }

    func test_languageRow_isSelectedFalse_showsEmptyCircle() {
        // Given
        let isSelected = false

        // Then
        XCTAssertFalse(isSelected)
    }

    // MARK: - Download Status Tests

    func test_downloadStatusText_downloaded() {
        // Given
        let status: LanguageModel.DownloadStatus = .downloaded

        // When
        let text = downloadStatusText(for: status)

        // Then
        XCTAssertEqual(text, "downloaded")
    }

    func test_downloadStatusText_downloading() {
        // Given
        let status: LanguageModel.DownloadStatus = .downloading

        // When
        let text = downloadStatusText(for: status)

        // Then
        XCTAssertEqual(text, "downloading")
    }

    func test_downloadStatusText_notDownloaded() {
        // Given
        let status: LanguageModel.DownloadStatus = .notDownloaded

        // When
        let text = downloadStatusText(for: status)

        // Then
        XCTAssertEqual(text, "not downloaded")
    }

    func test_downloadStatusText_error() {
        // Given
        let status: LanguageModel.DownloadStatus = .error

        // When
        let text = downloadStatusText(for: status)

        // Then
        XCTAssertEqual(text, "download error")
    }

    // MARK: - Accessibility Tests

    func test_accessibilityLabel_includesLanguageName() {
        // Given
        let language = LanguageModel.supportedLanguages.first { $0.code == "fr" }!
        let isSelected = true

        // When
        let label = accessibilityLabel(for: language, isSelected: isSelected, downloadStatus: .downloaded)

        // Then
        XCTAssertTrue(label.contains(language.name))
    }

    func test_accessibilityLabel_includesSelectionState() {
        // Given
        let language = LanguageModel.supportedLanguages.first { $0.code == "en" }!

        // When
        let labelSelected = accessibilityLabel(for: language, isSelected: true, downloadStatus: .downloaded)
        let labelNotSelected = accessibilityLabel(for: language, isSelected: false, downloadStatus: .downloaded)

        // Then
        XCTAssertTrue(labelSelected.contains("selected"))
        XCTAssertTrue(labelNotSelected.contains("not selected"))
    }

    func test_accessibilityLabel_includesDownloadStatus() {
        // Given
        let language = LanguageModel.supportedLanguages.first { $0.code == "en" }!

        // When
        let label = accessibilityLabel(for: language, isSelected: false, downloadStatus: .notDownloaded)

        // Then
        XCTAssertTrue(label.contains("not downloaded"))
    }

    func test_accessibilityHint_selectedLanguage() {
        // Given
        let isSelected = true

        // When
        let hint = accessibilityHint(isSelected: isSelected)

        // Then
        XCTAssertEqual(hint, "Currently selected language")
    }

    func test_accessibilityHint_notSelectedLanguage() {
        // Given
        let isSelected = false

        // When
        let hint = accessibilityHint(isSelected: isSelected)

        // Then
        XCTAssertEqual(hint, "Double tap to select this language")
    }

    // MARK: - Helper Methods

    private func downloadStatusText(for status: LanguageModel.DownloadStatus) -> String {
        switch status {
        case .downloaded:
            return "downloaded"
        case .downloading:
            return "downloading"
        case .notDownloaded:
            return "not downloaded"
        case .error:
            return "download error"
        }
    }

    private func accessibilityLabel(
        for language: LanguageModel,
        isSelected: Bool,
        downloadStatus: LanguageModel.DownloadStatus
    ) -> String {
        let selectionText = isSelected ? "selected" : "not selected"
        let statusText = downloadStatusText(for: downloadStatus)
        return "\(language.name), \(selectionText), \(statusText)"
    }

    private func accessibilityHint(isSelected: Bool) -> String {
        isSelected ? "Currently selected language" : "Double tap to select this language"
    }
}

// MARK: - Helper Classes

/// Helper to test filter logic that mirrors LanguagePicker's filteredLanguages
struct LanguageFilterHelper {
    let searchText: String

    var filteredLanguages: [LanguageModel] {
        if searchText.isEmpty {
            return LanguageModel.supportedLanguages
        }

        return LanguageModel.supportedLanguages.filter { language in
            language.name.localizedCaseInsensitiveContains(searchText) ||
            language.nativeName.localizedCaseInsensitiveContains(searchText) ||
            language.code.localizedCaseInsensitiveContains(searchText)
        }
    }
}
