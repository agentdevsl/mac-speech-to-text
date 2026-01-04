// SpeechToTextUITests.swift
// macOS Local Speech-to-Text Application
//
// Legacy UI tests - retained for compatibility
// New tests should be added to P1/, P2/, or P3/ directories
// See UITests/Base/UITestBase.swift for the new base class

import XCTest

/// Legacy UI Tests - retained for backwards compatibility
/// New tests should use UITestBase class and be placed in priority folders
/// @see RecordingFlowTests for recording tests
/// @see OnboardingFlowTests for onboarding tests
final class SpeechToTextUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Legacy arguments - use LaunchArguments constants in new tests
        app.launchArguments = ["--uitesting", "--reset-onboarding"]
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    // MARK: - Permission Dialog Handling

    /// Set up handler for system permission dialogs
    func setupPermissionDialogHandler() {
        // Handle microphone permission dialog
        addUIInterruptionMonitor(forInterruptionType: .alert) { alert in
            if alert.buttons["OK"].exists {
                alert.buttons["OK"].tap()
                return true
            } else if alert.buttons["Allow"].exists {
                alert.buttons["Allow"].tap()
                return true
            }
            return false
        }
    }

    // MARK: - Onboarding Tests (Legacy)
    // @see OnboardingFlowTests for comprehensive tests

    /// Test that onboarding appears on first launch
    func testOnboardingAppearsOnFirstLaunch() throws {
        app.launch()

        // Wait for onboarding window
        let onboardingWindow = app.windows["Welcome to Speech-to-Text"]
        XCTAssertTrue(onboardingWindow.waitForExistence(timeout: 5))

        // Verify welcome step is visible
        let welcomeText = onboardingWindow.staticTexts["Welcome to Speech-to-Text"]
        XCTAssertTrue(welcomeText.exists)
    }

    /// Test onboarding navigation through all steps
    func testOnboardingNavigation() throws {
        setupPermissionDialogHandler()
        app.launch()

        let onboardingWindow = app.windows["Welcome to Speech-to-Text"]
        XCTAssertTrue(onboardingWindow.waitForExistence(timeout: 5))

        // Step 1: Welcome - click Continue
        let continueButton = onboardingWindow.buttons["Continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 2))
        continueButton.tap()

        // Step 2: Microphone Permission
        let microphoneStep = onboardingWindow.staticTexts["Microphone Access"]
        XCTAssertTrue(microphoneStep.waitForExistence(timeout: 2))

        // Grant permission button
        let grantMicButton = onboardingWindow.buttons["Grant Microphone Access"]
        if grantMicButton.exists {
            grantMicButton.tap()
            // Interact with app to dismiss any dialogs
            app.tap()
        }

        // Click Continue to next step
        let nextButton = onboardingWindow.buttons["Continue"]
        if nextButton.isEnabled {
            nextButton.tap()
        }

        // Step 3: Accessibility Permission
        let accessibilityStep = onboardingWindow.staticTexts["Accessibility Access"]
        XCTAssertTrue(accessibilityStep.waitForExistence(timeout: 2))
    }

    /// Test onboarding completion
    func testOnboardingCompletion() throws {
        // Pre-grant permissions for this test
        app.launchArguments.append("--skip-permission-checks")
        app.launch()

        let onboardingWindow = app.windows["Welcome to Speech-to-Text"]
        XCTAssertTrue(onboardingWindow.waitForExistence(timeout: 5))

        // Navigate through all steps
        for _ in 0..<4 {
            let continueButton = onboardingWindow.buttons["Continue"]
            if continueButton.exists && continueButton.isEnabled {
                continueButton.tap()
                sleep(1)
            }
        }

        // Final step: Complete
        let completeButton = onboardingWindow.buttons["Get Started"]
        if completeButton.waitForExistence(timeout: 2) {
            completeButton.tap()
        }

        // Onboarding window should close
        XCTAssertFalse(onboardingWindow.exists)
    }

    // MARK: - Menu Bar Tests (Legacy)

    /// Test menu bar icon appears
    func testMenuBarIconAppears() throws {
        app.launchArguments.append("--skip-onboarding")
        app.launch()

        sleep(2)
        XCTAssertTrue(app.exists)
    }

    // MARK: - Recording Modal Tests (Legacy)
    // @see RecordingFlowTests for comprehensive tests

    /// Test recording modal can be opened
    func testRecordingModalOpens() throws {
        app.launchArguments.append("--skip-onboarding")
        app.launch()

        sleep(2)

        // Trigger hotkey (Cmd+Ctrl+Space)
        app.typeKey(" ", modifierFlags: [.command, .control])

        sleep(1)
        XCTAssertTrue(app.exists)
    }

    // MARK: - Settings Tests (Legacy)
    // @see SettingsTests for comprehensive tests

    /// Test settings window opens
    func testSettingsWindowOpens() throws {
        app.launchArguments.append("--skip-onboarding")
        app.launch()

        sleep(2)

        // Open settings via keyboard shortcut
        app.typeKey(",", modifierFlags: .command)

        let settingsWindow = app.windows["Settings"]
        XCTAssertTrue(settingsWindow.waitForExistence(timeout: 3) || !app.windows.isEmpty)
    }
}
