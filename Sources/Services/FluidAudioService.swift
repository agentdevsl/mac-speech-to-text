import AVFoundation
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
    func transcribe(samples: [Int16], sampleRate: Double) async throws -> TranscriptionResult
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

    /// Simulated error for testing (from launch arguments)
    private let simulatedError: SimulatedErrorType?

    init() {
        serviceId = UUID().uuidString.prefix(8).description
        // Check for simulated error from launch arguments
        // Note: ProcessInfo is accessed during init, which is fine for actors
        simulatedError = LaunchArguments.simulatedError
        AppLogger.service.debug("FluidAudioService[\(self.serviceId, privacy: .public)] created")
        if let error = simulatedError {
            AppLogger.service.debug("FluidAudioService[\(self.serviceId, privacy: .public)] will simulate error: \(error.rawValue, privacy: .public)")
        }
    }

    /// Initialize FluidAudio with specified language
    func initialize(language: String = "en") async throws {
        AppLogger.info(AppLogger.service, "[\(serviceId)] initialize(language: \(language)) called")

        // Check for simulated model loading error
        if simulatedError == .modelLoading {
            AppLogger.error(AppLogger.service, "[\(serviceId)] Simulating model loading error")
            throw FluidAudioError.initializationFailed("Simulated model loading failure for testing")
        }

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

    /// Transcribe audio samples at the given sample rate
    /// - Parameters:
    ///   - samples: Int16 audio samples at the native sample rate
    ///   - sampleRate: The sample rate of the input audio (e.g., 48000.0)
    func transcribe(samples: [Int16], sampleRate: Double) async throws -> TranscriptionResult {
        transcriptionCount += 1
        let transcriptionId = transcriptionCount

        print("[DEBUG] transcribe #\(transcriptionId): \(samples.count) samples at \(Int(sampleRate))Hz")
        fflush(stdout)
        AppLogger.info(AppLogger.service, "[\(serviceId)] transcribe #\(transcriptionId): \(samples.count) samples at \(Int(sampleRate))Hz")

        // Check for simulated transcription error
        if simulatedError == .transcription {
            AppLogger.error(AppLogger.service, "[\(serviceId)] Simulating transcription error")
            throw FluidAudioError.transcriptionFailed("Simulated transcription failure for testing")
        }

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

            // Resample to 16kHz if needed using FluidAudio's AudioConverter
            let finalSamples: [Float]
            let targetSampleRate = Double(Constants.Audio.sampleRate)

            if abs(sampleRate - targetSampleRate) > 1.0 {
                // Need to resample: create AVAudioPCMBuffer and use AudioConverter
                print("[DEBUG] Resampling from \(Int(sampleRate))Hz to \(Int(targetSampleRate))Hz...")
                fflush(stdout)

                guard let sourceFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false) else {
                    throw FluidAudioError.invalidAudioFormat
                }

                guard let buffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: AVAudioFrameCount(floatSamples.count)) else {
                    throw FluidAudioError.invalidAudioFormat
                }
                buffer.frameLength = AVAudioFrameCount(floatSamples.count)

                // Copy float samples into buffer
                if let channelData = buffer.floatChannelData {
                    for index in 0..<floatSamples.count {
                        channelData[0][index] = floatSamples[index]
                    }
                }

                // Use FluidAudio's AudioConverter to resample
                let audioConverter = AudioConverter()
                finalSamples = try audioConverter.resampleBuffer(buffer)
                print("[DEBUG] Resampled: \(floatSamples.count) samples -> \(finalSamples.count) samples")
                fflush(stdout)
            } else {
                // Already at 16kHz
                finalSamples = floatSamples
            }

            // Log sample statistics for debugging
            if AppLogger.currentLevel >= .trace {
                let minVal = finalSamples.min() ?? 0
                let maxVal = finalSamples.max() ?? 0
                let avgVal = finalSamples.reduce(0, +) / Float(finalSamples.count)
                AppLogger.trace(
                    AppLogger.service,
                    "[\(serviceId)] transcribe #\(transcriptionId): sample stats min=\(minVal) max=\(maxVal) avg=\(avgVal)"
                )
            }

            // Perform transcription
            print("[DEBUG] Calling FluidAudio ASR with \(finalSamples.count) samples at 16kHz...")
            fflush(stdout)
            AppLogger.debug(AppLogger.service, "[\(serviceId)] transcribe #\(transcriptionId): calling ASR with \(finalSamples.count) samples...")
            let result = try await asrManager.transcribe(finalSamples)

            let durationMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)

            // FluidAudio SDK returns confidence score directly (non-optional in v3)
            let confidence: Float = result.confidence

            print("[DEBUG] FluidAudio result: text='\(result.text.prefix(100))', confidence=\(confidence), durationMs=\(durationMs)")
            fflush(stdout)
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
            print("[DEBUG] FluidAudio transcription FAILED: \(error.localizedDescription)")
            fflush(stdout)
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
