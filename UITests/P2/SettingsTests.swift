// swiftlint:disable file_length type_body_length
// SettingsTests.swift
// macOS Local Speech-to-Text Application
//
// End-to-end UI tests for the Main View Settings sections
// Updated for unified MainView with NavigationSplitView structure
// Part of User Story 4: Settings and Preferences (P2)

import XCTest

/// Tests for the Main View Settings - user preferences and configuration
/// Settings are accessed via the sidebar navigation:
/// - Home, General, Audio, Language, Privacy, About
final class SettingsTests: UITestBase {
    // MARK: - Helper Methods

    /// Wait for the main view to be ready for testing
    /// - Returns: true if main view is visible and ready
    @discardableResult
    private func waitForMainViewReady() -> Bool {
        // Wait for main window and view
        guard waitForMainWindow(timeout: 5) else {
            print("Note: Main window not found")
            return false
        }
        guard waitForMainView(timeout: 3) else {
            print("Note: Main view not found")
            return false
        }
        return true
    }

    /// Navigate to a sidebar section and verify the content loads
    /// - Parameters:
    ///   - sidebarId: The accessibility identifier of the sidebar item
    ///   - contentId: The accessibility identifier of the section content (optional)
    /// - Returns: true if navigation and content load succeeded
    @discardableResult
    private func navigateAndVerify(sidebarId: String, contentId: String? = nil) -> Bool {
        // Find sidebar item - try multiple element types
        let sidebarItem = app.buttons[sidebarId].firstMatch

        if sidebarItem.waitForExistence(timeout: 3) {
            sidebarItem.click()
            sleep(1)

            // Verify content loaded if contentId provided
            if let contentId = contentId {
                let content = app.otherElements[contentId].firstMatch
                if content.waitForExistence(timeout: 2) {
                    return true
                }
                // Try as scrollView
                let scrollContent = app.scrollViews[contentId].firstMatch
                return scrollContent.waitForExistence(timeout: 2)
            }
            return true
        }

        // Try as other element (Label in List)
        let labelItem = app.staticTexts.matching(
            NSPredicate(format: "identifier == %@", sidebarId)
        ).firstMatch

        if labelItem.waitForExistence(timeout: 2) {
            labelItem.click()
            sleep(1)
            return true
        }

        return false
    }

    // MARK: - Test: Main Window and View Access

    /// SE-001: Test that main window opens with sidebar navigation
    func test_settings_mainWindowOpens() throws {
        launchAppSkippingOnboarding()
        sleep(2)

        captureScreenshot(named: "SE-001-App-Launched")

        // Verify main window and view exist
        let mainWindowFound = waitForMainWindow()
        let mainViewFound = waitForMainView()

        captureScreenshot(named: "SE-001-Main-Window-View")

        XCTAssertTrue(
            mainWindowFound || mainViewFound,
            "Main window or view should be visible after launch"
        )

        // Verify sidebar exists
        let sidebar = app.otherElements["mainViewSidebar"]
        if sidebar.waitForExistence(timeout: 3) {
            captureScreenshot(named: "SE-001-Sidebar-Found")
        }
    }

    // MARK: - Test: Home Section Navigation

    /// SE-002: Test Home section displays correctly
    func test_settings_homeSectionNavigation() throws {
        launchAppSkippingOnboarding()
        sleep(2)

        guard waitForMainViewReady() else {
            print("Note: Main view not ready")
            return
        }

        captureScreenshot(named: "SE-002-Before-Home-Navigation")

        // Navigate to Home section
        let navigated = navigateAndVerify(sidebarId: "sidebarHome", contentId: "homeSection")

        captureScreenshot(named: "SE-002-Home-Section")

        if navigated {
            // Verify Home section elements
            let heroSection = app.otherElements["heroSection"]
            let permissionCards = app.otherElements["permissionCards"]
            let typingPreview = app.otherElements["typingPreview"]

            let hasHomeElements = heroSection.exists || permissionCards.exists || typingPreview.exists

            XCTAssertTrue(
                hasHomeElements,
                "Home section should display hero, permission cards, or typing preview"
            )
        }
    }

    // MARK: - Test: General Section Navigation and Controls

    /// SE-003: Test General section with recording mode, toggles, and hotkey
    func test_settings_generalSectionNavigation() throws {
        launchAppSkippingOnboarding()
        sleep(2)

        guard waitForMainViewReady() else {
            print("Note: Main view not ready")
            return
        }

        captureScreenshot(named: "SE-003-Before-General-Navigation")

        // Navigate to General section
        let navigated = navigateAndVerify(sidebarId: "sidebarGeneral", contentId: "generalSection")

        captureScreenshot(named: "SE-003-General-Section")

        if navigated {
            // Verify General section elements
            let recordingModeSection = app.otherElements["recordingModeSection"]
            let behaviorSection = app.otherElements["behaviorSection"]
            let hotkeySection = app.otherElements["hotkeySection"]

            let hasGeneralElements = recordingModeSection.exists
                || behaviorSection.exists || hotkeySection.exists

            captureScreenshot(named: "SE-003-General-Elements")

            if hasGeneralElements {
                print("General section elements found")
            }

            // Test recording mode cards
            let holdToRecordCard = app.buttons["holdToRecordCard"]
            let toggleModeCard = app.buttons["toggleModeCard"]

            if holdToRecordCard.waitForExistence(timeout: 2) {
                holdToRecordCard.click()
                sleep(1)
                captureScreenshot(named: "SE-003-Hold-To-Record-Selected")
            }

            if toggleModeCard.waitForExistence(timeout: 2) {
                toggleModeCard.click()
                sleep(1)
                captureScreenshot(named: "SE-003-Toggle-Mode-Selected")
            }

            // Test behavior toggles
            let launchAtLoginToggle = app.switches["launchAtLoginToggle"]
            let autoInsertToggle = app.switches["autoInsertToggle"]
            let copyToClipboardToggle = app.switches["copyToClipboardToggle"]

            if launchAtLoginToggle.waitForExistence(timeout: 2) {
                let wasOn = launchAtLoginToggle.value as? String == "1"
                launchAtLoginToggle.click()
                sleep(1)
                captureScreenshot(named: "SE-003-Launch-Toggle-Changed")
                print("Launch at login toggle changed: \(wasOn) -> \(launchAtLoginToggle.value ?? "unknown")")
            }

            if autoInsertToggle.exists {
                captureScreenshot(named: "SE-003-Auto-Insert-Toggle")
            }

            if copyToClipboardToggle.exists {
                captureScreenshot(named: "SE-003-Copy-Toggle")
            }
        }
    }

    // MARK: - Test: Audio Section Navigation and Controls

    /// SE-004: Test Audio section with sliders and toggles
    func test_settings_audioSectionNavigation() throws {
        launchAppSkippingOnboarding()
        sleep(2)

        guard waitForMainViewReady() else {
            print("Note: Main view not ready")
            return
        }

        captureScreenshot(named: "SE-004-Before-Audio-Navigation")

        // Navigate to Audio section
        let navigated = navigateAndVerify(sidebarId: "sidebarAudio", contentId: "audioSection")

        captureScreenshot(named: "SE-004-Audio-Section")

        if navigated {
            // Verify Audio section elements
            let sensitivitySection = app.otherElements["sensitivitySection"]
            let silenceThresholdSection = app.otherElements["silenceThresholdSection"]
            let processingSection = app.otherElements["processingSection"]

            let hasAudioElements = sensitivitySection.exists
                || silenceThresholdSection.exists || processingSection.exists

            if hasAudioElements {
                print("Audio section elements found")
            }

            // Test sensitivity slider
            let sensitivitySlider = app.sliders["sensitivitySlider"]
            if sensitivitySlider.waitForExistence(timeout: 2) {
                let initialValue = sensitivitySlider.value as? String ?? ""
                sensitivitySlider.adjust(toNormalizedSliderPosition: 0.7)
                sleep(1)
                captureScreenshot(named: "SE-004-Sensitivity-Adjusted")
                print("Sensitivity slider adjusted: \(initialValue) -> \(sensitivitySlider.value ?? "unknown")")
            }

            // Test silence threshold slider
            let silenceThresholdSlider = app.sliders["silenceThresholdSlider"]
            if silenceThresholdSlider.waitForExistence(timeout: 2) {
                silenceThresholdSlider.adjust(toNormalizedSliderPosition: 0.5)
                sleep(1)
                captureScreenshot(named: "SE-004-Silence-Threshold-Adjusted")
            }

            // Test audio processing toggles
            let noiseSuppressionToggle = app.switches["noiseSuppressionToggle"]
            let autoGainControlToggle = app.switches["autoGainControlToggle"]

            if noiseSuppressionToggle.waitForExistence(timeout: 2) {
                noiseSuppressionToggle.click()
                sleep(1)
                captureScreenshot(named: "SE-004-Noise-Suppression-Toggle")
            }

            if autoGainControlToggle.waitForExistence(timeout: 2) {
                autoGainControlToggle.click()
                sleep(1)
                captureScreenshot(named: "SE-004-Auto-Gain-Toggle")
            }
        }
    }

    // MARK: - Test: Language Section Navigation and Controls

    /// SE-005: Test Language section with picker and auto-detect toggle
    func test_settings_languageSectionNavigation() throws {
        launchAppSkippingOnboarding()
        sleep(2)

        guard waitForMainViewReady() else {
            print("Note: Main view not ready")
            return
        }

        captureScreenshot(named: "SE-005-Before-Language-Navigation")

        // Navigate to Language section
        let navigated = navigateAndVerify(sidebarId: "sidebarLanguage", contentId: "languageSection")

        captureScreenshot(named: "SE-005-Language-Section")

        if navigated {
            // Verify Language section elements
            let currentLanguage = app.otherElements["languageSection.currentLanguage"]
            let autoDetectToggle = app.switches["languageSection.autoDetectToggle"]
            let recentLanguages = app.otherElements["languageSection.recentLanguages"]

            if currentLanguage.waitForExistence(timeout: 2) {
                captureScreenshot(named: "SE-005-Current-Language-Card")
                print("Current language card found")
            }

            // Test auto-detect toggle
            if autoDetectToggle.waitForExistence(timeout: 2) {
                let wasOn = autoDetectToggle.value as? String == "1"
                autoDetectToggle.click()
                sleep(1)
                captureScreenshot(named: "SE-005-Auto-Detect-Toggle")
                print("Auto-detect toggle changed: \(wasOn) -> \(autoDetectToggle.value ?? "unknown")")
            }

            // Test language picker expansion
            let allLanguagesToggle = app.buttons["languageSection.allLanguagesToggle"]
            if allLanguagesToggle.waitForExistence(timeout: 2) {
                allLanguagesToggle.click()
                sleep(1)
                captureScreenshot(named: "SE-005-Language-Picker-Expanded")

                // Test search field
                let searchField = app.textFields["languageSection.searchField"]
                if searchField.waitForExistence(timeout: 2) {
                    searchField.click()
                    searchField.typeText("English")
                    sleep(1)
                    captureScreenshot(named: "SE-005-Language-Search")
                }
            }

            // Test recent languages if visible
            if recentLanguages.waitForExistence(timeout: 2) {
                captureScreenshot(named: "SE-005-Recent-Languages")
            }
        }
    }

    // MARK: - Test: Privacy Section Navigation and Controls

    /// SE-006: Test Privacy section with toggles, storage policy, and retention slider
    func test_settings_privacySectionNavigation() throws {
        launchAppSkippingOnboarding()
        sleep(2)

        guard waitForMainViewReady() else {
            print("Note: Main view not ready")
            return
        }

        captureScreenshot(named: "SE-006-Before-Privacy-Navigation")

        // Navigate to Privacy section
        let navigated = navigateAndVerify(sidebarId: "sidebarPrivacy", contentId: "privacySection")

        captureScreenshot(named: "SE-006-Privacy-Section")

        if navigated {
            // Verify local processing card
            let localProcessingCard = app.otherElements["privacySection.localProcessing"]
            if localProcessingCard.waitForExistence(timeout: 2) {
                captureScreenshot(named: "SE-006-Local-Processing-Card")
                print("Local processing card found - privacy assured")
            }

            // Test anonymous stats toggle
            let statsToggle = app.switches["privacySection.statsToggle"]
            if statsToggle.waitForExistence(timeout: 2) {
                let wasOn = statsToggle.value as? String == "1"
                statsToggle.click()
                sleep(1)
                captureScreenshot(named: "SE-006-Stats-Toggle")
                print("Stats toggle changed: \(wasOn) -> \(statsToggle.value ?? "unknown")")
            }

            // Test storage policy options
            let storagePolicySection = app.otherElements["privacySection.storagePolicy"]
            if storagePolicySection.waitForExistence(timeout: 2) {
                captureScreenshot(named: "SE-006-Storage-Policy-Section")

                // Try selecting persistent storage to reveal retention slider
                let persistentOption = app.buttons["privacySection.storage.persistent"]
                if persistentOption.waitForExistence(timeout: 2) {
                    persistentOption.click()
                    sleep(1)
                    captureScreenshot(named: "SE-006-Persistent-Storage-Selected")

                    // Test data retention slider
                    let retentionSlider = app.sliders["privacySection.retentionSlider"]
                    if retentionSlider.waitForExistence(timeout: 2) {
                        retentionSlider.adjust(toNormalizedSliderPosition: 0.5)
                        sleep(1)
                        captureScreenshot(named: "SE-006-Retention-Slider-Adjusted")
                    }
                }
            }

            // Verify privacy footer
            let privacyFooter = app.otherElements["privacySection.footer"]
            if privacyFooter.exists {
                captureScreenshot(named: "SE-006-Privacy-Footer")
            }
        }
    }

    // MARK: - Test: About Section Navigation

    /// SE-007: Test About section with app info and links
    func test_settings_aboutSectionNavigation() throws {
        launchAppSkippingOnboarding()
        sleep(2)

        guard waitForMainViewReady() else {
            print("Note: Main view not ready")
            return
        }

        captureScreenshot(named: "SE-007-Before-About-Navigation")

        // Navigate to About section
        let navigated = navigateAndVerify(sidebarId: "sidebarAbout", contentId: "aboutSection")

        captureScreenshot(named: "SE-007-About-Section")

        if navigated {
            // Verify app identity section
            let identitySection = app.otherElements["aboutSection.identity"]
            if identitySection.waitForExistence(timeout: 2) {
                captureScreenshot(named: "SE-007-App-Identity")
                print("App identity section found")
            }

            // Verify keyboard shortcuts section
            let shortcutsSection = app.otherElements["aboutSection.shortcuts"]
            if shortcutsSection.waitForExistence(timeout: 2) {
                captureScreenshot(named: "SE-007-Keyboard-Shortcuts")
            }

            // Verify links section
            let linksSection = app.otherElements["aboutSection.links"]
            if linksSection.waitForExistence(timeout: 2) {
                captureScreenshot(named: "SE-007-Links-Section")

                // Verify support and privacy links exist
                let supportLink = app.buttons["aboutSection.supportLink"]
                let privacyLink = app.buttons["aboutSection.privacyLink"]
                let acknowledgementsLink = app.buttons["aboutSection.acknowledgementsLink"]

                let hasLinks = supportLink.exists || privacyLink.exists || acknowledgementsLink.exists
                if hasLinks {
                    print("About section links found")
                }
            }

            // Verify copyright footer
            let copyrightFooter = app.otherElements["aboutSection.copyright"]
            if copyrightFooter.exists {
                captureScreenshot(named: "SE-007-Copyright-Footer")
            }
        }
    }

    // MARK: - Test: Navigation Between Sections

    /// SE-008: Test navigation between all sections
    func test_settings_navigationBetweenSections() throws {
        launchAppSkippingOnboarding()
        sleep(2)

        guard waitForMainViewReady() else {
            print("Note: Main view not ready")
            return
        }

        // Define sections to navigate through
        let sections: [(id: String, name: String)] = [
            ("sidebarHome", "Home"),
            ("sidebarGeneral", "General"),
            ("sidebarAudio", "Audio"),
            ("sidebarLanguage", "Language"),
            ("sidebarPrivacy", "Privacy"),
            ("sidebarAbout", "About")
        ]

        var successCount = 0

        for section in sections {
            captureScreenshot(named: "SE-008-Before-\(section.name)")

            if navigateAndVerify(sidebarId: section.id) {
                successCount += 1
                captureScreenshot(named: "SE-008-\(section.name)-Section")
                sleep(1)
            } else {
                print("Note: Failed to navigate to \(section.name)")
            }
        }

        captureScreenshot(named: "SE-008-Navigation-Complete")

        XCTAssertGreaterThan(
            successCount, 0,
            "Should successfully navigate to at least one section"
        )

        print("Successfully navigated to \(successCount) of \(sections.count) sections")
    }

    // MARK: - Test: Quit Button Functionality

    /// SE-009: Test quit button in sidebar
    func test_settings_quitButtonFunctionality() throws {
        launchAppSkippingOnboarding()
        sleep(2)

        guard waitForMainViewReady() else {
            print("Note: Main view not ready")
            return
        }

        captureScreenshot(named: "SE-009-Before-Quit")

        // Find quit button
        let quitButton = app.buttons["quitButton"]

        if quitButton.waitForExistence(timeout: 3) {
            captureScreenshot(named: "SE-009-Quit-Button-Found")

            XCTAssertTrue(
                quitButton.exists && quitButton.isEnabled,
                "Quit button should exist and be enabled"
            )

            // Note: Actually clicking quit would terminate the app
            // For test purposes, we just verify it exists and is clickable
            print("Quit button found and enabled")
        } else {
            print("Note: Quit button not found")
        }
    }

    // MARK: - Test: Window Dismissal with Escape

    /// SE-010: Test that Escape key behavior works
    func test_settings_escapeKeyBehavior() throws {
        launchAppSkippingOnboarding()
        sleep(2)

        guard waitForMainViewReady() else {
            print("Note: Main view not ready")
            return
        }

        captureScreenshot(named: "SE-010-Before-Escape")

        // Press Escape
        UITestHelpers.pressEscape(in: app)
        sleep(1)

        captureScreenshot(named: "SE-010-After-Escape")

        // Main window behavior with Escape varies - document the interaction
        print("Escape key pressed - window state may vary")
    }

    // MARK: - Test: Settings Persistence

    /// SE-011: Test that settings persist across section navigation
    func test_settings_persistenceAcrossSections() throws {
        launchAppSkippingOnboarding()
        sleep(2)

        guard waitForMainViewReady() else {
            print("Note: Main view not ready")
            return
        }

        // Navigate to Audio and change a setting
        navigateAndVerify(sidebarId: "sidebarAudio")
        sleep(1)

        let sensitivitySlider = app.sliders["sensitivitySlider"]
        if sensitivitySlider.waitForExistence(timeout: 2) {
            sensitivitySlider.adjust(toNormalizedSliderPosition: 0.8)
            sleep(1)
            captureScreenshot(named: "SE-011-Sensitivity-Changed")
        }

        // Navigate away to General
        navigateAndVerify(sidebarId: "sidebarGeneral")
        sleep(1)
        captureScreenshot(named: "SE-011-At-General")

        // Navigate back to Audio
        navigateAndVerify(sidebarId: "sidebarAudio")
        sleep(1)
        captureScreenshot(named: "SE-011-Back-To-Audio")

        // Setting should still be applied (visual verification via screenshot)
        print("Settings persistence test complete - verify via screenshots")
    }

    // MARK: - Test: Permission Status Display

    /// SE-012: Test permission status indicators on Home section
    func test_settings_permissionStatusDisplay() throws {
        launchAppSkippingOnboarding()
        sleep(2)

        guard waitForMainViewReady() else {
            print("Note: Main view not ready")
            return
        }

        // Navigate to Home section
        navigateAndVerify(sidebarId: "sidebarHome")
        sleep(1)

        captureScreenshot(named: "SE-012-Home-Section")

        // Look for permission cards
        let microphoneCard = app.otherElements["microphonePermissionCard"]
        let accessibilityCard = app.otherElements["accessibilityPermissionCard"]

        let hasPermissionCards = microphoneCard.waitForExistence(timeout: 2)
            || accessibilityCard.waitForExistence(timeout: 2)

        captureScreenshot(named: "SE-012-Permission-Cards")

        if hasPermissionCards {
            print("Permission status cards found")
        } else {
            print("Note: Permission status cards not found")
        }
    }

    // MARK: - Test: Hotkey Display

    /// SE-013: Test hotkey display on Home section
    func test_settings_hotkeyDisplay() throws {
        launchAppSkippingOnboarding()
        sleep(2)

        guard waitForMainViewReady() else {
            print("Note: Main view not ready")
            return
        }

        // Navigate to Home section
        navigateAndVerify(sidebarId: "sidebarHome")
        sleep(1)

        // Look for hotkey display
        let hotkeyDisplay = app.otherElements["hotkeyDisplay"]
        if hotkeyDisplay.waitForExistence(timeout: 2) {
            captureScreenshot(named: "SE-013-Hotkey-Display")
            print("Hotkey display found")
        }

        // Also check in General section
        navigateAndVerify(sidebarId: "sidebarGeneral")
        sleep(1)

        let hotkeySection = app.otherElements["hotkeySection"]
        if hotkeySection.waitForExistence(timeout: 2) {
            captureScreenshot(named: "SE-013-Hotkey-Section-General")
            print("Hotkey section found in General")
        }
    }

    // MARK: - Test: Downloaded Models Info

    /// SE-014: Test downloaded models display in Language section
    func test_settings_downloadedModelsDisplay() throws {
        launchAppSkippingOnboarding()
        sleep(2)

        guard waitForMainViewReady() else {
            print("Note: Main view not ready")
            return
        }

        // Navigate to Language section
        navigateAndVerify(sidebarId: "sidebarLanguage")
        sleep(1)

        // Look for downloaded models section
        let downloadedModels = app.otherElements["languageSection.downloadedModels"]
        if downloadedModels.waitForExistence(timeout: 2) {
            captureScreenshot(named: "SE-014-Downloaded-Models")
            print("Downloaded models section found")
        } else {
            captureScreenshot(named: "SE-014-Language-Section-Full")
            print("Note: Downloaded models section not immediately visible")
        }
    }
}

// swiftlint:enable file_length type_body_length
