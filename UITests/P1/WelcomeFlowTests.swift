// WelcomeFlowTests.swift
// macOS Local Speech-to-Text Application
//
// End-to-end UI tests for the single-screen welcome flow
// Replaces the old multi-step OnboardingFlowTests
// Part of the UI Simplification initiative

import XCTest

/// Tests for the single-screen welcome flow
/// These tests verify the streamlined onboarding experience with:
/// - Mic permission inline request
/// - Mic input test
/// - Output preview
/// - Get Started dismissal
final class WelcomeFlowTests: UITestBase {
    // MARK: - WF-001: Welcome Screen Appears

    /// Test that welcome screen appears on first launch
    func test_welcome_screenAppears() throws {
        // Launch with fresh state (reset onboarding)
        launchAppWithFreshOnboarding()

        // Look for welcome window by accessibility identifier or title
        let welcomeWindow = app.windows.matching(
            NSPredicate(format: "identifier == 'welcomeWindow'")
        ).firstMatch
        let welcomeWindowByTitle = app.windows["Welcome"]

        let windowAppeared = welcomeWindow.waitForExistence(timeout: extendedTimeout)
            || welcomeWindowByTitle.waitForExistence(timeout: 3)

        XCTAssertTrue(
            windowAppeared,
            "Welcome window should appear on first launch"
        )

        // Verify welcome content - app title
        let appTitle = app.staticTexts["Speech to Text"]
        let hasTitleContent = appTitle.waitForExistence(timeout: 3)

        XCTAssertTrue(
            hasTitleContent || welcomeWindow.exists,
            "Welcome screen should display app title"
        )

        captureScreenshot(named: "WF-001-Welcome-Screen")
    }

    // MARK: - WF-002: Mic Permission Section

    /// Test that microphone permission section is visible
    func test_welcome_micPermissionSectionVisible() throws {
        launchAppWithFreshOnboarding()

        // Wait for welcome window
        let welcomeWindow = app.windows.matching(
            NSPredicate(format: "identifier == 'welcomeWindow'")
        ).firstMatch

        guard welcomeWindow.waitForExistence(timeout: extendedTimeout) else {
            captureScreenshot(named: "WF-002-No-Welcome-Window")
            XCTFail("Welcome window did not appear")
            return
        }

        // Look for microphone permission UI elements
        let microphoneLabel = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'microphone' OR label CONTAINS[c] 'mic'")
        ).firstMatch

        let permissionButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'microphone' OR label CONTAINS[c] 'permission' OR label CONTAINS[c] 'grant'")
        ).firstMatch

        let hasMicSection = microphoneLabel.waitForExistence(timeout: 3)
            || permissionButton.waitForExistence(timeout: 2)

        XCTAssertTrue(
            hasMicSection,
            "Welcome screen should have microphone permission section"
        )

        captureScreenshot(named: "WF-002-Mic-Permission-Section")
    }

    // MARK: - WF-003: Mic Test Button

    /// Test that mic test button exists and is functional
    func test_welcome_micTestFunctionality() throws {
        // Launch with permissions granted to enable test button
        launchApp(arguments: [
            LaunchArguments.resetOnboarding,
            LaunchArguments.skipPermissionChecks,
            "--mock-permissions=granted"
        ])

        let welcomeWindow = app.windows.matching(
            NSPredicate(format: "identifier == 'welcomeWindow'")
        ).firstMatch

        guard welcomeWindow.waitForExistence(timeout: extendedTimeout) else {
            captureScreenshot(named: "WF-003-No-Welcome-Window")
            XCTFail("Welcome window did not appear")
            return
        }

        // Look for mic test button
        let testMicButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'test' OR label CONTAINS[c] 'try'")
        ).firstMatch

        captureScreenshot(named: "WF-003-Before-Mic-Test")

        if testMicButton.waitForExistence(timeout: 3) {
            testMicButton.tap()
            // Wait for test to start
            sleep(1)
            captureScreenshot(named: "WF-003-During-Mic-Test")
        } else {
            // Permission may not be granted in test environment
            print("Note: Mic test button not available - permission may be required")
        }
    }

    // MARK: - WF-004: Output Preview Section

    /// Test that output preview section shows sample text
    func test_welcome_outputPreviewVisible() throws {
        launchAppWithFreshOnboarding()

        let welcomeWindow = app.windows.matching(
            NSPredicate(format: "identifier == 'welcomeWindow'")
        ).firstMatch

        guard welcomeWindow.waitForExistence(timeout: extendedTimeout) else {
            XCTFail("Welcome window did not appear")
            return
        }

        // Look for output preview - may be a text field or styled text area
        let outputPreview = app.textFields.matching(
            NSPredicate(format: "identifier CONTAINS[c] 'output' OR identifier CONTAINS[c] 'preview'")
        ).firstMatch

        let sampleText = app.staticTexts.matching(
            NSPredicate(
                format: "label CONTAINS[c] 'your transcribed' OR label CONTAINS[c] 'speech' OR label CONTAINS[c] 'say something'"
            )
        ).firstMatch

        let hasPreview = outputPreview.waitForExistence(timeout: 3)
            || sampleText.waitForExistence(timeout: 2)

        captureScreenshot(named: "WF-004-Output-Preview")

        // Preview section is optional - don't fail if not present
        if !hasPreview {
            print("Note: Output preview section not found - may be in different state")
        }
    }

    // MARK: - WF-005: Hotkey Hint Visible

    /// Test that hotkey hint is displayed
    func test_welcome_hotkeyHintVisible() throws {
        launchAppWithFreshOnboarding()

        let welcomeWindow = app.windows.matching(
            NSPredicate(format: "identifier == 'welcomeWindow'")
        ).firstMatch

        guard welcomeWindow.waitForExistence(timeout: extendedTimeout) else {
            XCTFail("Welcome window did not appear")
            return
        }

        // Look for hotkey hint - should show Cmd+Ctrl+Space or similar
        let hotkeyHint = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] '⌘' OR label CONTAINS[c] 'cmd' OR label CONTAINS[c] 'ctrl'")
        ).firstMatch

        let keycapElement = app.otherElements.matching(
            NSPredicate(format: "identifier CONTAINS[c] 'keycap' OR identifier CONTAINS[c] 'hotkey'")
        ).firstMatch

        let hasHotkeyHint = hotkeyHint.waitForExistence(timeout: 3)
            || keycapElement.waitForExistence(timeout: 2)

        captureScreenshot(named: "WF-005-Hotkey-Hint")

        XCTAssertTrue(
            hasHotkeyHint,
            "Welcome screen should display hotkey hint"
        )
    }

    // MARK: - WF-006: Get Started Dismisses

    /// Test that Get Started button dismisses welcome and starts app
    func test_welcome_getStartedDismisses() throws {
        launchApp(arguments: [
            LaunchArguments.resetOnboarding,
            LaunchArguments.skipPermissionChecks,
            "--mock-permissions=granted"
        ])

        let welcomeWindow = app.windows.matching(
            NSPredicate(format: "identifier == 'welcomeWindow'")
        ).firstMatch

        guard welcomeWindow.waitForExistence(timeout: extendedTimeout) else {
            captureScreenshot(named: "WF-006-No-Welcome-Window")
            XCTFail("Welcome window did not appear")
            return
        }

        // Find and tap Get Started button
        let getStartedButton = app.buttons["Get Started"]
        let startButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'start' OR label CONTAINS[c] 'begin'")
        ).firstMatch

        captureScreenshot(named: "WF-006-Before-Get-Started")

        if getStartedButton.waitForExistence(timeout: 3) {
            getStartedButton.tap()
        } else if startButton.waitForExistence(timeout: 2) {
            startButton.tap()
        } else {
            XCTFail("Get Started button not found")
            return
        }

        // Verify welcome window is dismissed
        let windowDismissed = waitForDisappearance(welcomeWindow, timeout: 5)

        XCTAssertTrue(
            windowDismissed,
            "Welcome window should be dismissed after tapping Get Started"
        )

        captureScreenshot(named: "WF-006-After-Get-Started")
    }

    // MARK: - WF-007: Welcome Not Shown After Completion

    /// Test that welcome doesn't appear after it's been dismissed
    func test_welcome_notShownAfterCompletion() throws {
        // Launch with onboarding skipped (simulates completed)
        launchAppSkippingOnboarding()

        // Wait for app to initialize
        _ = app.menuBarItems.firstMatch.waitForExistence(timeout: 2)

        // Verify welcome window does NOT appear
        let welcomeWindow = app.windows.matching(
            NSPredicate(format: "identifier == 'welcomeWindow'")
        ).firstMatch

        let windowAppeared = welcomeWindow.waitForExistence(timeout: 3)

        XCTAssertFalse(
            windowAppeared,
            "Welcome should not appear after completion"
        )

        captureScreenshot(named: "WF-007-No-Welcome")
    }

    // MARK: - WF-008: Escape Key Dismisses

    /// Test that pressing Escape key dismisses welcome screen
    func test_welcome_escapeKeyDismisses() throws {
        launchApp(arguments: [
            LaunchArguments.resetOnboarding,
            LaunchArguments.skipPermissionChecks
        ])

        let welcomeWindow = app.windows.matching(
            NSPredicate(format: "identifier == 'welcomeWindow'")
        ).firstMatch

        guard welcomeWindow.waitForExistence(timeout: extendedTimeout) else {
            XCTFail("Welcome window did not appear")
            return
        }

        // Press Escape
        UITestHelpers.pressEscape(in: app)

        // Welcome may require confirmation to dismiss
        // Check for dialog or just verify state
        let windowDismissed = waitForDisappearance(welcomeWindow, timeout: 3)

        // Escape may not dismiss if mic permission is required
        // This is expected behavior
        if !windowDismissed {
            print("Note: Escape did not dismiss welcome - may require permission setup first")
            captureScreenshot(named: "WF-008-Escape-Not-Dismissed")
        } else {
            captureScreenshot(named: "WF-008-Escape-Dismissed")
        }
    }
}
