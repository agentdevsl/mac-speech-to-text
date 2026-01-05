import Foundation
import OSLog

// MARK: - WakeWordResult

/// Result of wake word detection
struct WakeWordResult: Sendable {
    /// The keyword phrase that was detected
    let detectedKeyword: String

    /// Confidence score of the detection (0.0-1.0)
    let confidence: Float

    /// Timestamp when the keyword was detected
    let timestamp: Date
}

// MARK: - WakeWordError

/// Errors specific to wake word detection
enum WakeWordError: Error, LocalizedError, Sendable, Equatable {
    case modelNotFound(String)
    case initializationFailed(String)
    case invalidKeywords
    case processingFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotFound(let path):
            return "Wake word model not found at path: \(path)"
        case .initializationFailed(let message):
            return "Failed to initialize wake word service: \(message)"
        case .invalidKeywords:
            return "Invalid keywords configuration - at least one valid keyword is required"
        case .processingFailed(let message):
            return "Wake word processing failed: \(message)"
        }
    }
}

// MARK: - WakeWordServiceProtocol

/// Protocol for wake word detection service (enables mocking for tests)
protocol WakeWordServiceProtocol: Actor {
    /// Initialize the wake word spotter with model and keywords
    /// - Parameters:
    ///   - modelPath: Path to the sherpa-onnx keyword spotting model directory
    ///   - keywords: Array of trigger keywords to detect
    func initialize(modelPath: String, keywords: [TriggerKeyword]) async throws

    /// Process an audio frame and check for wake word detection
    /// - Parameter samples: Float audio samples (16kHz, mono, normalized [-1.0, 1.0])
    /// - Returns: WakeWordResult if a keyword was detected, nil otherwise
    func processFrame(_ samples: [Float]) -> WakeWordResult?

    /// Update the keywords being detected (requires re-initialization)
    /// - Parameter keywords: New array of trigger keywords
    func updateKeywords(_ keywords: [TriggerKeyword]) async throws

    /// Shutdown and release resources
    func shutdown()

    /// Whether the service is initialized and ready
    var isInitialized: Bool { get }
}

// MARK: - WakeWordService

/// Swift actor wrapping sherpa-onnx keyword spotting for thread-safe wake word detection
///
/// This service provides always-on wake word detection using sherpa-onnx's keyword spotting
/// functionality. It processes streaming audio frames and detects configured trigger keywords.
///
/// ## Usage
/// ```swift
/// let service = WakeWordService()
/// try await service.initialize(modelPath: "/path/to/model", keywords: [.heyClaudeDefault])
///
/// // In audio callback:
/// if let result = service.processFrame(audioSamples) {
///     print("Detected: \(result.detectedKeyword) with confidence \(result.confidence)")
/// }
/// ```
actor WakeWordService: WakeWordServiceProtocol {
    // MARK: - Private Properties

    /// Service instance identifier for logging
    private let serviceId: String

    /// Whether the service is initialized
    private var _isInitialized = false

    /// Current model path
    private var modelPath: String?

    /// Currently configured keywords
    private var currentKeywords: [TriggerKeyword] = []

    /// Keywords file content (generated from TriggerKeyword array)
    private var keywordsFileContent: String?

    // swiftlint:disable:next todo
    // TODO: sherpa-onnx integration
    // private var keywordSpotter: SherpaOnnxKeywordSpotter?
    // private var keywordSpotterStream: SherpaOnnxKeywordSpotterStream?

    /// Detection count for statistics
    private var detectionCount: Int = 0

    /// Frames processed count
    private var framesProcessed: Int = 0

    // MARK: - Initialization

    init() {
        serviceId = UUID().uuidString.prefix(8).description
        AppLogger.service.debug("WakeWordService[\(self.serviceId, privacy: .public)] created")
    }

    // MARK: - Public Properties

    var isInitialized: Bool {
        _isInitialized
    }

    // MARK: - Public Methods

    func initialize(modelPath: String, keywords: [TriggerKeyword]) async throws {
        AppLogger.info(
            AppLogger.service,
            "[\(serviceId)] initialize(modelPath: \(modelPath), keywords: \(keywords.count)) called"
        )

        // Validate model path exists
        guard FileManager.default.fileExists(atPath: modelPath) else {
            AppLogger.error(AppLogger.service, "[\(serviceId)] Model not found at path: \(modelPath)")
            throw WakeWordError.modelNotFound(modelPath)
        }

        // Validate keywords
        let enabledKeywords = keywords.filter { $0.isEnabled && $0.isValid }
        guard !enabledKeywords.isEmpty else {
            AppLogger.error(AppLogger.service, "[\(serviceId)] No valid enabled keywords provided")
            throw WakeWordError.invalidKeywords
        }

        // Generate keywords.txt content
        let keywordsContent = generateKeywordsFileContent(from: enabledKeywords)
        AppLogger.debug(AppLogger.service, "[\(serviceId)] Generated keywords file:\n\(keywordsContent)")

        // swiftlint:disable:next todo
        // TODO: Initialize sherpa-onnx keyword spotter
        // The following is placeholder code showing where sherpa-onnx calls will go:
        //
        // let config = SherpaOnnxKeywordSpotterConfig(
        //     featConfig: featConfig,
        //     modelConfig: modelConfig,
        //     maxActivePaths: 4,
        //     numTrailingBlanks: 1,
        //     keywordsScore: 1.0,
        //     keywordsThreshold: 0.25,
        //     keywordsFile: keywordsFilePath
        // )
        //
        // guard let spotter = SherpaOnnxKeywordSpotter(config: config) else {
        //     throw WakeWordError.initializationFailed("Failed to create keyword spotter")
        // }
        //
        // guard let stream = spotter.createStream() else {
        //     throw WakeWordError.initializationFailed("Failed to create keyword spotter stream")
        // }
        //
        // self.keywordSpotter = spotter
        // self.keywordSpotterStream = stream

        self.modelPath = modelPath
        self.currentKeywords = enabledKeywords
        self.keywordsFileContent = keywordsContent
        self._isInitialized = true

        AppLogger.info(
            AppLogger.service,
            "[\(serviceId)] WakeWordService initialized with \(enabledKeywords.count) keywords"
        )
    }

    func processFrame(_ samples: [Float]) -> WakeWordResult? {
        guard _isInitialized else {
            // Silently return nil if not initialized (common case during startup)
            return nil
        }

        guard !samples.isEmpty else {
            return nil
        }

        framesProcessed += 1

        // swiftlint:disable:next todo
        // TODO: Process audio through sherpa-onnx keyword spotter
        // The following is placeholder code showing where sherpa-onnx calls will go:
        //
        // guard let stream = keywordSpotterStream,
        //       let spotter = keywordSpotter else {
        //     return nil
        // }
        //
        // // Accept waveform (16kHz mono float samples)
        // stream.acceptWaveform(samples: samples, sampleRate: 16000)
        //
        // // Decode
        // while spotter.isReady(stream) {
        //     spotter.decode(stream)
        // }
        //
        // // Check for detection
        // let keyword = spotter.getResult(stream)
        // if !keyword.isEmpty {
        //     detectionCount += 1
        //     AppLogger.info(AppLogger.service, "[\(serviceId)] Detected keyword: \(keyword)")
        //
        //     return WakeWordResult(
        //         detectedKeyword: keyword,
        //         confidence: 1.0, // sherpa-onnx may provide confidence in result
        //         timestamp: Date()
        //     )
        // }

        // Stub implementation: no detection
        return nil
    }

    func updateKeywords(_ keywords: [TriggerKeyword]) async throws {
        AppLogger.info(
            AppLogger.service,
            "[\(serviceId)] updateKeywords called with \(keywords.count) keywords"
        )

        guard let modelPath = modelPath else {
            AppLogger.error(AppLogger.service, "[\(serviceId)] Cannot update keywords - not initialized")
            throw WakeWordError.initializationFailed("Service not initialized - call initialize() first")
        }

        // Shutdown current instance
        shutdown()

        // Re-initialize with new keywords
        try await initialize(modelPath: modelPath, keywords: keywords)
    }

    func shutdown() {
        AppLogger.info(
            AppLogger.service,
            "[\(serviceId)] shutdown() called, \(detectionCount) detections, \(framesProcessed) frames processed"
        )

        // swiftlint:disable:next todo
        // TODO: Clean up sherpa-onnx resources
        // keywordSpotterStream = nil
        // keywordSpotter = nil

        _isInitialized = false
        currentKeywords = []
        keywordsFileContent = nil
        // Keep modelPath for potential re-initialization

        AppLogger.debug(AppLogger.service, "[\(serviceId)] Shutdown complete")
    }

    // MARK: - Private Methods

    /// Generate keywords.txt content from TriggerKeyword array
    ///
    /// sherpa-onnx keyword spotting expects a keywords file with format:
    /// ```
    /// keyword phrase :keyword phrase @boosting_score #threshold
    /// ```
    ///
    /// For example:
    /// ```
    /// hey claude :hey claude @1.5 #0.35
    /// opus :opus @1.3 #0.4
    /// ```
    ///
    /// - Parameter keywords: Array of TriggerKeyword to convert
    /// - Returns: String content for keywords.txt file
    private func generateKeywordsFileContent(from keywords: [TriggerKeyword]) -> String {
        keywords
            .filter { $0.isEnabled && $0.isValid }
            .map { keyword in
                let phrase = keyword.phrase.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                // Format: "phrase :phrase @boost #threshold"
                // The :phrase part is the "output symbol" that will be returned on detection
                return "\(phrase) :\(phrase) @\(keyword.boostingScore) #\(keyword.triggerThreshold)"
            }
            .joined(separator: "\n")
    }

    /// Write keywords to a temporary file for sherpa-onnx
    /// - Parameter content: Keywords file content
    /// - Returns: Path to temporary keywords file
    /// - Throws: WakeWordError if file cannot be written
    func writeKeywordsToTempFile(_ content: String) throws -> String {
        let tempDir = FileManager.default.temporaryDirectory
        let keywordsPath = tempDir.appendingPathComponent("wake_keywords_\(serviceId).txt")

        do {
            try content.write(to: keywordsPath, atomically: true, encoding: .utf8)
            AppLogger.debug(AppLogger.service, "[\(serviceId)] Wrote keywords to: \(keywordsPath.path)")
            return keywordsPath.path
        } catch {
            AppLogger.error(
                AppLogger.service,
                "[\(serviceId)] Failed to write keywords file: \(error.localizedDescription)"
            )
            throw WakeWordError.processingFailed("Failed to write keywords file: \(error.localizedDescription)")
        }
    }

    // MARK: - Statistics

    /// Get current statistics
    func getStatistics() -> (detections: Int, framesProcessed: Int) {
        (detectionCount, framesProcessed)
    }

    /// Reset statistics counters
    func resetStatistics() {
        detectionCount = 0
        framesProcessed = 0
        AppLogger.debug(AppLogger.service, "[\(serviceId)] Statistics reset")
    }
}
