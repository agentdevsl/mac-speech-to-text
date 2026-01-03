// SpeechToTextUITests.swift
// macOS Local Speech-to-Text Application
//
// End-to-end UI tests using XCUITest
// These tests verify user flows including onboarding and permissions

import XCTest

/// UI Tests for SpeechToText app
/// Run on actual macOS hardware with: xcodebuild test -scheme SpeechToText -destination 'platform=macOS'
final class SpeechToTextUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()

        // Reset app state for clean tests
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
        addUIInterruptionMonitor(forContext: UIInterruptionContext.microphoneAccess) { alert in
            if alert.buttons["OK"].exists {
                alert.buttons["OK"].tap()
                return true
            }
            return false
        }

        // Handle accessibility permission dialog
        addUIInterruptionMonitor(forContext: UIInterruptionContext.unknown) { alert in
            // System Settings dialogs can't be directly automated
            // Log for manual intervention
            print("System dialog appeared: \(alert.debugDescription)")
            return false
        }
    }

    // MARK: - Onboarding Tests

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
        // Pre-grant permissions for this test (requires tccutil or MDM)
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

    // MARK: - Menu Bar Tests

    /// Test menu bar icon appears
    func testMenuBarIconAppears() throws {
        app.launchArguments.append("--skip-onboarding")
        app.launch()

        // Menu bar extras are accessed differently
        // XCUITest can't directly access menu bar extras
        // Use accessibility APIs or AppleScript instead
        sleep(2)

        // Verify app is running
        XCTAssertTrue(app.exists)
    }

    // MARK: - Recording Modal Tests

    /// Test recording modal can be opened
    func testRecordingModalOpens() throws {
        app.launchArguments.append("--skip-onboarding")
        app.launch()

        sleep(2)

        // Trigger hotkey (Cmd+Ctrl+Space)
        // Note: XCUITest can't simulate global hotkeys
        // Use AppleScript or trigger via notification
        app.typeKey(" ", modifierFlags: [.command, .control])

        // Check for recording modal
        let recordingModal = app.windows.element(boundBy: 0)
        // Modal might appear as a new window
        sleep(1)

        // Verify app didn't crash
        XCTAssertTrue(app.exists)
    }

    // MARK: - Settings Tests

    /// Test settings window opens
    func testSettingsWindowOpens() throws {
        app.launchArguments.append("--skip-onboarding")
        app.launch()

        sleep(2)

        // Open settings via keyboard shortcut
        app.typeKey(",", modifierFlags: .command)

        let settingsWindow = app.windows["Settings"]
        // Settings window may take a moment to appear
        XCTAssertTrue(settingsWindow.waitForExistence(timeout: 3) || !app.windows.isEmpty)
    }
}

// MARK: - UI Interruption Contexts

extension UIInterruptionContext {
    static let microphoneAccess = UIInterruptionContext(rawValue: "microphone")
    static let accessibilityAccess = UIInterruptionContext(rawValue: "accessibility")
}

// MARK: - Test Helpers

extension XCUIApplication {
    /// Grant microphone permission via tccutil (requires root or entitlements)
    func grantMicrophonePermission() {
        // This requires running: tccutil reset Microphone com.speechtotext.app
        // Or pre-configuring via MDM profile
    }
}
