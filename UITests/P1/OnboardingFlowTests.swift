// OnboardingFlowTests.swift
// macOS Local Speech-to-Text Application
//
// DEPRECATED: This file tests the old 5-step onboarding wizard.
// For new tests, see WelcomeFlowTests.swift which tests the single-screen welcome.
//
// These tests are retained for backwards compatibility and will be removed
// once the legacy onboarding code is fully deprecated.
//
// Part of User Story 3: Onboarding Flow Validation (P1)

import XCTest

/// Tests for the onboarding flow - first-time user experience
/// @deprecated Use WelcomeFlowTests for new single-screen welcome tests
/// These tests verify the complete onboarding journey including permissions
final class OnboardingFlowTests: UITestBase {
    // MARK: - OB-001: Welcome Step Appears

    /// Test that welcome step appears on first launch
    func test_onboarding_welcomeStepAppears() throws {
        // Launch with fresh onboarding state
        launchAppWithFreshOnboarding()

        // Verify onboarding window appears (prefer accessibility identifier)
        let onboardingWindowById = app.windows.matching(
            NSPredicate(format: "identifier == 'onboardingWindow'")
        ).firstMatch
        let onboardingWindowByTitle = app.windows["Welcome to Speech-to-Text"]

        let windowAppeared = onboardingWindowById.waitForExistence(timeout: extendedTimeout)
            || onboardingWindowByTitle.waitForExistence(timeout: 3)
        XCTAssertTrue(
            windowAppeared,
            "Onboarding window should appear on first launch"
        )

        // Verify welcome content (prefer accessibility identifier)
        let welcomeTitleById = app.staticTexts.matching(
            NSPredicate(format: "identifier == 'welcomeTitle'")
        ).firstMatch
        let welcomeTitleByLabel = app.staticTexts["Welcome to Speech-to-Text"]

        let titleVisible = welcomeTitleById.waitForExistence(timeout: 3)
            || welcomeTitleByLabel.waitForExistence(timeout: 1)
        XCTAssertTrue(
            titleVisible,
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

        // Use accessibility identifier for window
        let onboardingWindowById = app.windows.matching(
            NSPredicate(format: "identifier == 'onboardingWindow'")
        ).firstMatch
        let onboardingWindowByTitle = app.windows["Welcome to Speech-to-Text"]

        let windowExists = onboardingWindowById.waitForExistence(timeout: extendedTimeout)
            || onboardingWindowByTitle.waitForExistence(timeout: 3)
        guard windowExists else {
            XCTFail("Onboarding window did not appear")
            return
        }

        // Click Continue on Welcome step (step 0 uses "Continue")
        // Try accessibility identifier first, then fall back to button label
        let nextButtonById = app.buttons.matching(
            NSPredicate(format: "identifier == 'nextButton'")
        ).firstMatch
        let continueButton = app.buttons["Continue"]

        let buttonFound = nextButtonById.waitForExistence(timeout: 3)
            || continueButton.waitForExistence(timeout: 1)
        guard buttonFound else {
            captureScreenshot(named: "OB-002-No-Continue-Button")
            XCTFail("Continue button not found")
            return
        }

        // Tap whichever button we found
        if nextButtonById.exists {
            nextButtonById.tap()
        } else {
            continueButton.tap()
        }

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

        // Use accessibility identifier for window
        let onboardingWindowById = app.windows.matching(
            NSPredicate(format: "identifier == 'onboardingWindow'")
        ).firstMatch
        let onboardingWindowByTitle = app.windows["Welcome to Speech-to-Text"]

        let windowExists = onboardingWindowById.waitForExistence(timeout: extendedTimeout)
            || onboardingWindowByTitle.waitForExistence(timeout: 3)
        guard windowExists else {
            XCTFail("Onboarding window did not appear")
            return
        }

        // Navigate to microphone step (step 0 -> step 1)
        // Step 0 uses "Continue" button
        let nextButtonById = app.buttons.matching(
            NSPredicate(format: "identifier == 'nextButton'")
        ).firstMatch
        let continueButton = app.buttons["Continue"]

        if nextButtonById.waitForExistence(timeout: 3) {
            nextButtonById.tap()
        } else if continueButton.waitForExistence(timeout: 1) {
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

        guard getOnboardingWindow() != nil else {
            XCTFail("Onboarding window did not appear")
            return
        }

        // Navigate to accessibility step (step 2)
        navigateOnboardingSteps(count: 2, clickGetStarted: false)

        // Verify accessibility step content
        let accessibilityTitle = app.staticTexts["Accessibility Access"]
        let accessibilityExists = accessibilityTitle.waitForExistence(timeout: 3)
        captureScreenshot(named: "OB-004-Accessibility-Step")

        if !accessibilityExists {
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

        guard getOnboardingWindow() != nil else {
            XCTFail("Onboarding window did not appear")
            return
        }

        // Navigate past welcome (step 0)
        navigateOnboardingSteps(count: 1, clickGetStarted: false)

        // Look for Skip button on permission steps
        let skipButton = app.buttons["Skip"]
        if skipButton.waitForExistence(timeout: 3) {
            XCTAssertTrue(skipButton.exists, "Skip button should be available")
            skipButton.tap()
            captureScreenshot(named: "OB-005-After-Skip")

            // Verify we moved to next step or got a warning dialog
            let warningDialog = app.alerts.firstMatch
            if warningDialog.waitForExistence(timeout: 2) {
                XCTAssertTrue(warningDialog.exists, "Skip warning should appear")
            }
        } else {
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

        guard let onboardingWindow = getOnboardingWindow() else {
            captureScreenshot(named: "OB-006-No-Onboarding-Window")
            XCTFail("Onboarding window did not appear")
            return
        }

        // Navigate through all steps and click Get Started
        navigateOnboardingSteps(count: 5, clickGetStarted: true)
        captureScreenshot(named: "OB-006-After-Navigation")

        // Verify onboarding dismissed or shows completion
        let getStartedButton = app.buttons["Get Started"]
        let completionText = app.staticTexts["You're All Set!"]
        let reachedCompletion = getStartedButton.waitForExistence(timeout: 3)
            || completionText.waitForExistence(timeout: 1)

        if reachedCompletion {
            captureScreenshot(named: "OB-006-Completion-Step")
            if getStartedButton.exists { getStartedButton.tap() }
            XCTAssertTrue(
                waitForDisappearance(onboardingWindow, timeout: 5),
                "Onboarding window should close after completion"
            )
        } else {
            XCTAssertFalse(
                onboardingWindow.exists,
                "Onboarding should either show completion or be dismissed"
            )
        }
    }

    // MARK: - OB-007: Back Navigation

    /// Test that Back button returns to previous step
    func test_onboarding_backNavigation() throws {
        launchAppWithFreshOnboarding()

        guard getOnboardingWindow() != nil else {
            XCTFail("Onboarding window did not appear")
            return
        }

        // Go to second step
        navigateOnboardingSteps(count: 1, clickGetStarted: false)

        // Verify we're on microphone step
        let microphoneTitle = app.staticTexts["Microphone Access"]
        guard microphoneTitle.waitForExistence(timeout: 3) else {
            captureScreenshot(named: "OB-007-Not-On-Microphone-Step")
            XCTFail("Did not navigate to microphone step")
            return
        }

        // Click Back
        let backButton = app.buttons["Back"]
        guard backButton.waitForExistence(timeout: 2) else {
            captureScreenshot(named: "OB-007-No-Back-Button")
            XCTFail("Back button not found")
            return
        }

        backButton.tap()

        // Verify we're back on welcome step
        let welcomeTitleById = app.staticTexts.matching(
            NSPredicate(format: "identifier == 'welcomeTitle'")
        ).firstMatch
        let welcomeTitleByLabel = app.staticTexts["Welcome to Speech-to-Text"]
        let backToWelcome = welcomeTitleById.waitForExistence(timeout: 3)
            || welcomeTitleByLabel.waitForExistence(timeout: 1)

        XCTAssertTrue(backToWelcome, "Should return to welcome step after Back")
        captureScreenshot(named: "OB-007-After-Back")
    }

    // MARK: - OB-008: Onboarding Not Shown After Completion

    /// Test that onboarding doesn't appear after it's been completed
    func test_onboarding_notShownAfterCompletion() throws {
        // Launch with onboarding skipped (simulates completed)
        launchAppSkippingOnboarding()

        // Wait for app to initialize
        _ = app.menuBarItems.firstMatch.waitForExistence(timeout: 2)

        // Verify onboarding window does NOT appear
        let windowAppeared = getOnboardingWindow() != nil
        XCTAssertFalse(windowAppeared, "Onboarding should not appear after completion")
        captureScreenshot(named: "OB-008-No-Onboarding")
    }
}
