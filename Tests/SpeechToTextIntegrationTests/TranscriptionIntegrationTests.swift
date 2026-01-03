// TranscriptionIntegrationTests.swift
// Real transcription tests - requires microphone and FluidAudio model

import XCTest
@testable import SpeechToText

@MainActor
final class TranscriptionIntegrationTests: IntegrationTestBase {

    // MARK: - FluidAudio Initialization

    func test_fluidAudio_initializesSuccessfully() async throws {
        // Act
        AppLogger.service.info("🚀 Initializing FluidAudio...")
        let startTime = CFAbsoluteTimeGetCurrent()

        try await fluidAudioService.initialize(language: "en")

        let duration = CFAbsoluteTimeGetCurrent() - startTime
        AppLogger.service.info("✅ FluidAudio initialized in \(duration, format: .fixed(precision: 2))s")

        // Assert
        let initialized = await fluidAudioService.checkInitialized()
        XCTAssertTrue(initialized)
    }

    func test_fluidAudio_switchesLanguages() async throws {
        // Arrange
        try await fluidAudioService.initialize(language: "en")

        // Act & Assert - Test multiple language switches
        let languages = ["es", "fr", "de", "it", "en"]

        for lang in languages {
            try await fluidAudioService.switchLanguage(to: lang)
            let current = await fluidAudioService.getCurrentLanguage()
            XCTAssertEqual(current, lang)
            AppLogger.service.info("✅ Switched to language: \(lang)")
        }
    }

    // MARK: - End-to-End Transcription

    func test_endToEnd_captureAndTranscribe() async throws {
        try await skipIfMicrophoneNotGranted()

        // Initialize FluidAudio
        AppLogger.service.info("🚀 Initializing FluidAudio for E2E test...")
        try await fluidAudioService.initialize(language: "en")

        // Capture audio (user should speak during this)
        print("\n⏺️  SPEAK NOW for 3 seconds...\n")
        AppLogger.audio.info("⏺️ Starting audio capture - SPEAK NOW")

        var audioLevels: [Double] = []
        try await audioCaptureService.startCapture { level in
            audioLevels.append(level)
        }

        // Record for 3 seconds
        try await Task.sleep(nanoseconds: 3_000_000_000)

        print("\n⏹️  Recording stopped\n")
        AppLogger.audio.info("⏹️ Stopping audio capture")

        let samples = try await audioCaptureService.stopCapture()

        // Transcribe
        AppLogger.service.info("🔄 Transcribing \(samples.count) samples...")
        let result = try await fluidAudioService.transcribe(samples: samples)

        // Log results
        AppLogger.service.info("""
        ✅ Transcription complete:
           Text: "\(result.text)"
           Confidence: \(result.confidence, format: .fixed(precision: 2))
           Duration: \(result.durationMs)ms
           Audio levels: min=\(audioLevels.min() ?? 0, format: .fixed(precision: 4)), max=\(audioLevels.max() ?? 0, format: .fixed(precision: 4))
        """)

        print("""

        ═══════════════════════════════════════════════
        📝 TRANSCRIPTION RESULT
        ═══════════════════════════════════════════════
        Text: "\(result.text)"
        Confidence: \(Int(result.confidence * 100))%
        Processing time: \(result.durationMs)ms
        ═══════════════════════════════════════════════

        """)

        // Assert
        XCTAssertFalse(samples.isEmpty, "Should have captured audio")
        // Note: result.text may be empty if no speech was detected
    }

    func test_transcription_withSilence() async throws {
        try await skipIfMicrophoneNotGranted()

        // Initialize FluidAudio
        try await fluidAudioService.initialize(language: "en")

        print("\n🤫 Recording SILENCE for 2 seconds (don't speak)...\n")

        // Capture silent audio
        try await audioCaptureService.startCapture { _ in }
        try await Task.sleep(nanoseconds: 2_000_000_000)
        let samples = try await audioCaptureService.stopCapture()

        // Transcribe
        let result = try await fluidAudioService.transcribe(samples: samples)

        AppLogger.service.info("🤫 Silence transcription result: '\(result.text)'")

        // Silent audio should produce empty or very short transcription
        print("Silence transcription: '\(result.text)'")
    }
}
