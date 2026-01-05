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
        /// Inactivity timeout - auto-stop after this many seconds of no talking
        static let inactivityTimeout: TimeInterval = 30.0
        /// Audio level threshold to detect talking (0.0-1.0 normalized)
        static let talkingThreshold: Double = 0.02
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
    enum UserInterface {
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

    // MARK: - Voice Trigger (sherpa-onnx keyword spotting)
    enum VoiceTrigger {
        /// Default silence threshold after keyword detection (seconds)
        static let defaultSilenceThreshold: TimeInterval = 5.0
        /// Minimum silence threshold (seconds)
        static let minSilenceThreshold: TimeInterval = 1.0
        /// Maximum silence threshold (seconds)
        static let maxSilenceThreshold: TimeInterval = 10.0
        /// Default boosting score for keywords (1.0-2.0)
        static let defaultBoostingScore: Float = 1.5
        /// Default trigger threshold for keywords (0.0-1.0)
        static let defaultTriggerThreshold: Float = 0.35
        /// Maximum recording duration after keyword detection (seconds)
        static let maxRecordingDuration: TimeInterval = 60.0
        /// Keyword spotting model name
        static let modelName = "sherpa-onnx-kws-zipformer-gigaspeech-3.3M-2024-01-01"
        /// Model directory relative to Resources
        static let modelDirectory = "Models/kws"
        /// Sample rate expected by sherpa-onnx (16kHz)
        static let sampleRate: Int = 16000
        /// State polling interval for UI updates (seconds)
        static let statePollingInterval: TimeInterval = 0.1

        // MARK: - Model File Names
        /// Encoder ONNX model file name
        static let encoderFileName = "encoder-epoch-12-avg-2-chunk-16-left-64.onnx"
        /// Decoder ONNX model file name
        static let decoderFileName = "decoder-epoch-12-avg-2-chunk-16-left-64.onnx"
        /// Joiner ONNX model file name
        static let joinerFileName = "joiner-epoch-12-avg-2-chunk-16-left-64.onnx"
        /// Tokens file name
        static let tokensFileName = "tokens.txt"
        /// BPE model file name
        static let bpeModelFileName = "bpe.model"
        /// Keywords file name
        static let keywordsFileName = "keywords.txt"

        // MARK: - Model Path Helper

        /// Returns the path to the sherpa-onnx keyword spotting model directory in the app bundle
        /// Uses Bundle.module for SPM resource bundles, with fallback to Bundle.main for app bundles
        static var modelPath: String? {
            // First try SPM module bundle (for development builds)
            if let path = Bundle.module.path(forResource: modelName, ofType: nil, inDirectory: modelDirectory) {
                return path
            }
            // Fallback to main bundle (for app bundles built with Xcode)
            return Bundle.main.path(forResource: modelName, ofType: nil, inDirectory: modelDirectory)
        }

        /// Returns the full path to a specific model file within the model directory
        /// - Parameter fileName: The name of the model file (e.g., "encoder-epoch-12-avg-2-chunk-16-left-64.onnx")
        /// - Returns: The full path to the file, or nil if not found
        static func modelFilePath(_ fileName: String) -> String? {
            guard let basePath = modelPath else { return nil }
            let fullPath = (basePath as NSString).appendingPathComponent(fileName)
            return FileManager.default.fileExists(atPath: fullPath) ? fullPath : nil
        }

        /// Returns paths to all required model files, or nil if any are missing
        static var allModelFilePaths: (encoder: String, decoder: String, joiner: String, tokens: String, bpeModel: String)? {
            guard let encoder = modelFilePath(encoderFileName),
                  let decoder = modelFilePath(decoderFileName),
                  let joiner = modelFilePath(joinerFileName),
                  let tokens = modelFilePath(tokensFileName),
                  let bpeModel = modelFilePath(bpeModelFileName) else {
                return nil
            }
            return (encoder: encoder, decoder: decoder, joiner: joiner, tokens: tokens, bpeModel: bpeModel)
        }
    }
}
