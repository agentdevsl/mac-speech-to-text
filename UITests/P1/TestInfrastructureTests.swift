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
        // Launch app with welcome flow (to have predictable UI elements)
        launchApp(arguments: [
            LaunchArguments.resetWelcome,
            LaunchArguments.skipPermissionChecks
        ])

        // Test waitForWelcomeView helper
        XCTAssertTrue(
            waitForWelcomeView(timeout: 10),
            "Welcome view should appear within timeout"
        )

        // Test that non-existent elements return false
        let nonExistent = app.buttons["NonExistentButton12345"]
        XCTAssertFalse(
            UITestHelpers.waitForElement(nonExistent, timeout: 1),
            "Non-existent element should not be found"
        )

        // Test button tap helper with Get Started button
        let getStartedButton = app.buttons["getStartedButton"]
        if UITestHelpers.waitForElement(getStartedButton, timeout: 5) {
            XCTAssertNoThrow(
                try UITestHelpers.tapButton(getStartedButton),
                "Should be able to tap Get Started button"
            )
        }
    }

    // MARK: - TI-003: Reset Welcome

    /// Test that -resetWelcome clears state for fresh test runs
    func test_infrastructure_resetWelcome() throws {
        // First, launch with welcome skipped
        launchApp(arguments: [
            LaunchArguments.skipWelcome,
            LaunchArguments.skipPermissionChecks
        ])

        // Verify welcome is skipped (no welcome view)
        let welcomeView = app.otherElements["welcomeView"]
        XCTAssertFalse(
            welcomeView.waitForExistence(timeout: 2),
            "Welcome should be skipped"
        )

        // Terminate and relaunch with reset
        app.terminate()

        launchApp(arguments: [
            LaunchArguments.resetWelcome,
            LaunchArguments.skipPermissionChecks
        ])

        // Verify welcome view appears after reset
        XCTAssertTrue(
            waitForWelcomeView(timeout: 5),
            "Welcome view should appear after reset"
        )

        // Verify Get Started button is present
        let getStartedButton = app.buttons["getStartedButton"]
        XCTAssertTrue(
            getStartedButton.waitForExistence(timeout: 3),
            "Get Started button should be visible"
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
        XCTAssertEqual(LaunchArguments.skipWelcome, "--skip-welcome")
        XCTAssertEqual(LaunchArguments.resetWelcome, "--reset-welcome")
    }
}
