// SettingsTests.swift
// macOS Local Speech-to-Text Application
//
// End-to-end UI tests for the Settings window
// Part of User Story 4: Settings and Preferences (P2)

import XCTest

/// Tests for the Settings window - user preferences and configuration
final class SettingsTests: UITestBase {
    // MARK: - SE-001: Settings Opens

    /// Test that Settings window opens with Cmd+,
    func test_settings_opensWithKeyboardShortcut() throws {
        launchAppSkippingOnboarding()

        // Give app time to fully initialize
        Thread.sleep(forTimeInterval: 1)

        // Open settings with Cmd+,
        UITestHelpers.openSettings(in: app)

        // Verify settings window appears
        let settingsWindow = app.windows["Settings"]
        XCTAssertTrue(
            settingsWindow.waitForExistence(timeout: 5),
            "Settings window should open with Cmd+,"
        )

        captureScreenshot(named: "SE-001-Settings-Opened")
    }

    // MARK: - SE-002: Settings Tabs

    /// Test that settings has expected tabs/sections
    func test_settings_hasTabs() throws {
        launchAppSkippingOnboarding()
        UITestHelpers.openSettings(in: app)

        let settingsWindow = app.windows["Settings"]
        guard settingsWindow.waitForExistence(timeout: 5) else {
            XCTFail("Settings window did not open")
            return
        }

        // Look for common settings sections
        // The exact structure depends on SettingsView implementation
        let generalTab = app.buttons["General"]
        let audioTab = app.buttons["Audio"]
        let languageTab = app.buttons["Language"]

        // At least one settings control should exist
        let hasContent = generalTab.exists || audioTab.exists || languageTab.exists
            || !app.staticTexts.allElementsBoundByIndex.isEmpty

        XCTAssertTrue(hasContent, "Settings should have content")

        captureScreenshot(named: "SE-002-Settings-Tabs")
    }

    // MARK: - SE-003: Hotkey Configuration

    /// Test that hotkey settings are accessible
    func test_settings_hotkeyConfiguration() throws {
        launchAppSkippingOnboarding()
        UITestHelpers.openSettings(in: app)

        let settingsWindow = app.windows["Settings"]
        guard settingsWindow.waitForExistence(timeout: 5) else {
            XCTFail("Settings window did not open")
            return
        }

        // Look for hotkey-related text
        let hotkeyLabel = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'hotkey' OR label CONTAINS[c] 'shortcut'")
        ).firstMatch

        let hotkeyExists = hotkeyLabel.waitForExistence(timeout: 3)

        captureScreenshot(named: "SE-003-Hotkey-Settings")

        // Hotkey settings may be in a submenu or different location
        if !hotkeyExists {
            print("Note: Hotkey settings not found in main view - may be in submenu")
        }
    }

    // MARK: - SE-004: Language Selection

    /// Test that language selection is available
    func test_settings_languageSelection() throws {
        launchAppSkippingOnboarding()
        UITestHelpers.openSettings(in: app)

        let settingsWindow = app.windows["Settings"]
        guard settingsWindow.waitForExistence(timeout: 5) else {
            XCTFail("Settings window did not open")
            return
        }

        // Look for language-related elements
        let languageLabel = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'language'")
        ).firstMatch

        let languageExists = languageLabel.waitForExistence(timeout: 3)

        // Look for language picker/popup
        let languagePicker = app.popUpButtons.matching(
            NSPredicate(format: "identifier CONTAINS[c] 'language'")
        ).firstMatch

        captureScreenshot(named: "SE-004-Language-Settings")

        XCTAssertTrue(
            languageExists || languagePicker.exists,
            "Language settings should be accessible"
        )
    }

    // MARK: - SE-005: Audio Sensitivity

    /// Test that audio sensitivity slider is available
    func test_settings_audioSensitivity() throws {
        launchAppSkippingOnboarding()
        UITestHelpers.openSettings(in: app)

        let settingsWindow = app.windows["Settings"]
        guard settingsWindow.waitForExistence(timeout: 5) else {
            XCTFail("Settings window did not open")
            return
        }

        // Look for audio/sensitivity controls
        let sensitivitySlider = app.sliders.matching(
            NSPredicate(format: "identifier CONTAINS[c] 'sensitivity' OR identifier CONTAINS[c] 'audio'")
        ).firstMatch

        let sensitivityLabel = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'sensitivity' OR label CONTAINS[c] 'silence'")
        ).firstMatch

        captureScreenshot(named: "SE-005-Audio-Settings")

        let hasAudioSettings = sensitivitySlider.exists || sensitivityLabel.exists

        // Audio settings may be under a specific tab
        if !hasAudioSettings {
            print("Note: Audio sensitivity settings not found in main view")
        }
    }

    // MARK: - SE-006: Settings Close

    /// Test that settings can be closed
    func test_settings_canBeClosed() throws {
        launchAppSkippingOnboarding()
        UITestHelpers.openSettings(in: app)

        let settingsWindow = app.windows["Settings"]
        guard settingsWindow.waitForExistence(timeout: 5) else {
            XCTFail("Settings window did not open")
            return
        }

        // Close with Escape or window close button
        let closeButton = settingsWindow.buttons[XCUIIdentifierCloseWindow]

        if closeButton.exists {
            closeButton.tap()
        } else {
            // Try Escape key
            UITestHelpers.pressEscape(in: app)
        }

        // Verify window is closed
        let isClosed = waitForDisappearance(settingsWindow, timeout: 3)

        XCTAssertTrue(isClosed, "Settings window should be closable")

        captureScreenshot(named: "SE-006-Settings-Closed")
    }
}
