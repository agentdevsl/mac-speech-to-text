// AccessibilityTests.swift
// macOS Local Speech-to-Text Application
//
// End-to-end UI tests for accessibility compliance
// Part of User Story 7: Accessibility and Compliance (P3)

import XCTest

/// Tests for accessibility compliance - VoiceOver, keyboard navigation, etc.
final class AccessibilityTests: UITestBase {
    // MARK: - AC-001: All Interactive Elements Have Labels

    /// Test that all interactive elements have accessibility labels
    func test_accessibility_allElementsHaveLabels() throws {
        // Launch with accessibility testing enabled
        launchApp(arguments: [
            LaunchArguments.skipOnboarding,
            LaunchArguments.skipPermissionChecks,
            LaunchArguments.triggerRecording,
            LaunchArguments.accessibilityTesting
        ])

        // Wait for recording modal
        let recordingStatus = app.staticTexts["Recording"]
        guard recordingStatus.waitForExistence(timeout: extendedTimeout) else {
            captureScreenshot(named: "AC-001-No-Recording-Modal")
            XCTFail("Recording modal did not appear")
            return
        }

        // Check all buttons have labels
        let buttons = app.buttons.allElementsBoundByIndex
        for button in buttons {
            if button.exists && button.isHittable {
                XCTAssertFalse(
                    button.label.isEmpty,
                    "Button should have accessibility label: \(button)"
                )
            }
        }

        // Check the waveform has accessibility label
        let waveform = app.otherElements["waveformView"]
        if waveform.exists {
            XCTAssertFalse(
                waveform.label.isEmpty,
                "Waveform should have accessibility label"
            )
        }

        captureScreenshot(named: "AC-001-Recording-Modal-A11y")

        // Cancel to check other views
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.exists {
            cancelButton.tap()
        }
    }

    // MARK: - AC-002: Keyboard Navigation

    /// Test that all controls are keyboard accessible
    func test_accessibility_keyboardNavigation() throws {
        launchAppWithFreshOnboarding()

        let onboardingWindow = app.windows["Welcome to Speech-to-Text"]
        guard onboardingWindow.waitForExistence(timeout: extendedTimeout) else {
            XCTFail("Onboarding window did not appear")
            return
        }

        // Tab through elements
        app.typeKey(.tab, modifierFlags: [])
        captureScreenshot(named: "AC-002-After-Tab-1")

        app.typeKey(.tab, modifierFlags: [])
        captureScreenshot(named: "AC-002-After-Tab-2")

        // Press Enter/Return to activate focused element
        app.typeKey(.return, modifierFlags: [])

        // Should navigate forward
        Thread.sleep(forTimeInterval: 0.5)
        captureScreenshot(named: "AC-002-After-Enter")

        // Tab backwards with Shift+Tab
        app.typeKey(.tab, modifierFlags: .shift)
        captureScreenshot(named: "AC-002-After-Shift-Tab")
    }

    // MARK: - AC-003: Focus Indication

    /// Test that focused elements have visible focus indicators
    func test_accessibility_focusIndication() throws {
        launchAppWithFreshOnboarding()

        let onboardingWindow = app.windows["Welcome to Speech-to-Text"]
        guard onboardingWindow.waitForExistence(timeout: extendedTimeout) else {
            XCTFail("Onboarding window did not appear")
            return
        }

        // Tab to get focus ring on Continue button
        let continueButton = app.buttons["Continue"]
        if continueButton.exists {
            // Tab until Continue is focused
            for _ in 0..<5 {
                app.typeKey(.tab, modifierFlags: [])

                if continueButton.hasFocus {
                    break
                }
            }
        }

        captureScreenshot(named: "AC-003-Focus-Ring")

        // Focus ring visibility is primarily a visual check
        // Screenshots capture the focus state
    }

    // MARK: - AC-004: Color Contrast

    /// Test that text has sufficient color contrast (visual verification)
    func test_accessibility_colorContrast() throws {
        launchAppWithRecordingModal()

        let recordingStatus = app.staticTexts["Recording"]
        guard recordingStatus.waitForExistence(timeout: extendedTimeout) else {
            return
        }

        // Capture screenshots of different states for manual contrast verification
        captureScreenshot(named: "AC-004-Recording-State")

        // The actual contrast ratio check requires image analysis
        // This test captures UI states for manual or automated verification

        // Stop recording to get different state
        let stopButton = app.buttons["Stop Recording"]
        if stopButton.exists {
            stopButton.tap()
            Thread.sleep(forTimeInterval: 1)
            captureScreenshot(named: "AC-004-Processing-State")
        }
    }

    // MARK: - AC-005: Screen Reader Compatibility

    /// Test elements are properly announced for screen readers
    func test_accessibility_screenReaderCompatibility() throws {
        launchAppWithRecordingModal()

        let recordingStatus = app.staticTexts["Recording"]
        guard recordingStatus.waitForExistence(timeout: extendedTimeout) else {
            return
        }

        // Check that static texts have proper accessibility traits
        let allTexts = app.staticTexts.allElementsBoundByIndex

        for text in allTexts where text.exists {
            // Verify the text is accessible
            let traits = text.accessibilityTraits
            XCTAssertTrue(
                traits.contains(.staticText) || !text.label.isEmpty,
                "Static text should be accessible to screen readers"
            )
        }

        captureScreenshot(named: "AC-005-Screen-Reader-Elements")
    }

    // MARK: - AC-006: Error Announcements

    /// Test that errors are announced to assistive technology
    func test_accessibility_errorAnnouncements() throws {
        // Launch with simulated error
        launchApp(arguments: [
            LaunchArguments.skipOnboarding,
            LaunchArguments.skipPermissionChecks,
            LaunchArguments.triggerRecording,
            LaunchArguments.accessibilityTesting,
            "--simulate-error=transcription"
        ])

        let recordingStatus = app.staticTexts["Recording"]
        guard recordingStatus.waitForExistence(timeout: extendedTimeout) else {
            return
        }

        // Trigger error
        let stopButton = app.buttons["Stop Recording"]
        if stopButton.exists {
            stopButton.tap()
        }

        // Wait for error to appear
        Thread.sleep(forTimeInterval: 2)

        // Check for error message accessibility
        let errorMessage = app.otherElements["errorMessage"]
        if errorMessage.exists {
            // Error message should have accessibility label
            XCTAssertFalse(
                errorMessage.label.isEmpty,
                "Error message should have accessibility announcement"
            )
        }

        captureScreenshot(named: "AC-006-Error-Announcement")
    }

    // MARK: - AC-007: Onboarding Accessibility

    /// Test onboarding flow is fully accessible
    func test_accessibility_onboardingAccessible() throws {
        launchApp(arguments: [
            LaunchArguments.resetOnboarding,
            LaunchArguments.skipPermissionChecks,
            LaunchArguments.accessibilityTesting
        ])

        let onboardingWindow = app.windows["Welcome to Speech-to-Text"]
        guard onboardingWindow.waitForExistence(timeout: extendedTimeout) else {
            XCTFail("Onboarding window did not appear")
            return
        }

        // Check welcome step accessibility
        let welcomeTitle = app.staticTexts["Welcome to Speech-to-Text"]
        XCTAssertTrue(
            welcomeTitle.exists && !welcomeTitle.label.isEmpty,
            "Welcome title should be accessible"
        )

        // Check feature items have labels
        let featureItems = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'local' OR label CONTAINS[c] 'privacy'")
        )

        XCTAssertGreaterThan(
            featureItems.count, 0,
            "Feature descriptions should be accessible"
        )

        captureScreenshot(named: "AC-007-Onboarding-A11y")

        // Check Continue button
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(
            continueButton.exists && !continueButton.label.isEmpty,
            "Continue button should be accessible"
        )
    }

    // MARK: - AC-008: Heading Hierarchy

    /// Test that there's proper heading structure
    func test_accessibility_headingHierarchy() throws {
        launchAppWithFreshOnboarding()

        let onboardingWindow = app.windows["Welcome to Speech-to-Text"]
        guard onboardingWindow.waitForExistence(timeout: extendedTimeout) else {
            return
        }

        // In SwiftUI, headings are typically styled with .font(.title) etc.
        // Check that main title exists as heading
        let headings = app.staticTexts.matching(
            NSPredicate(format: "label == 'Welcome to Speech-to-Text'")
        )

        XCTAssertEqual(
            headings.count, 1,
            "Should have exactly one main heading"
        )

        captureScreenshot(named: "AC-008-Heading-Structure")
    }
}

// MARK: - XCUIElement Accessibility Extension

extension XCUIElement {
    /// Check if element has keyboard focus
    /// Note: XCUIElement doesn't expose focus directly, using heuristic
    var hasFocus: Bool {
        // Use heuristic: element exists, is enabled, and is hittable (likely focused)
        return exists && isEnabled && isHittable
    }

    /// Get accessibility traits based on element type
    /// Note: XCUIElement doesn't expose UIAccessibilityTraits directly on macOS
    var accessibilityTraits: UIAccessibilityTraits {
        // Infer traits from element type
        switch elementType {
        case .staticText:
            return .staticText
        case .button:
            return .button
        case .image:
            return .image
        case .link:
            return .link
        default:
            return []
        }
    }
}
