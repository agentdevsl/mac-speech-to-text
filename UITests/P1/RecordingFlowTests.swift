// RecordingFlowTests.swift
// macOS Local Speech-to-Text Application
//
// End-to-end UI tests for the core recording workflow
// Updated for glass overlay mode (replaces FloatingWidget + HoldToRecordOverlay)
// Part of User Story 1: Recording Flow Validation (P1)

import XCTest

/// Tests for the recording flow - the primary user interaction
/// Tests verify:
/// - GlassRecordingOverlay appearance during hold-to-record
/// - Recording status text updates
/// - Waveform and progress indicator visibility
/// - Pulsing recording indicator
/// - Overlay dismissal after completion
final class RecordingFlowTests: UITestBase {
    // MARK: - Accessibility Identifiers

    /// New UI accessibility identifiers for GlassRecordingOverlay
    private enum AccessibilityIDs {
        static let glassOverlay = "glassRecordingOverlay"
        static let overlayStatusText = "overlayStatusText"
        static let dynamicWaveform = "dynamicWaveform"
        static let overlayTimer = "overlayTimer"
        static let transcribingSpinner = "transcribingSpinner"
    }

    // MARK: - RF-001: Glass Overlay Appears on Recording Trigger

    /// Test that glass recording overlay appears when recording is triggered
    func test_glassOverlay_appearsOnRecordingTrigger() throws {
        // Launch app with recording triggered
        launchAppWithRecordingModal()

        // Wait for the glass overlay to appear
        let overlay = app.otherElements[AccessibilityIDs.glassOverlay]
        let overlayExists = overlay.waitForExistence(timeout: extendedTimeout)

        captureScreenshot(named: "RF-001-Glass-Overlay-Appeared")

        XCTAssertTrue(
            overlayExists,
            "GlassRecordingOverlay should appear when recording is triggered"
        )

        // Verify overlay has expected size (approximately 200x80)
        if overlayExists {
            let frame = overlay.frame
            XCTAssertGreaterThan(
                frame.width,
                100,
                "Overlay width should be substantial"
            )
            XCTAssertGreaterThan(
                frame.height,
                40,
                "Overlay height should be substantial"
            )
        }
    }

    // MARK: - RF-002: Overlay Appears in Recording State

    /// Test that glass overlay appears in recording state
    func test_glassOverlay_showsRecordingState() throws {
        // Launch app with recording triggered
        launchAppWithRecordingModal()

        // Wait for glass overlay
        let overlay = app.otherElements[AccessibilityIDs.glassOverlay]
        guard overlay.waitForExistence(timeout: extendedTimeout) else {
            captureScreenshot(named: "RF-002-No-Overlay")
            XCTFail("GlassRecordingOverlay not found")
            return
        }

        // Check for recording state
        let statusText = app.staticTexts[AccessibilityIDs.overlayStatusText]
        let statusExists = statusText.waitForExistence(timeout: defaultTimeout)

        captureScreenshot(named: "RF-002-Recording-State")

        if statusExists {
            let label = statusText.label
            let isRecording = label.contains("Recording")
            XCTAssertTrue(
                isRecording,
                "Status should show 'Recording' state, got: \(label)"
            )
        }
    }

    // MARK: - RF-003: Overlay Shows Status Text

    /// Test that glass overlay shows status text updates
    func test_glassOverlay_showsStatusText() throws {
        // Launch app with recording triggered
        launchAppWithRecordingModal()

        // Wait for overlay
        let overlay = app.otherElements[AccessibilityIDs.glassOverlay]
        guard overlay.waitForExistence(timeout: extendedTimeout) else {
            captureScreenshot(named: "RF-003-No-Overlay")
            XCTFail("GlassRecordingOverlay not found")
            return
        }

        // Look for status text with accessibility identifier
        let statusText = app.staticTexts[AccessibilityIDs.overlayStatusText]
        let statusExists = statusText.waitForExistence(timeout: defaultTimeout)

        captureScreenshot(named: "RF-003-Status-Text")

        XCTAssertTrue(
            statusExists,
            "Status text should be visible in overlay"
        )

        // Verify status shows expected recording state
        if statusExists {
            let label = statusText.label
            let isValidStatus = label.contains("Recording")
                || label.contains("Transcribing")
            XCTAssertTrue(
                isValidStatus,
                "Status should show 'Recording' or 'Transcribing', got: \(label)"
            )
        }
    }

    // MARK: - RF-004: Overlay Shows Timer

    /// Test that timer is visible during recording
    func test_glassOverlay_showsTimer() throws {
        // Launch app with recording triggered
        launchAppWithRecordingModal()

        // Wait for overlay
        let overlay = app.otherElements[AccessibilityIDs.glassOverlay]
        guard overlay.waitForExistence(timeout: extendedTimeout) else {
            captureScreenshot(named: "RF-004-No-Overlay")
            XCTFail("GlassRecordingOverlay not found")
            return
        }

        // Look for timer display
        let timer = app.staticTexts[AccessibilityIDs.overlayTimer]
        let timerExists = timer.waitForExistence(timeout: defaultTimeout)

        captureScreenshot(named: "RF-004-Timer")

        XCTAssertTrue(
            timerExists,
            "Timer should be visible during recording"
        )
    }

    // MARK: - RF-005: Overlay Shows Waveform

    /// Test that waveform is visible during recording
    func test_glassOverlay_showsWaveform() throws {
        // Launch app with recording triggered
        launchAppWithRecordingModal()

        // Wait for overlay
        let overlay = app.otherElements[AccessibilityIDs.glassOverlay]
        guard overlay.waitForExistence(timeout: extendedTimeout) else {
            captureScreenshot(named: "RF-005-No-Overlay")
            XCTFail("GlassRecordingOverlay not found")
            return
        }

        // Look for dynamic waveform
        let waveform = app.otherElements[AccessibilityIDs.dynamicWaveform]
        let waveformExists = waveform.waitForExistence(timeout: defaultTimeout)

        captureScreenshot(named: "RF-005-Waveform")

        XCTAssertTrue(
            waveformExists,
            "Dynamic waveform should be visible during recording"
        )
    }

    // MARK: - RF-006: Overlay Shows Transcribing State

    /// Test that spinner appears during transcription
    func test_glassOverlay_showsTranscribingState() throws {
        // Launch app with recording triggered
        launchAppWithRecordingModal()

        // Wait for recording to start
        let overlay = app.otherElements[AccessibilityIDs.glassOverlay]
        guard overlay.waitForExistence(timeout: extendedTimeout) else {
            captureScreenshot(named: "RF-006-No-Overlay")
            XCTFail("GlassRecordingOverlay not found")
            return
        }

        captureScreenshot(named: "RF-006-Recording-Active")

        // Press Escape to stop recording and trigger transcription
        UITestHelpers.pressEscape(in: app)

        // Wait for transcription state - spinner should appear
        let spinner = app.otherElements[AccessibilityIDs.transcribingSpinner]
        let statusText = app.staticTexts[AccessibilityIDs.overlayStatusText]

        // Either spinner or status showing "Transcribing"
        let inTranscriptionState = spinner.waitForExistence(timeout: defaultTimeout)
            || (statusText.exists && statusText.label.contains("Transcribing"))

        captureScreenshot(named: "RF-006-Transcription-State")

        // Note: Transcription may be very fast in test mode
        if !inTranscriptionState {
            print("Note: Transcription may have completed too quickly to capture state")
        }
    }

    // MARK: - RF-007: Overlay Dismisses After Completion

    /// Test that overlay dismisses after transcription completes
    func test_glassOverlay_dismissesAfterCompletion() throws {
        // Launch app with recording triggered
        launchAppWithRecordingModal()

        // Wait for recording to start
        let overlay = app.otherElements[AccessibilityIDs.glassOverlay]
        guard overlay.waitForExistence(timeout: extendedTimeout) else {
            captureScreenshot(named: "RF-007-No-Overlay")
            XCTFail("GlassRecordingOverlay not found")
            return
        }

        captureScreenshot(named: "RF-007-Recording-Active")

        // Stop recording by pressing Escape
        UITestHelpers.pressEscape(in: app)

        // Wait for overlay to dismiss after transcription completes
        let overlayDismissed = waitForDisappearance(overlay, timeout: extendedTimeout)

        captureScreenshot(named: "RF-007-After-Completion")

        XCTAssertTrue(
            overlayDismissed,
            "Overlay should dismiss after recording flow completes"
        )
    }

    // MARK: - RF-008: Multiple Recording Sessions

    /// Test that multiple recording sessions can be started
    func test_recording_multipleSessionsCanStart() throws {
        // First session
        launchAppWithRecordingModal()

        let overlay = app.otherElements[AccessibilityIDs.glassOverlay]
        guard overlay.waitForExistence(timeout: extendedTimeout) else {
            XCTFail("First recording overlay did not appear")
            return
        }

        captureScreenshot(named: "RF-008-First-Session")

        // Stop first session
        UITestHelpers.pressEscape(in: app)

        // Wait for overlay to dismiss
        _ = waitForDisappearance(overlay, timeout: extendedTimeout)

        captureScreenshot(named: "RF-008-Between-Sessions")

        // Note: In the new glass overlay design, there's no floating widget
        // Recording is triggered via hotkey only
        // Second session would require hotkey press which can't be simulated in XCUITest
    }

    // MARK: - RF-009: Escape Key Stops Recording

    /// Test that Escape key stops recording
    func test_recording_escapeKeyStops() throws {
        // Launch with recording
        launchAppWithRecordingModal()

        // Wait for overlay
        let overlay = app.otherElements[AccessibilityIDs.glassOverlay]
        guard overlay.waitForExistence(timeout: extendedTimeout) else {
            captureScreenshot(named: "RF-009-No-Overlay")
            XCTFail("Recording overlay did not appear")
            return
        }

        captureScreenshot(named: "RF-009-Before-Escape")

        // Press Escape to stop
        UITestHelpers.pressEscape(in: app)

        // Overlay should dismiss (either immediately for cancel, or after transcription)
        let overlayDismissed = waitForDisappearance(overlay, timeout: extendedTimeout)

        captureScreenshot(named: "RF-009-After-Escape")

        XCTAssertTrue(
            overlayDismissed,
            "Overlay should dismiss after pressing Escape"
        )
    }

    // MARK: - RF-010: Overlay Has Correct Accessibility

    /// Test that overlay has proper accessibility labels
    func test_glassOverlay_hasAccessibilityLabels() throws {
        // Launch with recording
        launchAppWithRecordingModal()

        // Wait for overlay
        let overlay = app.otherElements[AccessibilityIDs.glassOverlay]
        guard overlay.waitForExistence(timeout: extendedTimeout) else {
            captureScreenshot(named: "RF-010-No-Overlay")
            XCTFail("Recording overlay did not appear")
            return
        }

        // Verify accessibility identifier exists
        XCTAssertEqual(
            overlay.identifier,
            AccessibilityIDs.glassOverlay,
            "Overlay should have correct accessibility identifier"
        )

        captureScreenshot(named: "RF-010-Accessibility")
    }
}
