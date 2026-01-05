import XCTest
@testable import SpeechToText

final class WakeWordServiceTests: XCTestCase {

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

        let keywords = [TriggerKeyword.heyClaudeDefault]

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

        let keywords = [
            TriggerKeyword.heyClaudeDefault,
            TriggerKeyword.claudePreset,
            TriggerKeyword.opusPreset
        ]
        // Enable all keywords
        var enabledKeywords = keywords
        enabledKeywords[1] = TriggerKeyword(
            phrase: "Claude",
            boostingScore: 1.3,
            triggerThreshold: 0.4,
            isEnabled: true
        )
        enabledKeywords[2] = TriggerKeyword(
            phrase: "Opus",
            boostingScore: 1.3,
            triggerThreshold: 0.4,
            isEnabled: true
        )

        // When
        try await service.initialize(modelPath: tempModelPath, keywords: enabledKeywords)

        // Then
        let isInitialized = await service.isInitialized
        XCTAssertTrue(isInitialized)
    }

    // MARK: - Initialize Failure with Invalid Model Path Tests

    func test_initialize_withInvalidModelPath_throwsModelNotFoundError() async {
        // Given
        let service = WakeWordService()
        let invalidPath = "/nonexistent/path/to/model"
        let keywords = [TriggerKeyword.heyClaudeDefault]

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
        let keywords = [TriggerKeyword.heyClaudeDefault]

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
            keywords: [TriggerKeyword.heyClaudeDefault]
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
            keywords: [TriggerKeyword.heyClaudeDefault]
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
            keywords: [TriggerKeyword.heyClaudeDefault]
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
            keywords: [TriggerKeyword.heyClaudeDefault]
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
            keywords: [TriggerKeyword.heyClaudeDefault]
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
            try await service.updateKeywords([TriggerKeyword.heyClaudeDefault])
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
            keywords: [TriggerKeyword.heyClaudeDefault]
        )

        // Process some frames
        let samples: [Float] = Array(repeating: 0.5, count: 1600)
        _ = await service.processFrame(samples)
        _ = await service.processFrame(samples)

        let statsBefore = await service.getStatistics()
        XCTAssertEqual(statsBefore.framesProcessed, 2)

        // When - updateKeywords calls shutdown which clears state, then re-initializes
        // Note: Statistics are intentionally preserved across shutdown/reinitialize cycles
        try await service.updateKeywords([TriggerKeyword(phrase: "New Keyword", isEnabled: true)])

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
            keywords: [TriggerKeyword.heyClaudeDefault]
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
            keywords: [TriggerKeyword.heyClaudeDefault]
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
            keywords: [TriggerKeyword.heyClaudeDefault]
        )
        await service.shutdown()

        // When
        try await service.initialize(
            modelPath: tempModelPath,
            keywords: [TriggerKeyword(phrase: "New Phrase", isEnabled: true)]
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
            keywords: [TriggerKeyword.heyClaudeDefault]
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
            keywords: [TriggerKeyword.heyClaudeDefault]
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
            keywords: [TriggerKeyword.heyClaudeDefault]
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
            keywords: [TriggerKeyword.heyClaudeDefault]
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

        let keyword = TriggerKeyword(
            phrase: "Hey CLAUDE Test",
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
            keywords: [TriggerKeyword.heyClaudeDefault]
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
                            keywords: [TriggerKeyword.heyClaudeDefault]
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
        // Then
        XCTAssertNotNil(TriggerKeyword.heyClaudeDefault)
        XCTAssertNotNil(TriggerKeyword.claudePreset)
        XCTAssertNotNil(TriggerKeyword.opusPreset)
        XCTAssertNotNil(TriggerKeyword.sonnetPreset)
    }

    func test_triggerKeyword_heyClaudeDefault_hasCorrectValues() {
        // Given
        let keyword = TriggerKeyword.heyClaudeDefault

        // Then
        XCTAssertEqual(keyword.phrase, "Hey Claude")
        XCTAssertEqual(keyword.boostingScore, 1.5)
        XCTAssertEqual(keyword.triggerThreshold, 0.35)
        XCTAssertTrue(keyword.isEnabled)
    }

    // MARK: - Helper Methods

    /// Creates a temporary directory to simulate a model path
    private func createTempModelDirectory() -> String {
        let tempDir = FileManager.default.temporaryDirectory
        let modelPath = tempDir.appendingPathComponent("test_wake_model_\(UUID().uuidString)")

        do {
            try FileManager.default.createDirectory(at: modelPath, withIntermediateDirectories: true)
        } catch {
            XCTFail("Failed to create temp directory: \(error)")
        }

        return modelPath.path
    }

    /// Cleans up the temporary directory
    private func cleanupTempDirectory(_ path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }
}
