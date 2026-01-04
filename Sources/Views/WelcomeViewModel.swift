// WelcomeViewModel.swift
// macOS Local Speech-to-Text Application
//
// Phase 2.2: Single-screen WelcomeView replacing multi-step onboarding
// ViewModel managing microphone permission and audio testing

import AVFoundation
import Foundation
import Observation
import OSLog

/// WelcomeViewModel manages the welcome screen state and microphone testing
@Observable
@MainActor
final class WelcomeViewModel {
    // MARK: - Published State

    /// Whether microphone permission is granted
    var isPermissionGranted: Bool = false

    /// Whether microphone test is active
    var isTesting: Bool = false

    /// Real-time audio level (0.0 - 1.0)
    var audioLevel: Float = 0.0

    /// Error message (if any)
    var errorMessage: String?

    /// Current sample phrase index for typing animation
    var currentPhraseIndex: Int = 0

    /// Current character count for typing animation
    var displayedCharacterCount: Int = 0

    // MARK: - Callback

    /// Called when user completes welcome flow
    var onComplete: (() -> Void)?

    // MARK: - Sample Phrases

    /// Sample phrases to cycle through in output preview
    let samplePhrases: [String] = [
        "Hello, this is a test of the speech recognition.",
        "Dictate emails, notes, and messages hands-free.",
        "Works offline with complete privacy.",
        "Supports 25 languages with high accuracy."
    ]

    // MARK: - Dependencies
    // Use @ObservationIgnored to prevent @Observable from tracking services
    // This is critical for avoiding executor check crashes with actor existentials

    @ObservationIgnored private let permissionService: any PermissionChecker
    @ObservationIgnored private let settingsService: any SettingsServiceProtocol
    @ObservationIgnored private var audioService: AudioCaptureService?

    // MARK: - Private State

    @ObservationIgnored private var phraseTimer: Timer?
    @ObservationIgnored private var typingTimer: Timer?
    // nonisolated copies for deinit access (deinit cannot access MainActor-isolated state)
    @ObservationIgnored private nonisolated(unsafe) var deinitPhraseTimer: Timer?
    @ObservationIgnored private nonisolated(unsafe) var deinitTypingTimer: Timer?

    /// Unique ID for logging
    @ObservationIgnored private let viewModelId: String

    // MARK: - Initialization

    init(
        permissionService: any PermissionChecker = PermissionService(),
        settingsService: any SettingsServiceProtocol = SettingsService()
    ) {
        self.viewModelId = UUID().uuidString.prefix(8).description
        self.permissionService = permissionService
        self.settingsService = settingsService
        AppLogger.lifecycle(AppLogger.viewModel, self, event: "init[\(viewModelId)]")

        // Check initial permission status
        Task { [weak self] in
            await self?.checkMicrophonePermission()
        }
    }

    deinit {
        AppLogger.trace(AppLogger.viewModel, "WelcomeViewModel[\(viewModelId)] deallocating")
        deinitPhraseTimer?.invalidate()
        deinitTypingTimer?.invalidate()
    }

    // MARK: - Public Methods

    /// Check microphone permission status
    func checkMicrophonePermission() async {
        isPermissionGranted = await permissionService.checkMicrophonePermission()
        AppLogger.debug(AppLogger.viewModel, "[\(viewModelId)] Microphone permission: \(isPermissionGranted)")
    }

    /// Request microphone permission
    func requestMicrophonePermission() async {
        errorMessage = nil
        do {
            try await permissionService.requestMicrophonePermission()
            isPermissionGranted = await permissionService.checkMicrophonePermission()
            AppLogger.info(AppLogger.viewModel, "[\(viewModelId)] Microphone permission granted: \(isPermissionGranted)")
        } catch {
            AppLogger.error(AppLogger.viewModel, "[\(viewModelId)] Microphone permission error: \(error.localizedDescription)")
            errorMessage = "Microphone access was denied. Please grant access in System Settings > Privacy & Security > Microphone."
        }
    }

    /// Start microphone test with live audio level
    func startMicrophoneTest() async {
        guard isPermissionGranted else {
            errorMessage = "Microphone permission required"
            return
        }

        guard !isTesting else { return }

        AppLogger.info(AppLogger.viewModel, "[\(viewModelId)] Starting microphone test")
        isTesting = true
        errorMessage = nil

        do {
            let service = AudioCaptureService()
            audioService = service

            try await service.startCapture { @Sendable [weak self] level in
                Task { @MainActor in
                    self?.audioLevel = Float(level)
                }
            }

            AppLogger.debug(AppLogger.viewModel, "[\(viewModelId)] Microphone test started")
        } catch {
            AppLogger.error(AppLogger.viewModel, "[\(viewModelId)] Microphone test failed: \(error.localizedDescription)")
            errorMessage = "Failed to start microphone: \(error.localizedDescription)"
            isTesting = false
            audioService = nil
        }
    }

    /// Stop microphone test
    func stopMicrophoneTest() async {
        guard isTesting, let service = audioService else { return }

        AppLogger.info(AppLogger.viewModel, "[\(viewModelId)] Stopping microphone test")

        do {
            _ = try await service.stopCapture()
        } catch {
            AppLogger.warning(AppLogger.viewModel, "[\(viewModelId)] Error stopping mic test: \(error.localizedDescription)")
        }

        isTesting = false
        audioLevel = 0.0
        audioService = nil
        AppLogger.debug(AppLogger.viewModel, "[\(viewModelId)] Microphone test stopped")
    }

    /// Toggle microphone test
    func toggleMicrophoneTest() async {
        if isTesting {
            await stopMicrophoneTest()
        } else {
            await startMicrophoneTest()
        }
    }

    /// Start the sample phrase cycling animation
    func startPhraseAnimation() {
        // Reset state
        currentPhraseIndex = 0
        displayedCharacterCount = 0

        // Start typing animation
        startTypingAnimation()

        // Cycle phrases every 4 seconds
        let timer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.advanceToNextPhrase()
            }
        }
        phraseTimer = timer
        deinitPhraseTimer = timer
    }

    /// Stop phrase animation
    func stopPhraseAnimation() {
        phraseTimer?.invalidate()
        phraseTimer = nil
        deinitPhraseTimer = nil
        typingTimer?.invalidate()
        typingTimer = nil
        deinitTypingTimer = nil
    }

    /// Complete the welcome flow
    func complete() {
        AppLogger.info(AppLogger.viewModel, "[\(viewModelId)] Welcome flow completed")

        // Save onboarding state
        var settings = settingsService.load()
        settings.onboarding.completed = true
        settings.onboarding.permissionsGranted.microphone = isPermissionGranted

        do {
            try settingsService.save(settings)
        } catch {
            AppLogger.error(AppLogger.viewModel, "[\(viewModelId)] Failed to save settings: \(error.localizedDescription)")
        }

        // Stop any active test
        Task {
            await stopMicrophoneTest()
        }

        // Stop animations
        stopPhraseAnimation()

        // Invoke completion callback
        onComplete?()
    }

    // MARK: - Private Methods

    /// Advance to next sample phrase
    private func advanceToNextPhrase() {
        currentPhraseIndex = (currentPhraseIndex + 1) % samplePhrases.count
        displayedCharacterCount = 0
        startTypingAnimation()
    }

    /// Start typing animation for current phrase
    private func startTypingAnimation() {
        typingTimer?.invalidate()

        let currentPhrase = samplePhrases[currentPhraseIndex]
        let totalChars = currentPhrase.count

        // Type one character every 30ms for a natural typing feel
        let timer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self = self else {
                    timer.invalidate()
                    return
                }

                if self.displayedCharacterCount < totalChars {
                    self.displayedCharacterCount += 1
                } else {
                    timer.invalidate()
                }
            }
        }
        typingTimer = timer
        deinitTypingTimer = timer
    }

    /// Get the currently displayed portion of the sample phrase
    var displayedText: String {
        let phrase = samplePhrases[currentPhraseIndex]
        let endIndex = phrase.index(phrase.startIndex, offsetBy: min(displayedCharacterCount, phrase.count))
        return String(phrase[..<endIndex])
    }
}
