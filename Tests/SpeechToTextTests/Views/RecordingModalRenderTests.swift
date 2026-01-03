// RecordingModalRenderTests.swift
// macOS Local Speech-to-Text Application
//
// Integration tests for RecordingModal view rendering
// These tests verify that views render without crashing due to
// @Observable + actor existential type issues

import SwiftUI
import ViewInspector
import XCTest
@testable import SpeechToText

// MARK: - ViewInspector Conformance

extension RecordingModal: Inspectable {}

@MainActor
final class RecordingModalRenderTests: XCTestCase {
    // MARK: - Rendering Crash Detection Tests

    /// Test that RecordingModal can be instantiated without crashing
    /// This catches issues like the @Observable + actor existential crash
    func test_recordingModal_instantiatesWithoutCrash() {
        // Given/When - Simply creating the view should not crash
        let modal = RecordingModal()

        // Then - If we get here, no crash occurred
        XCTAssertNotNil(modal)
    }

    /// Test that RecordingModal body can be accessed without crashing
    /// The original crash occurred in RecordingModal.body.getter
    func test_recordingModal_bodyAccessDoesNotCrash() {
        // Given
        let modal = RecordingModal()

        // When - Access the body (this is where the crash occurred)
        let body = modal.body

        // Then - If we get here, no crash occurred
        XCTAssertNotNil(body)
    }

    /// Test that RecordingViewModel can be created and accessed
    func test_recordingViewModel_instantiatesWithoutCrash() {
        // Given/When
        let viewModel = RecordingViewModel()

        // Then - Verify observable properties can be accessed
        XCTAssertFalse(viewModel.isRecording)
        XCTAssertFalse(viewModel.isTranscribing)
        XCTAssertEqual(viewModel.audioLevel, 0.0)
        XCTAssertEqual(viewModel.transcribedText, "")
    }

    /// Test that RecordingViewModel with mock services doesn't crash
    func test_recordingViewModel_withMockActorService_doesNotCrash() async {
        // Given - Create mock actor service (this tests the existential type handling)
        let mockFluidService = MockFluidAudioServiceForRenderTest()

        // When
        let viewModel = RecordingViewModel(
            fluidAudioService: mockFluidService
        )

        // Then - Access properties that might trigger observation tracking
        XCTAssertFalse(viewModel.isRecording)
        XCTAssertNil(viewModel.currentSession)

        // Verify the mock actor can be awaited
        let isInitialized = await mockFluidService.checkInitialized()
        XCTAssertFalse(isInitialized)
    }

    /// Test that multiple RecordingViewModels can be created without memory issues
    func test_multipleRecordingViewModels_noMemoryCorruption() {
        // Given/When - Create multiple instances rapidly
        var viewModels: [RecordingViewModel] = []
        for _ in 0..<10 {
            viewModels.append(RecordingViewModel())
        }

        // Then - All should be valid
        XCTAssertEqual(viewModels.count, 10)
        for vm in viewModels {
            XCTAssertFalse(vm.isRecording)
        }
    }

    // MARK: - View Hierarchy Tests

    /// Test RecordingModal view structure using ViewInspector
    func test_recordingModal_viewHierarchy() throws {
        // Given
        let modal = RecordingModal()

        // When
        let view = try modal.inspect()

        // Then - Verify basic structure exists
        XCTAssertNoThrow(try view.find(ViewType.ZStack.self))
    }

    // MARK: - Observable State Tests

    /// Test that @Observable state changes don't cause crashes
    func test_observableStateChanges_noCrash() async {
        // Given
        let viewModel = RecordingViewModel()

        // When - Modify observable state
        viewModel.audioLevel = 0.5
        viewModel.transcribedText = "Test"
        viewModel.errorMessage = "Error"

        // Then - State should be updated without crash
        XCTAssertEqual(viewModel.audioLevel, 0.5)
        XCTAssertEqual(viewModel.transcribedText, "Test")
        XCTAssertEqual(viewModel.errorMessage, "Error")
    }

    /// Test that currentLanguageModel computed property works
    func test_currentLanguageModel_accessDoesNotCrash() {
        // Given
        let viewModel = RecordingViewModel()
        viewModel.currentLanguage = "en"

        // When
        let languageModel = viewModel.currentLanguageModel

        // Then
        XCTAssertNotNil(languageModel)
        XCTAssertEqual(languageModel?.code, "en")
    }
}

// MARK: - Mock Actor Service for Render Tests

/// Actor-based mock that tests the existential type pattern
actor MockFluidAudioServiceForRenderTest: FluidAudioServiceProtocol {
    private var initialized = false
    private var language = "en"

    func initialize(language: String) async throws {
        self.language = language
        initialized = true
    }

    func transcribe(samples: [Int16]) async throws -> TranscriptionResult {
        return TranscriptionResult(text: "Mock", confidence: 0.9, durationMs: 100)
    }

    func switchLanguage(to language: String) async throws {
        self.language = language
    }

    func getCurrentLanguage() -> String {
        return language
    }

    func checkInitialized() -> Bool {
        return initialized
    }

    func shutdown() {
        initialized = false
    }
}
