import Foundation
import OSLog
import SherpaOnnxSwift

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

    /// Path to temporary keywords file (for cleanup)
    private var tempKeywordsFilePath: String?

    /// sherpa-onnx keyword spotter wrapper (handles both spotter and stream)
    private var keywordSpotter: SherpaOnnxKeywordSpotterWrapper?

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

        // Generate keywords.txt content (BPE-tokenized)
        let keywordsContent = generateKeywordsFileContent(from: enabledKeywords)

        // Check if any keywords have BPE mappings
        guard !keywordsContent.isEmpty else {
            AppLogger.error(
                AppLogger.service,
                "[\(serviceId)] No BPE token mappings found for any enabled keywords"
            )
            throw WakeWordError.invalidKeywords
        }

        AppLogger.debug(AppLogger.service, "[\(serviceId)] Generated keywords file:\n\(keywordsContent)")

        // Clean up any existing resources from previous initialization
        if let existingSpotter = keywordSpotter {
            existingSpotter.inputFinished()
            keywordSpotter = nil
        }

        if let existingTempPath = tempKeywordsFilePath {
            try? FileManager.default.removeItem(atPath: existingTempPath)
            tempKeywordsFilePath = nil
        }

        // Write keywords to temporary file for sherpa-onnx
        let keywordsFilePath = try writeKeywordsToTempFile(keywordsContent)

        // Build model file paths
        // The model directory should contain: encoder-*.onnx, decoder-*.onnx, joiner-*.onnx, tokens.txt
        let tokensPath = (modelPath as NSString).appendingPathComponent("tokens.txt")
        let encoderPath = (modelPath as NSString).appendingPathComponent(
            "encoder-epoch-12-avg-2-chunk-16-left-64.int8.onnx"
        )
        let decoderPath = (modelPath as NSString).appendingPathComponent(
            "decoder-epoch-12-avg-2-chunk-16-left-64.int8.onnx"
        )
        let joinerPath = (modelPath as NSString).appendingPathComponent(
            "joiner-epoch-12-avg-2-chunk-16-left-64.int8.onnx"
        )

        // Verify model files exist
        for path in [tokensPath, encoderPath, decoderPath, joinerPath] {
            guard FileManager.default.fileExists(atPath: path) else {
                AppLogger.error(AppLogger.service, "[\(serviceId)] Required model file not found: \(path)")
                throw WakeWordError.modelNotFound(path)
            }
        }

        AppLogger.debug(AppLogger.service, "[\(serviceId)] Model files verified, creating spotter config...")

        // Create feature config (16kHz sample rate, 80-dim features)
        let featConfig = sherpaOnnxFeatureConfig(sampleRate: 16000, featureDim: 80)

        // Create transducer model config
        let transducerConfig = sherpaOnnxOnlineTransducerModelConfig(
            encoder: encoderPath,
            decoder: decoderPath,
            joiner: joinerPath
        )

        // Create online model config
        let modelConfig = sherpaOnnxOnlineModelConfig(
            tokens: tokensPath,
            transducer: transducerConfig,
            numThreads: 2,
            provider: "cpu",
            debug: 0,
            modelType: "zipformer2"
        )

        // Create keyword spotter config
        // Use global keywords score/threshold; individual keyword thresholds are in keywords file
        var config = sherpaOnnxKeywordSpotterConfig(
            featConfig: featConfig,
            modelConfig: modelConfig,
            keywordsFile: keywordsFilePath,
            maxActivePaths: 4,
            numTrailingBlanks: 1,
            keywordsScore: 1.0,
            keywordsThreshold: 0.25
        )

        // Create keyword spotter wrapper (includes stream creation)
        let spotter = SherpaOnnxKeywordSpotterWrapper(config: &config)

        // Verify spotter was created
        guard spotter.spotter != nil else {
            AppLogger.error(AppLogger.service, "[\(serviceId)] Failed to create keyword spotter")
            throw WakeWordError.initializationFailed("Failed to create keyword spotter - check model files")
        }

        guard spotter.stream != nil else {
            AppLogger.error(AppLogger.service, "[\(serviceId)] Failed to create keyword spotter stream")
            throw WakeWordError.initializationFailed("Failed to create keyword spotter stream")
        }

        self.keywordSpotter = spotter
        self.modelPath = modelPath
        self.currentKeywords = enabledKeywords
        self.keywordsFileContent = keywordsContent
        self._isInitialized = true

        AppLogger.info(
            AppLogger.service,
            "[\(serviceId)] WakeWordService initialized with \(enabledKeywords.count) keywords"
        )
    }

    private var processFrameLogCount = 0
    func processFrame(_ samples: [Float]) -> WakeWordResult? {
        processFrameLogCount += 1

        guard _isInitialized else {
            if processFrameLogCount % 500 == 1 {
                print("[DEBUG] WakeWordService not initialized!")
                fflush(stdout)
            }
            return nil
        }

        guard !samples.isEmpty else {
            return nil
        }

        guard let spotter = keywordSpotter else {
            if processFrameLogCount % 500 == 1 {
                print("[DEBUG] WakeWordService spotter is nil!")
                fflush(stdout)
            }
            return nil
        }

        framesProcessed += 1

        // Accept waveform (16kHz mono float samples normalized to [-1.0, 1.0])
        spotter.acceptWaveform(samples: samples, sampleRate: 16000)

        // Decode while there are enough frames
        var decodeCount = 0
        while spotter.isReady() {
            spotter.decode()
            decodeCount += 1
        }

        if processFrameLogCount % 500 == 1 {
            print("[DEBUG] WakeWordService: processed \(samples.count) samples, decoded \(decodeCount) times")
            fflush(stdout)
        }

        // Check for keyword detection
        let result = spotter.getResult()
        let detectedKeyword = result.keyword

        // Non-empty keyword means a detection occurred
        if !detectedKeyword.isEmpty {
            detectionCount += 1
            AppLogger.info(
                AppLogger.service,
                "[\(serviceId)] Detected keyword: '\(detectedKeyword)' (detection #\(detectionCount))"
            )

            // Reset the stream to prepare for next detection
            spotter.reset()

            return WakeWordResult(
                detectedKeyword: detectedKeyword,
                confidence: 1.0, // sherpa-onnx keyword spotting doesn't provide confidence scores
                timestamp: Date()
            )
        }

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

        // Signal input finished to the spotter stream before cleanup
        if let spotter = keywordSpotter {
            spotter.inputFinished()
            AppLogger.debug(AppLogger.service, "[\(serviceId)] Signaled input finished to keyword spotter")
        }

        // Release sherpa-onnx resources
        // The SherpaOnnxKeywordSpotterWrapper deinit handles cleanup of spotter and stream
        keywordSpotter = nil

        // Clean up temporary keywords file
        if let tempPath = tempKeywordsFilePath {
            do {
                try FileManager.default.removeItem(atPath: tempPath)
                AppLogger.debug(AppLogger.service, "[\(serviceId)] Removed temp keywords file: \(tempPath)")
            } catch {
                AppLogger.warning(
                    AppLogger.service,
                    "[\(serviceId)] Failed to remove temp keywords file: \(error.localizedDescription)"
                )
            }
            tempKeywordsFilePath = nil
        }

        _isInitialized = false
        currentKeywords = []
        keywordsFileContent = nil
        // Keep modelPath for potential re-initialization

        AppLogger.debug(AppLogger.service, "[\(serviceId)] Shutdown complete")
    }

    // MARK: - Private Methods

    /// BPE token mappings for common wake word phrases
    ///
    /// These are pre-tokenized using the sherpa-onnx-kws-zipformer-gigaspeech model's BPE vocabulary.
    /// The tokens use the ▁ (Unicode U+2581) character to indicate word boundaries.
    ///
    /// To add new keywords, use `sherpa-onnx-cli text2token` to convert text to BPE tokens.
    // swiftlint:disable:next line_length
    private static let bpeTokenMappings: [String: String] = [
        // Assistant-style wake words
        "hey siri": "▁HE Y ▁S I RI",
        "hi google": "▁HI ▁GO O G LE",
        "ok google": "▁O K ▁GO O G LE",
        "alexa": "▁A LE X A",
        "hey claude": "▁HE Y ▁C LA U DE",
        "claude": "▁C LA U DE",
        "jarvis": "▁JAR V I S",
        "hey jarvis": "▁HE Y ▁JAR V I S",
        "computer": "▁COMP U T ER",
        "hey computer": "▁HE Y ▁COMP U T ER",

        // Action-style wake words
        "start listening": "▁START ▁LIS T EN ING",
        "stop listening": "▁STOP ▁LIS T EN ING",
        "take note": "▁TAKE ▁NOTE",
        "take notes": "▁TAKE ▁NOTE S",
        "start recording": "▁START ▁REC OR D ING",
        "stop recording": "▁STOP ▁REC OR D ING",
        "go home": "▁GO ▁HOME",
        "play music": "▁PLAY ▁MU S IC",
        "open mail": "▁O PEN ▁MA IL",
        "open browser": "▁O PEN ▁BRO W S ER",
        "open calendar": "▁O PEN ▁CA LEN DAR",
        "open settings": "▁O PEN ▁SET T ING S",
        "open notes": "▁O PEN ▁NOTE S",
        "search": "▁SEARCH",
        "send message": "▁SEND ▁MES S AGE",
        "new email": "▁NEW ▁E MA IL",
        "call": "▁CALL",
        "remind me": "▁RE MIND ▁ME",
        "set timer": "▁SET ▁TIM ER",
        "what time": "▁WHAT ▁TIME",

        // Short triggers
        "hey": "▁HE Y",
        "hello": "▁HE LL O",
        "hello world": "▁HE LL O ▁WORLD",
        "okay": "▁OKAY",
        "listen": "▁LIS T EN",
        "record": "▁REC ORD",
        "start": "▁START",
        "stop": "▁STOP",
        "opus": "▁O P U S",
        "sonnet": "▁S O N N E T",
        "transcribe": "▁TRANS CRI BE"
    ]

    /// Generate keywords.txt content from TriggerKeyword array
    ///
    /// sherpa-onnx keyword spotting expects a keywords file with BPE-tokenized format:
    /// ```
    /// TOKEN1 TOKEN2 TOKEN3 :boosting_score #threshold
    /// ```
    ///
    /// For example (HEY SIRI with boost 1.5 and threshold 0.35):
    /// ```
    /// ▁HE Y ▁S I RI :1.5 #0.35
    /// ```
    ///
    /// The parameters are:
    /// - `:boosting_score` - Adjusts the score weight for this keyword (higher = easier to trigger)
    /// - `#threshold` - Per-keyword detection threshold (0.0-1.0, lower = easier to trigger)
    ///
    /// - Note: The tokens use the ▁ (Unicode U+2581) character to indicate word boundaries.
    ///   Keywords not in the pre-defined mapping will be skipped with a warning.
    ///
    /// - Parameter keywords: Array of TriggerKeyword to convert
    /// - Returns: String content for keywords.txt file
    private func generateKeywordsFileContent(from keywords: [TriggerKeyword]) -> String {
        keywords
            .filter { $0.isEnabled && $0.isValid }
            .compactMap { keyword -> String? in
                let phrase = keyword.phrase.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

                // Look up BPE tokens for this phrase
                guard let bpeTokens = Self.bpeTokenMappings[phrase] else {
                    AppLogger.warning(
                        AppLogger.service,
                        "[\(serviceId)] No BPE mapping for keyword '\(phrase)' - skipping"
                    )
                    return nil
                }

                // Format: "TOKEN1 TOKEN2 :boosting_score #threshold"
                // - :boostingScore adjusts score weight for this keyword (higher = easier to trigger)
                // - #threshold is the detection threshold (0.0-1.0, lower = easier to trigger)
                return "\(bpeTokens) :\(keyword.boostingScore) #\(keyword.triggerThreshold)"
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
            // Track the path so shutdown() can clean it up
            tempKeywordsFilePath = keywordsPath.path
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
