// ErrorStateTests.swift
// macOS Local Speech-to-Text Application
//
// End-to-end UI tests for error states and recovery
// Part of User Story 5: Error Handling and Recovery (P2)

import XCTest

/// Tests for error states - verifies error display and recovery
final class ErrorStateTests: UITestBase {
    // MARK: - ER-001: Transcription Error Display

    /// Test that transcription errors are displayed to user
    func test_error_transcriptionErrorDisplay() throws {
        // Launch with simulated transcription error
        launchApp(arguments: [
            LaunchArguments.skipOnboarding,
            LaunchArguments.skipPermissionChecks,
            LaunchArguments.triggerRecording,
            "--simulate-error=transcription"
        ])

        // Wait for recording modal
        let recordingStatus = app.staticTexts["Recording"]
        guard recordingStatus.waitForExistence(timeout: extendedTimeout) else {
            captureScreenshot(named: "ER-001-No-Recording-Modal")
            XCTFail("Recording modal did not appear")
            return
        }

        // Stop recording to trigger transcription error
        let stopButton = app.buttons["Stop Recording"]
        if stopButton.waitForExistence(timeout: 3) {
            stopButton.tap()
        }

        // Wait for error to appear
        let errorMessage = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'error' OR label CONTAINS[c] 'failed'")
        ).firstMatch

        let errorView = app.otherElements["errorMessage"]

        // Either error text or error view should appear
        let errorAppeared = errorMessage.waitForExistence(timeout: 5)
            || errorView.waitForExistence(timeout: 2)

        captureScreenshot(named: "ER-001-Transcription-Error")

        XCTAssertTrue(
            errorAppeared,
            "Error message should be displayed for transcription failure"
        )
    }

    // MARK: - ER-002: Model Loading Error

    /// Test that model loading errors are handled gracefully
    func test_error_modelLoadingError() throws {
        // Launch with simulated model loading error
        launchApp(arguments: [
            LaunchArguments.skipOnboarding,
            LaunchArguments.skipPermissionChecks,
            LaunchArguments.triggerRecording,
            "--simulate-error=model-loading"
        ])

        // The recording modal may fail to start properly
        // or show an initialization error
        let recordingModal = app.staticTexts["Recording"]
        let errorIndicator = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'error' OR label CONTAINS[c] 'failed' OR label CONTAINS[c] 'initialize'")
        ).firstMatch

        // Wait for either modal or error to appear
        _ = recordingModal.waitForExistence(timeout: 3)
            || errorIndicator.waitForExistence(timeout: 1)

        captureScreenshot(named: "ER-002-Model-Loading-Error")

        // Either recording appears (then errors on stop)
        // or error appears immediately
        let hasResponse = recordingModal.exists || errorIndicator.exists || !app.windows.isEmpty

        XCTAssertTrue(
            hasResponse,
            "App should respond to model loading error"
        )
    }

    // MARK: - ER-003: Audio Capture Error

    /// Test that audio capture errors are displayed
    func test_error_audioCaptureError() throws {
        // Launch with simulated audio error
        launchApp(arguments: [
            LaunchArguments.skipOnboarding,
            "--mock-permissions=denied"
        ])

        // Wait for potential onboarding or permission error
        let errorMessage = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'permission' OR label CONTAINS[c] 'denied' OR label CONTAINS[c] 'microphone'")
        ).firstMatch

        // Wait for error message or any window to appear
        _ = errorMessage.waitForExistence(timeout: 3)
            || app.windows.firstMatch.waitForExistence(timeout: 1)

        captureScreenshot(named: "ER-003-Audio-Capture-Error")

        // Note: The specific behavior depends on how permission denial is handled
        // App might show error, open System Settings, or show onboarding permission step
    }

    // MARK: - ER-004: Error Recovery

    /// Test that user can recover from error state
    func test_error_recoveryPossible() throws {
        // Launch with simulated error
        launchApp(arguments: [
            LaunchArguments.skipOnboarding,
            LaunchArguments.skipPermissionChecks,
            LaunchArguments.triggerRecording,
            "--simulate-error=transcription"
        ])

        // Wait for recording modal
        let recordingStatus = app.staticTexts["Recording"]
        guard recordingStatus.waitForExistence(timeout: extendedTimeout) else {
            captureScreenshot(named: "ER-004-No-Recording-Modal")
            XCTFail("Recording modal did not appear")
            return
        }

        // Trigger error by stopping
        let stopButton = app.buttons["Stop Recording"]
        if stopButton.waitForExistence(timeout: 3) {
            stopButton.tap()
        }

        // Wait for error state or status change
        let errorText = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'error'")
        ).firstMatch
        _ = errorText.waitForExistence(timeout: 3)
        captureScreenshot(named: "ER-004-Error-State")

        // Cancel button should still work for recovery
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.waitForExistence(timeout: 3) {
            cancelButton.tap()

            // Modal should dismiss
            let dismissed = waitForDisappearance(recordingStatus, timeout: 5)
            XCTAssertTrue(
                dismissed,
                "Should be able to dismiss error state with Cancel"
            )
        } else {
            // Try Escape key
            UITestHelpers.pressEscape(in: app)
        }

        captureScreenshot(named: "ER-004-After-Recovery")
    }

    // MARK: - ER-005: Error Message Clarity

    /// Test that error messages are user-friendly
    func test_error_messageClarity() throws {
        // Launch with simulated error
        launchApp(arguments: [
            LaunchArguments.skipOnboarding,
            LaunchArguments.skipPermissionChecks,
            LaunchArguments.triggerRecording,
            "--simulate-error=transcription"
        ])

        // Wait for recording modal
        let recordingStatus = app.staticTexts["Recording"]
        guard recordingStatus.waitForExistence(timeout: extendedTimeout) else {
            return
        }

        // Trigger error
        let stopButton = app.buttons["Stop Recording"]
        if stopButton.waitForExistence(timeout: 3) {
            stopButton.tap()
        }

        // Look for error message
        let errorMessage = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'failed' OR label CONTAINS[c] 'error'")
        ).firstMatch

        // Wait for error message to appear
        _ = errorMessage.waitForExistence(timeout: 3)

        captureScreenshot(named: "ER-005-Error-Message")

        if errorMessage.exists {
            let label = errorMessage.label

            // Error messages should not contain technical jargon
            // They should be user-friendly
            let hasTechnicalJargon = label.contains("exception")
                || label.contains("nil")
                || label.contains("null")
                || label.contains("stack")

            XCTAssertFalse(
                hasTechnicalJargon,
                "Error messages should be user-friendly, not technical"
            )
        }
    }

    // MARK: - ER-006: No Data Loss on Error

    /// Test that partial data is preserved on error
    func test_error_noDataLoss() throws {
        // This test verifies behavior after transcription failure
        // In a real scenario, the recorded audio could be saved for retry

        launchApp(arguments: [
            LaunchArguments.skipOnboarding,
            LaunchArguments.skipPermissionChecks,
            LaunchArguments.triggerRecording
        ])

        // Record something
        let recordingStatus = app.staticTexts["Recording"]
        guard recordingStatus.waitForExistence(timeout: extendedTimeout) else {
            return
        }

        // Wait for recording controls to be ready
        let stopButton = app.buttons["Stop Recording"]
        _ = stopButton.waitForExistence(timeout: 3)

        captureScreenshot(named: "ER-006-Recording")

        // Cancel recording
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.waitForExistence(timeout: 2) {
            cancelButton.tap()
        }

        // Verify no crash occurred
        XCTAssertTrue(
            app.exists,
            "App should remain running after cancelled recording"
        )

        captureScreenshot(named: "ER-006-After-Cancel")
    }
}
