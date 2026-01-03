import FluidAudio
import Foundation
import OSLog

/// Result of transcription
struct TranscriptionResult: Sendable {
    let text: String
    let confidence: Float
    let durationMs: Int
}

/// Protocol for FluidAudio service (enables mocking for tests)
protocol FluidAudioServiceProtocol: Actor {
    func initialize(language: String) async throws
    func transcribe(samples: [Int16]) async throws -> TranscriptionResult
    func switchLanguage(to language: String) async throws
    func getCurrentLanguage() -> String
    func checkInitialized() -> Bool
    func shutdown()
}

/// Errors specific to FluidAudio integration
enum FluidAudioError: Error, LocalizedError, Sendable, Equatable {
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
actor FluidAudioService: FluidAudioServiceProtocol {
    private var asrManager: AsrManager?
    private var currentLanguage: String = "en"
    private var isLanguageSwitching: Bool = false
    private var models: AsrModels?
    private var isInitialized = false
    private let serviceId: String
    private var transcriptionCount: Int = 0

    init() {
        serviceId = UUID().uuidString.prefix(8).description
        AppLogger.service.debug("FluidAudioService[\(self.serviceId, privacy: .public)] created")
    }

    /// Initialize FluidAudio with specified language
    func initialize(language: String = "en") async throws {
        AppLogger.info(AppLogger.service, "[\(serviceId)] initialize(language: \(language)) called")

        guard !isInitialized else {
            AppLogger.debug(AppLogger.service, "[\(serviceId)] Already initialized, skipping")
            return
        }

        do {
            // Download and load models (FluidAudio handles caching)
            AppLogger.debug(AppLogger.service, "[\(serviceId)] Downloading/loading ASR models (v3)...")
            let startTime = CFAbsoluteTimeGetCurrent()
            let models = try await AsrModels.downloadAndLoad(version: .v3)
            let modelLoadTime = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
            self.models = models
            AppLogger.info(AppLogger.service, "[\(serviceId)] Models loaded in \(modelLoadTime)ms")

            // Initialize ASR manager with default config
            AppLogger.debug(AppLogger.service, "[\(serviceId)] Creating ASR manager with default config...")
            let config = ASRConfig.default
            let manager = AsrManager(config: config)

            AppLogger.debug(AppLogger.service, "[\(serviceId)] Initializing ASR manager...")
            let initStartTime = CFAbsoluteTimeGetCurrent()
            try await manager.initialize(models: models)
            let initTime = Int((CFAbsoluteTimeGetCurrent() - initStartTime) * 1000)
            AppLogger.info(AppLogger.service, "[\(serviceId)] ASR manager initialized in \(initTime)ms")

            self.asrManager = manager
            self.currentLanguage = language
            self.isInitialized = true
            AppLogger.info(AppLogger.service, "[\(serviceId)] FluidAudio initialization complete")
        } catch {
            AppLogger.error(AppLogger.service, "[\(serviceId)] Initialization failed: \(error.localizedDescription)")
            throw FluidAudioError.initializationFailed(error.localizedDescription)
        }
    }

    /// Transcribe audio samples
    func transcribe(samples: [Int16]) async throws -> TranscriptionResult {
        transcriptionCount += 1
        let transcriptionId = transcriptionCount

        AppLogger.info(AppLogger.service, "[\(serviceId)] transcribe #\(transcriptionId): \(samples.count) samples")

        guard let asrManager = asrManager else {
            AppLogger.error(AppLogger.service, "[\(serviceId)] transcribe #\(transcriptionId): NOT INITIALIZED")
            throw FluidAudioError.notInitialized
        }

        guard !samples.isEmpty else {
            AppLogger.error(AppLogger.service, "[\(serviceId)] transcribe #\(transcriptionId): empty samples")
            throw FluidAudioError.invalidAudioFormat
        }

        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            // Convert Int16 samples to Float (FluidAudio expects Float in range [-1.0, 1.0])
            AppLogger.debug(AppLogger.service, "[\(serviceId)] transcribe #\(transcriptionId): converting to float...")
            let floatSamples = samples.map { Float($0) / 32768.0 }

            // Log sample statistics for debugging
            if AppLogger.currentLevel >= .trace {
                let minVal = floatSamples.min() ?? 0
                let maxVal = floatSamples.max() ?? 0
                let avgVal = floatSamples.reduce(0, +) / Float(floatSamples.count)
                AppLogger.trace(
                    AppLogger.service,
                    "[\(serviceId)] transcribe #\(transcriptionId): sample stats min=\(minVal) max=\(maxVal) avg=\(avgVal)"
                )
            }

            // Perform transcription
            AppLogger.debug(AppLogger.service, "[\(serviceId)] transcribe #\(transcriptionId): calling ASR...")
            let result = try await asrManager.transcribe(floatSamples)

            let durationMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)

            // FluidAudio SDK returns confidence score directly (non-optional in v3)
            let confidence: Float = result.confidence

            AppLogger.info(
                AppLogger.service,
                "[\(serviceId)] transcribe #\(transcriptionId): completed in \(durationMs)ms, confidence=\(confidence), text=\"\(result.text.prefix(50))...\""
            )

            return TranscriptionResult(
                text: result.text,
                confidence: confidence,
                durationMs: durationMs
            )
        } catch {
            let durationMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
            AppLogger.error(
                AppLogger.service,
                "[\(serviceId)] transcribe #\(transcriptionId): FAILED after \(durationMs)ms: \(error.localizedDescription)"
            )
            throw FluidAudioError.transcriptionFailed(error.localizedDescription)
        }
    }

    /// Switch to a different language
    /// Note: Parakeet TDT v3 is multilingual, so no model reload is needed
    func switchLanguage(to language: String) async throws {
        AppLogger.info(AppLogger.service, "[\(serviceId)] switchLanguage from \(currentLanguage) to \(language)")

        guard SupportedLanguage.isSupported(language) else {
            AppLogger.error(AppLogger.service, "[\(serviceId)] Language not supported: \(language)")
            throw FluidAudioError.languageNotSupported(language)
        }

        // FluidAudio Parakeet TDT v3 supports all 25 European languages
        // No need to reload model - it's multilingual
        let oldLanguage = currentLanguage
        currentLanguage = language
        AppLogger.debug(AppLogger.service, "[\(serviceId)] Language switched: \(oldLanguage) -> \(language)")
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
        AppLogger.info(AppLogger.service, "[\(serviceId)] shutdown() called, \(transcriptionCount) transcriptions performed")
        asrManager = nil
        models = nil
        isInitialized = false
        currentLanguage = "en"
        AppLogger.debug(AppLogger.service, "[\(serviceId)] Shutdown complete")
    }
}
