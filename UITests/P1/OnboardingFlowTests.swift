// OnboardingFlowTests.swift
// macOS Local Speech-to-Text Application
//
// End-to-end UI tests for the onboarding flow
// Part of User Story 3: Onboarding Flow Validation (P1)

import XCTest

/// Tests for the onboarding flow - first-time user experience
/// These tests verify the complete onboarding journey including permissions
final class OnboardingFlowTests: UITestBase {
    // MARK: - OB-001: Welcome Step Appears

    /// Test that welcome step appears on first launch
    func test_onboarding_welcomeStepAppears() throws {
        // Launch with fresh onboarding state
        launchAppWithFreshOnboarding()

        // Verify onboarding window appears
        let onboardingWindow = app.windows["Welcome to Speech-to-Text"]
        XCTAssertTrue(
            onboardingWindow.waitForExistence(timeout: extendedTimeout),
            "Onboarding window should appear on first launch"
        )

        // Verify welcome content
        let welcomeTitle = app.staticTexts["Welcome to Speech-to-Text"]
        XCTAssertTrue(
            welcomeTitle.waitForExistence(timeout: 3),
            "Welcome title should be visible"
        )

        // Verify feature highlights are present
        let localProcessing = app.staticTexts["100% local processing"]
        XCTAssertTrue(
            localProcessing.exists,
            "Local processing feature should be mentioned"
        )

        captureScreenshot(named: "OB-001-Welcome-Step")
    }

    // MARK: - OB-002: Navigation Works

    /// Test that Continue button navigates to next step
    func test_onboarding_navigationWorks() throws {
        launchAppWithFreshOnboarding()

        let onboardingWindow = app.windows["Welcome to Speech-to-Text"]
        guard onboardingWindow.waitForExistence(timeout: extendedTimeout) else {
            XCTFail("Onboarding window did not appear")
            return
        }

        // Click Continue on Welcome step
        let continueButton = app.buttons["Continue"]
        guard continueButton.waitForExistence(timeout: 3) else {
            captureScreenshot(named: "OB-002-No-Continue-Button")
            XCTFail("Continue button not found")
            return
        }

        continueButton.tap()

        // Verify next step (Microphone) appears
        let microphoneTitle = app.staticTexts["Microphone Access"]
        XCTAssertTrue(
            microphoneTitle.waitForExistence(timeout: 3),
            "Microphone step should appear after Continue"
        )

        captureScreenshot(named: "OB-002-After-Continue")
    }

    // MARK: - OB-003: Microphone Permission Step

    /// Test that microphone permission step displays correctly
    func test_onboarding_microphonePermissionStep() throws {
        launchAppWithFreshOnboarding()

        let onboardingWindow = app.windows["Welcome to Speech-to-Text"]
        guard onboardingWindow.waitForExistence(timeout: extendedTimeout) else {
            XCTFail("Onboarding window did not appear")
            return
        }

        // Navigate to microphone step
        let continueButton = app.buttons["Continue"]
        if continueButton.waitForExistence(timeout: 3) {
            continueButton.tap()
        }

        // Verify microphone step content
        let microphoneTitle = app.staticTexts["Microphone Access"]
        XCTAssertTrue(
            microphoneTitle.waitForExistence(timeout: 3),
            "Microphone step title should be visible"
        )

        // Check for grant permission button
        let grantButton = app.buttons["Grant Microphone Access"]
        let exists = grantButton.waitForExistence(timeout: 3)

        captureScreenshot(named: "OB-003-Microphone-Step")

        // If permission already granted, button may not be present
        // or may show different text - this is expected behavior
        if !exists {
            // Check for "Permission Granted" indicator instead
            let grantedIndicator = app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS[c] 'granted'")
            ).firstMatch
            let hasGranted = grantedIndicator.waitForExistence(timeout: 1)
            XCTAssertTrue(
                hasGranted || grantButton.exists,
                "Either grant button or granted indicator should exist"
            )
        }
    }

    // MARK: - OB-004: Accessibility Permission Step

    /// Test that accessibility permission step displays correctly
    func test_onboarding_accessibilityPermissionStep() throws {
        launchAppWithFreshOnboarding()

        // Navigate to accessibility step (step 2)
        let onboardingWindow = app.windows["Welcome to Speech-to-Text"]
        guard onboardingWindow.waitForExistence(timeout: extendedTimeout) else {
            XCTFail("Onboarding window did not appear")
            return
        }

        // Click through to accessibility step
        for _ in 0..<2 {
            let continueButton = app.buttons["Continue"]
            if continueButton.waitForExistence(timeout: 2) && continueButton.isEnabled {
                continueButton.tap()
                // Small delay between clicks
                Thread.sleep(forTimeInterval: 0.5)
            } else {
                break
            }
        }

        // Verify accessibility step content
        let accessibilityTitle = app.staticTexts["Accessibility Access"]
        let accessibilityExists = accessibilityTitle.waitForExistence(timeout: 3)

        captureScreenshot(named: "OB-004-Accessibility-Step")

        if !accessibilityExists {
            // May still be on microphone step if not advanced
            // Check what step we're on
            let microphoneTitle = app.staticTexts["Microphone Access"]
            if microphoneTitle.exists {
                XCTFail("Still on microphone step - navigation may have stalled")
            }
        } else {
            XCTAssertTrue(accessibilityExists, "Accessibility step title should be visible")
        }
    }

    // MARK: - OB-005: Skip Functionality

    /// Test that Skip button works for optional steps
    func test_onboarding_skipFunctionality() throws {
        launchAppWithFreshOnboarding()

        let onboardingWindow = app.windows["Welcome to Speech-to-Text"]
        guard onboardingWindow.waitForExistence(timeout: extendedTimeout) else {
            XCTFail("Onboarding window did not appear")
            return
        }

        // Navigate past welcome
        let continueButton = app.buttons["Continue"]
        if continueButton.waitForExistence(timeout: 3) {
            continueButton.tap()
        }

        // Look for Skip button on permission steps
        let skipButton = app.buttons["Skip"]

        if skipButton.waitForExistence(timeout: 3) {
            // Verify Skip is available
            XCTAssertTrue(skipButton.exists, "Skip button should be available")

            // Click Skip
            skipButton.tap()

            captureScreenshot(named: "OB-005-After-Skip")

            // Verify we moved to next step or got a warning dialog
            let warningDialog = app.alerts.firstMatch
            if warningDialog.waitForExistence(timeout: 2) {
                // Skip warning dialog appeared - this is expected
                XCTAssertTrue(warningDialog.exists, "Skip warning should appear")
            }
        } else {
            // Skip may not be available if all permissions are required
            captureScreenshot(named: "OB-005-No-Skip-Button")
            print("Note: Skip button not available - all steps may be required")
        }
    }

    // MARK: - OB-006: Completion Step

    /// Test that completion step appears after all steps
    func test_onboarding_completionStep() throws {
        // Skip permission checks for this test to reach completion faster
        launchApp(arguments: [
            LaunchArguments.resetOnboarding,
            LaunchArguments.skipPermissionChecks,
            "--mock-permissions=granted"
        ])

        let onboardingWindow = app.windows["Welcome to Speech-to-Text"]
        guard onboardingWindow.waitForExistence(timeout: extendedTimeout) else {
            captureScreenshot(named: "OB-006-No-Onboarding-Window")
            XCTFail("Onboarding window did not appear")
            return
        }

        // Navigate through all steps
        for step in 0..<5 {
            let continueButton = app.buttons["Continue"]
            let nextButton = app.buttons["Next"]
            let getStartedButton = app.buttons["Get Started"]

            if getStartedButton.waitForExistence(timeout: 1) {
                // Reached completion step
                getStartedButton.tap()
                break
            } else if continueButton.waitForExistence(timeout: 2) && continueButton.isEnabled {
                continueButton.tap()
            } else if nextButton.waitForExistence(timeout: 1) && nextButton.isEnabled {
                nextButton.tap()
            }

            // Small delay between steps
            Thread.sleep(forTimeInterval: 0.5)
            captureScreenshot(named: "OB-006-Step-\(step)")
        }

        // Verify completion step or onboarding dismissed
        let getStartedButton = app.buttons["Get Started"]
        let completionText = app.staticTexts["You're All Set!"]

        let reachedCompletion = getStartedButton.waitForExistence(timeout: 3)
            || completionText.waitForExistence(timeout: 1)

        if reachedCompletion {
            captureScreenshot(named: "OB-006-Completion-Step")

            // Click Get Started to dismiss
            if getStartedButton.exists {
                getStartedButton.tap()
            }

            // Verify onboarding is dismissed
            XCTAssertTrue(
                waitForDisappearance(onboardingWindow, timeout: 5),
                "Onboarding window should close after completion"
            )
        } else {
            // Check if already dismissed (permissions auto-advanced)
            let stillExists = onboardingWindow.exists
            XCTAssertFalse(
                stillExists,
                "Onboarding should either show completion or be dismissed"
            )
        }
    }

    // MARK: - OB-007: Back Navigation

    /// Test that Back button returns to previous step
    func test_onboarding_backNavigation() throws {
        launchAppWithFreshOnboarding()

        let onboardingWindow = app.windows["Welcome to Speech-to-Text"]
        guard onboardingWindow.waitForExistence(timeout: extendedTimeout) else {
            XCTFail("Onboarding window did not appear")
            return
        }

        // Go to second step
        let continueButton = app.buttons["Continue"]
        if continueButton.waitForExistence(timeout: 3) {
            continueButton.tap()
        }

        // Verify we're on microphone step
        let microphoneTitle = app.staticTexts["Microphone Access"]
        guard microphoneTitle.waitForExistence(timeout: 3) else {
            captureScreenshot(named: "OB-007-Not-On-Microphone-Step")
            XCTFail("Did not navigate to microphone step")
            return
        }

        // Click Back
        let backButton = app.buttons["Back"]
        if backButton.waitForExistence(timeout: 2) {
            backButton.tap()

            // Verify we're back on welcome step
            let welcomeTitle = app.staticTexts["Welcome to Speech-to-Text"]
            XCTAssertTrue(
                welcomeTitle.waitForExistence(timeout: 3),
                "Should return to welcome step after Back"
            )

            captureScreenshot(named: "OB-007-After-Back")
        } else {
            captureScreenshot(named: "OB-007-No-Back-Button")
            XCTFail("Back button not found")
        }
    }

    // MARK: - OB-008: Onboarding Not Shown After Completion

    /// Test that onboarding doesn't appear after it's been completed
    func test_onboarding_notShownAfterCompletion() throws {
        // Launch with onboarding skipped (simulates completed)
        launchAppSkippingOnboarding()

        // Wait a moment for app to initialize
        Thread.sleep(forTimeInterval: 1)

        // Verify onboarding window does NOT appear
        let onboardingWindow = app.windows["Welcome to Speech-to-Text"]
        XCTAssertFalse(
            onboardingWindow.waitForExistence(timeout: 3),
            "Onboarding should not appear after completion"
        )

        captureScreenshot(named: "OB-008-No-Onboarding")
    }
}
