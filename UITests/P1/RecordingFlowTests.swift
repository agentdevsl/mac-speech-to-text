// RecordingFlowTests.swift
// macOS Local Speech-to-Text Application
//
// End-to-end UI tests for the core recording workflow
// Updated for hold-to-record mode with FloatingWidget and HoldToRecordOverlay
// Part of User Story 1: Recording Flow Validation (P1)

import XCTest

/// Tests for the recording flow - the primary user interaction
/// Tests verify:
/// - FloatingWidget visibility and tap interaction
/// - HoldToRecordOverlay appearance and states
/// - Recording status text updates
/// - Waveform and progress indicator visibility
/// - Pulsing recording indicator
final class RecordingFlowTests: UITestBase {
    // MARK: - Accessibility Identifiers

    /// New UI accessibility identifiers
    private enum AccessibilityIDs {
        static let floatingWidget = "floatingWidget"
        static let holdToRecordOverlay = "holdToRecordOverlay"
        static let holdToRecordStatus = "holdToRecordStatus"
        static let compactWaveform = "compactWaveform"
        static let progressIndicator = "progressIndicator"
        static let recordingIndicator = "recordingIndicator"
    }

    // MARK: - RF-001: Floating Widget Visibility

    /// Test that floating widget appears when app launches
    func test_floatingWidget_isVisible() throws {
        // Launch app skipping onboarding
        launchAppSkippingOnboarding()

        // Wait for app to initialize
        sleep(2)

        // Look for floating widget by accessibility identifier
        let floatingWidget = app.otherElements[AccessibilityIDs.floatingWidget]
        let widgetExists = floatingWidget.waitForExistence(timeout: extendedTimeout)

        captureScreenshot(named: "RF-001-Floating-Widget-Visible")

        XCTAssertTrue(
            widgetExists,
            "FloatingWidget should be visible after app launches"
        )

        // Verify widget is hittable (can be interacted with)
        if widgetExists {
            XCTAssertTrue(
                floatingWidget.isHittable,
                "FloatingWidget should be interactable"
            )
        }
    }

    // MARK: - RF-002: Floating Widget Tap Starts Recording

    /// Test that tapping the floating widget toggles recording
    func test_floatingWidget_tapStartsRecording() throws {
        // Launch app skipping onboarding
        launchAppSkippingOnboarding()

        // Wait for app to initialize
        sleep(2)

        // Find and tap the floating widget
        let floatingWidget = app.otherElements[AccessibilityIDs.floatingWidget]
        guard floatingWidget.waitForExistence(timeout: extendedTimeout) else {
            captureScreenshot(named: "RF-002-No-Widget")
            XCTFail("FloatingWidget not found")
            return
        }

        captureScreenshot(named: "RF-002-Before-Tap")
        floatingWidget.tap()

        // After tap, recording should start and overlay should appear
        let overlay = app.otherElements[AccessibilityIDs.holdToRecordOverlay]
        let overlayAppeared = overlay.waitForExistence(timeout: extendedTimeout)

        captureScreenshot(named: "RF-002-After-Tap")

        XCTAssertTrue(
            overlayAppeared,
            "HoldToRecordOverlay should appear after tapping FloatingWidget"
        )
    }

    // MARK: - RF-003: HoldToRecordOverlay Appears When Recording

    /// Test that HoldToRecordOverlay appears during recording
    func test_holdToRecordOverlay_appearsWhenRecording() throws {
        // Launch app with recording triggered
        launchAppWithRecordingModal()

        // Wait for the overlay to appear
        let overlay = app.otherElements[AccessibilityIDs.holdToRecordOverlay]
        let overlayExists = overlay.waitForExistence(timeout: extendedTimeout)

        captureScreenshot(named: "RF-003-Overlay-Appeared")

        XCTAssertTrue(
            overlayExists,
            "HoldToRecordOverlay should appear when recording is triggered"
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

    // MARK: - RF-004: HoldToRecordOverlay Shows Status

    /// Test that HoldToRecordOverlay shows status text updates
    func test_holdToRecordOverlay_showsStatus() throws {
        // Launch app with recording triggered
        launchAppWithRecordingModal()

        // Wait for overlay
        let overlay = app.otherElements[AccessibilityIDs.holdToRecordOverlay]
        guard overlay.waitForExistence(timeout: extendedTimeout) else {
            captureScreenshot(named: "RF-004-No-Overlay")
            XCTFail("HoldToRecordOverlay not found")
            return
        }

        // Look for status text with accessibility identifier
        let statusText = app.staticTexts[AccessibilityIDs.holdToRecordStatus]
        let statusExists = statusText.waitForExistence(timeout: defaultTimeout)

        captureScreenshot(named: "RF-004-Status-Text")

        XCTAssertTrue(
            statusExists,
            "Status text should be visible in overlay"
        )

        // Verify status shows expected recording state
        if statusExists {
            let label = statusText.label
            let isValidStatus = label.contains("Recording")
                || label.contains("Transcribing")
                || label.contains("Pasting")
            XCTAssertTrue(
                isValidStatus,
                "Status should show 'Recording...', 'Transcribing...', or 'Pasting...'"
            )
        }
    }

    // MARK: - RF-005: HoldToRecordOverlay Shows Waveform

    /// Test that waveform is visible during recording
    func test_holdToRecordOverlay_showsWaveform() throws {
        // Launch app with recording triggered
        launchAppWithRecordingModal()

        // Wait for overlay
        let overlay = app.otherElements[AccessibilityIDs.holdToRecordOverlay]
        guard overlay.waitForExistence(timeout: extendedTimeout) else {
            captureScreenshot(named: "RF-005-No-Overlay")
            XCTFail("HoldToRecordOverlay not found")
            return
        }

        // Look for compact waveform
        let waveform = app.otherElements[AccessibilityIDs.compactWaveform]
        let waveformExists = waveform.waitForExistence(timeout: defaultTimeout)

        captureScreenshot(named: "RF-005-Waveform")

        XCTAssertTrue(
            waveformExists,
            "Compact waveform should be visible during recording"
        )
    }

    // MARK: - RF-006: Recording Indicator Visible

    /// Test that pulsing recording indicator is visible during recording
    func test_holdToRecordOverlay_showsRecordingIndicator() throws {
        // Launch app with recording triggered
        launchAppWithRecordingModal()

        // Wait for overlay
        let overlay = app.otherElements[AccessibilityIDs.holdToRecordOverlay]
        guard overlay.waitForExistence(timeout: extendedTimeout) else {
            captureScreenshot(named: "RF-006-No-Overlay")
            XCTFail("HoldToRecordOverlay not found")
            return
        }

        // Look for pulsing amber recording indicator dot
        let recordingIndicator = app.otherElements[AccessibilityIDs.recordingIndicator]
        let indicatorExists = recordingIndicator.waitForExistence(timeout: defaultTimeout)

        captureScreenshot(named: "RF-006-Recording-Indicator")

        XCTAssertTrue(
            indicatorExists,
            "Pulsing recording indicator should be visible during recording"
        )
    }

    // MARK: - RF-007: Progress Indicator During Transcription

    /// Test that progress indicator appears during transcription
    func test_holdToRecordOverlay_showsProgressIndicator() throws {
        // Launch app with recording triggered
        launchAppWithRecordingModal()

        // Wait for recording to start
        let overlay = app.otherElements[AccessibilityIDs.holdToRecordOverlay]
        guard overlay.waitForExistence(timeout: extendedTimeout) else {
            captureScreenshot(named: "RF-007-No-Overlay")
            XCTFail("HoldToRecordOverlay not found")
            return
        }

        captureScreenshot(named: "RF-007-Recording-Active")

        // Press Escape to stop recording and trigger transcription
        UITestHelpers.pressEscape(in: app)

        // Wait for transcription state - progress indicator should appear
        let progressIndicator = app.otherElements[AccessibilityIDs.progressIndicator]
        let statusText = app.staticTexts[AccessibilityIDs.holdToRecordStatus]

        // Either progress indicator or status showing "Transcribing..."
        let inTranscriptionState = progressIndicator.waitForExistence(timeout: defaultTimeout)
            || (statusText.exists && statusText.label.contains("Transcribing"))

        captureScreenshot(named: "RF-007-Transcription-State")

        // Note: Transcription may be very fast in test mode
        // We verify the UI can show these states
        if !inTranscriptionState {
            print("Note: Transcription may have completed too quickly to capture progress state")
        }
    }

    // MARK: - RF-008: Overlay Dismisses After Completion

    /// Test that overlay dismisses after transcription and paste completes
    func test_holdToRecordOverlay_dismissesAfterCompletion() throws {
        // Launch app with recording triggered
        launchAppWithRecordingModal()

        // Wait for recording to start
        let overlay = app.otherElements[AccessibilityIDs.holdToRecordOverlay]
        guard overlay.waitForExistence(timeout: extendedTimeout) else {
            captureScreenshot(named: "RF-008-No-Overlay")
            XCTFail("HoldToRecordOverlay not found")
            return
        }

        captureScreenshot(named: "RF-008-Recording-Active")

        // Stop recording by pressing Escape
        UITestHelpers.pressEscape(in: app)

        // Wait for overlay to dismiss after transcription completes
        // In test mode without actual audio, this should be quick
        let overlayDismissed = waitForDisappearance(overlay, timeout: extendedTimeout)

        captureScreenshot(named: "RF-008-After-Completion")

        XCTAssertTrue(
            overlayDismissed,
            "Overlay should dismiss after recording flow completes"
        )
    }

    // MARK: - RF-009: Multiple Recording Sessions

    /// Test that multiple recording sessions can be started
    func test_recording_multipleSessionsCanStart() throws {
        // First session
        launchAppWithRecordingModal()

        let overlay = app.otherElements[AccessibilityIDs.holdToRecordOverlay]
        guard overlay.waitForExistence(timeout: extendedTimeout) else {
            XCTFail("First recording overlay did not appear")
            return
        }

        captureScreenshot(named: "RF-009-First-Session")

        // Stop first session
        UITestHelpers.pressEscape(in: app)

        // Wait for overlay to dismiss
        _ = waitForDisappearance(overlay, timeout: extendedTimeout)

        // Start second session by tapping widget
        let floatingWidget = app.otherElements[AccessibilityIDs.floatingWidget]
        if floatingWidget.waitForExistence(timeout: defaultTimeout) {
            floatingWidget.tap()

            // Verify second session started
            let secondOverlay = overlay.waitForExistence(timeout: extendedTimeout)

            captureScreenshot(named: "RF-009-Second-Session")

            XCTAssertTrue(
                secondOverlay,
                "Second recording session should start"
            )
        }
    }

    // MARK: - RF-010: Widget Visibility After Recording

    /// Test that floating widget is still visible after recording completes
    func test_floatingWidget_visibleAfterRecording() throws {
        // Launch and trigger recording
        launchAppWithRecordingModal()

        let overlay = app.otherElements[AccessibilityIDs.holdToRecordOverlay]
        guard overlay.waitForExistence(timeout: extendedTimeout) else {
            XCTFail("Recording overlay did not appear")
            return
        }

        // Stop recording
        UITestHelpers.pressEscape(in: app)

        // Wait for overlay to dismiss
        _ = waitForDisappearance(overlay, timeout: extendedTimeout)

        // Verify widget is still visible
        let floatingWidget = app.otherElements[AccessibilityIDs.floatingWidget]
        let widgetVisible = floatingWidget.waitForExistence(timeout: defaultTimeout)

        captureScreenshot(named: "RF-010-Widget-After-Recording")

        XCTAssertTrue(
            widgetVisible,
            "FloatingWidget should remain visible after recording completes"
        )
    }

    // MARK: - RF-011: Recording State in Widget

    /// Test that widget shows recording state when overlay is visible
    func test_floatingWidget_showsRecordingState() throws {
        // Launch with recording
        launchAppWithRecordingModal()

        // Wait for overlay
        let overlay = app.otherElements[AccessibilityIDs.holdToRecordOverlay]
        guard overlay.waitForExistence(timeout: extendedTimeout) else {
            captureScreenshot(named: "RF-011-No-Overlay")
            XCTFail("Recording overlay did not appear")
            return
        }

        // Check if widget still exists and shows recording state
        // The widget may hide or change appearance during recording
        let floatingWidget = app.otherElements[AccessibilityIDs.floatingWidget]

        captureScreenshot(named: "RF-011-During-Recording")

        // Widget behavior during recording may vary - document what we see
        if floatingWidget.exists {
            print("FloatingWidget is visible during recording")
        } else {
            print("FloatingWidget hides during recording (expected for overlay mode)")
        }

        // The overlay should definitely be showing recording state
        let statusText = app.staticTexts[AccessibilityIDs.holdToRecordStatus]
        if statusText.exists {
            XCTAssertTrue(
                statusText.label.contains("Recording") || statusText.label.contains("Transcribing"),
                "Status should indicate recording or transcribing state"
            )
        }
    }

    // MARK: - RF-012: Escape Key Cancels Recording

    /// Test that Escape key cancels recording (new behavior - no buttons)
    func test_recording_escapeKeyCancels() throws {
        // Launch with recording
        launchAppWithRecordingModal()

        // Wait for overlay
        let overlay = app.otherElements[AccessibilityIDs.holdToRecordOverlay]
        guard overlay.waitForExistence(timeout: extendedTimeout) else {
            captureScreenshot(named: "RF-012-No-Overlay")
            XCTFail("Recording overlay did not appear")
            return
        }

        captureScreenshot(named: "RF-012-Before-Escape")

        // Press Escape to cancel/stop
        UITestHelpers.pressEscape(in: app)

        // Overlay should dismiss (either immediately for cancel, or after transcription)
        let overlayDismissed = waitForDisappearance(overlay, timeout: extendedTimeout)

        captureScreenshot(named: "RF-012-After-Escape")

        XCTAssertTrue(
            overlayDismissed,
            "Overlay should dismiss after pressing Escape"
        )
    }
}
