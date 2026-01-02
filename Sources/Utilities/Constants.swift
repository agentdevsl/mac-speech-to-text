import Foundation

/// App-wide constants
enum Constants {
    // MARK: - Audio
    enum Audio {
        static let sampleRate: Int = 16000 // 16kHz
        static let channels: Int = 1 // Mono
        static let chunkSize: Int = 1600 // 100ms chunks at 16kHz
        static let maxRecordingDuration: TimeInterval = 300 // 5 minutes
        static let defaultSilenceThreshold: TimeInterval = 1.5 // seconds
        static let minSilenceThreshold: TimeInterval = 0.5
        static let maxSilenceThreshold: TimeInterval = 3.0
    }

    // MARK: - Performance
    enum Performance {
        static let targetHotkeyLatency: TimeInterval = 0.050 // 50ms
        static let targetTranscriptionLatency: TimeInterval = 0.100 // 100ms
        static let targetWaveformFPS: Int = 30
        static let idleMemoryTarget: Int = 200 * 1024 * 1024 // 200MB
        static let activeMemoryTarget: Int = 500 * 1024 * 1024 // 500MB
    }

    // MARK: - UI
    enum UI {
        static let modalCornerRadius: CGFloat = 16
        static let modalPadding: CGFloat = 32
        static let animationDuration: TimeInterval = 0.3
        static let springResponse: Double = 0.5
        static let springDampingFraction: Double = 0.7
    }

    // MARK: - Defaults
    enum Defaults {
        static let defaultLanguage = "en"
        static let defaultHotkeyCode = 49 // Space
        static let defaultAudioSensitivity = 0.3
        static let defaultConfidenceThreshold = 0.5
    }

    // MARK: - Storage
    enum Storage {
        static let settingsKey = "com.speechtotext.settings"
        static let statisticsKey = "com.speechtotext.statistics"
        static let cacheDirectory = "com.speechtotext.cache"
        static let modelsDirectory = "FluidAudio/models"
    }

    // MARK: - Validation
    enum Validation {
        static let maxWordCount = 10000
        static let minConfidence = 0.0
        static let maxConfidence = 1.0
        static let minAudioDuration = 0.1 // seconds
    }

    // MARK: - Privacy
    enum Privacy {
        static let defaultRetentionDays = 7
        static let retentionOptions = [0, 7, 30, 90, 365]
    }

    // MARK: - App Info
    enum App {
        static let bundleIdentifier = "com.example.SpeechToText"
        static let appName = "Speech to Text"
        static let version = "1.0.0"
        static let buildNumber = "1"
    }
}
