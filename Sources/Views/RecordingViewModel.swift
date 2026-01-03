// RecordingViewModel.swift
// macOS Local Speech-to-Text Application
//
// User Story 1: Quick Speech-to-Text Capture
// Task T025: RecordingViewModel - @Observable class coordinating audio capture,
// FluidAudio transcription, and text insertion

import AVFoundation
import Foundation
import Observation
import OSLog

/// RecordingViewModel coordinates the recording, transcription, and text insertion workflow
@Observable
@MainActor
final class RecordingViewModel {
    // MARK: - Published State

    /// Current recording session state
    var currentSession: RecordingSession?

    /// Real-time audio level (0.0 - 1.0)
    var audioLevel: Double = 0.0

    /// Whether recording is active
    var isRecording: Bool = false

    /// Whether transcription is in progress
    var isTranscribing: Bool = false

    /// Whether text is being inserted
    var isInserting: Bool = false

    /// Current error message (if any)
    var errorMessage: String?

    /// Last transcribed text
    var transcribedText: String = ""

    /// Confidence score of last transcription (0.0 - 1.0)
    var confidence: Double = 0.0

    /// Is language switching (T067)
    var isLanguageSwitching: Bool = false

    /// Current language code (T068)
    var currentLanguage: String = "en"

    /// Current language model for display (T068)
    var currentLanguageModel: LanguageModel? {
        LanguageModel.supportedLanguages.first { $0.code == currentLanguage }
    }

    // MARK: - Dependencies

    private let audioService: AudioCaptureService
    private let fluidAudioService: FluidAudioService
    private let textInsertionService: TextInsertionService
    private let settingsService: SettingsService
    private let statisticsService: StatisticsService

    // MARK: - Private State

    @ObservationIgnored private var silenceTimer: Timer?
    private let silenceThreshold: TimeInterval
    @ObservationIgnored private var languageSwitchObserver: NSObjectProtocol?

    // nonisolated copies for deinit access (deinit cannot access MainActor-isolated state)
    @ObservationIgnored private nonisolated(unsafe) var deinitLanguageSwitchObserver: NSObjectProtocol?
    @ObservationIgnored private nonisolated(unsafe) var deinitSilenceTimer: Timer?

    // MARK: - Initialization

    init(
        audioService: AudioCaptureService = AudioCaptureService(),
        fluidAudioService: FluidAudioService = FluidAudioService(),
        textInsertionService: TextInsertionService = TextInsertionService(),
        settingsService: SettingsService = SettingsService(),
        statisticsService: StatisticsService = StatisticsService()
    ) {
        self.audioService = audioService
        self.fluidAudioService = fluidAudioService
        self.textInsertionService = textInsertionService
        self.settingsService = settingsService
        self.statisticsService = statisticsService

        // Get silence threshold from settings
        let settings = settingsService.load()
        self.silenceThreshold = settings.audio.silenceThreshold

        // Get current language from settings (T068)
        self.currentLanguage = settings.language.defaultLanguage

        // Setup language switch observer (T064)
        setupLanguageSwitchObserver()
    }

    deinit {
        // For closure-based observers, we must remove via the returned token
        // Store observer in nonisolated(unsafe) property for deinit access
        if let observer = deinitLanguageSwitchObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        // Invalidate any pending timer
        deinitSilenceTimer?.invalidate()
    }

    // MARK: - Language Switch Observer

    private func setupLanguageSwitchObserver() {
        // Listen for language switch notifications (T064, T067)
        let observer = NotificationCenter.default.addObserver(
            forName: .switchLanguage,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let languageCode = notification.userInfo?["languageCode"] as? String else {
                return
            }

            // Use [weak self] inside Task to avoid strong capture after guard
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isLanguageSwitching = true
                self.currentLanguage = languageCode

                // Switch language in FluidAudioService
                do {
                    try await self.fluidAudioService.switchLanguage(to: languageCode)
                } catch {
                    self.errorMessage = "Failed to switch language: \(error.localizedDescription)"
                }

                self.isLanguageSwitching = false
            }
        }
        languageSwitchObserver = observer
        deinitLanguageSwitchObserver = observer
    }

    // MARK: - Public Methods

    /// Start recording audio
    func startRecording() async throws {
        guard !isRecording else {
            throw RecordingError.alreadyRecording
        }

        // Clear previous state
        errorMessage = nil
        transcribedText = ""
        confidence = 0.0

        // Create new recording session
        let settings = settingsService.load()
        currentSession = RecordingSession(
            id: UUID(),
            startTime: Date(),
            language: settings.language.defaultLanguage
        )

        isRecording = true

        do {
            // Start audio capture with level callback
            try await audioService.startCapture { [weak self] level in
                Task { @MainActor in
                    self?.audioLevel = level
                    self?.resetSilenceTimer()
                }
            }
        } catch {
            isRecording = false
            currentSession = nil
            throw RecordingError.audioCaptureFailed(error.localizedDescription)
        }
    }

    /// Stop recording and trigger transcription
    func stopRecording() async throws {
        guard isRecording else {
            throw RecordingError.notRecording
        }

        isRecording = false
        silenceTimer?.invalidate()
        silenceTimer = nil
        deinitSilenceTimer = nil

        do {
            // Stop audio capture and get samples
            let samples = try await audioService.stopCapture()

            guard !samples.isEmpty else {
                throw RecordingError.noAudioCaptured
            }

            // Update session
            currentSession?.endTime = Date()
            currentSession?.audioData = samples

            // Transcribe audio
            try await transcribe(samples: samples)

        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    /// Cancel recording without transcription
    func cancelRecording() async {
        isRecording = false
        isTranscribing = false
        isInserting = false

        silenceTimer?.invalidate()
        silenceTimer = nil
        deinitSilenceTimer = nil

        // Stop audio capture
        do {
            _ = try await audioService.stopCapture()
        } catch {
            AppLogger.audio.warning("Non-fatal error during recording cancellation: \(error.localizedDescription, privacy: .public)")
        }

        // Mark session as cancelled
        currentSession?.errorMessage = "User cancelled"
        currentSession = nil

        // Reset state
        audioLevel = 0.0
        transcribedText = ""
        confidence = 0.0
        errorMessage = nil
    }

    // MARK: - Private Methods

    /// Transcribe audio samples using FluidAudio
    private func transcribe(samples: [Int16]) async throws {
        guard var session = currentSession else {
            throw RecordingError.noActiveSession
        }

        isTranscribing = true

        do {
            // Initialize FluidAudio if needed
            let settings = settingsService.load()
            try await fluidAudioService.initialize(language: settings.language.defaultLanguage)

            // Transcribe
            let result = try await fluidAudioService.transcribe(samples: samples)

            // Update session
            session.transcribedText = result.text
            session.confidenceScore = Double(result.confidence)
            // Note: wordCount is a computed property, no need to set it
            currentSession = session

            // Update local state
            transcribedText = result.text
            confidence = Double(result.confidence)

            isTranscribing = false

            // Insert text
            try await insertText(result.text)

        } catch {
            isTranscribing = false
            errorMessage = "Transcription failed: \(error.localizedDescription)"
            session.errorMessage = error.localizedDescription
            currentSession = session
            throw RecordingError.transcriptionFailed(error.localizedDescription)
        }
    }

    /// Insert transcribed text into active application
    private func insertText(_ text: String) async throws {
        guard var session = currentSession else {
            throw RecordingError.noActiveSession
        }

        isInserting = true

        do {
            // Try text insertion via Accessibility API
            try await textInsertionService.insertText(text)

            session.insertionSuccess = true
            currentSession = session

            isInserting = false

            // Save statistics
            await saveStatistics(session: session)

        } catch {
            isInserting = false
            errorMessage = "Text insertion failed: \(error.localizedDescription)"
            session.errorMessage = error.localizedDescription
            session.insertionSuccess = false
            currentSession = session
            throw RecordingError.textInsertionFailed(error.localizedDescription)
        }
    }

    /// Reset silence detection timer (T029)
    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        deinitSilenceTimer?.invalidate()

        // Check if audio level is below threshold (silence)
        if audioLevel < 0.01 { // Very low threshold for silence
            let timer = Timer.scheduledTimer(
                withTimeInterval: silenceThreshold,
                repeats: false
            ) { [weak self] _ in
                Task { @MainActor in
                    await self?.onSilenceDetected()
                }
            }
            silenceTimer = timer
            deinitSilenceTimer = timer
        } else {
            silenceTimer = nil
            deinitSilenceTimer = nil
        }
    }

    /// Called when silence is detected after threshold
    private func onSilenceDetected() async {
        guard isRecording else { return }

        do {
            try await stopRecording()
        } catch {
            errorMessage = "Failed to stop recording: \(error.localizedDescription)"
        }
    }

    /// Save statistics to database
    private func saveStatistics(session: RecordingSession) async {
        do {
            try await statisticsService.recordSession(session)
        } catch {
            // Log error but don't fail the workflow
            AppLogger.viewModel.warning("Failed to save statistics: \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - Recording Errors

enum RecordingError: LocalizedError, Equatable, Sendable {
    case alreadyRecording
    case notRecording
    case audioCaptureFailed(String)
    case noAudioCaptured
    case noActiveSession
    case transcriptionFailed(String)
    case textInsertionFailed(String)

    var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            return "Recording is already in progress"
        case .notRecording:
            return "No active recording to stop"
        case .audioCaptureFailed(let message):
            return "Audio capture failed: \(message)"
        case .noAudioCaptured:
            return "No audio was captured"
        case .noActiveSession:
            return "No active recording session"
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        case .textInsertionFailed(let message):
            return "Text insertion failed: \(message)"
        }
    }
}
