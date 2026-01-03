import XCTest
@testable import SpeechToText

final class RecordingSessionTests: XCTestCase {

    // MARK: - Initialization Tests

    func test_initialization_setsDefaultValues() {
        let session = RecordingSession()

        XCTAssertNotNil(session.id)
        XCTAssertEqual(session.state, .idle)
        XCTAssertNil(session.endTime)
        XCTAssertEqual(session.transcribedText, "")
        XCTAssertEqual(session.language, "en")
        XCTAssertEqual(session.confidenceScore, 0.0)
        XCTAssertFalse(session.insertionSuccess)
        XCTAssertNil(session.errorMessage)
        XCTAssertEqual(session.peakAmplitude, 0)
        XCTAssertTrue(session.segments.isEmpty)
        XCTAssertNil(session.audioData)
    }

    func test_initialization_acceptsCustomLanguage() {
        let session = RecordingSession(language: "de")
        XCTAssertEqual(session.language, "de")
    }

    func test_initialization_acceptsCustomState() {
        let session = RecordingSession(state: .recording)
        XCTAssertEqual(session.state, .recording)
    }

    func test_initialization_acceptsCustomId() {
        let customId = UUID()
        let session = RecordingSession(id: customId)
        XCTAssertEqual(session.id, customId)
    }

    func test_initialization_acceptsCustomStartTime() {
        let customStartTime = Date(timeIntervalSinceNow: -100)
        let session = RecordingSession(startTime: customStartTime)
        XCTAssertEqual(session.startTime, customStartTime)
    }

    // MARK: - Computed Property Tests

    func test_duration_withEndTime_returnsCorrectDuration() {
        let startTime = Date(timeIntervalSinceNow: -10)
        var session = RecordingSession(startTime: startTime)
        session.endTime = Date()

        XCTAssertEqual(session.duration, 10.0, accuracy: 0.5)
    }

    func test_duration_withoutEndTime_returnsDurationToNow() {
        let session = RecordingSession(startTime: Date(timeIntervalSinceNow: -5))

        XCTAssertEqual(session.duration, 5.0, accuracy: 0.5)
    }

    func test_wordCount_emptyText_returnsZero() {
        let session = RecordingSession()
        XCTAssertEqual(session.wordCount, 0)
    }

    func test_wordCount_withText_returnsCorrectCount() {
        var session = RecordingSession()
        session.transcribedText = "Hello world this is a test"
        XCTAssertEqual(session.wordCount, 6)
    }

    func test_wordCount_handlesMultipleSpaces() {
        var session = RecordingSession()
        session.transcribedText = "Hello   world"
        XCTAssertEqual(session.wordCount, 2)
    }

    func test_wordCount_handlesSingleWord() {
        var session = RecordingSession()
        session.transcribedText = "Hello"
        XCTAssertEqual(session.wordCount, 1)
    }

    func test_wordCount_handlesWhitespaceOnly() {
        var session = RecordingSession()
        session.transcribedText = "   "
        XCTAssertEqual(session.wordCount, 0)
    }

    // MARK: - Validation Tests

    func test_isValid_returnsTrueForValidSession() {
        var session = RecordingSession()
        session.endTime = Date(timeIntervalSinceNow: 10)
        session.confidenceScore = 0.85

        XCTAssertTrue(session.isValid)
    }

    func test_isValid_returnsTrueWithNoEndTime() {
        let session = RecordingSession()
        XCTAssertTrue(session.isValid)
    }

    func test_isValid_returnsFalseWhenEndTimeBeforeStartTime() {
        var session = RecordingSession()
        session.endTime = Date(timeIntervalSinceNow: -10)

        XCTAssertFalse(session.isValid)
    }

    func test_isValid_returnsFalseWhenConfidenceNegative() {
        var session = RecordingSession()
        session.endTime = Date()
        session.confidenceScore = -0.1

        XCTAssertFalse(session.isValid)
    }

    func test_isValid_returnsFalseWhenConfidenceExceedsOne() {
        var session = RecordingSession()
        session.endTime = Date()
        session.confidenceScore = 1.1

        XCTAssertFalse(session.isValid)
    }

    func test_isValid_returnsFalseWhenLanguageEmpty() {
        let session = RecordingSession(language: "")
        XCTAssertFalse(session.isValid)
    }

    func test_isValid_returnsTrueAtConfidenceBoundaries() {
        var session = RecordingSession()

        session.confidenceScore = 0.0
        XCTAssertTrue(session.isValid)

        session.confidenceScore = 1.0
        XCTAssertTrue(session.isValid)
    }

    // MARK: - SessionState Tests

    func test_sessionState_isActive_recording() {
        XCTAssertTrue(SessionState.recording.isActive)
    }

    func test_sessionState_isActive_transcribing() {
        XCTAssertTrue(SessionState.transcribing.isActive)
    }

    func test_sessionState_isActive_inserting() {
        XCTAssertTrue(SessionState.inserting.isActive)
    }

    func test_sessionState_isActive_idle() {
        XCTAssertFalse(SessionState.idle.isActive)
    }

    func test_sessionState_isActive_completed() {
        XCTAssertFalse(SessionState.completed.isActive)
    }

    func test_sessionState_isActive_cancelled() {
        XCTAssertFalse(SessionState.cancelled.isActive)
    }

    func test_sessionState_description() {
        XCTAssertEqual(SessionState.idle.description, "Idle")
        XCTAssertEqual(SessionState.recording.description, "Recording...")
        XCTAssertEqual(SessionState.transcribing.description, "Transcribing...")
        XCTAssertEqual(SessionState.inserting.description, "Inserting text...")
        XCTAssertEqual(SessionState.completed.description, "Completed")
        XCTAssertEqual(SessionState.cancelled.description, "Cancelled")
    }

    func test_sessionState_allCases() {
        XCTAssertEqual(SessionState.allCases.count, 6)
        XCTAssertTrue(SessionState.allCases.contains(.idle))
        XCTAssertTrue(SessionState.allCases.contains(.recording))
        XCTAssertTrue(SessionState.allCases.contains(.transcribing))
        XCTAssertTrue(SessionState.allCases.contains(.inserting))
        XCTAssertTrue(SessionState.allCases.contains(.completed))
        XCTAssertTrue(SessionState.allCases.contains(.cancelled))
    }

    func test_sessionState_codableRoundtrip() throws {
        for state in SessionState.allCases {
            let data = try JSONEncoder().encode(state)
            let decoded = try JSONDecoder().decode(SessionState.self, from: data)
            XCTAssertEqual(decoded, state)
        }
    }

    // MARK: - TranscriptionSegment Tests

    func test_transcriptionSegment_initialization() {
        let segment = TranscriptionSegment(
            text: "Hello",
            startTime: 0.0,
            endTime: 1.5,
            confidence: 0.95
        )

        XCTAssertNotNil(segment.id)
        XCTAssertEqual(segment.text, "Hello")
        XCTAssertEqual(segment.startTime, 0.0)
        XCTAssertEqual(segment.endTime, 1.5)
        XCTAssertEqual(segment.confidence, 0.95)
    }

    func test_transcriptionSegment_customId() {
        let customId = UUID()
        let segment = TranscriptionSegment(
            id: customId,
            text: "Test",
            startTime: 0.0,
            endTime: 0.5,
            confidence: 0.9
        )

        XCTAssertEqual(segment.id, customId)
    }

    // MARK: - Mutability Tests

    func test_session_stateCanBeModified() {
        var session = RecordingSession()
        XCTAssertEqual(session.state, .idle)

        session.state = .recording
        XCTAssertEqual(session.state, .recording)

        session.state = .transcribing
        XCTAssertEqual(session.state, .transcribing)

        session.state = .completed
        XCTAssertEqual(session.state, .completed)
    }

    func test_session_transcribedTextCanBeModified() {
        var session = RecordingSession()
        session.transcribedText = "Hello world"

        XCTAssertEqual(session.transcribedText, "Hello world")
    }

    func test_session_confidenceScoreCanBeModified() {
        var session = RecordingSession()
        session.confidenceScore = 0.95

        XCTAssertEqual(session.confidenceScore, 0.95)
    }

    func test_session_insertionSuccessCanBeModified() {
        var session = RecordingSession()
        session.insertionSuccess = true

        XCTAssertTrue(session.insertionSuccess)
    }

    func test_session_errorMessageCanBeModified() {
        var session = RecordingSession()
        session.errorMessage = "An error occurred"

        XCTAssertEqual(session.errorMessage, "An error occurred")
    }

    func test_session_peakAmplitudeCanBeModified() {
        var session = RecordingSession()
        session.peakAmplitude = 1000

        XCTAssertEqual(session.peakAmplitude, 1000)
    }

    func test_session_audioDataCanBeModified() {
        var session = RecordingSession()
        let samples: [Int16] = [100, 200, 300]
        session.audioData = samples

        XCTAssertEqual(session.audioData, samples)
    }

    func test_session_segmentsCanBeModified() {
        var session = RecordingSession()
        let segment = TranscriptionSegment(
            text: "Test",
            startTime: 0.0,
            endTime: 1.0,
            confidence: 0.9
        )
        session.segments = [segment]

        XCTAssertEqual(session.segments.count, 1)
        XCTAssertEqual(session.segments[0].text, "Test")
    }

    // MARK: - Identifiable Tests

    func test_session_uniqueIds() {
        let session1 = RecordingSession()
        let session2 = RecordingSession()

        XCTAssertNotEqual(session1.id, session2.id)
    }

    func test_segment_uniqueIds() {
        let segment1 = TranscriptionSegment(text: "A", startTime: 0, endTime: 1, confidence: 0.9)
        let segment2 = TranscriptionSegment(text: "B", startTime: 1, endTime: 2, confidence: 0.9)

        XCTAssertNotEqual(segment1.id, segment2.id)
    }
}
