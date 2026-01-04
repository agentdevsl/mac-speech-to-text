// FloatingWidgetViewModel.swift
// macOS Local Speech-to-Text Application
//
// Phase 2.1: FloatingWidget State Management
// Manages recording state, audio levels, and recording lifecycle

import Foundation
import Observation
import OSLog

/// ViewModel for the FloatingWidget - manages recording state and audio levels
@Observable
@MainActor
final class FloatingWidgetViewModel {
    // MARK: - Published State

    /// Whether recording is currently active
    var isRecording: Bool = false

    /// Real-time audio level (0.0 - 1.0)
    var audioLevel: Float = 0.0

    /// Whether transcription is in progress
    var isTranscribing: Bool = false

    /// Current error message (if any)
    var errorMessage: String?

    /// Last transcribed text
    var transcribedText: String = ""

    // MARK: - Dependencies
    // All services are @ObservationIgnored to prevent @Observable from tracking them
    // This is critical for fluidAudioService which is an actor existential type

    @ObservationIgnored private let audioService: AudioCaptureService
    @ObservationIgnored private let fluidAudioService: any FluidAudioServiceProtocol
    @ObservationIgnored private let textInsertionService: TextInsertionService
    @ObservationIgnored private let settingsService: SettingsService

    // MARK: - Private State

    @ObservationIgnored private var isAudioCaptureActive: Bool = false
    @ObservationIgnored private let viewModelId: String

    // MARK: - Initialization

    init(
        audioService: AudioCaptureService = AudioCaptureService(),
        fluidAudioService: any FluidAudioServiceProtocol = FluidAudioService(),
        textInsertionService: TextInsertionService = TextInsertionService(),
        settingsService: SettingsService = SettingsService()
    ) {
        self.viewModelId = UUID().uuidString.prefix(8).description
        self.audioService = audioService
        self.fluidAudioService = fluidAudioService
        self.textInsertionService = textInsertionService
        self.settingsService = settingsService
        AppLogger.lifecycle(AppLogger.viewModel, self, event: "init[\(viewModelId)]")
    }

    deinit {
        AppLogger.trace(AppLogger.viewModel, "FloatingWidgetViewModel[\(viewModelId)] deallocating")
    }

    // MARK: - Public Methods

    /// Start recording audio
    func startRecording() async {
        AppLogger.info(AppLogger.viewModel, "[\(viewModelId)] startRecording() called")

        guard !isRecording else {
            AppLogger.warning(AppLogger.viewModel, "[\(viewModelId)] Already recording")
            return
        }

        // Clear previous state
        errorMessage = nil
        transcribedText = ""
        isRecording = true

        do {
            // Ensure microphone permission
            let permissionService = PermissionService()
            if !(await permissionService.checkMicrophonePermission()) {
                try await permissionService.requestMicrophonePermission()
            }

            // Start audio capture
            try await audioService.startCapture { @Sendable [weak self] level in
                Task { @MainActor in
                    self?.audioLevel = Float(level)
                }
            }
            isAudioCaptureActive = true
            AppLogger.info(AppLogger.viewModel, "[\(viewModelId)] Audio capture started")
        } catch {
            AppLogger.error(AppLogger.viewModel, "[\(viewModelId)] Failed to start recording: \(error.localizedDescription)")
            isRecording = false
            errorMessage = error.localizedDescription
        }
    }

    /// Stop recording and trigger transcription
    func stopRecording() async {
        AppLogger.info(AppLogger.viewModel, "[\(viewModelId)] stopRecording() called")

        guard isRecording else {
            AppLogger.warning(AppLogger.viewModel, "[\(viewModelId)] Not recording")
            return
        }

        isRecording = false

        guard isAudioCaptureActive else {
            AppLogger.warning(AppLogger.viewModel, "[\(viewModelId)] Audio capture not active")
            return
        }

        isAudioCaptureActive = false
        isTranscribing = true

        do {
            // Stop audio capture and get samples
            let samples = try await audioService.stopCapture()
            AppLogger.info(AppLogger.viewModel, "[\(viewModelId)] Got \(samples.count) samples")

            guard !samples.isEmpty else {
                isTranscribing = false
                errorMessage = "No audio captured"
                return
            }

            // Transcribe audio
            let settings = settingsService.load()
            try await fluidAudioService.initialize(language: settings.language.defaultLanguage)
            let result = try await fluidAudioService.transcribe(samples: samples)

            transcribedText = result.text
            isTranscribing = false

            // Insert text
            try await textInsertionService.insertText(result.text)
            AppLogger.info(AppLogger.viewModel, "[\(viewModelId)] Text inserted successfully")

        } catch {
            AppLogger.error(AppLogger.viewModel, "[\(viewModelId)] Error: \(error.localizedDescription)")
            isTranscribing = false
            errorMessage = error.localizedDescription
        }
    }

    /// Toggle recording state
    func toggleRecording() async {
        if isRecording {
            await stopRecording()
        } else {
            await startRecording()
        }
    }

    /// Cancel recording without transcription
    func cancelRecording() async {
        AppLogger.info(AppLogger.viewModel, "[\(viewModelId)] cancelRecording()")

        isRecording = false
        isTranscribing = false

        if isAudioCaptureActive {
            isAudioCaptureActive = false
            do {
                _ = try await audioService.stopCapture()
            } catch {
                AppLogger.warning(AppLogger.viewModel, "[\(viewModelId)] Error cancelling: \(error.localizedDescription)")
            }
        }

        audioLevel = 0.0
        transcribedText = ""
        errorMessage = nil
    }
}
