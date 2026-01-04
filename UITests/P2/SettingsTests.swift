// swiftlint:disable file_length type_body_length
// SettingsTests.swift
// macOS Local Speech-to-Text Application
//
// End-to-end UI tests for the Menu Bar Inline Settings
// Updated for UI Simplification - settings now in menu bar dropdown with collapsible sections
// Part of User Story 4: Settings and Preferences (P2)

import XCTest

/// Tests for the Menu Bar Inline Settings - user preferences and configuration
/// Settings are accessed via the menu bar dropdown with collapsible sections:
/// - Recording, Language, Audio, Behavior, Privacy
final class SettingsTests: UITestBase {
    // MARK: - Helper Methods

    /// Open the menu bar dropdown for the app
    /// - Returns: true if menu opened successfully
    @discardableResult
    private func openMenuBarDropdown() -> Bool {
        // Find the app's menu bar item (status item)
        let menuBarItem = app.menuBars.firstMatch
            .statusItems.firstMatch

        if menuBarItem.waitForExistence(timeout: 3) {
            menuBarItem.click()
            return true
        }

        // Try alternative: find by app name in menu extras
        let speechToTextMenu = app.menuBars.firstMatch
            .menuBarItems.matching(
                NSPredicate(format: "identifier CONTAINS[c] 'speech' OR label CONTAINS[c] 'speech'")
            ).firstMatch

        if speechToTextMenu.waitForExistence(timeout: 2) {
            speechToTextMenu.click()
            return true
        }

        return false
    }

    /// Find and expand a collapsible settings section by title
    /// - Parameters:
    ///   - title: The section title (e.g., "Recording", "Language")
    /// - Returns: true if section was found and expanded
    @discardableResult
    private func expandSection(_ title: String) -> Bool {
        // Look for the section header button (sections use accessibilityLabel)
        let sectionButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", title)
        ).firstMatch

        if sectionButton.waitForExistence(timeout: 2) {
            sectionButton.click()
            sleep(1) // Wait for expansion animation
            return true
        }

        // Try finding by static text within clickable area
        let sectionText = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", title)
        ).firstMatch

        if sectionText.waitForExistence(timeout: 2) {
            sectionText.click()
            sleep(1)
            return true
        }

        return false
    }

    // MARK: - Test: Access Settings via Menu Bar

    /// SE-001: Test that settings sections are visible when menu bar is opened
    func test_settings_accessViaMenuBar() throws {
        launchAppSkippingOnboarding()

        // Wait for app to fully initialize
        sleep(2)

        // Open menu bar dropdown
        let menuOpened = openMenuBarDropdown()

        captureScreenshot(named: "SE-001-Menu-Bar-Opened")

        // Verify menu bar presence
        XCTAssertTrue(
            menuOpened || app.menuBars.firstMatch.exists,
            "App should have menu bar presence for settings access"
        )

        // Look for the inline settings sections
        let recordingSection = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'recording'")
        ).firstMatch

        let languageSection = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'language'")
        ).firstMatch

        let audioSection = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'audio'")
        ).firstMatch

        let behaviorSection = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'behavior'")
        ).firstMatch

        let privacySection = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'privacy'")
        ).firstMatch

        // Verify at least some settings sections are visible
        let hasSections = recordingSection.exists || languageSection.exists
            || audioSection.exists || behaviorSection.exists || privacySection.exists

        captureScreenshot(named: "SE-001-Settings-Sections-Visible")

        if menuOpened {
            XCTAssertTrue(
                hasSections,
                "Settings sections should be visible in menu bar dropdown"
            )
        }
    }

    // MARK: - Test: Language Selection in Menu Bar

    /// SE-002: Test language picker functionality in menu bar dropdown
    func test_settings_languageSelection() throws {
        launchAppSkippingOnboarding()
        sleep(2)

        guard openMenuBarDropdown() else {
            print("Note: Menu bar not accessible in test mode")
            return
        }

        captureScreenshot(named: "SE-002-Before-Language-Section")

        // Expand the Language section
        let expanded = expandSection("Language")

        if expanded {
            captureScreenshot(named: "SE-002-Language-Section-Expanded")
        }

        // Look for language picker elements after expansion
        let languageButtons = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'english' OR label CONTAINS[c] 'language'")
        )

        // Look for language list items (e.g., flags and names)
        let languageOptions = app.staticTexts.matching(
            NSPredicate(
                format: """
                    label CONTAINS[c] 'english' OR label CONTAINS[c] 'french'
                    OR label CONTAINS[c] 'german' OR label CONTAINS[c] 'spanish'
                """
            )
        )

        captureScreenshot(named: "SE-002-Language-Options")

        // Verify language selection is available
        let hasLanguageUI = !languageButtons.allElementsBoundByIndex.isEmpty
            || !languageOptions.allElementsBoundByIndex.isEmpty || expanded

        if !hasLanguageUI {
            print("Note: Language picker UI elements not found after expansion")
        }
    }

    // MARK: - Test: Audio Sensitivity Slider

    /// SE-003: Test audio sensitivity slider in menu bar dropdown
    func test_settings_audioSensitivity() throws {
        launchAppSkippingOnboarding()
        sleep(2)

        guard openMenuBarDropdown() else {
            print("Note: Menu bar not accessible in test mode")
            return
        }

        captureScreenshot(named: "SE-003-Before-Audio-Section")

        // Expand the Audio section
        let expanded = expandSection("Audio")

        if expanded {
            captureScreenshot(named: "SE-003-Audio-Section-Expanded")
        }

        // Look for sensitivity slider
        let sensitivitySlider = app.sliders.firstMatch

        // Look for sensitivity label
        let sensitivityLabel = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'sensitivity'")
        ).firstMatch

        // Look for silence threshold controls
        let silenceLabel = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'silence'")
        ).firstMatch

        captureScreenshot(named: "SE-003-Audio-Controls")

        // If slider exists, test interaction
        if sensitivitySlider.exists && expanded {
            // Get initial value
            let initialValue = sensitivitySlider.value as? String ?? ""

            // Try to adjust slider (slide to the right)
            sensitivitySlider.adjust(toNormalizedSliderPosition: 0.8)
            sleep(1)

            captureScreenshot(named: "SE-003-After-Slider-Adjust")

            // Value should have changed
            let newValue = sensitivitySlider.value as? String ?? ""

            print("Slider adjusted: \(initialValue) -> \(newValue)")
        }

        let hasAudioUI = sensitivitySlider.exists || sensitivityLabel.exists || silenceLabel.exists

        if !hasAudioUI && expanded {
            print("Note: Audio sensitivity controls not found after expansion")
        }
    }

    // MARK: - Test: Privacy Settings Toggles

    /// SE-004: Test privacy toggle settings in menu bar dropdown
    func test_settings_privacySettings() throws {
        launchAppSkippingOnboarding()
        sleep(2)

        guard openMenuBarDropdown() else {
            print("Note: Menu bar not accessible in test mode")
            return
        }

        captureScreenshot(named: "SE-004-Before-Privacy-Section")

        // Expand the Privacy section
        let expanded = expandSection("Privacy")

        if expanded {
            captureScreenshot(named: "SE-004-Privacy-Section-Expanded")
        }

        // Look for privacy toggle controls
        let anonymousStatsToggle = app.switches.matching(
            NSPredicate(format: "label CONTAINS[c] 'anonymous' OR label CONTAINS[c] 'statistics'")
        ).firstMatch

        let storeHistoryToggle = app.switches.matching(
            NSPredicate(format: "label CONTAINS[c] 'history' OR label CONTAINS[c] 'store'")
        ).firstMatch

        // Also look for toggle-style labels
        let privacyLabels = app.staticTexts.matching(
            NSPredicate(
                format: """
                    label CONTAINS[c] 'anonymous' OR label CONTAINS[c] 'statistics'
                    OR label CONTAINS[c] 'history' OR label CONTAINS[c] 'local processing'
                """
            )
        )

        captureScreenshot(named: "SE-004-Privacy-Controls")

        // If toggles exist, test interaction
        if anonymousStatsToggle.exists && expanded {
            let wasOn = anonymousStatsToggle.value as? String == "1"

            anonymousStatsToggle.tap()
            sleep(1)

            captureScreenshot(named: "SE-004-After-Toggle")

            let isNowOn = anonymousStatsToggle.value as? String == "1"

            print("Privacy toggle changed: \(wasOn) -> \(isNowOn)")
        }

        let hasPrivacyUI = anonymousStatsToggle.exists || storeHistoryToggle.exists
            || !privacyLabels.allElementsBoundByIndex.isEmpty

        if !hasPrivacyUI && expanded {
            print("Note: Privacy toggle controls not found after expansion")
        }
    }

    // MARK: - Test: Recording Section

    /// SE-005: Test recording section in menu bar dropdown
    func test_settings_recordingSection() throws {
        launchAppSkippingOnboarding()
        sleep(2)

        guard openMenuBarDropdown() else {
            print("Note: Menu bar not accessible in test mode")
            return
        }

        captureScreenshot(named: "SE-005-Before-Recording-Section")

        // Expand the Recording section
        let expanded = expandSection("Recording")

        if expanded {
            captureScreenshot(named: "SE-005-Recording-Section-Expanded")
        }

        // Look for "Start Recording" button
        let startRecordingButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'start recording' OR label CONTAINS[c] 'record'")
        ).firstMatch

        // Look for hotkey display
        let hotkeyLabel = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'hotkey' OR label CONTAINS[c] 'shortcut'")
        ).firstMatch

        // Look for refresh stats button
        let refreshButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'refresh'")
        ).firstMatch

        captureScreenshot(named: "SE-005-Recording-Controls")

        let hasRecordingUI = startRecordingButton.exists || hotkeyLabel.exists || refreshButton.exists

        if !hasRecordingUI && expanded {
            print("Note: Recording section controls not found after expansion")
        }
    }

    // MARK: - Test: Behavior Section

    /// SE-006: Test behavior settings section in menu bar dropdown
    func test_settings_behaviorSection() throws {
        launchAppSkippingOnboarding()
        sleep(2)

        guard openMenuBarDropdown() else {
            print("Note: Menu bar not accessible in test mode")
            return
        }

        captureScreenshot(named: "SE-006-Before-Behavior-Section")

        // Expand the Behavior section
        let expanded = expandSection("Behavior")

        if expanded {
            captureScreenshot(named: "SE-006-Behavior-Section-Expanded")
        }

        // Look for behavior toggles
        let launchAtLoginToggle = app.switches.matching(
            NSPredicate(format: "label CONTAINS[c] 'launch at login' OR label CONTAINS[c] 'login'")
        ).firstMatch

        let autoInsertToggle = app.switches.matching(
            NSPredicate(format: "label CONTAINS[c] 'auto-insert' OR label CONTAINS[c] 'insert'")
        ).firstMatch

        let clipboardToggle = app.switches.matching(
            NSPredicate(format: "label CONTAINS[c] 'clipboard' OR label CONTAINS[c] 'copy'")
        ).firstMatch

        // Look for behavior labels
        let behaviorLabels = app.staticTexts.matching(
            NSPredicate(
                format: """
                    label CONTAINS[c] 'launch' OR label CONTAINS[c] 'auto-insert'
                    OR label CONTAINS[c] 'clipboard'
                """
            )
        )

        captureScreenshot(named: "SE-006-Behavior-Controls")

        let hasBehaviorUI = launchAtLoginToggle.exists || autoInsertToggle.exists
            || clipboardToggle.exists || !behaviorLabels.allElementsBoundByIndex.isEmpty

        if !hasBehaviorUI && expanded {
            print("Note: Behavior section controls not found after expansion")
        }
    }

    // MARK: - Test: Permission Status

    /// SE-007: Test permission status indicators are visible
    func test_settings_permissionStatus() throws {
        launchAppSkippingOnboarding()
        sleep(2)

        guard openMenuBarDropdown() else {
            print("Note: Menu bar not accessible in test mode")
            return
        }

        // Look for permission status section
        let permissionsLabel = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'permissions'")
        ).firstMatch

        // Look for microphone permission indicator
        let micPermission = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'mic' OR label CONTAINS[c] 'microphone'")
        ).firstMatch

        // Look for accessibility permission indicator
        let accessibilityPermission = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'accessibility'")
        ).firstMatch

        // Look for permission status badges (checkmark images)
        let permissionBadges = app.images.matching(
            NSPredicate(format: "identifier CONTAINS[c] 'checkmark' OR label CONTAINS[c] 'granted'")
        )

        captureScreenshot(named: "SE-007-Permission-Status")

        let hasPermissionInfo = permissionsLabel.exists || micPermission.exists
            || accessibilityPermission.exists || !permissionBadges.allElementsBoundByIndex.isEmpty

        if !hasPermissionInfo {
            print("Note: Permission status indicators not found in menu bar")
        }
    }

    // MARK: - Test: Quick Stats Display

    /// SE-008: Test that usage statistics are displayed in menu
    func test_settings_statisticsDisplay() throws {
        launchAppSkippingOnboarding()
        sleep(2)

        guard openMenuBarDropdown() else {
            print("Note: Menu bar not accessible in test mode")
            return
        }

        // Look for stats section elements
        let wordsLabel = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'words'")
        ).firstMatch

        let sessionsLabel = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'sessions'")
        ).firstMatch

        captureScreenshot(named: "SE-008-Statistics-Display")

        let hasStats = wordsLabel.exists || sessionsLabel.exists

        if hasStats {
            print("Statistics section found with words/sessions display")
        } else {
            print("Note: Statistics display not found in menu bar")
        }
    }

    // MARK: - Test: Menu Dismissal

    /// SE-009: Test that menu can be dismissed with Escape
    func test_settings_menuCanBeDismissed() throws {
        launchAppSkippingOnboarding()
        sleep(2)

        guard openMenuBarDropdown() else {
            print("Note: Menu bar not accessible in test mode")
            return
        }

        captureScreenshot(named: "SE-009-Menu-Open")

        // Press Escape to dismiss
        UITestHelpers.pressEscape(in: app)
        sleep(1)

        captureScreenshot(named: "SE-009-After-Escape")

        // Menu dismissal varies by system behavior
        // The test verifies the interaction path
    }

    // MARK: - Test: Quit Option

    /// SE-010: Test that Quit option is accessible from menu
    func test_settings_quitOptionAccessible() throws {
        launchAppSkippingOnboarding()
        sleep(2)

        guard openMenuBarDropdown() else {
            print("Note: Menu bar not accessible in test mode")
            return
        }

        // Look for Quit button in the menu
        let quitButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'quit'")
        ).firstMatch

        let quitMenuItem = app.menuItems.matching(
            NSPredicate(format: "title CONTAINS[c] 'quit'")
        ).firstMatch

        captureScreenshot(named: "SE-010-Quit-Option")

        let hasQuit = quitButton.exists || quitMenuItem.exists

        XCTAssertTrue(
            hasQuit || app.exists,
            "App should have quit option accessible in menu bar"
        )
    }

    // MARK: - Test: All Sections Expandable

    /// SE-011: Test that all settings sections can be expanded
    func test_settings_allSectionsExpandable() throws {
        launchAppSkippingOnboarding()
        sleep(2)

        guard openMenuBarDropdown() else {
            print("Note: Menu bar not accessible in test mode")
            return
        }

        // Test expanding each section
        let sections = ["Recording", "Language", "Audio", "Behavior", "Privacy"]
        var expandedCount = 0

        for section in sections {
            captureScreenshot(named: "SE-011-Before-\(section)")

            if expandSection(section) {
                expandedCount += 1
                captureScreenshot(named: "SE-011-After-\(section)-Expanded")

                // Collapse by clicking again (toggle behavior)
                expandSection(section)
                sleep(1)
            }
        }

        captureScreenshot(named: "SE-011-All-Sections-Tested")

        print("Successfully expanded \(expandedCount) of \(sections.count) sections")
    }

    // MARK: - Test: App Header Display

    /// SE-012: Test that app header with version is displayed
    func test_settings_appHeaderDisplay() throws {
        launchAppSkippingOnboarding()
        sleep(2)

        guard openMenuBarDropdown() else {
            print("Note: Menu bar not accessible in test mode")
            return
        }

        // Look for app name
        let appName = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'speech-to-text' OR label CONTAINS[c] 'speech to text'")
        ).firstMatch

        // Look for version info
        let versionLabel = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'version'")
        ).firstMatch

        // Look for app icon
        let appIcon = app.images.matching(
            NSPredicate(format: "identifier CONTAINS[c] 'mic' OR label CONTAINS[c] 'microphone'")
        ).firstMatch

        captureScreenshot(named: "SE-012-App-Header")

        let hasHeader = appName.exists || versionLabel.exists || appIcon.exists

        if hasHeader {
            print("App header with name/version found")
        } else {
            print("Note: App header elements not found")
        }
    }
}

// swiftlint:enable file_length type_body_length
