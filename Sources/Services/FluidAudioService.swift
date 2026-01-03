import Foundation
import FluidAudio

/// Result of transcription
struct TranscriptionResult {
    let text: String
    let confidence: Float
    let durationMs: Int
}

/// Errors specific to FluidAudio integration
enum FluidAudioError: Error, LocalizedError, Sendable {
    case notInitialized
    case modelNotLoaded
    case initializationFailed(String)
    case transcriptionFailed(String)
    case invalidAudioFormat
    case languageNotSupported(String)

    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "FluidAudio service has not been initialized"
        case .modelNotLoaded:
            return "Language model has not been loaded"
        case .initializationFailed(let message):
            return "Failed to initialize FluidAudio: \(message)"
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        case .invalidAudioFormat:
            return "Invalid audio format. Expected 16kHz mono Int16 samples"
        case .languageNotSupported(let lang):
            return "Language '\(lang)' is not supported"
        }
    }
}

/// Swift actor wrapping FluidAudio SDK for thread-safe ASR
actor FluidAudioService {
    private var asrManager: AsrManager?
    private var currentLanguage: String = "en"
    private var isLanguageSwitching: Bool = false
    private var models: AsrModels?
    private var isInitialized = false

    init() {}

    /// Initialize FluidAudio with specified language
    func initialize(language: String = "en") async throws {
        guard !isInitialized else { return }

        do {
            // Download and load models (FluidAudio handles caching)
            let models = try await AsrModels.downloadAndLoad(version: .v3)
            self.models = models

            // Initialize ASR manager with default config
            let config = ASRConfig.default
            let manager = AsrManager(config: config)
            try await manager.initialize(models: models)

            self.asrManager = manager
            self.currentLanguage = language
            self.isInitialized = true
        } catch {
            throw FluidAudioError.initializationFailed(error.localizedDescription)
        }
    }

    /// Transcribe audio samples
    func transcribe(samples: [Int16]) async throws -> TranscriptionResult {
        guard let asrManager = asrManager else {
            throw FluidAudioError.notInitialized
        }

        guard !samples.isEmpty else {
            throw FluidAudioError.invalidAudioFormat
        }

        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            // Convert Int16 samples to Float (FluidAudio expects Float in range [-1.0, 1.0])
            let floatSamples = samples.map { Float($0) / 32768.0 }

            // Perform transcription
            let result = try await asrManager.transcribe(floatSamples)

            let durationMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)

            return TranscriptionResult(
                text: result.text,
                confidence: result.confidence ?? 0.95,
                durationMs: durationMs
            )
        } catch {
            throw FluidAudioError.transcriptionFailed(error.localizedDescription)
        }
    }

    /// Switch to a different language
    /// Note: Parakeet TDT v3 is multilingual, so no model reload is needed
    func switchLanguage(to language: String) async throws {
        guard SupportedLanguage.isSupported(language) else {
            throw FluidAudioError.languageNotSupported(language)
        }

        // FluidAudio Parakeet TDT v3 supports all 25 European languages
        // No need to reload model - it's multilingual
        currentLanguage = language
    }

    /// Get current language
    func getCurrentLanguage() -> String {
        currentLanguage
    }

    /// Check if service is initialized
    func checkInitialized() -> Bool {
        isInitialized
    }

    /// Shutdown and clean up resources
    func shutdown() {
        asrManager = nil
        models = nil
        isInitialized = false
    }
}
