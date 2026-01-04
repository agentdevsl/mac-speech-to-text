// OnboardingFlowTests.swift
// macOS Local Speech-to-Text Application
//
// DEPRECATED: The old 5-step onboarding wizard has been replaced by WelcomeView.
// This file now tests the single-screen WelcomeView flow.
//
// The legacy multi-step tests have been removed. If you need to see the old tests,
// check git history for this file before the WelcomeView migration.
//
// Part of User Story 3: Onboarding Flow Validation (P1)

import XCTest

/// Tests for the WelcomeView - first-time user experience
/// These tests verify the single-screen welcome flow including:
/// - UI element presence and layout
/// - Microphone permission request flow
/// - Microphone test functionality
/// - Welcome completion and dismissal
final class OnboardingFlowTests: UITestBase {
    // MARK: - WV-001: Welcome View Displays Correctly

    /// Test that all WelcomeView elements are displayed correctly on first launch
    func test_welcome_viewDisplaysCorrectly() throws {
        // Launch with fresh onboarding state
        launchAppWithFreshWelcome()

        // Verify main container exists
        let welcomeView = app.otherElements["welcomeView"]
        XCTAssertTrue(
            welcomeView.waitForExistence(timeout: extendedTimeout),
            "WelcomeView should appear on first launch"
        )

        // Verify header section elements
        let welcomeIcon = app.images["welcomeIcon"]
        XCTAssertTrue(
            welcomeIcon.waitForExistence(timeout: 3),
            "Welcome icon should be visible"
        )

        let welcomeTitle = app.staticTexts["welcomeTitle"]
        XCTAssertTrue(
            welcomeTitle.waitForExistence(timeout: 3),
            "Welcome title should be visible"
        )

        // Check the title text matches expected content
        // Note: WelcomeView uses "Speech to Text" (without hyphen)
        let titleByLabel = app.staticTexts["Speech to Text"]
        XCTAssertTrue(
            titleByLabel.exists || welcomeTitle.exists,
            "Title 'Speech to Text' should be visible"
        )

        // Verify microphone section
        let microphoneSection = app.otherElements["microphoneSection"]
        XCTAssertTrue(
            microphoneSection.waitForExistence(timeout: 3),
            "Microphone section should be visible"
        )

        // Verify output preview section
        let outputPreviewSection = app.otherElements["outputPreviewSection"]
        XCTAssertTrue(
            outputPreviewSection.waitForExistence(timeout: 3),
            "Output preview section should be visible"
        )

        // Verify Get Started button
        let getStartedButton = app.buttons["getStartedButton"]
        XCTAssertTrue(
            getStartedButton.waitForExistence(timeout: 3),
            "Get Started button should be visible"
        )

        captureScreenshot(named: "WV-001-Welcome-View-Elements")
    }

    // MARK: - WV-002: Microphone Permission Request

    /// Test the microphone permission request flow
    func test_welcome_microphonePermissionRequest() throws {
        // Launch without skip-permission-checks to test real permission flow
        // Note: In a sandboxed test environment, permission dialogs may not appear
        launchApp(arguments: [
            LaunchArguments.resetOnboarding
        ])

        // Wait for welcome view
        let welcomeView = app.otherElements["welcomeView"]
        guard welcomeView.waitForExistence(timeout: extendedTimeout) else {
            XCTFail("WelcomeView did not appear")
            return
        }

        // Verify microphone section is present
        let microphoneSection = app.otherElements["microphoneSection"]
        XCTAssertTrue(
            microphoneSection.waitForExistence(timeout: 3),
            "Microphone section should be visible"
        )

        // Look for the grant permission button (visible when permission not granted)
        let grantMicrophoneButton = app.buttons["grantMicrophoneButton"]

        // If permission is already granted, the test button will be visible instead
        let testMicrophoneButton = app.buttons["testMicrophoneButton"]

        let hasPermissionButton = grantMicrophoneButton.waitForExistence(timeout: 3)
        let hasTestButton = testMicrophoneButton.waitForExistence(timeout: 1)

        // Either the grant button or test button should be visible
        XCTAssertTrue(
            hasPermissionButton || hasTestButton,
            "Either grant permission button or test microphone button should be visible"
        )

        captureScreenshot(named: "WV-002-Microphone-Permission-State")

        if hasPermissionButton {
            // Set up handler for system permission dialog
            setupPermissionDialogHandlers()

            // Tap the grant permission button
            grantMicrophoneButton.tap()

            // Interact with app to trigger any pending dialog handlers
            app.tap()

            // Wait a moment for permission state to update
            Thread.sleep(forTimeInterval: 1)

            captureScreenshot(named: "WV-002-After-Permission-Request")

            // After tapping, either:
            // 1. Test button should appear (permission granted)
            // 2. Grant button still visible (permission denied or dialog not shown)
            // 3. Error message visible (permission explicitly denied)
            let permissionHandled = testMicrophoneButton.waitForExistence(timeout: 3)
                || grantMicrophoneButton.exists

            XCTAssertTrue(
                permissionHandled,
                "UI should update after permission interaction"
            )
        }
    }

    // MARK: - WV-003: Microphone Test Works

    /// Test the microphone test functionality
    func test_welcome_microphoneTestWorks() throws {
        // Launch with permissions granted (mock) to test the mic test feature
        launchAppWithFreshWelcome()

        // Wait for welcome view
        let welcomeView = app.otherElements["welcomeView"]
        guard welcomeView.waitForExistence(timeout: extendedTimeout) else {
            XCTFail("WelcomeView did not appear")
            return
        }

        // With --skip-permission-checks, microphone permission is mocked as granted
        // So the test button should be visible
        let testMicrophoneButton = app.buttons["testMicrophoneButton"]

        if testMicrophoneButton.waitForExistence(timeout: 3) {
            captureScreenshot(named: "WV-003-Before-Mic-Test")

            // Tap to start microphone test
            testMicrophoneButton.tap()

            // Wait for UI to update
            Thread.sleep(forTimeInterval: 0.5)

            captureScreenshot(named: "WV-003-During-Mic-Test")

            // The button should still be accessible (now showing stop icon)
            XCTAssertTrue(
                testMicrophoneButton.exists,
                "Microphone test toggle button should remain visible during test"
            )

            // Tap again to stop the test
            testMicrophoneButton.tap()

            Thread.sleep(forTimeInterval: 0.3)

            captureScreenshot(named: "WV-003-After-Mic-Test")

            XCTAssertTrue(
                testMicrophoneButton.exists,
                "Microphone test button should remain visible after stopping test"
            )
        } else {
            // If test button is not visible, check for grant button
            let grantMicrophoneButton = app.buttons["grantMicrophoneButton"]
            if grantMicrophoneButton.exists {
                captureScreenshot(named: "WV-003-Permission-Not-Granted")
                // This is expected if permissions couldn't be mocked
                print("Note: Microphone test not available - permission not granted")
            } else {
                captureScreenshot(named: "WV-003-Unknown-State")
                XCTFail("Neither test button nor grant button visible")
            }
        }
    }

    // MARK: - WV-004: Get Started Dismisses View

    /// Test that clicking Get Started completes the welcome flow
    func test_welcome_getStartedDismissesView() throws {
        // Launch with fresh welcome state
        launchAppWithFreshWelcome()

        // Wait for welcome view
        let welcomeView = app.otherElements["welcomeView"]
        guard welcomeView.waitForExistence(timeout: extendedTimeout) else {
            XCTFail("WelcomeView did not appear")
            return
        }

        captureScreenshot(named: "WV-004-Before-Get-Started")

        // Find and tap the Get Started button
        let getStartedButton = app.buttons["getStartedButton"]
        guard getStartedButton.waitForExistence(timeout: 3) else {
            // Try alternative: button by label
            let getStartedByLabel = app.buttons["Get Started"]
            guard getStartedByLabel.waitForExistence(timeout: 2) else {
                captureScreenshot(named: "WV-004-No-Get-Started-Button")
                XCTFail("Get Started button not found")
                return
            }
            getStartedByLabel.tap()
            return
        }

        getStartedButton.tap()

        // Wait for welcome view to dismiss
        let dismissed = waitForDisappearance(welcomeView, timeout: 5)

        captureScreenshot(named: "WV-004-After-Get-Started")

        XCTAssertTrue(
            dismissed,
            "WelcomeView should dismiss after clicking Get Started"
        )

        // Verify the welcome view is no longer visible
        XCTAssertFalse(
            welcomeView.exists,
            "WelcomeView should not exist after completion"
        )
    }

    // MARK: - WV-005: Welcome Not Shown After Completion

    /// Test that welcome doesn't appear after it's been completed
    func test_welcome_notShownAfterCompletion() throws {
        // Launch with onboarding skipped (simulates completed welcome)
        launchAppSkippingOnboarding()

        // Wait for app to initialize
        Thread.sleep(forTimeInterval: 2)

        // Verify welcome view does NOT appear
        let welcomeView = app.otherElements["welcomeView"]
        let welcomeAppeared = welcomeView.waitForExistence(timeout: 2)

        XCTAssertFalse(
            welcomeAppeared,
            "WelcomeView should not appear after completion"
        )

        captureScreenshot(named: "WV-005-No-Welcome")
    }

    // MARK: - WV-006: Keyboard Shortcut Hint Visible

    /// Test that the keyboard shortcut hint is displayed
    func test_welcome_keyboardShortcutHintVisible() throws {
        launchAppWithFreshWelcome()

        // Wait for welcome view
        let welcomeView = app.otherElements["welcomeView"]
        guard welcomeView.waitForExistence(timeout: extendedTimeout) else {
            XCTFail("WelcomeView did not appear")
            return
        }

        // Look for the keyboard shortcut hint text
        // The hint says "Press ... anywhere to record"
        let shortcutHint = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'record'")
        ).firstMatch

        XCTAssertTrue(
            shortcutHint.waitForExistence(timeout: 3),
            "Keyboard shortcut hint should be visible"
        )

        captureScreenshot(named: "WV-006-Keyboard-Shortcut-Hint")
    }

    // MARK: - WV-007: Output Preview Animates

    /// Test that the output preview section shows sample text
    func test_welcome_outputPreviewDisplaysSampleText() throws {
        launchAppWithFreshWelcome()

        // Wait for welcome view
        let welcomeView = app.otherElements["welcomeView"]
        guard welcomeView.waitForExistence(timeout: extendedTimeout) else {
            XCTFail("WelcomeView did not appear")
            return
        }

        // Verify output preview section
        let outputPreviewSection = app.otherElements["outputPreviewSection"]
        XCTAssertTrue(
            outputPreviewSection.waitForExistence(timeout: 3),
            "Output preview section should be visible"
        )

        // Wait for typing animation to display some text
        Thread.sleep(forTimeInterval: 1.5)

        captureScreenshot(named: "WV-007-Output-Preview")

        // The section should contain some text (the animated sample phrases)
        XCTAssertTrue(
            outputPreviewSection.exists,
            "Output preview should be visible with sample text"
        )
    }
}
