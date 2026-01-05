// VoiceTriggerMonitoringServiceTests.swift
// macOS Local Speech-to-Text Application
//
// Unit tests for VoiceTriggerMonitoringService

import AVFoundation
import XCTest
@testable import SpeechToText

@MainActor
final class VoiceTriggerMonitoringServiceTests: XCTestCase {
    // MARK: - Properties

    var sut: VoiceTriggerMonitoringService!
    var mockWakeWordService: MockWakeWordService!
    var mockAudioService: MockAudioCaptureService!
    var mockFluidAudioService: MockFluidAudioService!
    var mockTextInsertionService: TextInsertionService!
    var mockSettingsService: SettingsService!

    // MARK: - Setup / Teardown

    override func setUp() async throws {
        try await super.setUp()
        mockWakeWordService = MockWakeWordService()
        mockAudioService = MockAudioCaptureService()
        mockFluidAudioService = MockFluidAudioService()
        mockTextInsertionService = TextInsertionService()
        mockSettingsService = SettingsService()

        sut = VoiceTriggerMonitoringService(
            wakeWordService: mockWakeWordService,
            audioService: mockAudioService,
            fluidAudioService: mockFluidAudioService,
            textInsertionService: mockTextInsertionService,
            settingsService: mockSettingsService
        )
    }

    override func tearDown() async throws {
        await sut.stopMonitoring()
        sut = nil
        mockWakeWordService = nil
        mockAudioService = nil
        mockFluidAudioService = nil
        mockTextInsertionService = nil
        mockSettingsService = nil
        try await super.tearDown()
    }

    // MARK: - Initial State Tests

    func test_initialState_isIdle() {
        XCTAssertEqual(sut.state, .idle)
    }

    func test_initialAudioLevel_isZero() {
        XCTAssertEqual(sut.audioLevel, 0.0)
    }

    func test_initialCurrentKeyword_isNil() {
        XCTAssertNil(sut.currentKeyword)
    }

    func test_initialSilenceTimeRemaining_isNil() {
        XCTAssertNil(sut.silenceTimeRemaining)
    }

    // MARK: - State Machine Tests

    func test_startMonitoring_whenIdle_transitionsToMonitoring() async throws {
        // Given
        let settings = mockSettingsService.load()
        var updatedSettings = settings
        updatedSettings.voiceTrigger.enabled = true
        updatedSettings.voiceTrigger.keywords = [.heyClaudeDefault]
        try mockSettingsService.save(updatedSettings)

        // When
        try await sut.startMonitoring()

        // Then
        XCTAssertEqual(sut.state, .monitoring)
    }

    func test_startMonitoring_whenNoKeywords_throwsError() async {
        // Given
        let settings = mockSettingsService.load()
        var updatedSettings = settings
        updatedSettings.voiceTrigger.enabled = true
        updatedSettings.voiceTrigger.keywords = []
        try? mockSettingsService.save(updatedSettings)

        // When/Then
        do {
            try await sut.startMonitoring()
            XCTFail("Expected error to be thrown")
        } catch VoiceTriggerError.noKeywordsConfigured {
            // Expected - direct throw
        } catch VoiceTriggerError.wakeWordInitFailed(let message) where message.contains("No") {
            // Also acceptable - wrapped error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_startMonitoring_whenAlreadyMonitoring_throwsError() async throws {
        // Given
        try await setupAndStartMonitoring()

        // When/Then
        do {
            try await sut.startMonitoring()
            XCTFail("Expected error to be thrown")
        } catch VoiceTriggerError.wakeWordInitFailed {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_stopMonitoring_whenMonitoring_transitionsToIdle() async throws {
        // Given
        try await setupAndStartMonitoring()
        XCTAssertEqual(sut.state, .monitoring)

        // When
        await sut.stopMonitoring()

        // Then
        XCTAssertEqual(sut.state, .idle)
    }

    func test_stopMonitoring_whenIdle_remainsIdle() async {
        // Given
        XCTAssertEqual(sut.state, .idle)

        // When
        await sut.stopMonitoring()

        // Then
        XCTAssertEqual(sut.state, .idle)
    }

    func test_stopMonitoring_clearsCurrentKeyword() async throws {
        // Given
        try await setupAndStartMonitoring()

        // When
        await sut.stopMonitoring()

        // Then
        XCTAssertNil(sut.currentKeyword)
    }

    func test_stopMonitoring_resetsAudioLevel() async throws {
        // Given
        try await setupAndStartMonitoring()

        // When
        await sut.stopMonitoring()

        // Then
        XCTAssertEqual(sut.audioLevel, 0.0)
    }

    // MARK: - VoiceTriggerState Tests

    func test_voiceTriggerState_idle_isNotActive() {
        XCTAssertFalse(VoiceTriggerState.idle.isActive)
    }

    func test_voiceTriggerState_monitoring_isActive() {
        XCTAssertTrue(VoiceTriggerState.monitoring.isActive)
    }

    func test_voiceTriggerState_capturing_isActive() {
        XCTAssertTrue(VoiceTriggerState.capturing.isActive)
    }

    func test_voiceTriggerState_error_isNotActive() {
        XCTAssertFalse(VoiceTriggerState.error(.noKeywordsConfigured).isActive)
    }

    func test_voiceTriggerState_idle_isNotMonitoring() {
        XCTAssertFalse(VoiceTriggerState.idle.isMonitoring)
    }

    func test_voiceTriggerState_monitoring_isMonitoring() {
        XCTAssertTrue(VoiceTriggerState.monitoring.isMonitoring)
    }

    func test_voiceTriggerState_capturing_isProcessing() {
        XCTAssertTrue(VoiceTriggerState.capturing.isProcessing)
    }

    func test_voiceTriggerState_transcribing_isProcessing() {
        XCTAssertTrue(VoiceTriggerState.transcribing.isProcessing)
    }

    func test_voiceTriggerState_idle_description() {
        XCTAssertEqual(VoiceTriggerState.idle.description, "Idle")
    }

    func test_voiceTriggerState_monitoring_description() {
        XCTAssertEqual(VoiceTriggerState.monitoring.description, "Listening for wake word...")
    }

    func test_voiceTriggerState_triggered_description() {
        XCTAssertEqual(
            VoiceTriggerState.triggered(keyword: "Hey Claude").description,
            "Wake word detected: Hey Claude"
        )
    }

    // MARK: - VoiceTriggerError Tests

    func test_voiceTriggerError_hasLocalizedDescription() {
        let error = VoiceTriggerError.noKeywordsConfigured
        XCTAssertNotNil(error.errorDescription)
        XCTAssertEqual(error.errorDescription, error.description)
    }

    func test_voiceTriggerError_wakeWordInitFailed_description() {
        let error = VoiceTriggerError.wakeWordInitFailed("Test reason")
        XCTAssertEqual(error.description, "Wake word initialization failed: Test reason")
    }

    func test_voiceTriggerError_noKeywordsConfigured_description() {
        let error = VoiceTriggerError.noKeywordsConfigured
        XCTAssertEqual(error.description, "No wake word keywords configured")
    }

    func test_voiceTriggerError_audioCaptureFailed_description() {
        let error = VoiceTriggerError.audioCaptureFailed("Audio issue")
        XCTAssertEqual(error.description, "Audio capture failed: Audio issue")
    }

    func test_voiceTriggerError_equatable() {
        XCTAssertEqual(VoiceTriggerError.noKeywordsConfigured, VoiceTriggerError.noKeywordsConfigured)
        XCTAssertNotEqual(
            VoiceTriggerError.wakeWordInitFailed("A"),
            VoiceTriggerError.wakeWordInitFailed("B")
        )
    }

    // MARK: - Service Integration Tests

    func test_startMonitoring_initializesWakeWordService() async throws {
        // Given
        try await setupAndStartMonitoring()

        // Then
        let called = await mockWakeWordService.initializeCalled
        XCTAssertTrue(called)
    }

    func test_startMonitoring_startsAudioCapture() async throws {
        // Given
        try await setupAndStartMonitoring()

        // Then
        XCTAssertTrue(mockAudioService.startCaptureCalled)
    }

    func test_stopMonitoring_shutsDownWakeWordService() async throws {
        // Given
        try await setupAndStartMonitoring()

        // When
        await sut.stopMonitoring()

        // Then
        let called = await mockWakeWordService.shutdownCalled
        XCTAssertTrue(called)
    }

    // MARK: - Helper Methods

    private func setupAndStartMonitoring() async throws {
        let settings = mockSettingsService.load()
        var updatedSettings = settings
        updatedSettings.voiceTrigger.enabled = true
        updatedSettings.voiceTrigger.keywords = [.heyClaudeDefault]
        try mockSettingsService.save(updatedSettings)
        try await sut.startMonitoring()
    }
}

// MARK: - Mock Services

actor MockWakeWordService: WakeWordServiceProtocol {
    private var _initializeCalled = false
    private var _processFrameCalled = false
    private var _shutdownCalled = false
    var mockResult: WakeWordResult?
    private var _isInitialized = false

    var isInitialized: Bool {
        _isInitialized
    }

    // Public accessors for test assertions
    var initializeCalled: Bool { _initializeCalled }
    var processFrameCalled: Bool { _processFrameCalled }
    var shutdownCalled: Bool { _shutdownCalled }

    func initialize(modelPath: String, keywords: [TriggerKeyword]) async throws {
        _initializeCalled = true
        _isInitialized = true
    }

    func processFrame(_ samples: [Float]) -> WakeWordResult? {
        _processFrameCalled = true
        return mockResult
    }

    func updateKeywords(_ keywords: [TriggerKeyword]) async throws {
        // No-op for mock
    }

    func shutdown() {
        _shutdownCalled = true
        _isInitialized = false
    }
}

actor MockFluidAudioService: FluidAudioServiceProtocol {
    private var _initializeCalled = false
    private var _transcribeCalled = false
    var mockResult = TranscriptionResult(text: "Mock transcription", confidence: 0.9, durationMs: 1000)
    private var isInitialized = false
    private var currentLanguage = "en"

    // Public accessors for test assertions
    var initializeCalled: Bool { _initializeCalled }
    var transcribeCalled: Bool { _transcribeCalled }

    func initialize(language: String) async throws {
        _initializeCalled = true
        isInitialized = true
        currentLanguage = language
    }

    func transcribe(samples: [Int16], sampleRate: Double) async throws -> TranscriptionResult {
        _transcribeCalled = true
        return mockResult
    }

    func switchLanguage(to language: String) async throws {
        currentLanguage = language
    }

    func supportedLanguages() async -> [String] {
        return ["en", "es", "fr"]
    }

    func getCurrentLanguage() -> String {
        return currentLanguage
    }

    func checkInitialized() -> Bool {
        return isInitialized
    }

    func shutdown() {
        isInitialized = false
    }
}

class MockAudioCaptureService: AudioCaptureService {
    var startCaptureCalled = false
    var stopCaptureCalled = false

    override func startCapture(
        levelCallback: @escaping @Sendable (Double) -> Void,
        bufferCallback: (@Sendable (AVAudioPCMBuffer) -> Void)? = nil
    ) async throws {
        startCaptureCalled = true
    }

    override func stopCapture() async throws -> (samples: [Int16], sampleRate: Double) {
        stopCaptureCalled = true
        return (samples: [100, 200, 300], sampleRate: 16000.0)
    }
}
