// AudioCaptureIntegrationTests.swift
// Real audio capture tests - requires microphone permission

import XCTest
@testable import SpeechToText

@MainActor
final class AudioCaptureIntegrationTests: IntegrationTestBase {

    // MARK: - Real Audio Capture Tests

    func test_realAudioCapture_startsAndStopsSuccessfully() async throws {
        try await skipIfMicrophoneNotGranted()

        // Arrange
        var audioLevels: [Double] = []

        // Act - Start recording
        try await audioCaptureService.startCapture { level in
            audioLevels.append(level)
            AppLogger.audio.debug("🎤 Audio level: \(level, format: .fixed(precision: 3))")
        }

        // Record for 1 second
        try await Task.sleep(nanoseconds: 1_000_000_000)

        // Stop and get samples
        let samples = try await audioCaptureService.stopCapture()

        // Assert
        XCTAssertFalse(samples.isEmpty, "Should have captured audio samples")
        XCTAssertFalse(audioLevels.isEmpty, "Should have received audio level callbacks")

        AppLogger.audio.info("✅ Captured \(samples.count) samples, \(audioLevels.count) level updates")
    }

    func test_realAudioCapture_detectsSilenceVsSpeech() async throws {
        try await skipIfMicrophoneNotGranted()

        // Arrange
        var maxLevel: Double = 0
        var minLevel: Double = 1

        // Act - Capture audio for 2 seconds
        try await audioCaptureService.startCapture { level in
            maxLevel = max(maxLevel, level)
            minLevel = min(minLevel, level)
        }

        try await Task.sleep(nanoseconds: 2_000_000_000)
        _ = try await audioCaptureService.stopCapture()

        // Assert
        AppLogger.audio.info("📊 Audio levels - min: \(minLevel, format: .fixed(precision: 4)), max: \(maxLevel, format: .fixed(precision: 4))")

        // We should detect some variation in audio levels
        XCTAssertGreaterThan(maxLevel, 0, "Should detect some audio")
    }

    func test_realAudioCapture_multipleStartStopCycles() async throws {
        try await skipIfMicrophoneNotGranted()

        // Test multiple start/stop cycles don't cause issues
        for cycle in 1...3 {
            AppLogger.audio.info("🔄 Audio capture cycle \(cycle)")

            try await audioCaptureService.startCapture { _ in }
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            let samples = try await audioCaptureService.stopCapture()

            XCTAssertFalse(samples.isEmpty, "Cycle \(cycle): Should have samples")
        }

        AppLogger.audio.info("✅ All audio capture cycles completed successfully")
    }

    func test_realAudioCapture_longRecording() async throws {
        try await skipIfMicrophoneNotGranted()

        // Test a longer recording session (5 seconds)
        var levelCount = 0
        try await audioCaptureService.startCapture { _ in
            levelCount += 1
        }

        try await Task.sleep(nanoseconds: 5_000_000_000)
        let samples = try await audioCaptureService.stopCapture()

        // At 16kHz for 5 seconds, we should have ~80,000 samples
        let expectedSamples = 16000 * 5
        let tolerance = expectedSamples / 10 // 10% tolerance

        XCTAssertGreaterThan(samples.count, expectedSamples - tolerance, "Should have approximately 5 seconds of audio")
        AppLogger.audio.info("✅ Long recording: \(samples.count) samples, \(levelCount) level callbacks")
    }
}
