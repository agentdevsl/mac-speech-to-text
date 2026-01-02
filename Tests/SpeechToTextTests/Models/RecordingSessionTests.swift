import XCTest
@testable import SpeechToText

final class RecordingSessionTests: XCTestCase {

    // MARK: - Initialization Tests

    func testInitialization_CreatesSessionWithIdleState() {
        // Given/When
        let session = RecordingSession()

        // Then
        XCTAssertNotNil(session.id)
        XCTAssertEqual(session.state, .idle)
        XCTAssertNil(session.startTime)
        XCTAssertNil(session.endTime)
        XCTAssertTrue(session.audioSegments.isEmpty)
        XCTAssertEqual(session.languageCode, "en-US")
        XCTAssertNil(session.transcriptionText)
        XCTAssertEqual(session.confidence, 0.0)
        XCTAssertNil(session.errorMessage)
        XCTAssertFalse(session.wasCancelled)
        XCTAssertTrue(session.metadata.isEmpty)
    }

    // MARK: - State Transition Tests

    func testStartRecording_TransitionsFromIdleToRecording() {
        // Given
        var session = RecordingSession()
        XCTAssertEqual(session.state, .idle)

        // When
        session.startRecording()

        // Then
        XCTAssertEqual(session.state, .recording)
        XCTAssertNotNil(session.startTime)
    }

    func testStopRecording_TransitionsFromRecordingToProcessing() {
        // Given
        var session = RecordingSession()
        session.startRecording()

        // When
        session.stopRecording()

        // Then
        XCTAssertEqual(session.state, .processing)
        XCTAssertNotNil(session.endTime)
    }

    func testCompleteTranscription_TransitionsToCompleted() {
        // Given
        var session = RecordingSession()
        session.startRecording()
        session.stopRecording()

        // When
        session.completeTranscription(text: "Hello world", confidence: 0.95)

        // Then
        XCTAssertEqual(session.state, .completed)
        XCTAssertEqual(session.transcriptionText, "Hello world")
        XCTAssertEqual(session.confidence, 0.95)
    }

    func testCancel_TransitionsToFailed() {
        // Given
        var session = RecordingSession()
        session.startRecording()

        // When
        session.cancel()

        // Then
        XCTAssertEqual(session.state, .failed)
        XCTAssertTrue(session.wasCancelled)
    }

    func testFail_TransitionsToFailedWithError() {
        // Given
        var session = RecordingSession()
        session.startRecording()

        // When
        session.fail(error: "Network timeout")

        // Then
        XCTAssertEqual(session.state, .failed)
        XCTAssertEqual(session.errorMessage, "Network timeout")
    }

    // MARK: - Audio Segment Tests

    func testAddAudioSegment_AppendsToSegments() {
        // Given
        var session = RecordingSession()
        session.startRecording()
        let buffer = AudioBuffer(samples: [0.1, 0.2, 0.3], sampleRate: 16000, channelCount: 1, duration: 0.01, timestamp: Date())

        // When
        session.addAudioSegment(buffer)

        // Then
        XCTAssertEqual(session.audioSegments.count, 1)
        XCTAssertEqual(session.audioSegments[0].samples.count, 3)
    }

    // MARK: - Duration Tests

    func testDuration_ReturnsNilWhenNotStarted() {
        // Given
        let session = RecordingSession()

        // Then
        XCTAssertNil(session.duration)
    }

    func testDuration_ReturnsElapsedTimeWhenRecording() {
        // Given
        var session = RecordingSession()
        session.startRecording()

        // When
        Thread.sleep(forTimeInterval: 0.1)

        // Then
        XCTAssertNotNil(session.duration)
        XCTAssertGreaterThan(session.duration!, 0.0)
    }

    func testDuration_ReturnsFixedTimeWhenCompleted() {
        // Given
        var session = RecordingSession()
        session.startRecording()
        Thread.sleep(forTimeInterval: 0.1)
        session.stopRecording()
        session.completeTranscription(text: "Test", confidence: 0.9)

        // When
        let duration = session.duration

        // Then
        XCTAssertNotNil(duration)
        XCTAssertGreaterThan(duration!, 0.0)
    }

    // MARK: - Word Count Tests

    func testWordCount_ReturnsZeroWhenNoTranscription() {
        // Given
        let session = RecordingSession()

        // Then
        XCTAssertEqual(session.wordCount, 0)
    }

    func testWordCount_CountsWordsCorrectly() {
        // Given
        var session = RecordingSession()
        session.completeTranscription(text: "Hello world this is a test", confidence: 0.9)

        // Then
        XCTAssertEqual(session.wordCount, 6)
    }

    // MARK: - Invalid State Transition Tests

    func testStartRecording_ThrowsWhenNotIdle() {
        // Given
        var session = RecordingSession()
        session.startRecording()

        // When/Then
        XCTAssertThrowsError(try session.startRecording()) { error in
            XCTAssertEqual(error as? RecordingError, .invalidStateTransition)
        }
    }
}
