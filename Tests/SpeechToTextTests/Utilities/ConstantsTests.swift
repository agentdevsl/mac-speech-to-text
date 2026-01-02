import XCTest
@testable import SpeechToText

final class ConstantsTests: XCTestCase {

    // MARK: - Audio Constants Tests

    func test_audio_sampleRate_is16kHz() {
        // Given/When
        let sampleRate = Constants.Audio.sampleRate

        // Then
        XCTAssertEqual(sampleRate, 16000)
    }

    func test_audio_channels_isMono() {
        // Given/When
        let channels = Constants.Audio.channels

        // Then
        XCTAssertEqual(channels, 1)
    }

    func test_audio_chunkSize_is100msAt16kHz() {
        // Given/When
        let chunkSize = Constants.Audio.chunkSize

        // Then
        // 100ms at 16kHz = 1600 samples
        XCTAssertEqual(chunkSize, 1600)
    }

    func test_audio_maxRecordingDuration_is5Minutes() {
        // Given/When
        let maxDuration = Constants.Audio.maxRecordingDuration

        // Then
        XCTAssertEqual(maxDuration, 300) // 5 minutes = 300 seconds
    }

    func test_audio_silenceThresholds_areInValidRange() {
        // Given/When
        let defaultThreshold = Constants.Audio.defaultSilenceThreshold
        let minThreshold = Constants.Audio.minSilenceThreshold
        let maxThreshold = Constants.Audio.maxSilenceThreshold

        // Then
        XCTAssertGreaterThanOrEqual(defaultThreshold, minThreshold)
        XCTAssertLessThanOrEqual(defaultThreshold, maxThreshold)
        XCTAssertEqual(defaultThreshold, 1.5)
        XCTAssertEqual(minThreshold, 0.5)
        XCTAssertEqual(maxThreshold, 3.0)
    }

    // MARK: - Performance Constants Tests

    func test_performance_targetHotkeyLatency_is50ms() {
        // Given/When
        let latency = Constants.Performance.targetHotkeyLatency

        // Then
        XCTAssertEqual(latency, 0.050)
    }

    func test_performance_targetTranscriptionLatency_is100ms() {
        // Given/When
        let latency = Constants.Performance.targetTranscriptionLatency

        // Then
        XCTAssertEqual(latency, 0.100)
    }

    func test_performance_targetWaveformFPS_is30() {
        // Given/When
        let fps = Constants.Performance.targetWaveformFPS

        // Then
        XCTAssertEqual(fps, 30)
    }

    func test_performance_memoryTargets_areReasonable() {
        // Given/When
        let idleMemory = Constants.Performance.idleMemoryTarget
        let activeMemory = Constants.Performance.activeMemoryTarget

        // Then
        XCTAssertEqual(idleMemory, 200 * 1024 * 1024) // 200MB
        XCTAssertEqual(activeMemory, 500 * 1024 * 1024) // 500MB
        XCTAssertLessThan(idleMemory, activeMemory)
    }

    // MARK: - UI Constants Tests

    func test_ui_modalCornerRadius_isReasonable() {
        // Given/When
        let cornerRadius = Constants.UI.modalCornerRadius

        // Then
        XCTAssertEqual(cornerRadius, 16)
        XCTAssertGreaterThan(cornerRadius, 0)
    }

    func test_ui_modalPadding_isReasonable() {
        // Given/When
        let padding = Constants.UI.modalPadding

        // Then
        XCTAssertEqual(padding, 32)
        XCTAssertGreaterThan(padding, 0)
    }

    func test_ui_animationDuration_is300ms() {
        // Given/When
        let duration = Constants.UI.animationDuration

        // Then
        XCTAssertEqual(duration, 0.3)
    }

    func test_ui_springParameters_areValid() {
        // Given/When
        let response = Constants.UI.springResponse
        let damping = Constants.UI.springDampingFraction

        // Then
        XCTAssertEqual(response, 0.5)
        XCTAssertEqual(damping, 0.7)
        XCTAssertGreaterThan(response, 0)
        XCTAssertGreaterThan(damping, 0)
        XCTAssertLessThanOrEqual(damping, 1.0)
    }

    // MARK: - Defaults Constants Tests

    func test_defaults_defaultLanguage_isEnglish() {
        // Given/When
        let language = Constants.Defaults.defaultLanguage

        // Then
        XCTAssertEqual(language, "en")
    }

    func test_defaults_defaultHotkeyCode_isSpace() {
        // Given/When
        let keyCode = Constants.Defaults.defaultHotkeyCode

        // Then
        XCTAssertEqual(keyCode, 49) // Space key
    }

    func test_defaults_audioSensitivity_isInValidRange() {
        // Given/When
        let sensitivity = Constants.Defaults.defaultAudioSensitivity

        // Then
        XCTAssertEqual(sensitivity, 0.3)
        XCTAssertGreaterThanOrEqual(sensitivity, 0.0)
        XCTAssertLessThanOrEqual(sensitivity, 1.0)
    }

    func test_defaults_confidenceThreshold_isInValidRange() {
        // Given/When
        let threshold = Constants.Defaults.defaultConfidenceThreshold

        // Then
        XCTAssertEqual(threshold, 0.5)
        XCTAssertGreaterThanOrEqual(threshold, 0.0)
        XCTAssertLessThanOrEqual(threshold, 1.0)
    }

    // MARK: - Storage Constants Tests

    func test_storage_settingsKey_isCorrect() {
        // Given/When
        let key = Constants.Storage.settingsKey

        // Then
        XCTAssertEqual(key, "com.speechtotext.settings")
        XCTAssertFalse(key.isEmpty)
    }

    func test_storage_statisticsKey_isCorrect() {
        // Given/When
        let key = Constants.Storage.statisticsKey

        // Then
        XCTAssertEqual(key, "com.speechtotext.statistics")
        XCTAssertFalse(key.isEmpty)
    }

    func test_storage_cacheDirectory_isCorrect() {
        // Given/When
        let dir = Constants.Storage.cacheDirectory

        // Then
        XCTAssertEqual(dir, "com.speechtotext.cache")
        XCTAssertFalse(dir.isEmpty)
    }

    func test_storage_modelsDirectory_isCorrect() {
        // Given/When
        let dir = Constants.Storage.modelsDirectory

        // Then
        XCTAssertEqual(dir, "FluidAudio/models")
        XCTAssertFalse(dir.isEmpty)
    }

    // MARK: - Validation Constants Tests

    func test_validation_maxWordCount_isReasonable() {
        // Given/When
        let maxWords = Constants.Validation.maxWordCount

        // Then
        XCTAssertEqual(maxWords, 10000)
        XCTAssertGreaterThan(maxWords, 0)
    }

    func test_validation_confidenceRange_isValid() {
        // Given/When
        let minConfidence = Constants.Validation.minConfidence
        let maxConfidence = Constants.Validation.maxConfidence

        // Then
        XCTAssertEqual(minConfidence, 0.0)
        XCTAssertEqual(maxConfidence, 1.0)
        XCTAssertLessThan(minConfidence, maxConfidence)
    }

    func test_validation_minAudioDuration_isReasonable() {
        // Given/When
        let minDuration = Constants.Validation.minAudioDuration

        // Then
        XCTAssertEqual(minDuration, 0.1) // 100ms
        XCTAssertGreaterThan(minDuration, 0)
    }

    // MARK: - Privacy Constants Tests

    func test_privacy_defaultRetentionDays_is7() {
        // Given/When
        let retention = Constants.Privacy.defaultRetentionDays

        // Then
        XCTAssertEqual(retention, 7)
        XCTAssertGreaterThan(retention, 0)
    }

    func test_privacy_retentionOptions_includeCommonValues() {
        // Given/When
        let options = Constants.Privacy.retentionOptions

        // Then
        XCTAssertTrue(options.contains(0)) // Never delete
        XCTAssertTrue(options.contains(7)) // 1 week
        XCTAssertTrue(options.contains(30)) // 1 month
        XCTAssertTrue(options.contains(90)) // 3 months
        XCTAssertTrue(options.contains(365)) // 1 year
        XCTAssertEqual(options.count, 5)
    }

    func test_privacy_retentionOptions_areSorted() {
        // Given/When
        let options = Constants.Privacy.retentionOptions

        // Then
        for i in 0..<(options.count - 1) {
            XCTAssertLessThan(options[i], options[i + 1])
        }
    }

    // MARK: - App Info Constants Tests

    func test_app_bundleIdentifier_isCorrect() {
        // Given/When
        let bundleId = Constants.App.bundleIdentifier

        // Then
        XCTAssertEqual(bundleId, "com.example.SpeechToText")
        XCTAssertFalse(bundleId.isEmpty)
    }

    func test_app_appName_isCorrect() {
        // Given/When
        let name = Constants.App.appName

        // Then
        XCTAssertEqual(name, "Speech to Text")
        XCTAssertFalse(name.isEmpty)
    }

    func test_app_version_isCorrect() {
        // Given/When
        let version = Constants.App.version

        // Then
        XCTAssertEqual(version, "1.0.0")
        XCTAssertFalse(version.isEmpty)
    }

    func test_app_buildNumber_isCorrect() {
        // Given/When
        let build = Constants.App.buildNumber

        // Then
        XCTAssertEqual(build, "1")
        XCTAssertFalse(build.isEmpty)
    }

    // MARK: - Consistency Tests

    func test_audio_chunkSize_matchesSampleRateAndDuration() {
        // Given
        let sampleRate = Constants.Audio.sampleRate
        let chunkSize = Constants.Audio.chunkSize

        // When
        let expectedChunkSize = sampleRate / 10 // 100ms chunks

        // Then
        XCTAssertEqual(chunkSize, expectedChunkSize)
    }

    func test_performance_latencies_areRealistic() {
        // Given
        let hotkeyLatency = Constants.Performance.targetHotkeyLatency
        let transcriptionLatency = Constants.Performance.targetTranscriptionLatency

        // Then
        // Hotkey should be faster than transcription
        XCTAssertLessThan(hotkeyLatency, transcriptionLatency)

        // Both should be under 1 second
        XCTAssertLessThan(hotkeyLatency, 1.0)
        XCTAssertLessThan(transcriptionLatency, 1.0)
    }

    func test_validation_confidenceRange_coversFullSpectrum() {
        // Given
        let minConfidence = Constants.Validation.minConfidence
        let maxConfidence = Constants.Validation.maxConfidence
        let defaultThreshold = Constants.Defaults.defaultConfidenceThreshold

        // Then
        XCTAssertGreaterThanOrEqual(defaultThreshold, minConfidence)
        XCTAssertLessThanOrEqual(defaultThreshold, maxConfidence)
    }

    // MARK: - Type Safety Tests

    func test_constants_haveCorrectTypes() {
        // Given/When/Then
        XCTAssertTrue(type(of: Constants.Audio.sampleRate) == Int.self)
        XCTAssertTrue(type(of: Constants.Audio.defaultSilenceThreshold) == TimeInterval.self)
        XCTAssertTrue(type(of: Constants.UI.modalCornerRadius) == CGFloat.self)
        XCTAssertTrue(type(of: Constants.Defaults.defaultAudioSensitivity) == Double.self)
        XCTAssertTrue(type(of: Constants.Storage.settingsKey) == String.self)
    }

    // MARK: - Immutability Tests

    func test_constants_areStaticAndImmutable() {
        // Given
        let sampleRate1 = Constants.Audio.sampleRate
        let sampleRate2 = Constants.Audio.sampleRate

        // When/Then
        XCTAssertEqual(sampleRate1, sampleRate2)

        // Constants should not be modifiable (enforced by Swift 'static let')
    }
}
