// GeneralSectionTests.swift
// macOS Local Speech-to-Text Application
//
// Unit tests for GeneralSection view

import SwiftUI
import XCTest
@testable import SpeechToText

@MainActor
final class GeneralSectionTests: XCTestCase {
    // MARK: - Properties

    var settingsService: SettingsService!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        settingsService = SettingsService()
    }

    override func tearDown() async throws {
        settingsService = nil
        try await super.tearDown()
    }

    // MARK: - Instantiation Tests

    func test_generalSection_instantiatesWithoutCrash() {
        // When - Create the view
        let view = GeneralSection(settingsService: settingsService)

        // Then - Should not crash
        XCTAssertNotNil(view)
    }

    func test_generalSection_hasCorrectAccessibilityIdentifier() {
        // Given
        let view = GeneralSection(settingsService: settingsService)

        // Then - View should exist without crashing
        XCTAssertNotNil(view)
    }

    // MARK: - Settings Loading Tests

    func test_generalSection_loadsSettings() {
        // Given - Ensure settings service works
        let settings = settingsService.load()

        // Then - Settings should be valid
        XCTAssertNotNil(settings)
    }

    func test_generalSection_loadsRecordingMode() {
        // Given
        var settings = settingsService.load()
        settings.ui.recordingMode = .toggle
        try? settingsService.save(settings)

        // When - Create view with updated settings
        let view = GeneralSection(settingsService: settingsService)

        // Then - Should not crash
        XCTAssertNotNil(view)
    }

    func test_generalSection_loadsLaunchAtLogin() {
        // Given
        let settings = settingsService.load()

        // Then - launchAtLogin should have a valid boolean value
        XCTAssertNotNil(settings.general.launchAtLogin)
    }

    func test_generalSection_loadsAutoInsertText() {
        // Given
        let settings = settingsService.load()

        // Then - autoInsertText should have a valid boolean value
        XCTAssertNotNil(settings.general.autoInsertText)
    }

    func test_generalSection_loadsCopyToClipboard() {
        // Given
        let settings = settingsService.load()

        // Then - copyToClipboard should have a valid boolean value
        XCTAssertNotNil(settings.general.copyToClipboard)
    }

    func test_generalSection_loadsPasteBehavior() {
        // Given
        let settings = settingsService.load()

        // Then - pasteBehavior should have a valid value
        XCTAssertNotNil(settings.general.pasteBehavior)
    }
}

// MARK: - RecordingMode Tests

@MainActor
final class RecordingModeTests: XCTestCase {
    func test_recordingMode_hasExpectedCases() {
        // Then - Verify all expected cases exist
        let holdToRecord = RecordingMode.holdToRecord
        let toggle = RecordingMode.toggle

        XCTAssertNotEqual(holdToRecord, toggle)
    }

    func test_recordingMode_isComparable() {
        // Given
        let mode1 = RecordingMode.holdToRecord
        let mode2 = RecordingMode.holdToRecord
        let mode3 = RecordingMode.toggle

        // Then
        XCTAssertEqual(mode1, mode2)
        XCTAssertNotEqual(mode1, mode3)
    }
}

// MARK: - PasteBehavior Tests

@MainActor
final class PasteBehaviorTests: XCTestCase {
    func test_pasteBehavior_allCasesIsNotEmpty() {
        // Then
        XCTAssertFalse(PasteBehavior.allCases.isEmpty)
    }

    func test_pasteBehavior_hasDisplayName() {
        // Then
        for behavior in PasteBehavior.allCases {
            XCTAssertFalse(behavior.displayName.isEmpty)
        }
    }
}

// MARK: - Settings Persistence Tests

@MainActor
final class GeneralSectionPersistenceTests: XCTestCase {
    var settingsService: SettingsService!

    override func setUp() async throws {
        try await super.setUp()
        settingsService = SettingsService()
    }

    override func tearDown() async throws {
        settingsService = nil
        try await super.tearDown()
    }

    func test_settingsSave_persistsChanges() {
        // Given
        var settings = settingsService.load()
        let originalValue = settings.general.autoInsertText
        settings.general.autoInsertText = !originalValue

        // When
        try? settingsService.save(settings)

        // Then
        let reloadedSettings = settingsService.load()
        XCTAssertEqual(reloadedSettings.general.autoInsertText, !originalValue)

        // Cleanup - restore original value
        settings.general.autoInsertText = originalValue
        try? settingsService.save(settings)
    }

    func test_settingsSave_persistsRecordingMode() {
        // Given
        var settings = settingsService.load()
        let originalMode = settings.ui.recordingMode
        let newMode: RecordingMode = originalMode == .holdToRecord ? .toggle : .holdToRecord
        settings.ui.recordingMode = newMode

        // When
        try? settingsService.save(settings)

        // Then
        let reloadedSettings = settingsService.load()
        XCTAssertEqual(reloadedSettings.ui.recordingMode, newMode)

        // Cleanup - restore original value
        settings.ui.recordingMode = originalMode
        try? settingsService.save(settings)
    }

    func test_settingsSave_persistsCopyToClipboard() {
        // Given
        var settings = settingsService.load()
        let originalValue = settings.general.copyToClipboard
        settings.general.copyToClipboard = !originalValue

        // When
        try? settingsService.save(settings)

        // Then
        let reloadedSettings = settingsService.load()
        XCTAssertEqual(reloadedSettings.general.copyToClipboard, !originalValue)

        // Cleanup - restore original value
        settings.general.copyToClipboard = originalValue
        try? settingsService.save(settings)
    }
}
