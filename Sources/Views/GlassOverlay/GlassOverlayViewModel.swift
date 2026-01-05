// GlassOverlayViewModel.swift
// macOS Local Speech-to-Text Application
//
// Glass Recording Overlay - State Management
// Manages overlay visibility, recording state, and audio visualization

import Foundation
import Observation
import OSLog

// MARK: - Overlay State

/// State of the glass recording overlay
enum OverlayState: Equatable, Sendable {
    case hidden
    case recording
    case transcribing
}

// MARK: - GlassOverlayViewModel

/// ViewModel for the Glass Recording Overlay - manages visibility and recording state
@Observable
@MainActor
final class GlassOverlayViewModel {
    // MARK: - Published State

    /// Current overlay state
    var state: OverlayState = .hidden

    /// Real-time audio level (0.0 - 1.0) for waveform visualization
    var audioLevel: Float = 0.0

    /// Current recording duration in seconds
    var recordingDuration: TimeInterval = 0.0

    /// Current waveform style from user settings
    var waveformStyle: WaveformStyleOption = .aurora

    /// Whether the overlay is currently visible (state != .hidden)
    var isVisible: Bool {
        state != .hidden
    }

    /// Formatted duration string (e.g., "0:00", "1:23")
    var formattedDuration: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Private State

    @ObservationIgnored private var durationTimer: Timer?
    @ObservationIgnored private let viewModelId: String
    // nonisolated copy for deinit access
    @ObservationIgnored private nonisolated(unsafe) var deinitDurationTimer: Timer?

    // MARK: - Initialization

    init() {
        self.viewModelId = UUID().uuidString.prefix(8).description
        AppLogger.lifecycle(AppLogger.viewModel, self, event: "init[\(viewModelId)]")
    }

    deinit {
        AppLogger.trace(AppLogger.viewModel, "GlassOverlayViewModel[\(viewModelId)] deallocating")
        deinitDurationTimer?.invalidate()
    }

    // MARK: - Public Methods

    /// Force reset to hidden state (use at start of new session to clear any stuck state)
    func forceReset() {
        AppLogger.info(AppLogger.viewModel, "[\(viewModelId)] forceReset() called, current state=\(state)")
        stopDurationTimer()
        state = .hidden
        audioLevel = 0.0
        recordingDuration = 0.0
    }

    /// Transition to recording state with fade-in animation
    func showRecording() {
        AppLogger.info(AppLogger.viewModel, "[\(viewModelId)] showRecording() called, current state=\(state)")

        // If not hidden, force reset first (handles stuck state from previous session)
        if state != .hidden {
            AppLogger.warning(AppLogger.viewModel, "[\(viewModelId)] showRecording: forcing reset from state \(state)")
            forceReset()
        }

        // Reset state for new recording
        audioLevel = 0.0
        recordingDuration = 0.0

        // Transition to recording state
        AppLogger.stateChange(AppLogger.viewModel, from: state, to: OverlayState.recording, context: "state")
        state = .recording

        // Start duration timer
        startDurationTimer()
    }

    /// Transition to transcribing state
    /// - Returns: `true` if transition succeeded, `false` if state was invalid
    @discardableResult
    func showTranscribing() -> Bool {
        AppLogger.info(
            AppLogger.viewModel,
            "[\(viewModelId)] showTranscribing() called, currentState=\(state), duration=\(formattedDuration)"
        )

        guard state == .recording else {
            AppLogger.warning(
                AppLogger.viewModel,
                """
                [\(viewModelId)] showTranscribing: FAILED - cannot transition from \(state) \
                (expected .recording). audioLevel=\(audioLevel), duration=\(recordingDuration)s
                """
            )
            return false
        }

        // Stop duration timer (keep showing last duration)
        stopDurationTimer()

        // Transition to transcribing state
        AppLogger.stateChange(AppLogger.viewModel, from: state, to: OverlayState.transcribing, context: "state")
        state = .transcribing

        AppLogger.debug(
            AppLogger.viewModel,
            "[\(viewModelId)] showTranscribing: SUCCESS - transitioned to transcribing after \(formattedDuration)"
        )
        return true
    }

    /// Hide the overlay with fade-out animation
    func hide() {
        AppLogger.info(AppLogger.viewModel, "[\(viewModelId)] hide() called")

        guard state != .hidden else {
            AppLogger.warning(AppLogger.viewModel, "[\(viewModelId)] hide: already hidden")
            return
        }

        // Stop duration timer
        stopDurationTimer()

        // Transition to hidden state
        AppLogger.stateChange(AppLogger.viewModel, from: state, to: OverlayState.hidden, context: "state")
        state = .hidden

        // Reset state
        audioLevel = 0.0
        recordingDuration = 0.0
    }

    /// Update audio level for waveform visualization
    /// - Parameter level: Audio level normalized to 0.0-1.0 range
    func updateAudioLevel(_ level: Float) {
        // Clamp value to valid range
        audioLevel = max(0.0, min(1.0, level))
    }

    // MARK: - Private Methods

    /// Start the recording duration timer
    private func startDurationTimer() {
        stopDurationTimer()

        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                // Guard against orphaned timer callbacks - only update if still recording
                guard let self, self.state == .recording else {
                    AppLogger.trace(
                        AppLogger.viewModel,
                        "Duration timer callback skipped - self deallocated or state != .recording"
                    )
                    return
                }
                self.recordingDuration += 1.0
            }
        }
        durationTimer = timer
        deinitDurationTimer = timer
        AppLogger.debug(AppLogger.viewModel, "[\(viewModelId)] Duration timer started")
    }

    /// Stop the recording duration timer
    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
        deinitDurationTimer = nil
        AppLogger.debug(AppLogger.viewModel, "[\(viewModelId)] Duration timer stopped")
    }
}
