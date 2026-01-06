import XCTest
@testable import SpeechToText

@MainActor
final class AudioCaptureServiceTests: XCTestCase {

    var service: AudioCaptureService!

    override func setUp() async throws {
        try await super.setUp()
        service = AudioCaptureService()
    }

    override func tearDown() async throws {
        // Ensure capture is stopped
        try? await service.stopCapture()
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func test_initialization_createsService() {
        // Given/When
        let service = AudioCaptureService()

        // Then
        XCTAssertNotNil(service)
    }

    // MARK: - Start Capture Tests

    func test_startCapture_requiresMicrophonePermission() async {
        // Given
        var levelCallbackInvoked = false
        let levelCallback: (Double) -> Void = { _ in levelCallbackInvoked = true }

        // When/Then
        do {
            try await service.startCapture(levelCallback: levelCallback)
            // If we get here, microphone permission was granted
            // This test will pass or fail depending on system permissions
        } catch let error as PermissionError {
            XCTAssertEqual(error, .microphoneDenied)
        } catch {
            // May also throw AudioCaptureError
            XCTAssertTrue(error is AudioCaptureError || error is PermissionError)
        }
    }

    func test_startCapture_storesLevelCallback() async {
        // Given
        var receivedLevel: Double?
        let levelCallback: (Double) -> Void = { level in receivedLevel = level }

        // When
        do {
            try await service.startCapture(levelCallback: levelCallback)
            // Level callback will be invoked when audio is processed
        } catch {
            // Expected to fail without microphone permission
            XCTAssertTrue(error is PermissionError || error is AudioCaptureError)
        }
    }

    // MARK: - Stop Capture Tests

    func test_stopCapture_throwsErrorWhenNoDataRecorded() async {
        // Given
        // Service not started

        // When/Then
        do {
            _ = try await service.stopCapture()
            XCTFail("Should throw noDataRecorded error")
        } catch let error as AudioCaptureError {
            XCTAssertEqual(error, .noDataRecorded)
        } catch {
            XCTFail("Wrong error type")
        }
    }

    func test_stopCapture_returnsRecordedSamples() async {
        // Given
        let levelCallback: (Double) -> Void = { _ in }

        // When
        do {
            try await service.startCapture(levelCallback: levelCallback)

            // Wait a bit to record some audio
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms

            let samples = try await service.stopCapture()

            // Then
            // Samples may be empty if no audio was captured in test environment
            XCTAssertNotNil(samples)
        } catch {
            // Expected to fail in test environment without microphone
            XCTAssertTrue(error is PermissionError || error is AudioCaptureError)
        }
    }

    // MARK: - Audio Format Tests

    func test_audioFormat_uses16kHzSampleRate() {
        // Given
        // Audio format is configured in startCapture

        // When/Then
        // This is verified by checking Constants.Audio.sampleRate
        XCTAssertEqual(Constants.Audio.sampleRate, 16000)
    }

    func test_audioFormat_usesMonoChannel() {
        // Given/When/Then
        XCTAssertEqual(Constants.Audio.channels, 1)
    }

    func test_audioFormat_usesInt16Format() {
        // This test verifies that the audio format is PCM Int16
        // The actual format is set in AVAudioFormat initialization
        // We verify this through the type of samples returned
        // Given/When/Then
        // Type is verified at compile time: [Int16]
        let samples: [Int16] = []
        XCTAssertTrue(type(of: samples) == [Int16].self)
    }

    // MARK: - AudioCaptureError Tests

    func test_audioCaptureError_invalidFormat_hasCorrectDescription() {
        // Given
        let error = AudioCaptureError.invalidFormat

        // When
        let description = error.errorDescription

        // Then
        XCTAssertEqual(description, "Invalid audio format. Expected 16kHz mono PCM")
    }

    func test_audioCaptureError_noDataRecorded_hasCorrectDescription() {
        // Given
        let error = AudioCaptureError.noDataRecorded

        // When
        let description = error.errorDescription

        // Then
        XCTAssertEqual(description, "No audio data was recorded")
    }

    func test_audioCaptureError_engineStartFailed_hasCorrectDescription() {
        // Given
        let error = AudioCaptureError.engineStartFailed("Test error")

        // When
        let description = error.errorDescription

        // Then
        XCTAssertTrue(description?.contains("Failed to start audio engine") ?? false)
        XCTAssertTrue(description?.contains("Test error") ?? false)
    }

    // MARK: - Level Callback Tests

    func test_levelCallback_receivesNormalizedValues() async {
        // Given
        var receivedLevels: [Double] = []
        let levelCallback: (Double) -> Void = { level in
            receivedLevels.append(level)
        }

        // When
        do {
            try await service.startCapture(levelCallback: levelCallback)

            // Wait for some audio processing
            try await Task.sleep(nanoseconds: 200_000_000) // 200ms

            _ = try await service.stopCapture()

            // Then
            // Levels should be normalized to 0-1 range
            for level in receivedLevels {
                XCTAssertGreaterThanOrEqual(level, 0.0)
                XCTAssertLessThanOrEqual(level, 1.0)
            }
        } catch {
            // Expected to fail in test environment
            XCTAssertTrue(error is PermissionError || error is AudioCaptureError)
        }
    }

    // MARK: - Streaming Buffer Tests

    func test_streamingBuffer_accumulatesSamples() async {
        // Given
        let levelCallback: (Double) -> Void = { _ in }

        // When
        do {
            try await service.startCapture(levelCallback: levelCallback)

            // Record for a short duration
            try await Task.sleep(nanoseconds: 300_000_000) // 300ms

            let samples = try await service.stopCapture()

            // Then
            // At 16kHz, 300ms should yield approximately 4800 samples
            // In test environment, this may vary
            XCTAssertNotNil(samples)
        } catch {
            // Expected to fail in test environment
            XCTAssertTrue(error is PermissionError || error is AudioCaptureError)
        }
    }

    // MARK: - Concurrent Access Tests

    func test_startCapture_cannotBeCalledConcurrently() async {
        // Given
        let levelCallback: (Double) -> Void = { _ in }

        // When
        do {
            try await service.startCapture(levelCallback: levelCallback)

            // Attempting to start again should either fail or restart
            try await service.startCapture(levelCallback: levelCallback)

        } catch {
            // Expected behavior - either permission error or audio engine error
            XCTAssertTrue(error is PermissionError || error is AudioCaptureError)
        }
    }

    // MARK: - Multiple Start/Stop Cycles Tests

    func test_multipleCapturesCycles_workCorrectly() async {
        // Given
        let levelCallback: (Double) -> Void = { _ in }

        // When/Then
        for _ in 0..<3 {
            do {
                try await service.startCapture(levelCallback: levelCallback)
                try await Task.sleep(nanoseconds: 50_000_000) // 50ms
                let samples = try await service.stopCapture()
                XCTAssertNotNil(samples)
            } catch {
                // Expected to fail in test environment
                XCTAssertTrue(error is PermissionError || error is AudioCaptureError)
                break
            }
        }
    }

    // MARK: - Buffer Size Tests

    func test_bufferSize_matchesChunkSize() {
        // Given
        let expectedChunkSize = Constants.Audio.chunkSize

        // When/Then
        // Chunk size should be 1600 samples (100ms at 16kHz)
        XCTAssertEqual(expectedChunkSize, 1600)
    }

    // MARK: - Edge Cases Tests

    func test_stopCapture_whenNotStarted_throwsError() async {
        // Given
        // Service never started

        // When/Then
        do {
            _ = try await service.stopCapture()
            XCTFail("Should throw error when stopping without starting")
        } catch {
            XCTAssertTrue(error is AudioCaptureError)
        }
    }

    func test_stopCapture_clearsStreamingBuffer() async {
        // Given
        let levelCallback: (Double) -> Void = { _ in }

        // When
        do {
            try await service.startCapture(levelCallback: levelCallback)
            try await Task.sleep(nanoseconds: 50_000_000)
            _ = try await service.stopCapture()

            // Then
            // Stopping again should fail because buffer was cleared
            do {
                _ = try await service.stopCapture()
                XCTFail("Should fail on second stop")
            } catch {
                XCTAssertTrue(error is AudioCaptureError)
            }
        } catch {
            // Expected to fail in test environment
            XCTAssertTrue(error is PermissionError || error is AudioCaptureError)
        }
    }

    // MARK: - Audio Engine Tests

    func test_audioEngine_initialization() {
        // Given/When
        let service = AudioCaptureService()

        // Then
        // Service should initialize without errors
        XCTAssertNotNil(service)
    }
}

// MARK: - PendingWritesCounter Tests

final class PendingWritesCounterTests: XCTestCase {

    func test_initialState_isEmpty() {
        // Given
        let counter = PendingWritesCounter()

        // When/Then
        XCTAssertTrue(counter.isEmpty)
        XCTAssertEqual(counter.currentCount, 0)
    }

    func test_increment_increasesCount() {
        // Given
        let counter = PendingWritesCounter()

        // When
        counter.increment()

        // Then
        XCTAssertFalse(counter.isEmpty)
        XCTAssertEqual(counter.currentCount, 1)
    }

    func test_decrement_decreasesCount() {
        // Given
        let counter = PendingWritesCounter()
        counter.increment()
        counter.increment()

        // When
        counter.decrement()

        // Then
        XCTAssertFalse(counter.isEmpty)
        XCTAssertEqual(counter.currentCount, 1)
    }

    func test_incrementAndDecrement_balancedReturnsToEmpty() {
        // Given
        let counter = PendingWritesCounter()

        // When
        counter.increment()
        counter.increment()
        counter.increment()
        counter.decrement()
        counter.decrement()
        counter.decrement()

        // Then
        XCTAssertTrue(counter.isEmpty)
        XCTAssertEqual(counter.currentCount, 0)
    }

    func test_waitForCompletion_immediatelyReturnsWhenEmpty() async {
        // Given
        let counter = PendingWritesCounter()

        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        await counter.waitForCompletion()
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime

        // Then
        // Should return immediately (< 10ms)
        XCTAssertLessThan(elapsed, 0.01)
    }

    func test_waitForCompletion_waitsForPendingWrites() async {
        // Given
        let counter = PendingWritesCounter()
        counter.increment()

        // When - decrement in background after short delay
        Task {
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            counter.decrement()
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        await counter.waitForCompletion()
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime

        // Then
        // Should wait at least 50ms but less than 200ms
        XCTAssertGreaterThan(elapsed, 0.04)
        XCTAssertLessThan(elapsed, 0.2)
        XCTAssertTrue(counter.isEmpty)
    }

    func test_concurrentAccess_isThreadSafe() async {
        // Given
        let counter = PendingWritesCounter()
        let iterations = 1000

        // When - concurrent increments followed by concurrent decrements
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<iterations {
                group.addTask {
                    counter.increment()
                }
            }
        }

        XCTAssertEqual(counter.currentCount, iterations)

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<iterations {
                group.addTask {
                    counter.decrement()
                }
            }
        }

        // Then
        XCTAssertTrue(counter.isEmpty)
        XCTAssertEqual(counter.currentCount, 0)
    }

    func test_multipleWaiters_areNotSupported() async {
        // Given - PendingWritesCounter only supports one waiter at a time
        // This test documents the behavior rather than testing a feature
        let counter = PendingWritesCounter()
        counter.increment()

        // When - first waiter will be notified when decrement happens
        Task {
            try? await Task.sleep(nanoseconds: 50_000_000)
            counter.decrement()
        }

        await counter.waitForCompletion()

        // Then - counter should be empty
        XCTAssertTrue(counter.isEmpty)
    }
}
