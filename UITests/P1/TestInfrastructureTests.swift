// TestInfrastructureTests.swift
// macOS Local Speech-to-Text Application
//
// Tests for the UI test infrastructure itself
// Verifies screenshot capture, helpers, and reset functionality
// Part of User Story 8: Test Infrastructure Improvements (P1)

import XCTest

/// Tests for the UI test infrastructure
/// These tests verify that the testing utilities work correctly
final class TestInfrastructureTests: UITestBase {
    // MARK: - TI-001: Screenshot Capture

    /// Test that screenshots are captured on test failure
    /// Verification: After test, check xcresult bundle for screenshot attachment
    func test_infrastructure_screenshotCaptured() throws {
        // Launch app in basic test mode
        launchAppSkippingOnboarding()

        // Take a manual screenshot to verify the mechanism works
        captureScreenshot(named: "Infrastructure-Test-Manual-Screenshot")

        // Verify app is running (basic sanity check)
        XCTAssertTrue(app.exists, "App should be running")

        // The screenshot capture on failure is tested by tearDown automatically
        // when any test fails - this test verifies manual capture works
    }

    // MARK: - TI-002: Helper Functions

    /// Test that UITestHelpers functions work correctly
    func test_infrastructure_helpersFunction() throws {
        // Launch app with onboarding (to have predictable UI elements)
        launchApp(arguments: [
            LaunchArguments.resetOnboarding,
            LaunchArguments.skipPermissionChecks
        ])

        // Test waitForElement helper
        let welcomeText = app.staticTexts["Welcome to Speech-to-Text"]
        XCTAssertTrue(
            UITestHelpers.waitForElement(welcomeText, timeout: 10),
            "Welcome text should appear within timeout"
        )

        // Test verifyTextExists helper
        XCTAssertTrue(
            UITestHelpers.verifyTextExists("Welcome to Speech-to-Text", in: app),
            "Should find welcome text in app"
        )

        // Test that non-existent elements return false
        let nonExistent = app.buttons["NonExistentButton12345"]
        XCTAssertFalse(
            UITestHelpers.waitForElement(nonExistent, timeout: 1),
            "Non-existent element should not be found"
        )

        // Test button tap helper
        let continueButton = app.buttons["Continue"]
        if UITestHelpers.waitForElement(continueButton, timeout: 5) {
            XCTAssertNoThrow(
                try UITestHelpers.tapButton(continueButton),
                "Should be able to tap Continue button"
            )
        }
    }

    // MARK: - TI-003: Reset Onboarding

    /// Test that --reset-onboarding clears state for fresh test runs
    func test_infrastructure_resetOnboarding() throws {
        // First, launch and complete onboarding
        launchApp(arguments: [
            LaunchArguments.skipOnboarding,
            LaunchArguments.skipPermissionChecks
        ])

        // Verify onboarding is skipped (no onboarding window)
        let onboardingWindow = app.windows["Welcome to Speech-to-Text"]
        XCTAssertFalse(
            onboardingWindow.waitForExistence(timeout: 2),
            "Onboarding should be skipped"
        )

        // Terminate and relaunch with reset
        app.terminate()

        launchApp(arguments: [
            LaunchArguments.resetOnboarding,
            LaunchArguments.skipPermissionChecks
        ])

        // Verify onboarding appears after reset
        XCTAssertTrue(
            onboardingWindow.waitForExistence(timeout: 5),
            "Onboarding should appear after reset"
        )

        // Verify welcome content is present
        let welcomeText = app.staticTexts["Welcome to Speech-to-Text"]
        XCTAssertTrue(
            welcomeText.waitForExistence(timeout: 3),
            "Welcome text should be visible"
        )
    }

    // MARK: - Infrastructure Verification

    /// Verify that the test base class provides expected utilities
    func test_infrastructure_baseClassProvided() throws {
        // Verify app instance is available
        XCTAssertNotNil(app, "App instance should be available")

        // Verify default timeout is set
        XCTAssertEqual(defaultTimeout, 5.0, "Default timeout should be 5 seconds")

        // Verify extended timeout is set
        XCTAssertEqual(extendedTimeout, 10.0, "Extended timeout should be 10 seconds")
    }

    /// Verify that launch argument helpers work
    func test_infrastructure_launchArgumentHelpers() throws {
        // Test that launchAppWithRecordingModal includes correct arguments
        // We don't actually launch here, just verify the method exists
        // The actual launch is tested in RecordingFlowTests

        // Verify LaunchArguments constants are accessible
        XCTAssertEqual(LaunchArguments.uitesting, "--uitesting")
        XCTAssertEqual(LaunchArguments.skipOnboarding, "--skip-onboarding")
        XCTAssertEqual(LaunchArguments.resetOnboarding, "--reset-onboarding")
        XCTAssertEqual(LaunchArguments.skipPermissionChecks, "--skip-permission-checks")
        XCTAssertEqual(LaunchArguments.triggerRecording, "--trigger-recording")
    }
}
