// RecordingViewModelTests.swift
// macOS Local Speech-to-Text Application
//
// Unit tests for RecordingViewModel

import XCTest
@testable import SpeechToText

@MainActor
final class RecordingViewModelTests: XCTestCase {
    // MARK: - Properties

    var sut: RecordingViewModel!
    var mockAudioService: MockAudioCaptureService!
    var mockFluidAudioService: MockFluidAudioService!
    var mockTextInsertionService: MockTextInsertionService!
    var mockSettingsService: MockSettingsService!
    var mockStatisticsService: MockStatisticsService!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()

        mockAudioService = MockAudioCaptureService()
        mockFluidAudioService = MockFluidAudioService()
        mockTextInsertionService = MockTextInsertionService()
        mockSettingsService = MockSettingsService()
        mockStatisticsService = MockStatisticsService()

        sut = RecordingViewModel(
            audioService: mockAudioService,
            fluidAudioService: mockFluidAudioService,
            textInsertionService: mockTextInsertionService,
            settingsService: mockSettingsService,
            statisticsService: mockStatisticsService
        )
    }

    override func tearDown() async throws {
        sut = nil
        mockAudioService = nil
        mockFluidAudioService = nil
        mockTextInsertionService = nil
        mockSettingsService = nil
        mockStatisticsService = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func test_initialization_setsDefaultState() {
        // Then
        XCTAssertNil(sut.currentSession)
        XCTAssertEqual(sut.audioLevel, 0.0)
        XCTAssertFalse(sut.isRecording)
        XCTAssertFalse(sut.isTranscribing)
        XCTAssertFalse(sut.isInserting)
        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(sut.transcribedText, "")
        XCTAssertEqual(sut.confidence, 0.0)
    }

    func test_initialization_loadsLanguageFromSettings() {
        // Given
        let customSettings = UserSettings.default
        mockSettingsService.mockSettings = customSettings

        // When
        let viewModel = RecordingViewModel(
            audioService: mockAudioService,
            fluidAudioService: mockFluidAudioService,
            textInsertionService: mockTextInsertionService,
            settingsService: mockSettingsService,
            statisticsService: mockStatisticsService
        )

        // Then
        XCTAssertEqual(viewModel.currentLanguage, customSettings.language.defaultLanguage)
    }

    // MARK: - startRecording Tests

    func test_startRecording_setsIsRecordingTrue() async throws {
        // When
        try await sut.startRecording()

        // Then
        XCTAssertTrue(sut.isRecording)
    }

    func test_startRecording_createsNewSession() async throws {
        // When
        try await sut.startRecording()

        // Then
        XCTAssertNotNil(sut.currentSession)
        XCTAssertEqual(sut.currentSession?.state, .recording)
    }

    func test_startRecording_clearsErrorMessage() async throws {
        // Given
        sut.errorMessage = "Previous error"

        // When
        try await sut.startRecording()

        // Then
        XCTAssertNil(sut.errorMessage)
    }

    func test_startRecording_clearsPreviousTranscription() async throws {
        // Given
        sut.transcribedText = "Previous text"
        sut.confidence = 0.9

        // When
        try await sut.startRecording()

        // Then
        XCTAssertEqual(sut.transcribedText, "")
        XCTAssertEqual(sut.confidence, 0.0)
    }

    func test_startRecording_callsAudioService() async throws {
        // When
        try await sut.startRecording()

        // Then
        XCTAssertTrue(mockAudioService.startCaptureCalled)
    }

    func test_startRecording_throwsWhenAlreadyRecording() async throws {
        // Given
        try await sut.startRecording()

        // When/Then
        do {
            try await sut.startRecording()
            XCTFail("Expected alreadyRecording error")
        } catch let error as RecordingError {
            XCTAssertEqual(error, .alreadyRecording)
        }
    }

    func test_startRecording_throwsWhenAudioCaptureFails() async {
        // Given
        mockAudioService.shouldFailStartCapture = true

        // When/Then
        do {
            try await sut.startRecording()
            XCTFail("Expected audioCaptureFailed error")
        } catch let error as RecordingError {
            if case .audioCaptureFailed = error {
                // Expected
            } else {
                XCTFail("Expected audioCaptureFailed error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func test_startRecording_resetsStateOnFailure() async {
        // Given
        mockAudioService.shouldFailStartCapture = true

        // When
        do {
            try await sut.startRecording()
        } catch {
            // Expected
        }

        // Then
        XCTAssertFalse(sut.isRecording)
        XCTAssertNil(sut.currentSession)
    }

    // MARK: - stopRecording Tests

    func test_stopRecording_setsIsRecordingFalse() async throws {
        // Given
        try await sut.startRecording()

        // When
        try await sut.stopRecording()

        // Then
        XCTAssertFalse(sut.isRecording)
    }

    func test_stopRecording_throwsWhenNotRecording() async {
        // When/Then
        do {
            try await sut.stopRecording()
            XCTFail("Expected notRecording error")
        } catch let error as RecordingError {
            XCTAssertEqual(error, .notRecording)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func test_stopRecording_callsAudioServiceStopCapture() async throws {
        // Given
        try await sut.startRecording()

        // When
        try await sut.stopRecording()

        // Then
        XCTAssertTrue(mockAudioService.stopCaptureCalled)
    }

    func test_stopRecording_triggersTranscription() async throws {
        // Given
        try await sut.startRecording()
        mockAudioService.mockSamples = [100, 200, 300]
        mockFluidAudioService.mockResult = TranscriptionResult(text: "Hello", confidence: 0.95)

        // When
        try await sut.stopRecording()

        // Then
        XCTAssertTrue(mockFluidAudioService.transcribeCalled)
    }

    func test_stopRecording_updatesTranscribedText() async throws {
        // Given
        try await sut.startRecording()
        mockAudioService.mockSamples = [100, 200, 300]
        mockFluidAudioService.mockResult = TranscriptionResult(text: "Test transcription", confidence: 0.85)

        // When
        try await sut.stopRecording()

        // Then
        XCTAssertEqual(sut.transcribedText, "Test transcription")
        XCTAssertEqual(sut.confidence, 0.85, accuracy: 0.01)
    }

    func test_stopRecording_insertsTextViaTextInsertionService() async throws {
        // Given
        try await sut.startRecording()
        mockAudioService.mockSamples = [100, 200, 300]
        mockFluidAudioService.mockResult = TranscriptionResult(text: "Insert me", confidence: 0.9)

        // When
        try await sut.stopRecording()

        // Then
        XCTAssertTrue(mockTextInsertionService.insertTextCalled)
        XCTAssertEqual(mockTextInsertionService.lastInsertedText, "Insert me")
    }

    func test_stopRecording_throwsWhenNoAudioCaptured() async throws {
        // Given
        try await sut.startRecording()
        mockAudioService.mockSamples = [] // Empty samples

        // When/Then
        do {
            try await sut.stopRecording()
            XCTFail("Expected noAudioCaptured error")
        } catch let error as RecordingError {
            XCTAssertEqual(error, .noAudioCaptured)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - cancelRecording Tests

    func test_cancelRecording_resetsAllState() async throws {
        // Given
        try await sut.startRecording()

        // When
        await sut.cancelRecording()

        // Then
        XCTAssertFalse(sut.isRecording)
        XCTAssertFalse(sut.isTranscribing)
        XCTAssertFalse(sut.isInserting)
        XCTAssertNil(sut.currentSession)
        XCTAssertEqual(sut.audioLevel, 0.0)
        XCTAssertEqual(sut.transcribedText, "")
        XCTAssertEqual(sut.confidence, 0.0)
        XCTAssertNil(sut.errorMessage)
    }

    func test_cancelRecording_stopsAudioCapture() async throws {
        // Given
        try await sut.startRecording()

        // When
        await sut.cancelRecording()

        // Then
        XCTAssertTrue(mockAudioService.stopCaptureCalled)
    }

    func test_cancelRecording_canBeCalledWhenNotRecording() async {
        // When - should not throw
        await sut.cancelRecording()

        // Then
        XCTAssertFalse(sut.isRecording)
    }

    // MARK: - currentLanguageModel Tests

    func test_currentLanguageModel_returnsCorrectLanguage() {
        // Given
        sut.currentLanguage = "fr"

        // When
        let model = sut.currentLanguageModel

        // Then
        XCTAssertNotNil(model)
        XCTAssertEqual(model?.code, "fr")
    }

    func test_currentLanguageModel_returnsNilForUnsupportedLanguage() {
        // Given
        sut.currentLanguage = "unsupported"

        // When
        let model = sut.currentLanguageModel

        // Then
        XCTAssertNil(model)
    }

    // MARK: - RecordingError Tests

    func test_recordingError_alreadyRecording_hasCorrectDescription() {
        // Given
        let error = RecordingError.alreadyRecording

        // Then
        XCTAssertEqual(error.errorDescription, "Recording is already in progress")
    }

    func test_recordingError_notRecording_hasCorrectDescription() {
        // Given
        let error = RecordingError.notRecording

        // Then
        XCTAssertEqual(error.errorDescription, "No active recording to stop")
    }

    func test_recordingError_noAudioCaptured_hasCorrectDescription() {
        // Given
        let error = RecordingError.noAudioCaptured

        // Then
        XCTAssertEqual(error.errorDescription, "No audio was captured")
    }

    func test_recordingError_noActiveSession_hasCorrectDescription() {
        // Given
        let error = RecordingError.noActiveSession

        // Then
        XCTAssertEqual(error.errorDescription, "No active recording session")
    }

    func test_recordingError_audioCaptureFailed_hasCorrectDescription() {
        // Given
        let error = RecordingError.audioCaptureFailed("Test error")

        // Then
        XCTAssertEqual(error.errorDescription, "Audio capture failed: Test error")
    }

    func test_recordingError_transcriptionFailed_hasCorrectDescription() {
        // Given
        let error = RecordingError.transcriptionFailed("ML error")

        // Then
        XCTAssertEqual(error.errorDescription, "Transcription failed: ML error")
    }

    func test_recordingError_textInsertionFailed_hasCorrectDescription() {
        // Given
        let error = RecordingError.textInsertionFailed("Accessibility error")

        // Then
        XCTAssertEqual(error.errorDescription, "Text insertion failed: Accessibility error")
    }
}

// MARK: - Mock Services

class MockAudioCaptureService: AudioCaptureService {
    var startCaptureCalled = false
    var stopCaptureCalled = false
    var shouldFailStartCapture = false
    var mockSamples: [Int16] = [100, 200, 300, 400, 500]

    override func startCapture(levelCallback: @escaping (Double) -> Void) async throws {
        startCaptureCalled = true
        if shouldFailStartCapture {
            throw AudioCaptureError.engineStartFailed
        }
    }

    override func stopCapture() async throws -> [Int16] {
        stopCaptureCalled = true
        return mockSamples
    }
}

class MockFluidAudioService: FluidAudioService {
    var initializeCalled = false
    var transcribeCalled = false
    var switchLanguageCalled = false
    var mockResult = TranscriptionResult(text: "Mock transcription", confidence: 0.9)

    override func initialize(language: String) async throws {
        initializeCalled = true
    }

    override func transcribe(samples: [Int16]) async throws -> TranscriptionResult {
        transcribeCalled = true
        return mockResult
    }

    override func switchLanguage(to languageCode: String) async throws {
        switchLanguageCalled = true
    }
}

class MockTextInsertionService: TextInsertionService {
    var insertTextCalled = false
    var lastInsertedText: String?

    override func insertText(_ text: String) async throws {
        insertTextCalled = true
        lastInsertedText = text
    }
}

class MockStatisticsService: StatisticsService {
    var recordSessionCalled = false

    override func recordSession(_ session: RecordingSession) async throws {
        recordSessionCalled = true
    }
}
