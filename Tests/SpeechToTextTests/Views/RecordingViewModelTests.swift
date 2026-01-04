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
    var mockAudioService: MockAudioCaptureServiceForRecording!
    var mockFluidAudioService: MockFluidAudioServiceForRecording!
    var mockTextInsertionService: MockTextInsertionServiceForRecording!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()

        mockAudioService = MockAudioCaptureServiceForRecording()
        mockFluidAudioService = MockFluidAudioServiceForRecording()
        mockTextInsertionService = MockTextInsertionServiceForRecording()

        sut = RecordingViewModel(
            audioService: mockAudioService,
            fluidAudioService: mockFluidAudioService,
            textInsertionService: mockTextInsertionService
        )
    }

    override func tearDown() async throws {
        sut = nil
        mockAudioService = nil
        mockFluidAudioService = nil
        mockTextInsertionService = nil
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

    func test_startRecording_resetsStaleStateWhenAlreadyRecording() async throws {
        // Given - start recording to set isRecording = true
        try await sut.startRecording()
        XCTAssertTrue(sut.isRecording)

        // When - call start again (simulating stale state scenario)
        // The fix should reset state instead of throwing
        try await sut.startRecording()

        // Then - should succeed with fresh state
        XCTAssertTrue(sut.isRecording)
        XCTAssertNotNil(sut.currentSession)
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
        await mockFluidAudioService.setMockResult(TranscriptionResult(text: "Hello", confidence: 0.95, durationMs: 1000))

        // When
        try await sut.stopRecording()

        // Then
        let transcribeCalled = await mockFluidAudioService.transcribeCalled
        XCTAssertTrue(transcribeCalled)
    }

    func test_stopRecording_updatesTranscribedText() async throws {
        // Given
        try await sut.startRecording()
        mockAudioService.mockSamples = [100, 200, 300]
        await mockFluidAudioService.setMockResult(TranscriptionResult(text: "Test transcription", confidence: 0.85, durationMs: 1500))

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
        await mockFluidAudioService.setMockResult(TranscriptionResult(text: "Insert me", confidence: 0.9, durationMs: 2000))

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

    // MARK: - Inactivity Timeout Tests

    func test_inactivityTimeout_constantIs30Seconds() {
        // Verify the constant is set correctly
        XCTAssertEqual(Constants.Audio.inactivityTimeout, 30.0)
    }

    func test_talkingThreshold_constantIsSet() {
        // Verify the talking threshold constant exists and is reasonable
        XCTAssertEqual(Constants.Audio.talkingThreshold, 0.02)
        XCTAssertGreaterThan(Constants.Audio.talkingThreshold, 0.0)
        XCTAssertLessThan(Constants.Audio.talkingThreshold, 1.0)
    }

    func test_startRecording_initializesInactivityTracking() async throws {
        // When
        try await sut.startRecording()

        // Then - recording should be active (inactivity timer started internally)
        XCTAssertTrue(sut.isRecording)
        // The inactivity timer is internal, but we can verify recording started successfully
    }

    func test_stopRecording_cleansUpInactivityTimer() async throws {
        // Given
        try await sut.startRecording()

        // When
        try await sut.stopRecording()

        // Then - should be able to start again without issues
        XCTAssertFalse(sut.isRecording)
    }

    func test_cancelRecording_cleansUpInactivityTimer() async throws {
        // Given
        try await sut.startRecording()

        // When
        await sut.cancelRecording()

        // Then - should be able to start again without issues
        XCTAssertFalse(sut.isRecording)
        try await sut.startRecording()
        XCTAssertTrue(sut.isRecording)
    }

    func test_multipleStartStopCycles_workCorrectly() async throws {
        // Test multiple recording cycles to verify state management
        for i in 1...3 {
            // Start recording
            try await sut.startRecording()
            XCTAssertTrue(sut.isRecording, "Cycle \(i): should be recording after start")

            // Stop recording
            try await sut.stopRecording()
            XCTAssertFalse(sut.isRecording, "Cycle \(i): should not be recording after stop")
        }
    }

    func test_startAfterCancel_worksCorrectly() async throws {
        // Given - start and cancel
        try await sut.startRecording()
        await sut.cancelRecording()

        // When - start again
        try await sut.startRecording()

        // Then
        XCTAssertTrue(sut.isRecording)
        XCTAssertNotNil(sut.currentSession)
    }

    func test_rapidStartCancel_handlesCorrectly() async throws {
        // Simulate rapid start/cancel cycles that could cause race conditions
        for _ in 1...5 {
            try await sut.startRecording()
            await sut.cancelRecording()
        }

        // Final state should be clean
        XCTAssertFalse(sut.isRecording)
        XCTAssertNil(sut.currentSession)

        // Should be able to start fresh
        try await sut.startRecording()
        XCTAssertTrue(sut.isRecording)
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

    // MARK: - New Properties Tests (showAccessibilityPrompt, lastTranscriptionCopiedToClipboard)

    func test_initialization_setsAccessibilityPromptFalse() {
        // Then
        XCTAssertFalse(sut.showAccessibilityPrompt)
        XCTAssertFalse(sut.lastTranscriptionCopiedToClipboard)
    }

    func test_cancelRecording_resetsAccessibilityPromptState() async throws {
        // Given
        try await sut.startRecording()
        sut.showAccessibilityPrompt = true
        sut.lastTranscriptionCopiedToClipboard = true

        // When
        await sut.cancelRecording()

        // Then
        XCTAssertFalse(sut.showAccessibilityPrompt)
        XCTAssertFalse(sut.lastTranscriptionCopiedToClipboard)
    }

    // MARK: - onHotkeyReleased Tests

    func test_onHotkeyReleased_throwsWhenNotRecording() async {
        // When/Then
        do {
            try await sut.onHotkeyReleased()
            XCTFail("Expected notRecording error")
        } catch let error as RecordingError {
            XCTAssertEqual(error, .notRecording)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func test_onHotkeyReleased_stopsRecording() async throws {
        // Given
        try await sut.startRecording()
        mockAudioService.mockSamples = [100, 200, 300]
        await mockFluidAudioService.setMockResult(TranscriptionResult(text: "Test", confidence: 0.9, durationMs: 1000))

        // When
        try await sut.onHotkeyReleased()

        // Then
        XCTAssertFalse(sut.isRecording)
        XCTAssertTrue(mockAudioService.stopCaptureCalled)
    }

    func test_onHotkeyReleased_throwsWhenNoAudio() async throws {
        // Given
        try await sut.startRecording()
        mockAudioService.mockSamples = []

        // When/Then
        do {
            try await sut.onHotkeyReleased()
            XCTFail("Expected noAudioCaptured error")
        } catch let error as RecordingError {
            XCTAssertEqual(error, .noAudioCaptured)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func test_onHotkeyReleased_usesInsertTextWithFallback() async throws {
        // Given
        try await sut.startRecording()
        mockAudioService.mockSamples = [100, 200, 300]
        await mockFluidAudioService.setMockResult(TranscriptionResult(text: "Hello world", confidence: 0.95, durationMs: 1500))
        mockTextInsertionService.mockFallbackResult = .insertedViaAccessibility

        // When
        try await sut.onHotkeyReleased()

        // Then
        XCTAssertTrue(mockTextInsertionService.insertTextWithFallbackCalled)
        XCTAssertEqual(mockTextInsertionService.lastInsertedText, "Hello world")
    }

    func test_onHotkeyReleased_showsAccessibilityPromptWhenRequired() async throws {
        // Given
        try await sut.startRecording()
        mockAudioService.mockSamples = [100, 200, 300]
        await mockFluidAudioService.setMockResult(TranscriptionResult(text: "Test", confidence: 0.9, durationMs: 1000))
        mockTextInsertionService.mockFallbackResult = .requiresAccessibilityPermission

        // When
        try await sut.onHotkeyReleased()

        // Then
        XCTAssertTrue(sut.showAccessibilityPrompt)
        XCTAssertTrue(sut.lastTranscriptionCopiedToClipboard)
    }

    func test_onHotkeyReleased_setsClipboardOnlyFlag() async throws {
        // Given
        try await sut.startRecording()
        mockAudioService.mockSamples = [100, 200, 300]
        await mockFluidAudioService.setMockResult(TranscriptionResult(text: "Test", confidence: 0.9, durationMs: 1000))
        mockTextInsertionService.mockFallbackResult = .copiedToClipboardOnly(reason: .userPreference)

        // When
        try await sut.onHotkeyReleased()

        // Then
        XCTAssertFalse(sut.showAccessibilityPrompt)
        XCTAssertTrue(sut.lastTranscriptionCopiedToClipboard)
    }

    func test_onHotkeyReleased_clearsAccessibilityPromptFlagOnSuccess() async throws {
        // Given
        try await sut.startRecording()
        mockAudioService.mockSamples = [100, 200, 300]
        await mockFluidAudioService.setMockResult(TranscriptionResult(text: "Test", confidence: 0.9, durationMs: 1000))
        mockTextInsertionService.mockFallbackResult = .insertedViaAccessibility

        // When
        try await sut.onHotkeyReleased()

        // Then
        XCTAssertFalse(sut.showAccessibilityPrompt)
        XCTAssertFalse(sut.lastTranscriptionCopiedToClipboard)
    }

    func test_onHotkeyReleased_resetsPromptStateBeforeProcessing() async throws {
        // Given - set prompt state from previous session
        sut.showAccessibilityPrompt = true
        sut.lastTranscriptionCopiedToClipboard = true

        try await sut.startRecording()
        mockAudioService.mockSamples = [100, 200, 300]
        await mockFluidAudioService.setMockResult(TranscriptionResult(text: "Test", confidence: 0.9, durationMs: 1000))
        mockTextInsertionService.mockFallbackResult = .insertedViaAccessibility

        // When
        try await sut.onHotkeyReleased()

        // Then - should reset and then set based on result
        XCTAssertFalse(sut.showAccessibilityPrompt)
        XCTAssertFalse(sut.lastTranscriptionCopiedToClipboard)
    }

    // MARK: - dismissAccessibilityPrompt Tests

    func test_dismissAccessibilityPrompt_hidesPrompt() {
        // Given
        sut.showAccessibilityPrompt = true

        // When
        sut.dismissAccessibilityPrompt()

        // Then
        XCTAssertFalse(sut.showAccessibilityPrompt)
    }
}

// MARK: - Mock Services

class MockAudioCaptureServiceForRecording: AudioCaptureService {
    var startCaptureCalled = false
    var stopCaptureCalled = false
    var shouldFailStartCapture = false
    var mockSamples: [Int16] = [100, 200, 300, 400, 500]

    override func startCapture(levelCallback: @escaping (Double) -> Void) async throws {
        startCaptureCalled = true
        if shouldFailStartCapture {
            throw AudioCaptureError.engineStartFailed("Mock engine start failed")
        }
    }

    override func stopCapture() async throws -> [Int16] {
        stopCaptureCalled = true
        return mockSamples
    }
}

actor MockFluidAudioServiceForRecording: FluidAudioServiceProtocol {
    var initializeCalled = false
    var transcribeCalled = false
    var switchLanguageCalled = false
    var mockResult = TranscriptionResult(text: "Mock transcription", confidence: 0.9, durationMs: 1000)
    private var currentLanguage = "en"
    private var isInitialized = false

    func setMockResult(_ result: TranscriptionResult) {
        mockResult = result
    }

    func initialize(language: String) async throws {
        initializeCalled = true
        currentLanguage = language
        isInitialized = true
    }

    func transcribe(samples: [Int16]) async throws -> TranscriptionResult {
        transcribeCalled = true
        return mockResult
    }

    func switchLanguage(to language: String) async throws {
        switchLanguageCalled = true
        currentLanguage = language
    }

    func getCurrentLanguage() -> String {
        currentLanguage
    }

    func checkInitialized() -> Bool {
        isInitialized
    }

    func shutdown() {
        isInitialized = false
    }
}

class MockTextInsertionServiceForRecording: TextInsertionService {
    var insertTextCalled = false
    var insertTextWithFallbackCalled = false
    var lastInsertedText: String?
    var mockFallbackResult: TextInsertionResult = .insertedViaAccessibility

    override func insertText(_ text: String) async throws {
        insertTextCalled = true
        lastInsertedText = text
    }

    override func insertTextWithFallback(_ text: String) async -> TextInsertionResult {
        insertTextWithFallbackCalled = true
        lastInsertedText = text
        return mockFallbackResult
    }
}
