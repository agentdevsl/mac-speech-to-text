// swiftlint:disable file_length type_body_length
// RecordingViewModel.swift
// macOS Local Speech-to-Text Application
//
// User Story 1: Quick Speech-to-Text Capture
// Task T025: RecordingViewModel - @Observable class coordinating audio capture,
// FluidAudio transcription, and text insertion

import AppKit
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

    /// Whether to show the inline accessibility permission prompt
    var showAccessibilityPrompt: Bool = false

    /// Whether to show the inline microphone permission prompt
    var showMicrophonePrompt: Bool = false

    /// Whether the last transcription was copied to clipboard (not inserted)
    var lastTranscriptionCopiedToClipboard: Bool = false

    // MARK: - Dependencies
    // All services are @ObservationIgnored to prevent @Observable from tracking them
    // This is critical for fluidAudioService which is an actor existential type -
    // tracking it can cause executor check crashes (pointer authentication failures)

    @ObservationIgnored private let audioService: AudioCaptureService
    @ObservationIgnored private let fluidAudioService: any FluidAudioServiceProtocol
    @ObservationIgnored private let textInsertionService: TextInsertionService
    @ObservationIgnored private let settingsService: SettingsService
    @ObservationIgnored private let statisticsService: StatisticsService

    // MARK: - Private State

    @ObservationIgnored private var languageSwitchObserver: NSObjectProtocol?
    @ObservationIgnored private var inactivityTimer: Timer?
    @ObservationIgnored private var lastTalkingTime: Date?
    @ObservationIgnored private var isAudioCaptureActive: Bool = false
    @ObservationIgnored private var microphonePermissionPollingTask: Task<Void, Never>?

    /// Flag to prevent double-firing of inactivity timeout (race condition fix)
    @ObservationIgnored private var inactivityTimeoutTriggered: Bool = false

    /// Session ID at start of operation - used to detect stale session after await
    @ObservationIgnored private var currentSessionId: UUID?

    /// Flag to prevent state transitions during active operation (race condition fix)
    @ObservationIgnored private var isTransitioning: Bool = false

    // nonisolated copies for deinit access (deinit cannot access MainActor-isolated state)
    // SAFETY: These are written on MainActor during init/setup, read in deinit after all refs released.
    // The isBeingDeallocated flag prevents notification handlers from running during deallocation.
    @ObservationIgnored private nonisolated(unsafe) var deinitLanguageSwitchObserver: NSObjectProtocol?
    @ObservationIgnored private nonisolated(unsafe) var deinitInactivityTimer: Timer?
    @ObservationIgnored private nonisolated(unsafe) var isBeingDeallocated: Bool = false

    /// Shared permission service instance (avoids state fragmentation from multiple instances)
    @ObservationIgnored private let permissionService: PermissionService

    /// Unique ID for logging
    @ObservationIgnored private let viewModelId: String

    // MARK: - Initialization

    init(
        audioService: AudioCaptureService? = nil,
        fluidAudioService: any FluidAudioServiceProtocol = FluidAudioService(),
        textInsertionService: TextInsertionService = TextInsertionService(),
        settingsService: SettingsService = SettingsService(),
        statisticsService: StatisticsService = StatisticsService(),
        permissionService: PermissionService = PermissionService()
    ) {
        self.viewModelId = UUID().uuidString.prefix(8).description
        // CRIT-1 Fix: Pass settingsService to AudioCaptureService so it can use the selected device
        self.audioService = audioService ?? AudioCaptureService(settingsService: settingsService)
        self.fluidAudioService = fluidAudioService
        self.textInsertionService = textInsertionService
        self.settingsService = settingsService
        self.statisticsService = statisticsService
        self.permissionService = permissionService
        // Get current language from settings (T068)
        self.currentLanguage = settingsService.load().language.defaultLanguage
        AppLogger.lifecycle(AppLogger.viewModel, self, event: "init[\(viewModelId)]")
        AppLogger.debug(AppLogger.viewModel, "[\(viewModelId)] Initialized with language=\(currentLanguage)")
        setupLanguageSwitchObserver()
    }

    deinit {
        // Set deallocation flag FIRST to prevent notification handlers from executing
        isBeingDeallocated = true
        AppLogger.trace(AppLogger.viewModel, "RecordingViewModel[\(viewModelId)] deallocating")
        if let observer = deinitLanguageSwitchObserver { NotificationCenter.default.removeObserver(observer) }
        deinitInactivityTimer?.invalidate()
        microphonePermissionPollingTask?.cancel()
    }

    // MARK: - Language Switch Observer

    private func setupLanguageSwitchObserver() {
        // Guard against duplicate observer registration (bug fix)
        if let existing = languageSwitchObserver {
            NotificationCenter.default.removeObserver(existing)
            languageSwitchObserver = nil
            deinitLanguageSwitchObserver = nil
        }

        // Listen for language switch notifications (T064, T067)
        // Note: We use queue: .main to ensure synchronous removal in deinit prevents races.
        // The isBeingDeallocated flag provides additional protection against handler execution
        // during deallocation.
        let observer = NotificationCenter.default.addObserver(
            forName: .switchLanguage,
            object: nil,
            queue: .main  // Use main queue for synchronous deinit removal
        ) { [weak self] notification in
            guard let self,
                  !self.isBeingDeallocated,
                  let languageCode = notification.userInfo?["languageCode"] as? String else {
                return
            }

            // Use Task to defer to next run loop iteration, avoiding @Observable re-entrancy
            // during SwiftUI view body evaluation
            Task { @MainActor [weak self] in
                guard let self, !self.isBeingDeallocated else { return }
                await self.handleLanguageSwitch(to: languageCode)
            }
        }
        languageSwitchObserver = observer
        deinitLanguageSwitchObserver = observer
    }

    /// Handle language switch - extracted to avoid @Observable mutations during notification delivery
    private func handleLanguageSwitch(to languageCode: String) async {
        // Re-entrancy guard: prevent concurrent language switches (bug fix)
        guard !isLanguageSwitching else {
            AppLogger.warning(AppLogger.viewModel, "[\(viewModelId)] Language switch already in progress, ignoring")
            return
        }

        AppLogger.info(AppLogger.viewModel, "[\(viewModelId)] handleLanguageSwitch to \(languageCode)")
        isLanguageSwitching = true
        currentLanguage = languageCode

        // Switch language in FluidAudioService
        do {
            try await fluidAudioService.switchLanguage(to: languageCode)
            AppLogger.debug(AppLogger.viewModel, "[\(viewModelId)] Language switch successful")
        } catch {
            AppLogger.error(AppLogger.viewModel, "[\(viewModelId)] Language switch failed: \(error.localizedDescription)")
            errorMessage = "Failed to switch language: \(error.localizedDescription)"
        }

        isLanguageSwitching = false
    }

    // MARK: - Public Methods

    /// Start recording audio
    func startRecording() async throws {
        AppLogger.info(AppLogger.viewModel, "[\(viewModelId)] startRecording() called, isRecording=\(isRecording)")

        // Transition guard: prevent concurrent start calls racing through cancel (bug fix)
        guard !isTransitioning else {
            AppLogger.warning(AppLogger.viewModel, "[\(viewModelId)] startRecording: transition in progress, ignoring")
            throw RecordingError.alreadyRecording
        }

        // Set transition flag with defer to ensure it's always reset (fixes race condition)
        isTransitioning = true
        defer { isTransitioning = false }

        // Reset stale state if needed (defensive - handles edge cases where state wasn't cleaned up)
        if isRecording {
            AppLogger.warning(AppLogger.viewModel, "[\(viewModelId)] startRecording: found stale recording state, resetting")
            await cancelRecording()
        }

        // Clear ALL previous state (bug fix: previously missed permission prompts)
        AppLogger.debug(AppLogger.viewModel, "[\(viewModelId)] Clearing previous state")
        errorMessage = nil
        transcribedText = ""
        confidence = 0.0
        showAccessibilityPrompt = false
        showMicrophonePrompt = false
        lastTranscriptionCopiedToClipboard = false
        inactivityTimeoutTriggered = false

        // Create new recording session with state set to recording
        let settings = settingsService.load()
        let sessionId = UUID()
        currentSessionId = sessionId  // Track session ID for staleness detection
        currentSession = RecordingSession(
            id: sessionId,
            startTime: Date(),
            language: settings.language.defaultLanguage,
            state: .recording
        )
        AppLogger.debug(AppLogger.viewModel, "[\(viewModelId)] Created session \(sessionId.uuidString.prefix(8))")

        AppLogger.stateChange(AppLogger.viewModel, from: false, to: true, context: "isRecording")
        isRecording = true

        do {
            // Ensure microphone permission before capture
            try await ensureMicrophonePermission()

            // Start audio capture - callback is @Sendable and handles MainActor dispatch
            try await audioService.startCapture { @Sendable [weak self] level in
                Task { @MainActor in self?.handleAudioLevel(level) }
            }
            isAudioCaptureActive = true
            // Initialize talking time and start inactivity timer
            lastTalkingTime = Date()
            startInactivityTimer()
            AppLogger.info(AppLogger.viewModel, "[\(viewModelId)] Audio capture started successfully")
        } catch PermissionError.microphoneDenied {
            // Microphone permission denied - keep isRecording=true and show prompt
            // The user can grant permission in System Settings and polling will auto-continue
            AppLogger.info(AppLogger.viewModel, "[\(viewModelId)] Microphone permission denied, waiting for user action")
            // Don't reset state - showMicrophonePrompt is already set by ensureMicrophonePermission
            // Don't throw - we're waiting for permission
        } catch {
            AppLogger.error(AppLogger.viewModel, "[\(viewModelId)] Audio capture failed: \(error.localizedDescription)")
            // Update session state before clearing (bug fix: preserve error info for debugging)
            currentSession?.state = .cancelled
            currentSession?.errorMessage = error.localizedDescription
            isRecording = false
            currentSession = nil
            currentSessionId = nil
            throw RecordingError.audioCaptureFailed(error.localizedDescription)
        }
    }

    /// Stop recording and trigger transcription
    func stopRecording() async throws {
        AppLogger.info(AppLogger.viewModel, "[\(viewModelId)] stopRecording() called, isRecording=\(isRecording)")

        guard isRecording else {
            AppLogger.warning(AppLogger.viewModel, "[\(viewModelId)] stopRecording: not recording")
            throw RecordingError.notRecording
        }

        AppLogger.stateChange(AppLogger.viewModel, from: true, to: false, context: "isRecording")
        isRecording = false
        inactivityTimer?.invalidate()
        inactivityTimer = nil
        deinitInactivityTimer = nil

        do {
            // Stop audio capture and get samples (only if active)
            guard isAudioCaptureActive else {
                AppLogger.error(AppLogger.viewModel, "[\(viewModelId)] stopRecording: audio capture not active")
                throw RecordingError.notRecording
            }
            isAudioCaptureActive = false

            AppLogger.debug(AppLogger.viewModel, "[\(viewModelId)] Stopping audio capture...")
            let (samples, sampleRate) = try await audioService.stopCapture()
            AppLogger.info(AppLogger.viewModel, "[\(viewModelId)] Audio capture stopped, got \(samples.count) samples at \(Int(sampleRate))Hz")

            guard !samples.isEmpty else {
                AppLogger.error(AppLogger.viewModel, "[\(viewModelId)] No audio captured")
                throw RecordingError.noAudioCaptured
            }

            // Update session
            currentSession?.endTime = Date()
            currentSession?.audioData = samples
            if let session = currentSession {
                let duration = session.endTime?.timeIntervalSince(session.startTime) ?? 0
                AppLogger.debug(AppLogger.viewModel, "[\(viewModelId)] Session duration: \(String(format: "%.2f", duration))s")
            }

            // Transcribe audio
            AppLogger.debug(AppLogger.viewModel, "[\(viewModelId)] Starting transcription...")
            try await transcribe(samples: samples, sampleRate: sampleRate)

        } catch {
            AppLogger.error(AppLogger.viewModel, "[\(viewModelId)] stopRecording error: \(error.localizedDescription)")
            // Update session state on error (bug fix: consistent error state tracking)
            currentSession?.state = .cancelled
            currentSession?.errorMessage = error.localizedDescription
            errorMessage = error.localizedDescription
            throw error
        }
    }

    /// Cancel recording without transcription
    func cancelRecording() async {
        AppLogger.info(
            AppLogger.viewModel,
            "[\(viewModelId)] cancelRecording() called, isRecording=\(isRecording), isAudioCaptureActive=\(isAudioCaptureActive)"
        )

        isRecording = false
        isTranscribing = false
        isInserting = false
        inactivityTimer?.invalidate()
        inactivityTimer = nil
        deinitInactivityTimer = nil
        inactivityTimeoutTriggered = false  // Reset timeout flag
        microphonePermissionPollingTask?.cancel()
        microphonePermissionPollingTask = nil

        // Stop audio capture only if active (prevents double-stop)
        if isAudioCaptureActive {
            isAudioCaptureActive = false
            AppLogger.debug(AppLogger.viewModel, "[\(viewModelId)] Stopping audio capture for cancellation...")
            do {
                _ = try await audioService.stopCapture()
                AppLogger.debug(AppLogger.viewModel, "[\(viewModelId)] Audio capture stopped for cancellation")
            } catch {
                AppLogger.warning(
                    AppLogger.viewModel,
                    "[\(viewModelId)] Non-fatal error during cancellation: \(error.localizedDescription)"
                )
            }
        }

        // Mark session as cancelled
        currentSession?.state = .cancelled
        currentSession?.errorMessage = "User cancelled"
        currentSession = nil
        currentSessionId = nil  // Clear session tracking

        // Reset state
        audioLevel = 0.0
        transcribedText = ""
        confidence = 0.0
        errorMessage = nil
        showAccessibilityPrompt = false
        showMicrophonePrompt = false
        lastTranscriptionCopiedToClipboard = false
        AppLogger.debug(AppLogger.viewModel, "[\(viewModelId)] Recording cancelled and state reset")
    }

    /// Handle hotkey release for hold-to-record mode
    ///
    /// This method is called when the hotkey is released in hold-to-record mode.
    /// It stops recording, transcribes the audio, and inserts text with fallback handling.
    /// If accessibility permission is not granted, it shows an inline prompt.
    func onHotkeyReleased() async throws {
        AppLogger.info(AppLogger.viewModel, "[\(viewModelId)] onHotkeyReleased() called, isRecording=\(isRecording)")

        guard isRecording else {
            AppLogger.warning(AppLogger.viewModel, "[\(viewModelId)] onHotkeyReleased: not recording")
            throw RecordingError.notRecording
        }

        // Reset accessibility prompt state
        showAccessibilityPrompt = false
        lastTranscriptionCopiedToClipboard = false

        AppLogger.stateChange(AppLogger.viewModel, from: true, to: false, context: "isRecording")
        isRecording = false
        inactivityTimer?.invalidate()
        inactivityTimer = nil
        deinitInactivityTimer = nil

        do {
            // Stop audio capture and get samples (only if active)
            guard isAudioCaptureActive else {
                AppLogger.error(AppLogger.viewModel, "[\(viewModelId)] onHotkeyReleased: audio capture not active")
                throw RecordingError.notRecording
            }
            isAudioCaptureActive = false

            AppLogger.debug(AppLogger.viewModel, "[\(viewModelId)] Stopping audio capture...")
            let (samples, sampleRate) = try await audioService.stopCapture()
            AppLogger.info(AppLogger.viewModel, "[\(viewModelId)] Audio capture stopped, got \(samples.count) samples at \(Int(sampleRate))Hz")

            guard !samples.isEmpty else {
                AppLogger.error(AppLogger.viewModel, "[\(viewModelId)] No audio captured")
                throw RecordingError.noAudioCaptured
            }

            // Update session
            currentSession?.endTime = Date()
            currentSession?.audioData = samples
            if let session = currentSession {
                let duration = session.endTime?.timeIntervalSince(session.startTime) ?? 0
                AppLogger.debug(AppLogger.viewModel, "[\(viewModelId)] Session duration: \(String(format: "%.2f", duration))s")
            }

            // Transcribe audio
            print("[DEBUG] onHotkeyReleased: Starting transcription with \(samples.count) samples at \(Int(sampleRate))Hz...")
            fflush(stdout)
            AppLogger.debug(AppLogger.viewModel, "[\(viewModelId)] Starting transcription...")
            try await transcribeWithFallback(samples: samples, sampleRate: sampleRate)

        } catch {
            AppLogger.error(AppLogger.viewModel, "[\(viewModelId)] onHotkeyReleased error: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            throw error
        }
    }

    /// Dismiss the accessibility prompt and remember the user's choice
    func dismissAccessibilityPrompt() {
        AppLogger.info(AppLogger.viewModel, "[\(viewModelId)] dismissAccessibilityPrompt() called")
        showAccessibilityPrompt = false

        // Remember that user dismissed the prompt
        do {
            var settings = settingsService.load()
            settings.general.accessibilityPromptDismissed = true
            try settingsService.save(settings)
            AppLogger.debug(AppLogger.viewModel, "[\(viewModelId)] Saved accessibilityPromptDismissed=true")
        } catch {
            AppLogger.error(AppLogger.viewModel, "[\(viewModelId)] Failed to save settings: \(error.localizedDescription)")
        }
    }

    /// Set clipboard-only mode preference (user chose "Use Clipboard Only")
    func setClipboardOnlyMode() {
        AppLogger.info(AppLogger.viewModel, "[\(viewModelId)] setClipboardOnlyMode() called")
        showAccessibilityPrompt = false

        // Save clipboard-only mode preference
        do {
            var settings = settingsService.load()
            settings.general.clipboardOnlyMode = true
            settings.general.accessibilityPromptDismissed = true
            try settingsService.save(settings)
            AppLogger.debug(AppLogger.viewModel, "[\(viewModelId)] Saved clipboardOnlyMode=true, accessibilityPromptDismissed=true")
        } catch {
            AppLogger.error(AppLogger.viewModel, "[\(viewModelId)] Failed to save settings: \(error.localizedDescription)")
        }
    }

    /// Open System Settings to accessibility preferences
    func openAccessibilitySettings() {
        AppLogger.info(AppLogger.viewModel, "[\(viewModelId)] openAccessibilitySettings() called")
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            let opened = NSWorkspace.shared.open(url)
            if !opened {
                AppLogger.error(AppLogger.viewModel, "[\(viewModelId)] Failed to open System Settings")
            }
        }
    }

    /// Open System Settings to microphone preferences
    func openMicrophoneSettings() {
        AppLogger.info(AppLogger.viewModel, "[\(viewModelId)] openMicrophoneSettings() called")
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            let opened = NSWorkspace.shared.open(url)
            if !opened {
                AppLogger.error(AppLogger.viewModel, "[\(viewModelId)] Failed to open System Settings for Microphone")
            }
        }
    }

    /// Dismiss the microphone permission prompt and cancel recording
    func dismissMicrophonePrompt() {
        AppLogger.info(AppLogger.viewModel, "[\(viewModelId)] dismissMicrophonePrompt() called")
        showMicrophonePrompt = false
        microphonePermissionPollingTask?.cancel()
        microphonePermissionPollingTask = nil

        // Reset recording state since we can't proceed without microphone
        isRecording = false
        currentSession = nil
        errorMessage = nil
        AppLogger.debug(AppLogger.viewModel, "[\(viewModelId)] Microphone prompt dismissed, recording cancelled")
    }

    /// Called when microphone permission is granted (either by polling or manually)
    func onMicrophonePermissionGranted() async {
        AppLogger.info(AppLogger.viewModel, "[\(viewModelId)] onMicrophonePermissionGranted() called")

        // State validation: ensure we're still in a valid waiting state (bug fix)
        guard isRecording, currentSession != nil, !isAudioCaptureActive else {
            AppLogger.warning(
                AppLogger.viewModel,
                "[\(viewModelId)] onMicrophonePermissionGranted: invalid state (isRecording=\(isRecording), " +
                "hasSession=\(currentSession != nil), isAudioCaptureActive=\(isAudioCaptureActive))"
            )
            return
        }

        showMicrophonePrompt = false
        microphonePermissionPollingTask?.cancel()
        microphonePermissionPollingTask = nil

        // Continue with audio capture now that permission is granted
        do {
            try await audioService.startCapture { @Sendable [weak self] level in
                Task { @MainActor in self?.handleAudioLevel(level) }
            }
            isAudioCaptureActive = true
            // Initialize talking time and start inactivity timer
            lastTalkingTime = Date()
            startInactivityTimer()
            AppLogger.info(AppLogger.viewModel, "[\(viewModelId)] Audio capture started after permission granted")
        } catch {
            AppLogger.error(AppLogger.viewModel, "[\(viewModelId)] Audio capture failed after permission: \(error.localizedDescription)")
            // Update session state before clearing (bug fix: consistent error handling)
            currentSession?.state = .cancelled
            currentSession?.errorMessage = error.localizedDescription
            isRecording = false
            currentSession = nil
            currentSessionId = nil
            errorMessage = "Audio capture failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Private Methods

    /// Transcribe audio samples using FluidAudio
    private func transcribe(samples: [Int16], sampleRate: Double) async throws {
        AppLogger.info(AppLogger.viewModel, "[\(viewModelId)] transcribe() called with \(samples.count) samples at \(Int(sampleRate))Hz")

        guard var session = currentSession else {
            AppLogger.error(AppLogger.viewModel, "[\(viewModelId)] transcribe: no active session")
            throw RecordingError.noActiveSession
        }

        // Capture session ID at start to detect staleness after await
        let startSessionId = currentSessionId

        AppLogger.stateChange(AppLogger.viewModel, from: false, to: true, context: "isTranscribing")
        isTranscribing = true
        session.state = .transcribing
        currentSession = session

        do {
            // Initialize FluidAudio if needed
            let settings = settingsService.load()
            AppLogger.debug(AppLogger.viewModel, "[\(viewModelId)] Initializing FluidAudio with language=\(settings.language.defaultLanguage)")
            try await fluidAudioService.initialize(language: settings.language.defaultLanguage)

            // Check for session cancellation after await (bug fix: staleness detection)
            guard currentSessionId == startSessionId, currentSession != nil else {
                AppLogger.warning(AppLogger.viewModel, "[\(viewModelId)] Session cancelled during FluidAudio init")
                isTranscribing = false
                throw RecordingError.noActiveSession
            }

            // Transcribe (samples are at native rate, FluidAudio will resample to 16kHz)
            print("[DEBUG] Calling FluidAudio transcribe with \(samples.count) samples at \(Int(sampleRate))Hz...")
            fflush(stdout)
            AppLogger.debug(AppLogger.viewModel, "[\(viewModelId)] Calling FluidAudio transcribe...")
            let result = try await fluidAudioService.transcribe(samples: samples, sampleRate: sampleRate)
            print("[DEBUG] FluidAudio result: text='\(result.text)', confidence=\(result.confidence), durationMs=\(result.durationMs)")
            fflush(stdout)
            AppLogger.info(
                AppLogger.viewModel,
                "[\(viewModelId)] Transcription complete: \(result.durationMs)ms, confidence=\(result.confidence)"
            )

            // Check for session cancellation after await (bug fix: staleness detection)
            guard currentSessionId == startSessionId, var updatedSession = currentSession else {
                AppLogger.warning(AppLogger.viewModel, "[\(viewModelId)] Session cancelled during transcription")
                isTranscribing = false
                throw RecordingError.noActiveSession
            }

            // Update session - re-fetch to avoid stale copy issues
            updatedSession.transcribedText = result.text
            updatedSession.confidenceScore = Double(result.confidence)
            self.currentSession = updatedSession

            // Update local state
            transcribedText = result.text
            confidence = Double(result.confidence)

            AppLogger.stateChange(AppLogger.viewModel, from: true, to: false, context: "isTranscribing")
            isTranscribing = false

            // Insert text
            AppLogger.debug(AppLogger.viewModel, "[\(viewModelId)] Proceeding to text insertion...")
            try await insertText(result.text)

        } catch {
            AppLogger.error(AppLogger.viewModel, "[\(viewModelId)] Transcription failed: \(error.localizedDescription)")
            isTranscribing = false
            errorMessage = "Transcription failed: \(error.localizedDescription)"
            // Re-fetch session to avoid overwriting concurrent changes (bug fix)
            if var updatedSession = currentSession, currentSessionId == startSessionId {
                updatedSession.errorMessage = error.localizedDescription
                updatedSession.state = .cancelled
                self.currentSession = updatedSession
            }
            throw RecordingError.transcriptionFailed(error.localizedDescription)
        }
    }

    /// Insert transcribed text into active application
    private func insertText(_ text: String) async throws {
        AppLogger.info(AppLogger.viewModel, "[\(viewModelId)] insertText() called, textLength=\(text.count)")

        guard var session = currentSession else {
            AppLogger.error(AppLogger.viewModel, "[\(viewModelId)] insertText: no active session")
            throw RecordingError.noActiveSession
        }

        // Capture session ID at start to detect staleness after await
        let startSessionId = currentSessionId

        AppLogger.stateChange(AppLogger.viewModel, from: false, to: true, context: "isInserting")
        isInserting = true
        session.state = .inserting
        currentSession = session

        do {
            // Try text insertion via Accessibility API
            AppLogger.debug(AppLogger.viewModel, "[\(viewModelId)] Calling TextInsertionService...")
            try await textInsertionService.insertText(text)
            AppLogger.info(AppLogger.viewModel, "[\(viewModelId)] Text insertion successful")

            // Check for session cancellation after await (bug fix: staleness detection)
            guard currentSessionId == startSessionId, var updatedSession = currentSession else {
                AppLogger.warning(AppLogger.viewModel, "[\(viewModelId)] Session cancelled during text insertion")
                isInserting = false
                throw RecordingError.noActiveSession
            }

            updatedSession.insertionSuccess = true
            updatedSession.state = .completed
            self.currentSession = updatedSession

            AppLogger.stateChange(AppLogger.viewModel, from: true, to: false, context: "isInserting")
            isInserting = false

            // Save statistics
            AppLogger.debug(AppLogger.viewModel, "[\(viewModelId)] Saving session statistics...")
            await saveStatistics(session: updatedSession)

        } catch {
            AppLogger.error(AppLogger.viewModel, "[\(viewModelId)] Text insertion failed: \(error.localizedDescription)")
            isInserting = false
            errorMessage = "Text insertion failed: \(error.localizedDescription)"
            // Re-fetch session to avoid overwriting concurrent changes (bug fix)
            if var updatedSession = currentSession, currentSessionId == startSessionId {
                updatedSession.errorMessage = error.localizedDescription
                updatedSession.insertionSuccess = false
                updatedSession.state = .cancelled
                self.currentSession = updatedSession
            }
            throw RecordingError.textInsertionFailed(error.localizedDescription)
        }
    }

    /// Transcribe audio samples and insert text with fallback handling
    ///
    /// This method is used by hold-to-record mode to handle the full workflow
    /// with graceful degradation when accessibility permission is not granted.
    /// - Parameters:
    ///   - samples: Audio samples at native sample rate
    ///   - sampleRate: Native sample rate of the audio (e.g., 48000.0)
    private func transcribeWithFallback(samples: [Int16], sampleRate: Double) async throws {
        AppLogger.info(AppLogger.viewModel, "[\(viewModelId)] transcribeWithFallback() called with \(samples.count) samples at \(Int(sampleRate))Hz")

        guard var session = currentSession else {
            AppLogger.error(AppLogger.viewModel, "[\(viewModelId)] transcribeWithFallback: no active session")
            throw RecordingError.noActiveSession
        }

        // Capture session ID at start to detect staleness after await
        let startSessionId = currentSessionId

        AppLogger.stateChange(AppLogger.viewModel, from: false, to: true, context: "isTranscribing")
        isTranscribing = true
        session.state = .transcribing
        currentSession = session

        do {
            // Initialize FluidAudio if needed
            let settings = settingsService.load()
            AppLogger.debug(AppLogger.viewModel, "[\(viewModelId)] Initializing FluidAudio with language=\(settings.language.defaultLanguage)")
            try await fluidAudioService.initialize(language: settings.language.defaultLanguage)

            // Check for session cancellation after await (bug fix: staleness detection)
            guard currentSessionId == startSessionId, currentSession != nil else {
                AppLogger.warning(AppLogger.viewModel, "[\(viewModelId)] Session cancelled during FluidAudio init")
                isTranscribing = false
                throw RecordingError.noActiveSession
            }

            // Transcribe (samples are at native rate, FluidAudio will resample to 16kHz)
            print("[DEBUG] Calling FluidAudio transcribe with \(samples.count) samples at \(Int(sampleRate))Hz...")
            fflush(stdout)
            AppLogger.debug(AppLogger.viewModel, "[\(viewModelId)] Calling FluidAudio transcribe...")
            let result = try await fluidAudioService.transcribe(samples: samples, sampleRate: sampleRate)
            print("[DEBUG] FluidAudio result: text='\(result.text)', confidence=\(result.confidence), durationMs=\(result.durationMs)")
            fflush(stdout)
            AppLogger.info(
                AppLogger.viewModel,
                "[\(viewModelId)] Transcription complete: \(result.durationMs)ms, confidence=\(result.confidence)"
            )

            // Check for session cancellation after await (bug fix: staleness detection)
            guard currentSessionId == startSessionId, var updatedSession = currentSession else {
                AppLogger.warning(AppLogger.viewModel, "[\(viewModelId)] Session cancelled during transcription")
                isTranscribing = false
                throw RecordingError.noActiveSession
            }

            // Update session - re-fetch to avoid stale copy issues
            updatedSession.transcribedText = result.text
            updatedSession.confidenceScore = Double(result.confidence)
            self.currentSession = updatedSession

            // Update local state
            transcribedText = result.text
            confidence = Double(result.confidence)

            AppLogger.stateChange(AppLogger.viewModel, from: true, to: false, context: "isTranscribing")
            isTranscribing = false

            // Insert text with fallback handling
            AppLogger.debug(AppLogger.viewModel, "[\(viewModelId)] Proceeding to text insertion with fallback...")
            try await insertTextWithFallback(result.text)

        } catch {
            AppLogger.error(AppLogger.viewModel, "[\(viewModelId)] Transcription failed: \(error.localizedDescription)")
            isTranscribing = false
            errorMessage = "Transcription failed: \(error.localizedDescription)"
            // Re-fetch session to avoid overwriting concurrent changes (bug fix)
            if var updatedSession = currentSession, currentSessionId == startSessionId {
                updatedSession.errorMessage = error.localizedDescription
                updatedSession.state = .cancelled
                self.currentSession = updatedSession
            }
            throw RecordingError.transcriptionFailed(error.localizedDescription)
        }
    }

    /// Insert text with fallback to clipboard and show accessibility prompt if needed
    private func insertTextWithFallback(_ text: String) async throws {
        AppLogger.info(AppLogger.viewModel, "[\(viewModelId)] insertTextWithFallback() called, textLength=\(text.count)")

        guard var session = currentSession else {
            AppLogger.error(AppLogger.viewModel, "[\(viewModelId)] insertTextWithFallback: no active session")
            throw RecordingError.noActiveSession
        }

        // Capture session ID at start to detect staleness after await
        let startSessionId = currentSessionId

        AppLogger.stateChange(AppLogger.viewModel, from: false, to: true, context: "isInserting")
        isInserting = true
        session.state = .inserting
        currentSession = session

        // Use fallback-aware insertion
        let insertionResult = await textInsertionService.insertTextWithFallback(text)

        // Check for session cancellation after await (bug fix: staleness detection)
        guard currentSessionId == startSessionId, var updatedSession = currentSession else {
            AppLogger.warning(AppLogger.viewModel, "[\(viewModelId)] Session cancelled during text insertion")
            isInserting = false
            throw RecordingError.noActiveSession
        }

        switch insertionResult {
        case .insertedViaAccessibility:
            AppLogger.info(AppLogger.viewModel, "[\(viewModelId)] Text inserted via accessibility")
            updatedSession.insertionSuccess = true
            lastTranscriptionCopiedToClipboard = false

        case .copiedToClipboardOnly(let reason):
            AppLogger.info(AppLogger.viewModel, "[\(viewModelId)] Text copied to clipboard: \(String(describing: reason))")
            updatedSession.insertionSuccess = true // Clipboard copy is still a success
            lastTranscriptionCopiedToClipboard = true

            // Don't show prompt for user preference or if already dismissed
            switch reason {
            case .userPreference, .accessibilityNotGranted:
                // User chose clipboard-only or already dismissed prompt
                break
            case .insertionFailed:
                // Insertion failed but clipboard worked - no prompt needed
                break
            }

        case .requiresAccessibilityPermission:
            AppLogger.info(AppLogger.viewModel, "[\(viewModelId)] Showing accessibility permission prompt")
            updatedSession.insertionSuccess = true // Clipboard copy is still a success
            lastTranscriptionCopiedToClipboard = true
            showAccessibilityPrompt = true
        }

        updatedSession.state = .completed
        self.currentSession = updatedSession

        AppLogger.stateChange(AppLogger.viewModel, from: true, to: false, context: "isInserting")
        isInserting = false

        // Save statistics
        AppLogger.debug(AppLogger.viewModel, "[\(viewModelId)] Saving session statistics...")
        await saveStatistics(session: updatedSession)
    }

    /// Handle audio level update - detect talking and manage inactivity timer
    private func handleAudioLevel(_ level: Double) {
        audioLevel = level

        // Detect if user is talking (audio above threshold)
        if level >= Constants.Audio.talkingThreshold {
            lastTalkingTime = Date()
            AppLogger.trace(AppLogger.viewModel, "[\(viewModelId)] Talking detected, level=\(String(format: "%.3f", level))")
        }
        // Note: Legacy short-pause silence timer disabled in favor of 30-second inactivity timeout
    }

    /// Start the inactivity timer that checks for prolonged silence
    private func startInactivityTimer() {
        inactivityTimer?.invalidate()
        inactivityTimeoutTriggered = false  // Reset flag on timer start

        // Check every second if we've exceeded the inactivity timeout
        // Using synchronous callback on main run loop (Timer runs on main), then dispatch to MainActor
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            // Timer callbacks run on main run loop which is MainActor-compatible
            // Use explicit @MainActor Task to ensure proper isolation (bug fix)
            Task { @MainActor [weak self] in
                self?.checkInactivity()
            }
        }
        inactivityTimer = timer
        deinitInactivityTimer = timer
        AppLogger.debug(AppLogger.viewModel, "[\(viewModelId)] Inactivity timer started (\(Constants.Audio.inactivityTimeout)s timeout)")
    }

    /// Check if inactivity timeout has been exceeded
    private func checkInactivity() {
        // Guard against double-triggering (bug fix: race condition between timer fires)
        guard isRecording, !inactivityTimeoutTriggered, let lastTalking = lastTalkingTime else { return }

        let silenceDuration = Date().timeIntervalSince(lastTalking)

        if silenceDuration >= Constants.Audio.inactivityTimeout {
            // Set flag BEFORE invalidating to prevent concurrent triggers
            inactivityTimeoutTriggered = true
            AppLogger.info(AppLogger.viewModel, "[\(viewModelId)] Inactivity timeout reached (\(String(format: "%.1f", silenceDuration))s of silence)")
            // Invalidate timer immediately to prevent multiple timeout triggers
            inactivityTimer?.invalidate()
            inactivityTimer = nil
            deinitInactivityTimer = nil
            Task { @MainActor [weak self] in
                await self?.onInactivityTimeout()
            }
        }
    }

    /// Called when inactivity timeout is reached
    private func onInactivityTimeout() async {
        // Double-check recording state and timeout flag (bug fix: race with manual stop)
        guard isRecording, inactivityTimeoutTriggered else {
            AppLogger.debug(AppLogger.viewModel, "[\(viewModelId)] onInactivityTimeout: state changed, skipping")
            return
        }
        do {
            AppLogger.info(AppLogger.viewModel, "[\(viewModelId)] Auto-stopping recording due to inactivity")
            try await stopRecording()
        } catch RecordingError.notRecording {
            // Expected if user manually stopped - not an error
            AppLogger.debug(AppLogger.viewModel, "[\(viewModelId)] Recording already stopped when inactivity triggered")
        } catch {
            AppLogger.error(AppLogger.viewModel, "[\(viewModelId)] Failed to stop on inactivity: \(error.localizedDescription)")
            errorMessage = "Failed to stop recording: \(error.localizedDescription)"
        }
    }
}

// MARK: - Private Helpers
extension RecordingViewModel {
    /// Check microphone permission and show prompt if not granted
    /// Returns true if permission is granted, false if prompt is shown
    fileprivate func ensureMicrophonePermission() async throws {
        // Use shared permissionService to avoid state fragmentation (bug fix)
        // Check if already granted
        if await permissionService.checkMicrophonePermission() {
            AppLogger.debug(AppLogger.viewModel, "[\(viewModelId)] Microphone permission already granted")
            return
        }

        // Try requesting permission (shows system dialog if not determined)
        do {
            try await permissionService.requestMicrophonePermission()
            AppLogger.info(AppLogger.viewModel, "[\(viewModelId)] Microphone permission granted via system dialog")
            return
        } catch PermissionError.microphoneDenied {
            // Permission was denied - show inline prompt and start polling
            AppLogger.info(AppLogger.viewModel, "[\(viewModelId)] Microphone permission denied, showing inline prompt")
            showMicrophonePrompt = true
            startMicrophonePermissionPolling()
            throw PermissionError.microphoneDenied
        }
    }

    /// Start polling for microphone permission status
    fileprivate func startMicrophonePermissionPolling() {
        // Cancel any existing polling task
        microphonePermissionPollingTask?.cancel()

        AppLogger.debug(AppLogger.viewModel, "[\(viewModelId)] Starting microphone permission polling")

        // Use explicit @MainActor to ensure proper isolation (bug fix)
        microphonePermissionPollingTask = Task { @MainActor [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                // Wait 1 second between polls
                try? await Task.sleep(nanoseconds: 1_000_000_000)

                guard !Task.isCancelled, !self.isBeingDeallocated else { break }

                // Check if permission is now granted using shared service (bug fix)
                if await self.permissionService.checkMicrophonePermission() {
                    AppLogger.info(
                        AppLogger.viewModel,
                        "[\(self.viewModelId)] Microphone permission granted via polling"
                    )
                    await self.onMicrophonePermissionGranted()
                    break
                }
            }

            AppLogger.debug(
                AppLogger.viewModel,
                "[\(self.viewModelId)] Microphone permission polling stopped"
            )
        }
    }

    fileprivate func saveStatistics(session: RecordingSession) async {
        do {
            try await statisticsService.recordSession(session)
        } catch {
            AppLogger.warning(AppLogger.viewModel, "[\(viewModelId)] Stats save failed: \(error)")
        }
    }
}

// MARK: - Recording Errors
enum RecordingError: LocalizedError, Equatable, Sendable {
    case alreadyRecording, notRecording, audioCaptureFailed(String)
    case noAudioCaptured, noActiveSession, transcriptionFailed(String), textInsertionFailed(String)

    var errorDescription: String? {
        switch self {
        case .alreadyRecording: return "Recording is already in progress"
        case .notRecording: return "No active recording to stop"
        case .audioCaptureFailed(let msg): return "Audio capture failed: \(msg)"
        case .noAudioCaptured: return "No audio was captured"
        case .noActiveSession: return "No active recording session"
        case .transcriptionFailed(let msg): return "Transcription failed: \(msg)"
        case .textInsertionFailed(let msg): return "Text insertion failed: \(msg)"
        }
    }
}

// swiftlint:enable file_length type_body_length
