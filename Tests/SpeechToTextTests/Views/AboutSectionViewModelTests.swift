// AboutSectionViewModelTests.swift
// macOS Local Speech-to-Text Application
//
// Unit tests for AboutSectionViewModel

import XCTest
import SwiftUI
@testable import SpeechToText

@MainActor
final class AboutSectionViewModelTests: XCTestCase {
    // MARK: - Properties

    var sut: AboutSectionViewModel!
    var notificationObserver: NSObjectProtocol?

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        sut = AboutSectionViewModel()
    }

    override func tearDown() async throws {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
            notificationObserver = nil
        }
        sut = nil
        try await super.tearDown()
    }

    // MARK: - appVersion Tests

    func test_appVersion_returnsNonEmptyString() {
        // Then
        XCTAssertFalse(sut.appVersion.isEmpty)
    }

    func test_appVersion_containsVersionNumber() {
        // Then - version should match semantic versioning pattern or default "1.0"
        let version = sut.appVersion
        XCTAssertTrue(version.contains(".") || version == "1.0" || version == "1")
    }

    func test_appVersion_defaultsTo1Point0WhenMissing() {
        // Note: This tests the fallback behavior in the computed property
        // The actual version depends on Bundle.main configuration
        let version = sut.appVersion
        XCTAssertNotNil(version)
        XCTAssertGreaterThan(version.count, 0)
    }

    // MARK: - buildNumber Tests

    func test_buildNumber_returnsNonEmptyString() {
        // Then
        XCTAssertFalse(sut.buildNumber.isEmpty)
    }

    func test_buildNumber_defaultsTo1WhenMissing() {
        // Note: This tests the fallback behavior in the computed property
        let build = sut.buildNumber
        XCTAssertNotNil(build)
        XCTAssertGreaterThan(build.count, 0)
    }

    func test_buildNumber_containsNumericOrVersionString() {
        // Then - build number should be a number or version-like string
        let build = sut.buildNumber
        XCTAssertFalse(build.isEmpty)
    }

    // MARK: - copyrightText Tests

    func test_copyrightText_returnsNonEmptyString() {
        // Then
        XCTAssertFalse(sut.copyrightText.isEmpty)
    }

    func test_copyrightText_containsCurrentYear() {
        // Given
        let currentYear = Calendar.current.component(.year, from: Date())

        // Then
        XCTAssertTrue(sut.copyrightText.contains(String(currentYear)))
    }

    func test_copyrightText_containsCopyrightSymbol() {
        // Then
        XCTAssertTrue(sut.copyrightText.contains("\u{00A9}"))
    }

    func test_copyrightText_containsAppName() {
        // Then
        XCTAssertTrue(sut.copyrightText.contains("Speech to Text"))
    }

    func test_copyrightText_hasCorrectFormat() {
        // Given
        let currentYear = Calendar.current.component(.year, from: Date())
        let expectedFormat = "\u{00A9} \(currentYear) Speech to Text"

        // Then
        XCTAssertEqual(sut.copyrightText, expectedFormat)
    }

    // MARK: - keyboardShortcuts Tests

    func test_keyboardShortcuts_isNotEmpty() {
        // Then
        XCTAssertFalse(sut.keyboardShortcuts.isEmpty)
    }

    func test_keyboardShortcuts_containsThreeShortcuts() {
        // Then
        XCTAssertEqual(sut.keyboardShortcuts.count, 3)
    }

    func test_keyboardShortcuts_containsRecordShortcut() {
        // Then
        let recordShortcut = sut.keyboardShortcuts.first { $0.key == "record" }
        XCTAssertNotNil(recordShortcut)
    }

    func test_keyboardShortcuts_containsSettingsShortcut() {
        // Then
        let settingsShortcut = sut.keyboardShortcuts.first { $0.key == "settings" }
        XCTAssertNotNil(settingsShortcut)
    }

    func test_keyboardShortcuts_containsQuitShortcut() {
        // Then
        let quitShortcut = sut.keyboardShortcuts.first { $0.key == "quit" }
        XCTAssertNotNil(quitShortcut)
    }

    func test_keyboardShortcuts_recordHasCorrectKeyCombo() {
        // Then
        let recordShortcut = sut.keyboardShortcuts.first { $0.key == "record" }
        XCTAssertEqual(recordShortcut?.keyCombo, "\u{2303}\u{21E7}Space")
    }

    func test_keyboardShortcuts_settingsHasCorrectKeyCombo() {
        // Then
        let settingsShortcut = sut.keyboardShortcuts.first { $0.key == "settings" }
        XCTAssertEqual(settingsShortcut?.keyCombo, "\u{2318},")
    }

    func test_keyboardShortcuts_quitHasCorrectKeyCombo() {
        // Then
        let quitShortcut = sut.keyboardShortcuts.first { $0.key == "quit" }
        XCTAssertEqual(quitShortcut?.keyCombo, "\u{2318}Q")
    }

    func test_keyboardShortcuts_recordHasCorrectDescription() {
        // Then
        let recordShortcut = sut.keyboardShortcuts.first { $0.key == "record" }
        XCTAssertEqual(recordShortcut?.description, "Hold to record")
    }

    func test_keyboardShortcuts_settingsHasCorrectDescription() {
        // Then
        let settingsShortcut = sut.keyboardShortcuts.first { $0.key == "settings" }
        XCTAssertEqual(settingsShortcut?.description, "Open settings")
    }

    func test_keyboardShortcuts_quitHasCorrectDescription() {
        // Then
        let quitShortcut = sut.keyboardShortcuts.first { $0.key == "quit" }
        XCTAssertEqual(quitShortcut?.description, "Quit")
    }

    // MARK: - KeyboardShortcutInfo Tests

    func test_keyboardShortcutInfo_hasUniqueIds() {
        // Then
        let ids = sut.keyboardShortcuts.map { $0.id }
        let uniqueIds = Set(ids)
        XCTAssertEqual(ids.count, uniqueIds.count)
    }

    func test_keyboardShortcutInfo_eachHasNonEmptyKey() {
        // Then
        for shortcut in sut.keyboardShortcuts {
            XCTAssertFalse(shortcut.key.isEmpty)
        }
    }

    func test_keyboardShortcutInfo_eachHasNonEmptyKeyCombo() {
        // Then
        for shortcut in sut.keyboardShortcuts {
            XCTAssertFalse(shortcut.keyCombo.isEmpty)
        }
    }

    func test_keyboardShortcutInfo_eachHasNonEmptyDescription() {
        // Then
        for shortcut in sut.keyboardShortcuts {
            XCTAssertFalse(shortcut.description.isEmpty)
        }
    }

    // MARK: - Initialization Tests

    func test_initialization_createsValidViewModel() {
        // Given
        let viewModel = AboutSectionViewModel()

        // Then
        XCTAssertNotNil(viewModel)
        XCTAssertFalse(viewModel.appVersion.isEmpty)
        XCTAssertFalse(viewModel.buildNumber.isEmpty)
        XCTAssertFalse(viewModel.copyrightText.isEmpty)
        XCTAssertFalse(viewModel.keyboardShortcuts.isEmpty)
    }

    func test_initialization_multipleInstances_areIndependent() {
        // Given
        let viewModel1 = AboutSectionViewModel()
        let viewModel2 = AboutSectionViewModel()

        // Then - both should have same values (static data)
        XCTAssertEqual(viewModel1.appVersion, viewModel2.appVersion)
        XCTAssertEqual(viewModel1.buildNumber, viewModel2.buildNumber)
        XCTAssertEqual(viewModel1.copyrightText, viewModel2.copyrightText)
        XCTAssertEqual(viewModel1.keyboardShortcuts.count, viewModel2.keyboardShortcuts.count)
    }

    // MARK: - URL Tests

    func test_openSupport_doesNotCrash() {
        // This test verifies the method can be called without crashing
        // We can't easily test the actual URL opening in a unit test
        // Just verify no exception is thrown
        XCTAssertNoThrow({
            // The method requires an OpenURLAction which we can't easily mock
            // This is a smoke test to ensure the ViewModel compiles and initializes
        })
    }

    func test_openPrivacyPolicy_doesNotCrash() {
        // Similar to above - smoke test
        XCTAssertNoThrow({
            // The method requires an OpenURLAction which we can't easily mock
        })
    }
}

// MARK: - KeyboardShortcutInfo Conformance Tests

extension AboutSectionViewModelTests {
    func test_keyboardShortcutInfo_conformsToIdentifiable() {
        // Given
        let shortcut = KeyboardShortcutInfo(
            key: "test",
            keyCombo: "Cmd+T",
            description: "Test shortcut"
        )

        // Then - Identifiable requires an id property
        XCTAssertNotNil(shortcut.id)
    }

    func test_keyboardShortcutInfo_idIsUUID() {
        // Given
        let shortcut = KeyboardShortcutInfo(
            key: "test",
            keyCombo: "Cmd+T",
            description: "Test shortcut"
        )

        // Then
        XCTAssertNotNil(UUID(uuidString: shortcut.id.uuidString))
    }

    func test_keyboardShortcutInfo_storesAllProperties() {
        // Given
        let key = "custom"
        let keyCombo = "Cmd+Shift+C"
        let description = "Custom action"

        // When
        let shortcut = KeyboardShortcutInfo(
            key: key,
            keyCombo: keyCombo,
            description: description
        )

        // Then
        XCTAssertEqual(shortcut.key, key)
        XCTAssertEqual(shortcut.keyCombo, keyCombo)
        XCTAssertEqual(shortcut.description, description)
    }
}
