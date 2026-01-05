// VoiceTriggerMonitoringService.swift
// macOS Local Speech-to-Text Application
//
// Coordinator service for voice trigger (wake word) monitoring.
// Orchestrates WakeWordService, AudioCaptureService, FluidAudioService,
// and TextInsertionService to provide hands-free voice activation.

import AppKit
import AVFoundation
import Foundation
import Observation
import OSLog

// MARK: - Voice Trigger Monitoring Service

/// Coordinator service for voice trigger monitoring
///
/// This service orchestrates the complete voice trigger workflow:
/// 1. Continuously listens for wake words using WakeWordService
/// 2. When a wake word is detected, switches to audio capture mode
/// 3. Monitors for silence to determine when user has finished speaking
/// 4. Transcribes captured audio using FluidAudioService
/// 5. Inserts transcribed text using TextInsertionService
///
/// Thread Safety:
/// - This is a @MainActor class for UI binding compatibility
/// - Service dependencies are @ObservationIgnored to prevent @Observable tracking issues
/// - Audio callbacks use Task dispatch to hop to MainActor
@Observable
@MainActor
final class VoiceTriggerMonitoringService {
    // MARK: - Published State

    /// Current state of the voice trigger workflow
    var state: VoiceTriggerState = .idle

    /// Real-time audio level for visualization (0.0 - 1.0)
    var audioLevel: Double = 0.0

    /// Currently detected keyword (set when wake word is heard)
    var currentKeyword: String?

    /// Time remaining before silence timeout ends capture (nil when not capturing)
    var silenceTimeRemaining: TimeInterval?

    /// Last transcribed text (for display/debugging)
    var lastTranscribedText: String = ""

    /// Last error message for UI display
    var errorMessage: String?

    // MARK: - Dependencies
    // All services are @ObservationIgnored to prevent @Observable from tracking them
    // This is critical for actor existential types which can cause executor check crashes

    @ObservationIgnored private let wakeWordService: any WakeWordServiceProtocol
    @ObservationIgnored private let audioService: AudioCaptureService
    @ObservationIgnored private let fluidAudioService: any FluidAudioServiceProtocol
    @ObservationIgnored private let textInsertionService: TextInsertionService
    @ObservationIgnored private let settingsService: SettingsService

    // MARK: - Private State

    /// Captured audio samples during recording phase (Float for FluidAudio)
    @ObservationIgnored private var capturedSamples: [Int16] = []

    /// Sample rate of captured audio
    @ObservationIgnored private var capturedSampleRate: Double = Double(Constants.Audio.sampleRate)

    /// Path to wake word model (from configuration/bundle)
    @ObservationIgnored private var wakeWordModelPath: String = ""

    /// Timer for silence detection
    @ObservationIgnored private var silenceTimer: Timer?

    /// Timer for max recording duration
    @ObservationIgnored private var maxDurationTimer: Timer?

    /// Last time audio was detected above threshold
    @ObservationIgnored private var lastAudioTime: Date?

    /// Unique ID for logging
    @ObservationIgnored private let serviceId: String

    /// Flag to prevent double state transitions
    @ObservationIgnored private var isTransitioning: Bool = false

    /// Current voice trigger configuration (cached)
    @ObservationIgnored private var configuration: VoiceTriggerConfiguration = .default

    // nonisolated copies for deinit access (deinit cannot access MainActor-isolated state)
    @ObservationIgnored private nonisolated(unsafe) var deinitSilenceTimer: Timer?
    @ObservationIgnored private nonisolated(unsafe) var deinitMaxDurationTimer: Timer?

    // MARK: - Initialization

    init(
        wakeWordService: any WakeWordServiceProtocol,
        audioService: AudioCaptureService? = nil,
        fluidAudioService: any FluidAudioServiceProtocol = FluidAudioService(),
        textInsertionService: TextInsertionService = TextInsertionService(),
        settingsService: SettingsService = SettingsService()
    ) {
        self.serviceId = UUID().uuidString.prefix(8).description
        self.wakeWordService = wakeWordService
        self.audioService = audioService ?? AudioCaptureService(settingsService: settingsService)
        self.fluidAudioService = fluidAudioService
        self.textInsertionService = textInsertionService
        self.settingsService = settingsService

        AppLogger.lifecycle(AppLogger.service, self, event: "init[\(serviceId)]")
    }

    deinit {
        deinitSilenceTimer?.invalidate()
        deinitMaxDurationTimer?.invalidate()
        AppLogger.service.debug("VoiceTriggerMonitoringService[\(self.serviceId, privacy: .public)] deallocated")
    }

    // MARK: - Public Methods

    /// Start voice trigger monitoring
    ///
    /// Begins listening for configured wake words. When a wake word is detected,
    /// the service automatically transitions to capturing mode.
    ///
    /// - Throws: VoiceTriggerError if already monitoring or setup fails
    func startMonitoring() async throws {
        AppLogger.info(AppLogger.service, "[\(serviceId)] startMonitoring() called, state=\(state.description)")

        guard !isTransitioning else {
            AppLogger.warning(AppLogger.service, "[\(serviceId)] startMonitoring: transition in progress")
            throw VoiceTriggerError.wakeWordInitFailed("Transition already in progress")
        }

        guard state == .idle else {
            AppLogger.warning(AppLogger.service, "[\(serviceId)] startMonitoring: already active (state=\(state.description))")
            throw VoiceTriggerError.wakeWordInitFailed("Already monitoring")
        }

        isTransitioning = true
        defer { isTransitioning = false }

        // Load configuration
        let settings = settingsService.load()
        configuration = settings.voiceTrigger
        AppLogger.debug(AppLogger.service, "[\(serviceId)] Configuration loaded: \(configuration.keywords.count) keywords, silenceThreshold=\(configuration.silenceThresholdSeconds)s")

        // Clear previous state
        errorMessage = nil
        currentKeyword = nil
        lastTranscribedText = ""
        capturedSamples = []
        silenceTimeRemaining = nil

        do {
            // Configure wake word service with active keywords
            let activeKeywords = configuration.keywords.filter { $0.isEnabled }
            guard !activeKeywords.isEmpty else {
                AppLogger.error(AppLogger.service, "[\(serviceId)] No active keywords configured")
                throw VoiceTriggerError.noKeywordsConfigured
            }

            // Get wake word model path from bundle or configuration
            // swiftlint:disable:next todo
            // TODO: Replace with actual model path from configuration when model is bundled
            let modelPath = getWakeWordModelPath()
            wakeWordModelPath = modelPath

            // Initialize wake word service with model and keywords
            try await wakeWordService.initialize(modelPath: modelPath, keywords: activeKeywords)

            // Start audio capture for wake word processing
            try await audioService.startCapture { @Sendable [weak self] level in
                Task { @MainActor in self?.handleAudioLevel(level) }
            }

            // Transition to monitoring state
            AppLogger.stateChange(AppLogger.service, from: state, to: VoiceTriggerState.monitoring, context: "startMonitoring")
            state = .monitoring

            AppLogger.info(AppLogger.service, "[\(serviceId)] Voice trigger monitoring started")

        } catch {
            AppLogger.error(AppLogger.service, "[\(serviceId)] Failed to start monitoring: \(error.localizedDescription)")
            state = .error(.wakeWordInitFailed(error.localizedDescription))
            throw VoiceTriggerError.wakeWordInitFailed(error.localizedDescription)
        }
    }

    /// Get the path to the wake word model
    /// - Returns: Path to the sherpa-onnx keyword spotting model directory
    private func getWakeWordModelPath() -> String {
        // Try to find model in bundle first
        if let bundlePath = Bundle.main.resourcePath {
            let modelPath = "\(bundlePath)/wake_word_model"
            if FileManager.default.fileExists(atPath: modelPath) {
                return modelPath
            }
        }

        // Fall back to Application Support directory
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let modelPath = appSupport.appendingPathComponent("SpeechToText/wake_word_model").path
            return modelPath
        }

        // Last resort: use temp directory (for development/testing)
        return FileManager.default.temporaryDirectory.appendingPathComponent("wake_word_model").path
    }

    /// Stop voice trigger monitoring
    ///
    /// Stops all monitoring activity and returns to idle state.
    /// Any in-progress capture or transcription is cancelled.
    func stopMonitoring() {
        AppLogger.info(AppLogger.service, "[\(serviceId)] stopMonitoring() called, state=\(state.description)")

        // Stop timers
        silenceTimer?.invalidate()
        silenceTimer = nil
        deinitSilenceTimer = nil
        maxDurationTimer?.invalidate()
        maxDurationTimer = nil
        deinitMaxDurationTimer = nil

        // Stop services (fire and forget - we're stopping anyway)
        Task { [weak self] in
            guard let self else { return }
            await self.wakeWordService.shutdown()
            _ = try? await self.audioService.stopCapture()
        }

        // Clear state
        currentKeyword = nil
        silenceTimeRemaining = nil
        capturedSamples = []
        audioLevel = 0.0

        // Transition to idle
        AppLogger.stateChange(AppLogger.service, from: state, to: VoiceTriggerState.idle, context: "stopMonitoring")
        state = .idle

        AppLogger.debug(AppLogger.service, "[\(serviceId)] Voice trigger monitoring stopped")
    }

    /// Handle incoming audio buffer
    ///
    /// Routes audio data to the appropriate handler based on current state:
    /// - In monitoring mode: Sends to wake word service for keyword detection
    /// - In capturing mode: Accumulates samples for transcription
    ///
    /// - Parameter buffer: Audio buffer from capture service
    func handleAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        Task { @MainActor [weak self] in
            guard let self else { return }

            switch self.state {
            case .monitoring:
                // Convert buffer to Float samples for wake word detection
                let floatSamples = self.convertBufferToFloatSamples(buffer)
                guard !floatSamples.isEmpty else { return }

                // Route to wake word detection
                if let result = await self.wakeWordService.processFrame(floatSamples) {
                    self.handleWakeWordDetected(keyword: result.detectedKeyword)
                }

            case .capturing:
                // Accumulate samples for transcription
                self.accumulateSamples(from: buffer)

            default:
                // Ignore audio in other states
                break
            }
        }
    }

    /// Convert AVAudioPCMBuffer to Float samples normalized to [-1.0, 1.0]
    /// - Parameter buffer: Audio buffer to convert
    /// - Returns: Float samples suitable for wake word processing
    private func convertBufferToFloatSamples(_ buffer: AVAudioPCMBuffer) -> [Float] {
        let frameLength = Int(buffer.frameLength)

        if let floatData = buffer.floatChannelData {
            // Already float format
            return Array(UnsafeBufferPointer(start: floatData[0], count: frameLength))
        } else if let int16Data = buffer.int16ChannelData {
            // Convert Int16 to Float [-1.0, 1.0]
            let int16Samples = UnsafeBufferPointer(start: int16Data[0], count: frameLength)
            return int16Samples.map { Float($0) / 32768.0 }
        }

        return []
    }

    // MARK: - Private Methods

    /// Handle audio level updates from capture service
    private func handleAudioLevel(_ level: Double) {
        audioLevel = level

        // Track audio activity for silence detection
        if level >= Constants.Audio.talkingThreshold {
            lastAudioTime = Date()
            AppLogger.trace(AppLogger.service, "[\(serviceId)] Audio detected, level=\(String(format: "%.3f", level))")
        }
    }

    /// Handle wake word detection
    private func handleWakeWordDetected(keyword: String) {
        AppLogger.info(AppLogger.service, "[\(serviceId)] Wake word detected: \"\(keyword)\"")

        guard state == .monitoring else {
            AppLogger.warning(AppLogger.service, "[\(serviceId)] Wake word detected but not in monitoring state")
            return
        }

        // Update state - first transition to triggered
        currentKeyword = keyword
        AppLogger.stateChange(AppLogger.service, from: state, to: VoiceTriggerState.triggered(keyword: keyword), context: "wakeWordDetected")
        state = .triggered(keyword: keyword)

        // Play feedback if enabled
        if configuration.feedbackSoundEnabled {
            playFeedbackSound()
        }

        // Immediately transition to capturing
        AppLogger.stateChange(AppLogger.service, from: state, to: VoiceTriggerState.capturing, context: "startCapture")
        state = .capturing

        // Clear previous samples and start fresh capture
        capturedSamples = []
        lastAudioTime = Date()

        // Start silence detection timer
        startSilenceTimer()

        // Start max duration timer
        startMaxDurationTimer()

        AppLogger.debug(AppLogger.service, "[\(serviceId)] Capture started for keyword: \(keyword)")
    }

    /// Accumulate audio samples during capture phase
    private func accumulateSamples(from buffer: AVAudioPCMBuffer) {
        let frameLength = Int(buffer.frameLength)

        // Convert buffer to Int16 samples
        let samples: [Int16]
        if let floatData = buffer.floatChannelData {
            let floatSamples = UnsafeBufferPointer(start: floatData[0], count: frameLength)
            samples = floatSamples.map { sample in
                let clamped = max(-1.0, min(1.0, sample))
                return Int16(clamped * Float(Int16.max))
            }
        } else if let int16Data = buffer.int16ChannelData {
            samples = Array(UnsafeBufferPointer(start: int16Data[0], count: frameLength))
        } else {
            AppLogger.warning(AppLogger.service, "[\(serviceId)] Unsupported audio format in buffer")
            return
        }

        capturedSamples.append(contentsOf: samples)

        // Store sample rate from buffer format
        capturedSampleRate = buffer.format.sampleRate

        AppLogger.trace(
            AppLogger.service,
            "[\(serviceId)] Accumulated \(samples.count) samples, total=\(capturedSamples.count)"
        )
    }

    /// Start silence detection timer
    private func startSilenceTimer() {
        silenceTimer?.invalidate()

        // Update silence time remaining every 0.1 seconds
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkSilence()
            }
        }
        silenceTimer = timer
        deinitSilenceTimer = timer

        AppLogger.debug(
            AppLogger.service,
            "[\(serviceId)] Silence timer started (threshold: \(configuration.silenceThresholdSeconds)s)"
        )
    }

    /// Check for silence timeout
    private func checkSilence() {
        guard case .capturing = state else { return }
        guard let lastAudio = lastAudioTime else { return }

        let silenceDuration = Date().timeIntervalSince(lastAudio)
        let threshold = configuration.silenceThresholdSeconds

        // Update remaining time for UI
        silenceTimeRemaining = max(0, threshold - silenceDuration)

        if silenceDuration >= threshold {
            AppLogger.info(
                AppLogger.service,
                "[\(serviceId)] Silence threshold reached (\(String(format: "%.1f", silenceDuration))s)"
            )
            Task { @MainActor [weak self] in
                await self?.handleSilenceTimeout()
            }
        }
    }

    /// Handle silence timeout - stop capture and transcribe
    private func handleSilenceTimeout() async {
        AppLogger.info(AppLogger.service, "[\(serviceId)] handleSilenceTimeout()")

        // Stop timers
        silenceTimer?.invalidate()
        silenceTimer = nil
        deinitSilenceTimer = nil
        maxDurationTimer?.invalidate()
        maxDurationTimer = nil
        deinitMaxDurationTimer = nil
        silenceTimeRemaining = nil

        // Proceed to transcription if we have audio
        if !capturedSamples.isEmpty {
            await transcribeAndInsert()
        } else {
            AppLogger.warning(AppLogger.service, "[\(serviceId)] No audio captured, returning to monitoring")
            state = .monitoring
            currentKeyword = nil
        }
    }

    /// Start max duration timer
    private func startMaxDurationTimer() {
        maxDurationTimer?.invalidate()

        let timer = Timer.scheduledTimer(withTimeInterval: configuration.maxRecordingDuration, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                AppLogger.info(AppLogger.service, "[\(self.serviceId)] Max recording duration reached")
                await self.handleSilenceTimeout() // Reuse same flow
            }
        }
        maxDurationTimer = timer
        deinitMaxDurationTimer = timer

        AppLogger.debug(
            AppLogger.service,
            "[\(serviceId)] Max duration timer started (\(configuration.maxRecordingDuration)s)"
        )
    }

    /// Transcribe captured audio and insert text
    private func transcribeAndInsert() async {
        AppLogger.info(
            AppLogger.service,
            "[\(serviceId)] transcribeAndInsert() - \(capturedSamples.count) samples at \(Int(capturedSampleRate))Hz"
        )

        // Transition to transcribing state
        AppLogger.stateChange(AppLogger.service, from: state, to: VoiceTriggerState.transcribing, context: "transcribeAndInsert")
        state = .transcribing

        do {
            // Initialize FluidAudio if needed
            let settings = settingsService.load()
            try await fluidAudioService.initialize(language: settings.language.defaultLanguage)

            // Transcribe
            let result = try await fluidAudioService.transcribe(
                samples: capturedSamples,
                sampleRate: capturedSampleRate
            )

            AppLogger.info(
                AppLogger.service,
                "[\(serviceId)] Transcription complete: \"\(result.text.prefix(50))...\" (confidence: \(result.confidence))"
            )

            lastTranscribedText = result.text

            // Check if we got meaningful text
            let trimmedText = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedText.isEmpty else {
                AppLogger.warning(AppLogger.service, "[\(serviceId)] Empty transcription, returning to monitoring")
                state = .monitoring
                currentKeyword = nil
                capturedSamples = []
                return
            }

            // Transition to inserting state
            AppLogger.stateChange(AppLogger.service, from: state, to: VoiceTriggerState.inserting, context: "insertText")
            state = .inserting

            // Insert text
            let insertResult = await textInsertionService.insertTextWithFallback(trimmedText)

            switch insertResult {
            case .insertedViaAccessibility:
                AppLogger.info(AppLogger.service, "[\(serviceId)] Text inserted successfully")

            case .copiedToClipboardOnly(let reason):
                AppLogger.info(AppLogger.service, "[\(serviceId)] Text copied to clipboard: \(String(describing: reason))")

            case .requiresAccessibilityPermission:
                AppLogger.warning(AppLogger.service, "[\(serviceId)] Accessibility permission required")
            }

            // Return to monitoring state for next wake word
            AppLogger.stateChange(AppLogger.service, from: state, to: VoiceTriggerState.monitoring, context: "complete")
            state = .monitoring
            currentKeyword = nil
            capturedSamples = []

        } catch {
            AppLogger.error(AppLogger.service, "[\(serviceId)] Transcription/insertion failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            state = .error(.transcriptionFailed(error.localizedDescription))

            // Attempt recovery to monitoring state after brief delay
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                guard let self, case .error = self.state else { return }
                AppLogger.debug(AppLogger.service, "[\(self.serviceId)] Recovering from error to monitoring state")
                self.state = .monitoring
                self.errorMessage = nil
            }
        }
    }

    /// Play feedback sound when wake word is detected
    private func playFeedbackSound() {
        // Use system sound for minimal latency
        // NSSound.beep() is simple but works; could be enhanced with custom sound
        AppLogger.trace(AppLogger.service, "[\(serviceId)] Playing feedback sound")
        NSSound.beep()
    }
}
