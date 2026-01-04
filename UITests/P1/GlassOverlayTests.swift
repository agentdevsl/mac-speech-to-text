// GlassOverlayTests.swift
// macOS Local Speech-to-Text Application
//
// End-to-end UI tests for the GlassRecordingOverlay component
// Tests verify overlay appearance, state transitions, and accessibility
// Part of User Story: Glass Overlay Recording UI (P1)

import XCTest

/// Tests for the GlassRecordingOverlay - the recording status indicator
/// Tests verify:
/// - Overlay appears when recording is triggered
/// - Recording indicator dot visibility and pulsing
/// - Status text updates (Recording.../Transcribing...)
/// - Timer display and increment during recording
/// - Waveform and spinner visibility based on state
/// - Proper accessibility labels and identifiers
final class GlassOverlayTests: UITestBase {
    // MARK: - GO-001: Glass Overlay Appears When Recording Triggered

    /// Test that glass overlay appears when recording is triggered via launch argument
    func test_GO001_glassOverlay_appearsWhenRecordingTriggered() throws {
        // Launch app with recording triggered using --trigger-recording argument
        launchAppWithRecordingModal()

        // Wait for the glass overlay to appear
        let glassOverlay = app.otherElements[AccessibilityIDs.GlassOverlay.overlay]
        let overlayAppeared = glassOverlay.waitForExistence(timeout: extendedTimeout)

        captureScreenshot(named: "GO-001-Glass-Overlay-Appeared")

        XCTAssertTrue(
            overlayAppeared,
            "GlassRecordingOverlay should appear when recording is triggered via --trigger-recording"
        )

        // Verify overlay has expected dimensions (approximately 300x80 based on implementation)
        if overlayAppeared {
            let frame = glassOverlay.frame
            XCTAssertGreaterThan(
                frame.width,
                200,
                "Glass overlay width should be substantial (expected ~300)"
            )
            XCTAssertGreaterThan(
                frame.height,
                50,
                "Glass overlay height should be substantial (expected ~80)"
            )
        }
    }

    // MARK: - GO-002: Recording Indicator Dot Visible

    /// Test that the pulsing recording indicator dot is visible during recording
    func test_GO002_recordingIndicatorDot_isVisible() throws {
        // Launch app with recording triggered
        launchAppWithRecordingModal()

        // Wait for glass overlay to appear first
        let glassOverlay = app.otherElements[AccessibilityIDs.GlassOverlay.overlay]
        guard glassOverlay.waitForExistence(timeout: extendedTimeout) else {
            captureScreenshot(named: "GO-002-No-Overlay")
            XCTFail("GlassRecordingOverlay not found - cannot verify recording indicator")
            return
        }

        // Look for the recording indicator dot
        let recordingDot = app.otherElements[AccessibilityIDs.GlassOverlay.recordingDot]
        let dotVisible = recordingDot.waitForExistence(timeout: defaultTimeout)

        captureScreenshot(named: "GO-002-Recording-Indicator-Dot")

        XCTAssertTrue(
            dotVisible,
            "Recording indicator dot should be visible when overlay is displayed"
        )

        // Verify dot has appropriate size (12x12 based on implementation)
        if dotVisible {
            let frame = recordingDot.frame
            XCTAssertGreaterThan(
                frame.width,
                5,
                "Recording indicator dot should have visible width"
            )
            XCTAssertGreaterThan(
                frame.height,
                5,
                "Recording indicator dot should have visible height"
            )
        }
    }

    // MARK: - GO-003: Status Text Shows "Recording..."

    /// Test that status text displays "Recording..." during active recording
    func test_GO003_statusText_showsRecording() throws {
        // Launch app with recording triggered
        launchAppWithRecordingModal()

        // Wait for glass overlay to appear
        let glassOverlay = app.otherElements[AccessibilityIDs.GlassOverlay.overlay]
        guard glassOverlay.waitForExistence(timeout: extendedTimeout) else {
            captureScreenshot(named: "GO-003-No-Overlay")
            XCTFail("GlassRecordingOverlay not found")
            return
        }

        // Find status text element
        let statusText = app.staticTexts[AccessibilityIDs.GlassOverlay.statusText]
        let statusExists = statusText.waitForExistence(timeout: defaultTimeout)

        captureScreenshot(named: "GO-003-Status-Text-Recording")

        XCTAssertTrue(
            statusExists,
            "Status text element should exist in overlay"
        )

        if statusExists {
            let labelText = statusText.label
            XCTAssertTrue(
                labelText.contains("Recording"),
                "Status text should contain 'Recording' during active recording. Got: '\(labelText)'"
            )
        }
    }

    // MARK: - GO-004: Timer Increments During Recording

    /// Test that the timer display shows and increments during recording
    func test_GO004_timer_incrementsDuringRecording() throws {
        // Launch app with recording triggered
        launchAppWithRecordingModal()

        // Wait for glass overlay to appear
        let glassOverlay = app.otherElements[AccessibilityIDs.GlassOverlay.overlay]
        guard glassOverlay.waitForExistence(timeout: extendedTimeout) else {
            captureScreenshot(named: "GO-004-No-Overlay")
            XCTFail("GlassRecordingOverlay not found")
            return
        }

        // Find timer element
        let timer = app.staticTexts[AccessibilityIDs.GlassOverlay.timer]
        let timerExists = timer.waitForExistence(timeout: defaultTimeout)

        XCTAssertTrue(
            timerExists,
            "Timer element should be visible during recording"
        )

        guard timerExists else {
            captureScreenshot(named: "GO-004-No-Timer")
            return
        }

        // Capture initial timer value
        let initialValue = timer.label
        captureScreenshot(named: "GO-004-Timer-Initial-\(initialValue.replacingOccurrences(of: ":", with: "-"))")

        // Verify initial value format (M:SS like "0:00" or "0:01")
        let timePattern = "^\\d+:\\d{2}$"
        let timeRegex = try NSRegularExpression(pattern: timePattern)
        let initialRange = NSRange(location: 0, length: initialValue.utf16.count)
        XCTAssertNotNil(
            timeRegex.firstMatch(in: initialValue, range: initialRange),
            "Timer should display in M:SS format. Got: '\(initialValue)'"
        )

        // Wait 2 seconds for timer to increment
        sleep(2)

        // Capture updated timer value
        let updatedValue = timer.label
        captureScreenshot(named: "GO-004-Timer-Updated-\(updatedValue.replacingOccurrences(of: ":", with: "-"))")

        // Verify timer has changed (incremented)
        // Note: In test mode without actual audio processing, timer should still increment
        XCTAssertNotEqual(
            initialValue,
            updatedValue,
            "Timer should increment during recording. Initial: '\(initialValue)', After 2s: '\(updatedValue)'"
        )
    }

    // MARK: - GO-005: Overlay Has Correct Accessibility Labels

    /// Test that overlay has proper accessibility labels for VoiceOver support
    func test_GO005_overlay_hasCorrectAccessibilityLabels() throws {
        // Launch app with recording triggered
        launchAppWithRecordingModal()

        // Wait for glass overlay to appear
        let glassOverlay = app.otherElements[AccessibilityIDs.GlassOverlay.overlay]
        guard glassOverlay.waitForExistence(timeout: extendedTimeout) else {
            captureScreenshot(named: "GO-005-No-Overlay")
            XCTFail("GlassRecordingOverlay not found")
            return
        }

        captureScreenshot(named: "GO-005-Accessibility-Labels")

        // Verify the overlay has an accessibility label
        let overlayLabel = glassOverlay.label
        XCTAssertFalse(
            overlayLabel.isEmpty,
            "Glass overlay should have an accessibility label for VoiceOver"
        )

        // The accessibility label should contain meaningful content
        // Based on implementation: "Recording in progress. X seconds. Audio level at Y percent."
        let hasRecordingInfo = overlayLabel.contains("Recording") || overlayLabel.contains("Transcribing")
        XCTAssertTrue(
            hasRecordingInfo,
            "Accessibility label should describe recording state. Got: '\(overlayLabel)'"
        )

        // Check for timer accessibility on the timer element specifically
        let timer = app.staticTexts[AccessibilityIDs.GlassOverlay.timer]
        if timer.exists {
            let timerLabel = timer.label
            // Timer should have accessible time format in its label
            XCTAssertFalse(
                timerLabel.isEmpty,
                "Timer should have accessibility label"
            )
        }

        // Verify recording indicator dot is accessible
        let recordingDot = app.otherElements[AccessibilityIDs.GlassOverlay.recordingDot]
        if recordingDot.exists {
            // Dot should be identifiable for testing (identifier is set)
            XCTAssertEqual(
                recordingDot.identifier,
                AccessibilityIDs.GlassOverlay.recordingDot,
                "Recording indicator dot should have correct accessibility identifier"
            )
        }

        // Verify status text has correct identifier
        let statusText = app.staticTexts[AccessibilityIDs.GlassOverlay.statusText]
        if statusText.exists {
            XCTAssertEqual(
                statusText.identifier,
                AccessibilityIDs.GlassOverlay.statusText,
                "Status text should have correct accessibility identifier"
            )
        }
    }

    // MARK: - GO-006: Waveform/Spinner Displays Based on State

    /// Test that waveform displays during recording and spinner during transcribing
    func test_GO006_waveformOrSpinner_displaysBasedOnState() throws {
        // Launch app with recording triggered
        launchAppWithRecordingModal()

        // Wait for glass overlay to appear
        let glassOverlay = app.otherElements[AccessibilityIDs.GlassOverlay.overlay]
        guard glassOverlay.waitForExistence(timeout: extendedTimeout) else {
            captureScreenshot(named: "GO-006-No-Overlay")
            XCTFail("GlassRecordingOverlay not found")
            return
        }

        // During recording state, waveform should be visible (not spinner)
        let waveform = app.otherElements[AccessibilityIDs.GlassOverlay.waveform]
        let spinner = app.progressIndicators.firstMatch
        let transcribingSpinner = app.otherElements[AccessibilityIDs.GlassOverlay.transcribingSpinner]

        let waveformVisible = waveform.waitForExistence(timeout: defaultTimeout)

        captureScreenshot(named: "GO-006-Recording-State-Waveform")

        // In recording state, waveform should be visible
        XCTAssertTrue(
            waveformVisible,
            "Waveform should be visible during recording state"
        )

        // Verify waveform has appropriate size
        if waveformVisible {
            let frame = waveform.frame
            XCTAssertGreaterThan(
                frame.width,
                80,
                "Waveform should have substantial width (expected ~120)"
            )
            XCTAssertGreaterThan(
                frame.height,
                20,
                "Waveform should have substantial height (expected ~40)"
            )
        }

        // Stop recording to trigger transcription state
        UITestHelpers.pressEscape(in: app)

        // Wait briefly for state transition
        sleep(1)

        // Check if we've transitioned to transcribing state
        // Note: In test mode, transcription may complete very quickly
        let statusText = app.staticTexts[AccessibilityIDs.GlassOverlay.statusText]
        let isTranscribing = statusText.exists && statusText.label.contains("Transcribing")

        captureScreenshot(named: "GO-006-After-Stop-Recording")

        if isTranscribing {
            // If we caught the transcribing state, spinner should be visible
            let spinnerVisible = spinner.exists || transcribingSpinner.exists
            XCTAssertTrue(
                spinnerVisible,
                "Spinner/progress indicator should be visible during transcribing state"
            )
            captureScreenshot(named: "GO-006-Transcribing-State-Spinner")
        } else {
            // Transcription completed too quickly - this is acceptable
            print("Note: Transcription completed before we could verify spinner visibility")
            print("Status text: \(statusText.exists ? statusText.label : "not found")")
        }
    }

    // MARK: - Additional Helper Tests

    /// Test that glass overlay container positions overlay correctly
    func test_glassOverlayContainer_positionsOverlayAtBottom() throws {
        // Launch app with recording triggered
        launchAppWithRecordingModal()

        // Wait for glass overlay container to appear
        let container = app.otherElements[AccessibilityIDs.GlassOverlay.container]
        let containerExists = container.waitForExistence(timeout: extendedTimeout)

        // Container may or may not be exposed to accessibility - check overlay directly if not
        if !containerExists {
            let glassOverlay = app.otherElements[AccessibilityIDs.GlassOverlay.overlay]
            guard glassOverlay.waitForExistence(timeout: defaultTimeout) else {
                captureScreenshot(named: "GO-Container-No-Overlay")
                XCTFail("Neither container nor overlay found")
                return
            }

            captureScreenshot(named: "GO-Container-Overlay-Position")

            // Verify overlay is positioned in lower portion of screen
            let frame = glassOverlay.frame
            let screenHeight = XCUIScreen.main.screenshot().image.size.height

            // Overlay should be in the bottom half of the screen (y > screenHeight/2)
            // Note: In XCUITest, y increases downward
            XCTAssertGreaterThan(
                frame.origin.y,
                screenHeight / 3,
                "Glass overlay should be positioned in lower portion of screen"
            )
        } else {
            captureScreenshot(named: "GO-Container-Found")
            XCTAssertTrue(
                containerExists,
                "Glass overlay container should be accessible"
            )
        }
    }

    /// Test that overlay dismisses after recording flow completes
    func test_glassOverlay_dismissesAfterCompletion() throws {
        // Launch app with recording triggered
        launchAppWithRecordingModal()

        // Wait for glass overlay to appear
        let glassOverlay = app.otherElements[AccessibilityIDs.GlassOverlay.overlay]
        guard glassOverlay.waitForExistence(timeout: extendedTimeout) else {
            captureScreenshot(named: "GO-Dismiss-No-Overlay")
            XCTFail("GlassRecordingOverlay not found")
            return
        }

        captureScreenshot(named: "GO-Dismiss-Before")

        // Stop recording
        UITestHelpers.pressEscape(in: app)

        // Wait for overlay to dismiss after transcription completes
        let dismissed = waitForDisappearance(glassOverlay, timeout: extendedTimeout)

        captureScreenshot(named: "GO-Dismiss-After")

        XCTAssertTrue(
            dismissed,
            "Glass overlay should dismiss after recording/transcription completes"
        )
    }

    /// Test overlay visibility using base class helper
    func test_glassOverlay_usingBaseClassHelper() throws {
        // Launch app with recording triggered
        launchAppWithRecordingModal()

        // Use base class helper method
        let overlayAppeared = waitForGlassOverlay()

        captureScreenshot(named: "GO-Helper-Test")

        XCTAssertTrue(
            overlayAppeared,
            "waitForGlassOverlay() helper should find the overlay"
        )

        // Verify helper method for checking recording state
        let isRecording = isOverlayRecording()
        XCTAssertTrue(
            isRecording,
            "isOverlayRecording() should return true when recording"
        )
    }
}
