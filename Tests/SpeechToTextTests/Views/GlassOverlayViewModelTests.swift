// GlassOverlayViewModelTests.swift
// macOS Local Speech-to-Text Application
//
// Unit tests for GlassOverlayViewModel

import XCTest
@testable import SpeechToText

@MainActor
final class GlassOverlayViewModelTests: XCTestCase {
    // MARK: - Properties

    var sut: GlassOverlayViewModel!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        sut = GlassOverlayViewModel()
    }

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func test_initialization_stateIsHidden() {
        XCTAssertEqual(sut.state, .hidden)
    }

    func test_initialization_audioLevelIsZero() {
        XCTAssertEqual(sut.audioLevel, 0.0)
    }

    func test_initialization_recordingDurationIsZero() {
        XCTAssertEqual(sut.recordingDuration, 0.0)
    }

    // MARK: - isVisible Tests

    func test_isVisible_returnsFalseWhenHidden() {
        // Given
        sut.state = .hidden

        // Then
        XCTAssertFalse(sut.isVisible)
    }

    func test_isVisible_returnsTrueWhenRecording() {
        // When
        sut.showRecording()

        // Then
        XCTAssertTrue(sut.isVisible)
    }

    func test_isVisible_returnsTrueWhenTranscribing() {
        // Given
        sut.showRecording()

        // When
        sut.showTranscribing()

        // Then
        XCTAssertTrue(sut.isVisible)
    }

    // MARK: - formattedDuration Tests

    func test_formattedDuration_returnsZeroColonZeroZeroWhenZero() {
        // Given
        sut.recordingDuration = 0

        // Then
        XCTAssertEqual(sut.formattedDuration, "0:00")
    }

    func test_formattedDuration_formatsSecondsCorrectly() {
        // Given
        sut.recordingDuration = 5

        // Then
        XCTAssertEqual(sut.formattedDuration, "0:05")
    }

    func test_formattedDuration_formatsMinutesAndSecondsCorrectly() {
        // Given
        sut.recordingDuration = 65

        // Then
        XCTAssertEqual(sut.formattedDuration, "1:05")
    }

    func test_formattedDuration_handles59Seconds() {
        // Given
        sut.recordingDuration = 59

        // Then
        XCTAssertEqual(sut.formattedDuration, "0:59")
    }

    func test_formattedDuration_handles10MinutesPlus() {
        // Given
        sut.recordingDuration = 605

        // Then
        XCTAssertEqual(sut.formattedDuration, "10:05")
    }

    func test_formattedDuration_handles60SecondsExactly() {
        // Given
        sut.recordingDuration = 60

        // Then
        XCTAssertEqual(sut.formattedDuration, "1:00")
    }

    func test_formattedDuration_handlesLargeValues() {
        // Given
        sut.recordingDuration = 3661 // 61 minutes 1 second

        // Then
        XCTAssertEqual(sut.formattedDuration, "61:01")
    }

    // MARK: - showRecording() Tests

    func test_showRecording_transitionsToRecordingState() {
        // When
        sut.showRecording()

        // Then
        XCTAssertEqual(sut.state, .recording)
    }

    func test_showRecording_resetsAudioLevelToZero() {
        // Given
        sut.audioLevel = 0.5

        // When
        sut.showRecording()

        // Then
        XCTAssertEqual(sut.audioLevel, 0.0)
    }

    func test_showRecording_resetsRecordingDurationToZero() {
        // Given
        sut.recordingDuration = 10

        // When
        sut.showRecording()

        // Then
        XCTAssertEqual(sut.recordingDuration, 0.0)
    }

    func test_showRecording_doesNotTransitionWhenAlreadyRecording() {
        // Given
        sut.showRecording()
        sut.recordingDuration = 15.0

        // When
        sut.showRecording() // Call again

        // Then - should stay in recording state and preserve duration
        XCTAssertEqual(sut.state, .recording)
        XCTAssertEqual(sut.recordingDuration, 15.0)
    }

    func test_showRecording_doesNotTransitionWhenTranscribing() {
        // Given
        sut.showRecording()
        sut.showTranscribing()
        let durationBefore = sut.recordingDuration

        // When
        sut.showRecording() // Try to call while transcribing

        // Then - should remain in transcribing state
        XCTAssertEqual(sut.state, .transcribing)
        XCTAssertEqual(sut.recordingDuration, durationBefore)
    }

    // MARK: - showTranscribing() Tests

    func test_showTranscribing_transitionsToTranscribingState() {
        // Given
        sut.showRecording()

        // When
        sut.showTranscribing()

        // Then
        XCTAssertEqual(sut.state, .transcribing)
    }

    func test_showTranscribing_preservesRecordingDuration() {
        // Given
        sut.showRecording()
        sut.recordingDuration = 30

        // When
        sut.showTranscribing()

        // Then
        XCTAssertEqual(sut.recordingDuration, 30)
    }

    func test_showTranscribing_doesNotTransitionFromHidden() {
        // Given - state is hidden (default)
        XCTAssertEqual(sut.state, .hidden)

        // When
        sut.showTranscribing()

        // Then - should remain hidden (guard blocks transition)
        XCTAssertEqual(sut.state, .hidden)
    }

    func test_showTranscribing_doesNotTransitionWhenAlreadyTranscribing() {
        // Given
        sut.showRecording()
        sut.showTranscribing()

        // When
        sut.showTranscribing() // Call again

        // Then - should remain in transcribing state
        XCTAssertEqual(sut.state, .transcribing)
    }

    // MARK: - hide() Tests

    func test_hide_transitionsToHiddenState() {
        // Given
        sut.showRecording()

        // When
        sut.hide()

        // Then
        XCTAssertEqual(sut.state, .hidden)
    }

    func test_hide_resetsAudioLevelToZero() {
        // Given
        sut.showRecording()
        sut.audioLevel = 0.8

        // When
        sut.hide()

        // Then
        XCTAssertEqual(sut.audioLevel, 0.0)
    }

    func test_hide_resetsRecordingDurationToZero() {
        // Given
        sut.showRecording()
        sut.recordingDuration = 45.0

        // When
        sut.hide()

        // Then
        XCTAssertEqual(sut.recordingDuration, 0.0)
    }

    func test_hide_worksFromRecordingState() {
        // Given
        sut.showRecording()
        XCTAssertEqual(sut.state, .recording)

        // When
        sut.hide()

        // Then
        XCTAssertEqual(sut.state, .hidden)
    }

    func test_hide_worksFromTranscribingState() {
        // Given
        sut.showRecording()
        sut.showTranscribing()
        XCTAssertEqual(sut.state, .transcribing)

        // When
        sut.hide()

        // Then
        XCTAssertEqual(sut.state, .hidden)
    }

    func test_hide_doesNothingWhenAlreadyHidden() {
        // Given - already hidden (default state)
        XCTAssertEqual(sut.state, .hidden)
        sut.audioLevel = 0.5
        sut.recordingDuration = 10.0

        // When
        sut.hide()

        // Then - values should not be reset since guard blocks execution
        XCTAssertEqual(sut.state, .hidden)
        XCTAssertEqual(sut.audioLevel, 0.5)
        XCTAssertEqual(sut.recordingDuration, 10.0)
    }

    // MARK: - updateAudioLevel() Tests

    func test_updateAudioLevel_setsValueCorrectly() {
        // When
        sut.updateAudioLevel(0.5)

        // Then
        XCTAssertEqual(sut.audioLevel, 0.5)
    }

    func test_updateAudioLevel_clampsValueAboveOne() {
        // When
        sut.updateAudioLevel(1.5)

        // Then
        XCTAssertEqual(sut.audioLevel, 1.0)
    }

    func test_updateAudioLevel_clampsValueBelowZero() {
        // When
        sut.updateAudioLevel(-0.5)

        // Then
        XCTAssertEqual(sut.audioLevel, 0.0)
    }

    func test_updateAudioLevel_acceptsZero() {
        // Given
        sut.audioLevel = 0.5

        // When
        sut.updateAudioLevel(0.0)

        // Then
        XCTAssertEqual(sut.audioLevel, 0.0)
    }

    func test_updateAudioLevel_acceptsOne() {
        // When
        sut.updateAudioLevel(1.0)

        // Then
        XCTAssertEqual(sut.audioLevel, 1.0)
    }

    func test_updateAudioLevel_acceptsSmallValues() {
        // When
        sut.updateAudioLevel(0.001)

        // Then
        XCTAssertEqual(sut.audioLevel, 0.001, accuracy: 0.0001)
    }

    // MARK: - OverlayState Enum Tests

    func test_overlayState_isEquatable() {
        // Then
        XCTAssertEqual(OverlayState.hidden, OverlayState.hidden)
        XCTAssertEqual(OverlayState.recording, OverlayState.recording)
        XCTAssertEqual(OverlayState.transcribing, OverlayState.transcribing)
        XCTAssertNotEqual(OverlayState.hidden, OverlayState.recording)
        XCTAssertNotEqual(OverlayState.recording, OverlayState.transcribing)
    }

    // MARK: - Full Cycle Tests

    func test_fullRecordingCycle() {
        // Given: Hidden state
        XCTAssertEqual(sut.state, .hidden)
        XCTAssertFalse(sut.isVisible)

        // When: Start recording
        sut.showRecording()
        XCTAssertEqual(sut.state, .recording)
        XCTAssertTrue(sut.isVisible)

        // Simulate audio input
        sut.updateAudioLevel(0.6)
        XCTAssertEqual(sut.audioLevel, 0.6)

        // Simulate duration update
        sut.recordingDuration = 10.0
        XCTAssertEqual(sut.formattedDuration, "0:10")

        // When: Start transcribing
        sut.showTranscribing()
        XCTAssertEqual(sut.state, .transcribing)
        XCTAssertTrue(sut.isVisible)
        XCTAssertEqual(sut.recordingDuration, 10.0) // Preserved

        // When: Hide
        sut.hide()
        XCTAssertEqual(sut.state, .hidden)
        XCTAssertFalse(sut.isVisible)
        XCTAssertEqual(sut.audioLevel, 0.0) // Reset
        XCTAssertEqual(sut.recordingDuration, 0.0) // Reset
    }

    func test_multipleRecordingCycles() {
        // First cycle
        sut.showRecording()
        sut.updateAudioLevel(0.8)
        sut.recordingDuration = 20.0
        sut.showTranscribing()
        sut.hide()

        XCTAssertEqual(sut.state, .hidden)
        XCTAssertEqual(sut.audioLevel, 0.0)
        XCTAssertEqual(sut.recordingDuration, 0.0)

        // Second cycle
        sut.showRecording()
        XCTAssertEqual(sut.state, .recording)
        XCTAssertEqual(sut.audioLevel, 0.0) // Fresh start
        XCTAssertEqual(sut.recordingDuration, 0.0) // Fresh start

        sut.updateAudioLevel(0.5)
        sut.recordingDuration = 30.0
        sut.showTranscribing()
        sut.hide()

        XCTAssertEqual(sut.state, .hidden)
    }

    func test_rapidStateTransitions() {
        // Simulate rapid state changes
        for _ in 1...5 {
            sut.showRecording()
            XCTAssertEqual(sut.state, .recording)

            sut.showTranscribing()
            XCTAssertEqual(sut.state, .transcribing)

            sut.hide()
            XCTAssertEqual(sut.state, .hidden)
        }

        // Final state should be clean
        XCTAssertEqual(sut.state, .hidden)
        XCTAssertEqual(sut.audioLevel, 0.0)
        XCTAssertEqual(sut.recordingDuration, 0.0)
    }
}
