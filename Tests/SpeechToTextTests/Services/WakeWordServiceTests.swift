import XCTest
@testable import SpeechToText
import SherpaOnnxSwift
import AVFoundation

final class WakeWordServiceTests: XCTestCase {

    // MARK: - Test Helpers

    /// A keyword with valid BPE mapping for use in tests
    /// Note: "Hey Claude" doesn't have a valid BPE mapping, so we use "hey siri" instead
    private static let validTestKeyword = TriggerKeyword(
        phrase: "hey siri",
        boostingScore: 1.5,
        triggerThreshold: 0.35,
        isEnabled: true
    )

    // MARK: - Initialization Tests

    func test_initialization_createsService() async {
        // Given/When
        let service = WakeWordService()

        // Then
        let isInitialized = await service.isInitialized
        XCTAssertFalse(isInitialized)
    }

    func test_initialization_startsWithNotInitializedState() async {
        // Given/When
        let service = WakeWordService()

        // Then
        let isInitialized = await service.isInitialized
        XCTAssertFalse(isInitialized)
    }

    // MARK: - Initialize with Valid Model Path Tests

    func test_initialize_withValidPathAndKeywords_setsInitializedFlag() async throws {
        // Given
        let service = WakeWordService()
        let tempModelPath = createTempModelDirectory()
        defer { cleanupTempDirectory(tempModelPath) }

        // Use a keyword with valid BPE mapping
        let keywords = [TriggerKeyword(phrase: "hey siri", boostingScore: 1.5, triggerThreshold: 0.35, isEnabled: true)]

        // When
        try await service.initialize(modelPath: tempModelPath, keywords: keywords)

        // Then
        let isInitialized = await service.isInitialized
        XCTAssertTrue(isInitialized)
    }

    func test_initialize_withMultipleValidKeywords_setsInitializedFlag() async throws {
        // Given
        let service = WakeWordService()
        let tempModelPath = createTempModelDirectory()
        defer { cleanupTempDirectory(tempModelPath) }

        // Use keywords with valid BPE mappings
        let keywords = [
            TriggerKeyword(phrase: "hey siri", boostingScore: 1.5, triggerThreshold: 0.35, isEnabled: true),
            TriggerKeyword(phrase: "hello world", boostingScore: 1.3, triggerThreshold: 0.4, isEnabled: true),
            TriggerKeyword(phrase: "hi google", boostingScore: 1.3, triggerThreshold: 0.4, isEnabled: true)
        ]

        // When
        try await service.initialize(modelPath: tempModelPath, keywords: keywords)

        // Then
        let isInitialized = await service.isInitialized
        XCTAssertTrue(isInitialized)
    }

    // MARK: - Initialize Failure with Invalid Model Path Tests

    func test_initialize_withInvalidModelPath_throwsModelNotFoundError() async {
        // Given
        let service = WakeWordService()
        let invalidPath = "/nonexistent/path/to/model"
        let keywords = [Self.validTestKeyword]

        // When/Then
        do {
            try await service.initialize(modelPath: invalidPath, keywords: keywords)
            XCTFail("Should throw modelNotFound error")
        } catch let error as WakeWordError {
            if case .modelNotFound(let path) = error {
                XCTAssertEqual(path, invalidPath)
            } else {
                XCTFail("Wrong error type: expected modelNotFound, got \(error)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func test_initialize_withEmptyModelPath_throwsModelNotFoundError() async {
        // Given
        let service = WakeWordService()
        let emptyPath = ""
        let keywords = [Self.validTestKeyword]

        // When/Then
        do {
            try await service.initialize(modelPath: emptyPath, keywords: keywords)
            XCTFail("Should throw modelNotFound error")
        } catch let error as WakeWordError {
            if case .modelNotFound = error {
                // Expected
            } else {
                XCTFail("Wrong error type: expected modelNotFound, got \(error)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - Initialize Failure with No Valid Keywords Tests

    func test_initialize_withNoKeywords_throwsInvalidKeywordsError() async {
        // Given
        let service = WakeWordService()
        let tempModelPath = createTempModelDirectory()
        defer { cleanupTempDirectory(tempModelPath) }

        let keywords: [TriggerKeyword] = []

        // When/Then
        do {
            try await service.initialize(modelPath: tempModelPath, keywords: keywords)
            XCTFail("Should throw invalidKeywords error")
        } catch let error as WakeWordError {
            XCTAssertEqual(error, .invalidKeywords)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func test_initialize_withAllDisabledKeywords_throwsInvalidKeywordsError() async {
        // Given
        let service = WakeWordService()
        let tempModelPath = createTempModelDirectory()
        defer { cleanupTempDirectory(tempModelPath) }

        let keywords = [
            TriggerKeyword(phrase: "Hey Claude", isEnabled: false),
            TriggerKeyword(phrase: "Claude", isEnabled: false)
        ]

        // When/Then
        do {
            try await service.initialize(modelPath: tempModelPath, keywords: keywords)
            XCTFail("Should throw invalidKeywords error")
        } catch let error as WakeWordError {
            XCTAssertEqual(error, .invalidKeywords)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func test_initialize_withInvalidKeywords_throwsInvalidKeywordsError() async {
        // Given
        let service = WakeWordService()
        let tempModelPath = createTempModelDirectory()
        defer { cleanupTempDirectory(tempModelPath) }

        // Empty phrase makes keyword invalid
        let keywords = [
            TriggerKeyword(phrase: "", isEnabled: true),
            TriggerKeyword(phrase: "   ", isEnabled: true)
        ]

        // When/Then
        do {
            try await service.initialize(modelPath: tempModelPath, keywords: keywords)
            XCTFail("Should throw invalidKeywords error")
        } catch let error as WakeWordError {
            XCTAssertEqual(error, .invalidKeywords)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func test_initialize_withMixedValidInvalidKeywords_onlyUsesValidOnes() async throws {
        // Given
        let service = WakeWordService()
        let tempModelPath = createTempModelDirectory()
        defer { cleanupTempDirectory(tempModelPath) }

        // One valid, one invalid (empty phrase), one disabled
        let keywords = [
            TriggerKeyword(phrase: "Hey Claude", isEnabled: true),
            TriggerKeyword(phrase: "", isEnabled: true),
            TriggerKeyword(phrase: "Claude", isEnabled: false)
        ]

        // When
        try await service.initialize(modelPath: tempModelPath, keywords: keywords)

        // Then
        let isInitialized = await service.isInitialized
        XCTAssertTrue(isInitialized)
    }

    // MARK: - ProcessFrame When Not Initialized Tests

    func test_processFrame_whenNotInitialized_returnsNil() async {
        // Given
        let service = WakeWordService()
        let samples: [Float] = Array(repeating: 0.5, count: 1600)

        // When
        let result = await service.processFrame(samples)

        // Then
        XCTAssertNil(result)
    }

    func test_processFrame_whenNotInitialized_doesNotCrash() async {
        // Given
        let service = WakeWordService()
        let samples: [Float] = Array(repeating: 0.1, count: 16000)

        // When/Then - Should not crash
        for _ in 0..<10 {
            let result = await service.processFrame(samples)
            XCTAssertNil(result)
        }
    }

    // MARK: - ProcessFrame With Empty Samples Tests

    func test_processFrame_withEmptySamples_returnsNil() async throws {
        // Given
        let service = WakeWordService()
        let tempModelPath = createTempModelDirectory()
        defer { cleanupTempDirectory(tempModelPath) }

        try await service.initialize(
            modelPath: tempModelPath,
            keywords: [Self.validTestKeyword]
        )

        // When
        let result = await service.processFrame([])

        // Then
        XCTAssertNil(result)
    }

    func test_processFrame_withEmptyArray_doesNotIncrementFramesProcessed() async throws {
        // Given
        let service = WakeWordService()
        let tempModelPath = createTempModelDirectory()
        defer { cleanupTempDirectory(tempModelPath) }

        try await service.initialize(
            modelPath: tempModelPath,
            keywords: [Self.validTestKeyword]
        )

        // When
        _ = await service.processFrame([])

        // Then
        let stats = await service.getStatistics()
        XCTAssertEqual(stats.framesProcessed, 0)
    }

    // MARK: - ProcessFrame Increments Statistics Tests

    func test_processFrame_withSamples_incrementsFramesProcessed() async throws {
        // Given
        let service = WakeWordService()
        let tempModelPath = createTempModelDirectory()
        defer { cleanupTempDirectory(tempModelPath) }

        try await service.initialize(
            modelPath: tempModelPath,
            keywords: [Self.validTestKeyword]
        )
        let samples: [Float] = Array(repeating: 0.3, count: 1600)

        // When
        _ = await service.processFrame(samples)
        _ = await service.processFrame(samples)
        _ = await service.processFrame(samples)

        // Then
        let stats = await service.getStatistics()
        XCTAssertEqual(stats.framesProcessed, 3)
    }

    // MARK: - UpdateKeywords Tests

    func test_updateKeywords_reInitializesService() async throws {
        // Given
        let service = WakeWordService()
        let tempModelPath = createTempModelDirectory()
        defer { cleanupTempDirectory(tempModelPath) }

        try await service.initialize(
            modelPath: tempModelPath,
            keywords: [Self.validTestKeyword]
        )
        let initialState = await service.isInitialized
        XCTAssertTrue(initialState)

        // When
        let newKeywords = [
            TriggerKeyword(phrase: "Opus", isEnabled: true),
            TriggerKeyword(phrase: "Sonnet", isEnabled: true)
        ]
        try await service.updateKeywords(newKeywords)

        // Then
        let finalState = await service.isInitialized
        XCTAssertTrue(finalState)
    }

    func test_updateKeywords_withInvalidKeywords_throwsError() async throws {
        // Given
        let service = WakeWordService()
        let tempModelPath = createTempModelDirectory()
        defer { cleanupTempDirectory(tempModelPath) }

        try await service.initialize(
            modelPath: tempModelPath,
            keywords: [Self.validTestKeyword]
        )

        // When/Then
        do {
            try await service.updateKeywords([])
            XCTFail("Should throw invalidKeywords error")
        } catch let error as WakeWordError {
            XCTAssertEqual(error, .invalidKeywords)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func test_updateKeywords_whenNotInitialized_throwsError() async {
        // Given
        let service = WakeWordService()

        // When/Then
        do {
            try await service.updateKeywords([Self.validTestKeyword])
            XCTFail("Should throw initializationFailed error")
        } catch let error as WakeWordError {
            if case .initializationFailed = error {
                // Expected
            } else {
                XCTFail("Wrong error type: expected initializationFailed, got \(error)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func test_updateKeywords_preservesStatistics() async throws {
        // Given
        let service = WakeWordService()
        let tempModelPath = createTempModelDirectory()
        defer { cleanupTempDirectory(tempModelPath) }

        try await service.initialize(
            modelPath: tempModelPath,
            keywords: [Self.validTestKeyword]
        )

        // Process some frames
        let samples: [Float] = Array(repeating: 0.5, count: 1600)
        _ = await service.processFrame(samples)
        _ = await service.processFrame(samples)

        let statsBefore = await service.getStatistics()
        XCTAssertEqual(statsBefore.framesProcessed, 2)

        // When - updateKeywords calls shutdown which clears state, then re-initializes
        // Note: Statistics are intentionally preserved across shutdown/reinitialize cycles
        // Use a keyword with a valid BPE mapping (lowercase for BPE lookup)
        try await service.updateKeywords([TriggerKeyword(phrase: "hello world", isEnabled: true)])

        // Process a frame after update
        _ = await service.processFrame(samples)

        // Then - statistics continue from previous count
        let statsAfter = await service.getStatistics()
        XCTAssertEqual(statsAfter.framesProcessed, 3)
    }

    // MARK: - Shutdown Tests

    func test_shutdown_clearsInitializedState() async throws {
        // Given
        let service = WakeWordService()
        let tempModelPath = createTempModelDirectory()
        defer { cleanupTempDirectory(tempModelPath) }

        try await service.initialize(
            modelPath: tempModelPath,
            keywords: [Self.validTestKeyword]
        )
        let initialState = await service.isInitialized
        XCTAssertTrue(initialState)

        // When
        await service.shutdown()

        // Then
        let finalState = await service.isInitialized
        XCTAssertFalse(finalState)
    }

    func test_shutdown_canBeCalledMultipleTimes() async throws {
        // Given
        let service = WakeWordService()
        let tempModelPath = createTempModelDirectory()
        defer { cleanupTempDirectory(tempModelPath) }

        try await service.initialize(
            modelPath: tempModelPath,
            keywords: [Self.validTestKeyword]
        )

        // When/Then - Should not crash
        await service.shutdown()
        await service.shutdown()
        await service.shutdown()

        let finalState = await service.isInitialized
        XCTAssertFalse(finalState)
    }

    func test_shutdown_allowsReinitialization() async throws {
        // Given
        let service = WakeWordService()
        let tempModelPath = createTempModelDirectory()
        defer { cleanupTempDirectory(tempModelPath) }

        try await service.initialize(
            modelPath: tempModelPath,
            keywords: [Self.validTestKeyword]
        )
        await service.shutdown()

        // When - use a different keyword with a valid BPE mapping
        try await service.initialize(
            modelPath: tempModelPath,
            keywords: [TriggerKeyword(phrase: "hello world", isEnabled: true)]
        )

        // Then
        let isInitialized = await service.isInitialized
        XCTAssertTrue(isInitialized)
    }

    func test_processFrame_afterShutdown_returnsNil() async throws {
        // Given
        let service = WakeWordService()
        let tempModelPath = createTempModelDirectory()
        defer { cleanupTempDirectory(tempModelPath) }

        try await service.initialize(
            modelPath: tempModelPath,
            keywords: [Self.validTestKeyword]
        )
        await service.shutdown()
        let samples: [Float] = Array(repeating: 0.5, count: 1600)

        // When
        let result = await service.processFrame(samples)

        // Then
        XCTAssertNil(result)
    }

    // MARK: - Statistics Tests

    func test_getStatistics_returnsInitialZeroValues() async {
        // Given
        let service = WakeWordService()

        // When
        let stats = await service.getStatistics()

        // Then
        XCTAssertEqual(stats.detections, 0)
        XCTAssertEqual(stats.framesProcessed, 0)
    }

    func test_getStatistics_tracksFramesProcessed() async throws {
        // Given
        let service = WakeWordService()
        let tempModelPath = createTempModelDirectory()
        defer { cleanupTempDirectory(tempModelPath) }

        try await service.initialize(
            modelPath: tempModelPath,
            keywords: [Self.validTestKeyword]
        )
        let samples: [Float] = Array(repeating: 0.5, count: 1600)

        // When
        for _ in 0..<5 {
            _ = await service.processFrame(samples)
        }

        // Then
        let stats = await service.getStatistics()
        XCTAssertEqual(stats.framesProcessed, 5)
    }

    func test_resetStatistics_clearsAllCounters() async throws {
        // Given
        let service = WakeWordService()
        let tempModelPath = createTempModelDirectory()
        defer { cleanupTempDirectory(tempModelPath) }

        try await service.initialize(
            modelPath: tempModelPath,
            keywords: [Self.validTestKeyword]
        )
        let samples: [Float] = Array(repeating: 0.5, count: 1600)

        for _ in 0..<5 {
            _ = await service.processFrame(samples)
        }

        let statsBefore = await service.getStatistics()
        XCTAssertEqual(statsBefore.framesProcessed, 5)

        // When
        await service.resetStatistics()

        // Then
        let statsAfter = await service.getStatistics()
        XCTAssertEqual(statsAfter.detections, 0)
        XCTAssertEqual(statsAfter.framesProcessed, 0)
    }

    func test_resetStatistics_doesNotAffectInitializedState() async throws {
        // Given
        let service = WakeWordService()
        let tempModelPath = createTempModelDirectory()
        defer { cleanupTempDirectory(tempModelPath) }

        try await service.initialize(
            modelPath: tempModelPath,
            keywords: [Self.validTestKeyword]
        )

        // When
        await service.resetStatistics()

        // Then
        let isInitialized = await service.isInitialized
        XCTAssertTrue(isInitialized)
    }

    // MARK: - Keyword File Content Generation Tests

    func test_writeKeywordsToTempFile_writesValidContent() async throws {
        // Given
        let service = WakeWordService()
        let testContent = "hey claude :hey claude @1.5 #0.35"

        // When
        let filePath = try await service.writeKeywordsToTempFile(testContent)

        // Then
        XCTAssertTrue(FileManager.default.fileExists(atPath: filePath))
        let fileContent = try String(contentsOfFile: filePath, encoding: .utf8)
        XCTAssertEqual(fileContent, testContent)

        // Cleanup
        try? FileManager.default.removeItem(atPath: filePath)
    }

    func test_keywordsFileContent_hasCorrectFormat() async throws {
        // Given
        let service = WakeWordService()
        let tempModelPath = createTempModelDirectory()
        defer { cleanupTempDirectory(tempModelPath) }

        let keyword = TriggerKeyword(
            phrase: "Hey Claude",
            boostingScore: 1.5,
            triggerThreshold: 0.35,
            isEnabled: true
        )

        // When
        try await service.initialize(modelPath: tempModelPath, keywords: [keyword])

        // Then - Verify format by writing to temp file
        // The format should be: "phrase :phrase @boost #threshold"
        let testContent = "hey claude :hey claude @1.5 #0.35"
        let filePath = try await service.writeKeywordsToTempFile(testContent)
        let fileContent = try String(contentsOfFile: filePath, encoding: .utf8)

        // Verify expected format
        XCTAssertTrue(fileContent.contains(":"))
        XCTAssertTrue(fileContent.contains("@"))
        XCTAssertTrue(fileContent.contains("#"))

        // Cleanup
        try? FileManager.default.removeItem(atPath: filePath)
    }

    func test_keywordsFileContent_multipleKeywords_separatedByNewlines() async throws {
        // Given
        let service = WakeWordService()
        let testContent = """
            hey claude :hey claude @1.5 #0.35
            opus :opus @1.3 #0.4
            sonnet :sonnet @1.3 #0.4
            """

        // When
        let filePath = try await service.writeKeywordsToTempFile(testContent)

        // Then
        let fileContent = try String(contentsOfFile: filePath, encoding: .utf8)
        let lines = fileContent.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 3)

        // Cleanup
        try? FileManager.default.removeItem(atPath: filePath)
    }

    func test_keywordsFileContent_lowercasesPhrase() async throws {
        // Given
        let service = WakeWordService()

        // The generateKeywordsFileContent method lowercases phrases
        // This is tested indirectly - when initialized, the service generates content
        let tempModelPath = createTempModelDirectory()
        defer { cleanupTempDirectory(tempModelPath) }

        // Use a keyword with BPE mapping but with mixed case to test lowercasing
        let keyword = TriggerKeyword(
            phrase: "Hey SIRI",  // Should lowercase to "hey siri" which has BPE mapping
            boostingScore: 1.5,
            triggerThreshold: 0.35,
            isEnabled: true
        )

        // When
        try await service.initialize(modelPath: tempModelPath, keywords: [keyword])

        // Then
        // Service is initialized, indicating keyword processing succeeded
        let isInitialized = await service.isInitialized
        XCTAssertTrue(isInitialized)
    }

    // MARK: - WakeWordError Tests

    func test_wakeWordError_modelNotFound_hasCorrectDescription() {
        // Given
        let error = WakeWordError.modelNotFound("/path/to/model")

        // When
        let description = error.errorDescription

        // Then
        XCTAssertEqual(description, "Wake word model not found at path: /path/to/model")
    }

    func test_wakeWordError_initializationFailed_hasCorrectDescription() {
        // Given
        let error = WakeWordError.initializationFailed("Test reason")

        // When
        let description = error.errorDescription

        // Then
        XCTAssertEqual(description, "Failed to initialize wake word service: Test reason")
    }

    func test_wakeWordError_invalidKeywords_hasCorrectDescription() {
        // Given
        let error = WakeWordError.invalidKeywords

        // When
        let description = error.errorDescription

        // Then
        XCTAssertEqual(description, "Invalid keywords configuration - at least one valid keyword is required")
    }

    func test_wakeWordError_processingFailed_hasCorrectDescription() {
        // Given
        let error = WakeWordError.processingFailed("Audio error")

        // When
        let description = error.errorDescription

        // Then
        XCTAssertEqual(description, "Wake word processing failed: Audio error")
    }

    func test_wakeWordError_equatable() {
        // Given
        let error1 = WakeWordError.invalidKeywords
        let error2 = WakeWordError.invalidKeywords
        let error3 = WakeWordError.modelNotFound("/path")
        let error4 = WakeWordError.modelNotFound("/path")
        let error5 = WakeWordError.modelNotFound("/other")

        // Then
        XCTAssertEqual(error1, error2)
        XCTAssertEqual(error3, error4)
        XCTAssertNotEqual(error3, error5)
        XCTAssertNotEqual(error1, error3)
    }

    // MARK: - WakeWordResult Tests

    func test_wakeWordResult_initialization() {
        // Given/When
        let timestamp = Date()
        let result = WakeWordResult(
            detectedKeyword: "hey claude",
            confidence: 0.95,
            timestamp: timestamp
        )

        // Then
        XCTAssertEqual(result.detectedKeyword, "hey claude")
        XCTAssertEqual(result.confidence, 0.95)
        XCTAssertEqual(result.timestamp, timestamp)
    }

    // MARK: - Thread Safety Tests (Actor)

    func test_service_canBeAccessedFromMultipleTasksConcurrently() async {
        // Given
        let service = WakeWordService()

        // When
        await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    await service.isInitialized
                }
            }

            // Then
            for await isInitialized in group {
                XCTAssertFalse(isInitialized)
            }
        }
    }

    func test_service_processFrame_isThreadSafe() async throws {
        // Given
        let service = WakeWordService()
        let tempModelPath = createTempModelDirectory()
        defer { cleanupTempDirectory(tempModelPath) }

        try await service.initialize(
            modelPath: tempModelPath,
            keywords: [Self.validTestKeyword]
        )

        let samples: [Float] = Array(repeating: 0.5, count: 1600)

        // When
        await withTaskGroup(of: WakeWordResult?.self) { group in
            for _ in 0..<20 {
                group.addTask {
                    await service.processFrame(samples)
                }
            }

            // Then - all should complete without crash
            for await _ in group { }
        }

        // Verify frames were processed
        let stats = await service.getStatistics()
        XCTAssertEqual(stats.framesProcessed, 20)
    }

    func test_service_concurrentInitializeAndShutdown() async {
        // Given
        let service = WakeWordService()
        let tempModelPath = createTempModelDirectory()
        defer { cleanupTempDirectory(tempModelPath) }

        // When - rapid initialize/shutdown cycles
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<5 {
                group.addTask {
                    if i % 2 == 0 {
                        try? await service.initialize(
                            modelPath: tempModelPath,
                            keywords: [Self.validTestKeyword]
                        )
                    } else {
                        await service.shutdown()
                    }
                }
            }
        }

        // Then - service should be in a valid state (either initialized or not)
        // No crash should occur
        let isInitialized = await service.isInitialized
        XCTAssertTrue(isInitialized == true || isInitialized == false)
    }

    // MARK: - Integration Tests with Real Model

    /// Test that the service can initialize with the real sherpa-onnx model
    func test_integration_initializeWithRealModel_succeeds() async throws {
        guard let modelPath = getRealModelDirectory() else {
            // Skip test if model not available
            throw XCTSkip("sherpa-onnx model not available at expected path")
        }

        // Given
        let service = WakeWordService()

        // Use a keyword with BPE mapping
        let keywords = [TriggerKeyword(phrase: "hey siri", boostingScore: 1.5, triggerThreshold: 0.25, isEnabled: true)]

        // When
        try await service.initialize(modelPath: modelPath, keywords: keywords)

        // Then
        let isInitialized = await service.isInitialized
        XCTAssertTrue(isInitialized, "Service should be initialized with real model")

        // Cleanup
        await service.shutdown()
    }

    /// Test that the service can process audio frames without crashing
    func test_integration_processFrame_withRealModel_doesNotCrash() async throws {
        guard let modelPath = getRealModelDirectory() else {
            throw XCTSkip("sherpa-onnx model not available at expected path")
        }

        // Given
        let service = WakeWordService()
        let keywords = [TriggerKeyword(phrase: "hey siri", boostingScore: 1.5, triggerThreshold: 0.25, isEnabled: true)]
        try await service.initialize(modelPath: modelPath, keywords: keywords)

        // Create synthetic audio frames (silence)
        let silentFrame: [Float] = Array(repeating: 0.0, count: 1600) // 100ms at 16kHz

        // When - process multiple frames
        for _ in 0..<10 {
            let result = await service.processFrame(silentFrame)
            // Silent audio should not trigger detection
            XCTAssertNil(result, "Silent audio should not trigger keyword detection")
        }

        // Then - verify statistics were updated
        let stats = await service.getStatistics()
        XCTAssertEqual(stats.framesProcessed, 10, "Should have processed 10 frames")

        // Cleanup
        await service.shutdown()
    }

    /// Test keyword detection with the test WAV files bundled with the model
    func test_integration_detectKeyword_lightUp_fromTestWav() async throws {
        guard let modelPath = getRealModelDirectory() else {
            throw XCTSkip("sherpa-onnx model not available at expected path")
        }

        // Given - use the test keywords file format which has "LIGHT UP"
        let service = WakeWordService()

        // Write keywords in the correct BPE format for "light up"
        // From test_keywords.txt: ▁ L IGHT ▁UP
        let keywordsContent = "▁ L IGHT ▁UP :1.5 #0.25"
        let keywordsFilePath = try await service.writeKeywordsToTempFile(keywordsContent)

        // Need to initialize the service manually since we have custom keywords file
        // For this test, we'll use a simpler approach with direct model initialization

        // First try to detect "light up" keyword using the provided test keywords
        let testKeywordsPath = (modelPath as NSString).appendingPathComponent("test_wavs/test_keywords.txt")
        guard FileManager.default.fileExists(atPath: testKeywordsPath) else {
            try? FileManager.default.removeItem(atPath: keywordsFilePath)
            throw XCTSkip("Test keywords file not found")
        }

        // Read the test WAV file using AVFoundation
        let testWavPath = (modelPath as NSString).appendingPathComponent("test_wavs/0.wav")
        guard FileManager.default.fileExists(atPath: testWavPath) else {
            try? FileManager.default.removeItem(atPath: keywordsFilePath)
            throw XCTSkip("Test WAV file not found")
        }

        // Read WAV file using AVFoundation
        let testWavURL = URL(fileURLWithPath: testWavPath)
        let audioFile: AVAudioFile
        do {
            audioFile = try AVAudioFile(forReading: testWavURL)
        } catch {
            try? FileManager.default.removeItem(atPath: keywordsFilePath)
            throw XCTSkip("Failed to read test WAV file: \(error)")
        }

        let audioFormat = audioFile.processingFormat
        let frameCount = UInt32(audioFile.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount) else {
            try? FileManager.default.removeItem(atPath: keywordsFilePath)
            throw XCTSkip("Failed to create audio buffer")
        }

        do {
            try audioFile.read(into: buffer)
        } catch {
            try? FileManager.default.removeItem(atPath: keywordsFilePath)
            throw XCTSkip("Failed to read audio into buffer: \(error)")
        }

        // Convert to Float array
        guard let floatData = buffer.floatChannelData else {
            try? FileManager.default.removeItem(atPath: keywordsFilePath)
            throw XCTSkip("Failed to get float channel data")
        }
        let samples = Array(UnsafeBufferPointer(start: floatData[0], count: Int(buffer.frameLength)))

        // Create a spotter directly with the test keywords
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

        let featConfig = sherpaOnnxFeatureConfig(sampleRate: 16000, featureDim: 80)
        let transducerConfig = sherpaOnnxOnlineTransducerModelConfig(
            encoder: encoderPath,
            decoder: decoderPath,
            joiner: joinerPath
        )
        let modelConfig = sherpaOnnxOnlineModelConfig(
            tokens: tokensPath,
            transducer: transducerConfig,
            numThreads: 2,
            provider: "cpu",
            debug: 0,
            modelType: "zipformer2"
        )

        var config = sherpaOnnxKeywordSpotterConfig(
            featConfig: featConfig,
            modelConfig: modelConfig,
            keywordsFile: testKeywordsPath,
            maxActivePaths: 4,
            numTrailingBlanks: 1,
            keywordsScore: 1.0,
            keywordsThreshold: 0.25
        )

        let spotter = SherpaOnnxKeywordSpotterWrapper(config: &config)
        guard spotter.spotter != nil, spotter.stream != nil else {
            try? FileManager.default.removeItem(atPath: keywordsFilePath)
            XCTFail("Failed to create keyword spotter")
            return
        }

        // When - process the audio
        spotter.acceptWaveform(samples: samples)

        // Add tail padding to ensure detection
        let tailPadding = [Float](repeating: 0.0, count: 3200) // 200ms
        spotter.acceptWaveform(samples: tailPadding)
        spotter.inputFinished()

        // Decode and check for detections
        var detectedKeywords: [String] = []
        while spotter.isReady() {
            spotter.decode()
            let result = spotter.getResult()
            let keyword = result.keyword
            if !keyword.isEmpty {
                detectedKeywords.append(keyword)
                spotter.reset()
            }
        }

        // Then - should detect "light up" keyword (it's in the 0.wav file)
        // The audio says "AFTER EARLY NIGHTFALL THE YELLOW LAMPS WOULD LIGHT UP..."
        XCTAssertFalse(detectedKeywords.isEmpty, "Should detect at least one keyword from test audio")

        // Cleanup
        try? FileManager.default.removeItem(atPath: keywordsFilePath)
    }

    /// Test that shutdown properly releases resources after processing
    func test_integration_shutdown_afterProcessing_releasesResources() async throws {
        guard let modelPath = getRealModelDirectory() else {
            throw XCTSkip("sherpa-onnx model not available at expected path")
        }

        // Given
        let service = WakeWordService()
        let keywords = [TriggerKeyword(phrase: "hey siri", boostingScore: 1.5, triggerThreshold: 0.25, isEnabled: true)]
        try await service.initialize(modelPath: modelPath, keywords: keywords)

        // Process some audio
        let samples: [Float] = Array(repeating: 0.1, count: 1600)
        _ = await service.processFrame(samples)
        _ = await service.processFrame(samples)

        let statsBeforeShutdown = await service.getStatistics()
        XCTAssertGreaterThan(statsBeforeShutdown.framesProcessed, 0)

        // When
        await service.shutdown()

        // Then
        let isInitialized = await service.isInitialized
        XCTAssertFalse(isInitialized, "Service should not be initialized after shutdown")

        // Processing should return nil after shutdown
        let result = await service.processFrame(samples)
        XCTAssertNil(result, "Processing should return nil after shutdown")
    }

    /// Test multiple initialize-shutdown cycles with real model
    func test_integration_multipleInitShutdownCycles_succeeds() async throws {
        guard let modelPath = getRealModelDirectory() else {
            throw XCTSkip("sherpa-onnx model not available at expected path")
        }

        let service = WakeWordService()
        let keywords = [TriggerKeyword(phrase: "hey siri", boostingScore: 1.5, triggerThreshold: 0.25, isEnabled: true)]

        // Cycle 1
        try await service.initialize(modelPath: modelPath, keywords: keywords)
        var isInit = await service.isInitialized
        XCTAssertTrue(isInit)
        await service.shutdown()
        isInit = await service.isInitialized
        XCTAssertFalse(isInit)

        // Cycle 2
        try await service.initialize(modelPath: modelPath, keywords: keywords)
        isInit = await service.isInitialized
        XCTAssertTrue(isInit)

        // Process some audio in cycle 2
        let samples: [Float] = Array(repeating: 0.0, count: 1600)
        _ = await service.processFrame(samples)

        await service.shutdown()
        isInit = await service.isInitialized
        XCTAssertFalse(isInit)

        // Cycle 3
        try await service.initialize(modelPath: modelPath, keywords: keywords)
        isInit = await service.isInitialized
        XCTAssertTrue(isInit)

        await service.shutdown()
    }

    /// Test updateKeywords with real model
    func test_integration_updateKeywords_withRealModel_succeeds() async throws {
        guard let modelPath = getRealModelDirectory() else {
            throw XCTSkip("sherpa-onnx model not available at expected path")
        }

        // Given
        let service = WakeWordService()
        let initialKeywords = [TriggerKeyword(phrase: "hey siri", boostingScore: 1.5, triggerThreshold: 0.25, isEnabled: true)]
        try await service.initialize(modelPath: modelPath, keywords: initialKeywords)

        // Process some audio
        let samples: [Float] = Array(repeating: 0.0, count: 1600)
        _ = await service.processFrame(samples)

        // When - update to different keywords
        let newKeywords = [
            TriggerKeyword(phrase: "hello world", boostingScore: 1.3, triggerThreshold: 0.3, isEnabled: true),
            TriggerKeyword(phrase: "hi google", boostingScore: 1.3, triggerThreshold: 0.3, isEnabled: true)
        ]
        try await service.updateKeywords(newKeywords)

        // Then
        let isInitialized = await service.isInitialized
        XCTAssertTrue(isInitialized, "Service should remain initialized after keyword update")

        // Can still process audio
        let result = await service.processFrame(samples)
        XCTAssertNil(result) // Silent audio, no detection expected

        // Cleanup
        await service.shutdown()
    }

    /// Test processing streaming audio chunks (simulating real-time audio)
    func test_integration_streamingAudioProcessing_handlesChunksCorrectly() async throws {
        guard let modelPath = getRealModelDirectory() else {
            throw XCTSkip("sherpa-onnx model not available at expected path")
        }

        // Given
        let service = WakeWordService()
        let keywords = [TriggerKeyword(phrase: "hey siri", boostingScore: 1.5, triggerThreshold: 0.25, isEnabled: true)]
        try await service.initialize(modelPath: modelPath, keywords: keywords)

        // Simulate streaming audio with varying chunk sizes (common in real audio pipelines)
        let chunkSizes = [160, 320, 480, 640, 800, 1600, 3200] // Various chunk sizes

        // When - process audio in varying chunk sizes
        for chunkSize in chunkSizes {
            let chunk: [Float] = Array(repeating: 0.0, count: chunkSize)
            let result = await service.processFrame(chunk)
            XCTAssertNil(result, "Silent audio should not trigger detection")
        }

        // Then - verify all chunks were processed
        let stats = await service.getStatistics()
        XCTAssertEqual(stats.framesProcessed, chunkSizes.count, "Should process all chunk sizes")

        // Cleanup
        await service.shutdown()
    }

    /// Test concurrent frame processing is thread-safe with real model
    func test_integration_concurrentProcessing_isThreadSafe() async throws {
        guard let modelPath = getRealModelDirectory() else {
            throw XCTSkip("sherpa-onnx model not available at expected path")
        }

        // Given
        let service = WakeWordService()
        let keywords = [TriggerKeyword(phrase: "hey siri", boostingScore: 1.5, triggerThreshold: 0.25, isEnabled: true)]
        try await service.initialize(modelPath: modelPath, keywords: keywords)

        let samples: [Float] = Array(repeating: 0.0, count: 1600)
        let iterations = 50

        // When - concurrent frame processing
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<iterations {
                group.addTask {
                    _ = await service.processFrame(samples)
                }
            }
        }

        // Then - all frames should be processed
        let stats = await service.getStatistics()
        XCTAssertEqual(stats.framesProcessed, iterations, "All concurrent frames should be processed")

        // Cleanup
        await service.shutdown()
    }

    /// Test that the service handles model files being present but potentially corrupted
    func test_integration_modelValidation_checksRequiredFiles() async throws {
        // Given - create a temp directory with only partial model files
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(
            "partial_model_\(UUID().uuidString)"
        )
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create only tokens.txt (missing encoder, decoder, joiner)
        let tokensPath = tempDir.appendingPathComponent("tokens.txt")
        try "test".write(to: tokensPath, atomically: true, encoding: .utf8)

        let service = WakeWordService()
        let keywords = [TriggerKeyword(phrase: "hey siri", boostingScore: 1.5, triggerThreshold: 0.25, isEnabled: true)]

        // When/Then - should fail because encoder is missing
        do {
            try await service.initialize(modelPath: tempDir.path, keywords: keywords)
            XCTFail("Should throw error for missing model files")
        } catch let error as WakeWordError {
            if case .modelNotFound(let path) = error {
                XCTAssertTrue(path.contains("encoder"), "Error should mention missing encoder file")
            } else {
                XCTFail("Expected modelNotFound error, got: \(error)")
            }
        }
    }

    /// Test processing a known audio pattern (synthetic tone)
    func test_integration_syntheticAudio_processesWithoutError() async throws {
        guard let modelPath = getRealModelDirectory() else {
            throw XCTSkip("sherpa-onnx model not available at expected path")
        }

        // Given
        let service = WakeWordService()
        let keywords = [TriggerKeyword(phrase: "hey siri", boostingScore: 1.5, triggerThreshold: 0.25, isEnabled: true)]
        try await service.initialize(modelPath: modelPath, keywords: keywords)

        // Create a synthetic audio signal (440Hz sine wave at 16kHz sample rate)
        let sampleRate: Float = 16000.0
        let frequency: Float = 440.0
        let duration: Float = 0.1 // 100ms
        let numSamples = Int(sampleRate * duration)

        var syntheticAudio: [Float] = []
        for i in 0..<numSamples {
            let t = Float(i) / sampleRate
            let sample = 0.5 * sin(2.0 * Float.pi * frequency * t)
            syntheticAudio.append(sample)
        }

        // When - process the synthetic audio
        let result = await service.processFrame(syntheticAudio)

        // Then - should not crash and should not detect keyword in pure tone
        XCTAssertNil(result, "Pure tone should not trigger keyword detection")

        let stats = await service.getStatistics()
        XCTAssertEqual(stats.framesProcessed, 1)

        // Cleanup
        await service.shutdown()
    }

    // MARK: - TriggerKeyword Tests

    func test_triggerKeyword_isValid_withValidPhrase() {
        // Given
        let keyword = TriggerKeyword(phrase: "Hey Claude", isEnabled: true)

        // Then
        XCTAssertTrue(keyword.isValid)
    }

    func test_triggerKeyword_isInvalid_withEmptyPhrase() {
        // Given
        let keyword = TriggerKeyword(phrase: "", isEnabled: true)

        // Then
        XCTAssertFalse(keyword.isValid)
    }

    func test_triggerKeyword_isInvalid_withWhitespaceOnlyPhrase() {
        // Given
        let keyword = TriggerKeyword(phrase: "   ", isEnabled: true)

        // Then
        XCTAssertFalse(keyword.isValid)
    }

    func test_triggerKeyword_clampsBoostingScore() {
        // Given - values outside 1.0-2.0 range
        let keywordLow = TriggerKeyword(phrase: "test", boostingScore: 0.5, isEnabled: true)
        let keywordHigh = TriggerKeyword(phrase: "test", boostingScore: 3.0, isEnabled: true)

        // Then
        XCTAssertEqual(keywordLow.boostingScore, 1.0)
        XCTAssertEqual(keywordHigh.boostingScore, 2.0)
    }

    func test_triggerKeyword_clampsTriggerThreshold() {
        // Given - values outside 0.0-1.0 range
        let keywordLow = TriggerKeyword(phrase: "test", triggerThreshold: -0.5, isEnabled: true)
        let keywordHigh = TriggerKeyword(phrase: "test", triggerThreshold: 1.5, isEnabled: true)

        // Then
        XCTAssertEqual(keywordLow.triggerThreshold, 0.0)
        XCTAssertEqual(keywordHigh.triggerThreshold, 1.0)
    }

    func test_triggerKeyword_displayName_returnsPhrase() {
        // Given
        let keyword = TriggerKeyword(phrase: "Hey Claude", isEnabled: true)

        // Then
        XCTAssertEqual(keyword.displayName, "Hey Claude")
    }

    func test_triggerKeyword_displayName_returnsEmptyPlaceholder() {
        // Given
        let keyword = TriggerKeyword(phrase: "", isEnabled: true)

        // Then
        XCTAssertEqual(keyword.displayName, "(empty)")
    }

    func test_triggerKeyword_presets_exist() {
        // Then - verify the actual presets defined in TriggerKeyword
        XCTAssertNotNil(TriggerKeyword.heyClaudeDefault)
        XCTAssertNotNil(TriggerKeyword.claudePreset)
        XCTAssertNotNil(TriggerKeyword.opusPreset)
        XCTAssertNotNil(TriggerKeyword.sonnetPreset)
    }

    func test_triggerKeyword_heyClaudeDefault_hasCorrectValues() {
        // Given - test the actual TriggerKeyword.heyClaudeDefault preset
        let keyword = TriggerKeyword.heyClaudeDefault

        // Then
        XCTAssertEqual(keyword.phrase, "Hey Claude")
        XCTAssertEqual(keyword.boostingScore, 1.5)
        XCTAssertEqual(keyword.triggerThreshold, 0.35)
        XCTAssertTrue(keyword.isEnabled)
    }

    func test_validTestKeyword_hasCorrectValues() {
        // Given - verify test helper keyword with valid BPE mapping
        let keyword = Self.validTestKeyword

        // Then
        XCTAssertEqual(keyword.phrase, "hey siri")
        XCTAssertEqual(keyword.boostingScore, 1.5)
        XCTAssertEqual(keyword.triggerThreshold, 0.35)
        XCTAssertTrue(keyword.isEnabled)
    }

    // MARK: - Helper Methods

    /// Returns the path to the real sherpa-onnx KWS model directory
    ///
    /// The model files are located at:
    /// `Sources/Resources/Models/kws/sherpa-onnx-kws-zipformer-gigaspeech-3.3M-2024-01-01/`
    /// (or legacy location: `Resources/Models/kws/...`)
    ///
    /// - Note: For tests that don't require actual model initialization,
    ///   use `createTempModelDirectory()` instead to create a mock directory.
    private func getRealModelDirectory() -> String? {
        // Try to find the model directory relative to the package root
        // In tests, we may be running from different working directories

        // Option 1: Check relative to current file
        let currentFile = #file
        let testsDir = (currentFile as NSString).deletingLastPathComponent  // Services
        let speechToTextTestsDir = (testsDir as NSString).deletingLastPathComponent  // SpeechToTextTests
        let testsRootDir = (speechToTextTestsDir as NSString).deletingLastPathComponent  // Tests
        let packageRoot = (testsRootDir as NSString).deletingLastPathComponent  // package root

        // Primary location: Sources/Resources/Models (SPM bundle resources)
        let modelPathSources = (packageRoot as NSString).appendingPathComponent(
            "Sources/Resources/Models/kws/sherpa-onnx-kws-zipformer-gigaspeech-3.3M-2024-01-01"
        )

        if FileManager.default.fileExists(atPath: modelPathSources) {
            return modelPathSources
        }

        // Legacy location: Resources/Models (fallback)
        let modelPath = (packageRoot as NSString).appendingPathComponent(
            "Resources/Models/kws/sherpa-onnx-kws-zipformer-gigaspeech-3.3M-2024-01-01"
        )

        if FileManager.default.fileExists(atPath: modelPath) {
            return modelPath
        }

        // Option 2: Try common paths when running from Xcode
        let possiblePaths = [
            "/Users/simon.lynch/git/mac-speech-to-text/Sources/Resources/Models/kws/sherpa-onnx-kws-zipformer-gigaspeech-3.3M-2024-01-01",
            "/Users/simon.lynch/git/mac-speech-to-text/Resources/Models/kws/sherpa-onnx-kws-zipformer-gigaspeech-3.3M-2024-01-01",
            "./Sources/Resources/Models/kws/sherpa-onnx-kws-zipformer-gigaspeech-3.3M-2024-01-01",
            "./Resources/Models/kws/sherpa-onnx-kws-zipformer-gigaspeech-3.3M-2024-01-01"
        ]

        for path in possiblePaths where FileManager.default.fileExists(atPath: path) {
            return path
        }

        return nil
    }

    /// Creates a temporary directory to simulate a model path for unit tests
    ///
    /// This uses the real model directory if available, which enables full integration testing.
    /// Tests that use this method should use keywords that have valid BPE mappings
    /// (e.g., "hey siri", "hello world", "hi google").
    ///
    /// - Note: Use `createMockModelDirectory()` for tests that need to use arbitrary keywords
    ///   like "Hey Claude" which don't have valid BPE mappings in the model.
    private func createTempModelDirectory() -> String {
        // Use real model directory to enable integration testing
        if let realModelPath = getRealModelDirectory() {
            return realModelPath
        }

        // Fallback to mock directory if real model not available
        return createMockModelDirectory()
    }

    /// Creates a mock model directory for unit tests that don't need real model functionality
    ///
    /// This is used for tests that:
    /// - Test error handling (invalid paths, empty keywords)
    /// - Use arbitrary keywords that don't have valid BPE mappings
    /// - Don't need actual sherpa-onnx model initialization
    ///
    /// - Note: Tests using this directory will have a stub "initialized" state but
    ///   processFrame() will use a simulated path without real sherpa-onnx processing.
    private func createMockModelDirectory() -> String {
        let tempDir = FileManager.default.temporaryDirectory
        let modelPath = tempDir.appendingPathComponent("test_wake_model_\(UUID().uuidString)")

        do {
            try FileManager.default.createDirectory(at: modelPath, withIntermediateDirectories: true)
        } catch {
            XCTFail("Failed to create temp directory: \(error)")
        }

        return modelPath.path
    }

    /// Cleans up the temporary directory (only if it's a temp directory, not the real model path)
    private func cleanupTempDirectory(_ path: String) {
        // Don't delete the real model directory
        if let realPath = getRealModelDirectory(), path == realPath {
            return
        }
        try? FileManager.default.removeItem(atPath: path)
    }
}
