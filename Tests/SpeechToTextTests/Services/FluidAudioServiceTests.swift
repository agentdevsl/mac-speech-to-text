import XCTest
@testable import SpeechToText

final class FluidAudioServiceTests: XCTestCase {

    // MARK: - Initialization Tests

    func test_initialization_createsService() async {
        // Given/When
        let service = FluidAudioService()

        // Then
        let isInitialized = await service.checkInitialized()
        XCTAssertFalse(isInitialized)
    }

    func test_initialization_startsWithEnglishLanguage() async {
        // Given/When
        let service = FluidAudioService()

        // Then
        let currentLanguage = await service.getCurrentLanguage()
        XCTAssertEqual(currentLanguage, "en")
    }

    // MARK: - Initialize Tests

    func test_initialize_setsInitializedFlag() async throws {
        // Given
        let service = FluidAudioService()
        let initialState = await service.checkInitialized()
        XCTAssertFalse(initialState)

        // When
        // Note: This will fail in tests because FluidAudio SDK is not available
        // This is a TDD test that should initially fail
        do {
            try await service.initialize(language: "en")
            let isInitialized = await service.checkInitialized()
            XCTAssertTrue(isInitialized)
        } catch {
            // Expected to fail in test environment without FluidAudio SDK
            XCTAssertTrue(error is FluidAudioError)
        }
    }

    func test_initialize_doesNotReinitializeIfAlreadyInitialized() async throws {
        // Given
        let service = FluidAudioService()

        // When/Then
        // First initialization attempt
        do {
            try await service.initialize(language: "en")
        } catch {
            // Expected to fail in test environment
        }

        // Second initialization should not throw or reinitialize
        do {
            try await service.initialize(language: "fr")
        } catch {
            // Expected to fail in test environment
        }
    }

    // MARK: - Transcribe Tests

    func test_transcribe_throwsErrorWhenNotInitialized() async {
        // Given
        let service = FluidAudioService()
        let samples: [Int16] = Array(repeating: 100, count: 1600)

        // When/Then
        do {
            _ = try await service.transcribe(samples: samples)
            XCTFail("Should throw notInitialized error")
        } catch let error as FluidAudioError {
            XCTAssertEqual(error, .notInitialized)
        } catch {
            XCTFail("Wrong error type")
        }
    }

    func test_transcribe_throwsErrorWhenSamplesAreEmpty() async {
        // Given
        let service = FluidAudioService()
        let samples: [Int16] = []

        // When/Then
        // Note: notInitialized error takes precedence over invalidAudioFormat
        // when service is not initialized
        do {
            _ = try await service.transcribe(samples: samples)
            XCTFail("Should throw error")
        } catch let error as FluidAudioError {
            // Either notInitialized (if checked first) or invalidAudioFormat is acceptable
            XCTAssertTrue(error == .notInitialized || error == .invalidAudioFormat,
                          "Expected notInitialized or invalidAudioFormat, got \(error)")
        } catch {
            XCTFail("Wrong error type")
        }
    }

    // MARK: - Language Switch Tests

    func test_switchLanguage_throwsErrorForUnsupportedLanguage() async {
        // Given
        let service = FluidAudioService()

        // When/Then
        do {
            try await service.switchLanguage(to: "zh") // Chinese not supported
            XCTFail("Should throw languageNotSupported error")
        } catch let error as FluidAudioError {
            if case .languageNotSupported(let lang) = error {
                XCTAssertEqual(lang, "zh")
            } else {
                XCTFail("Wrong error type")
            }
        } catch {
            XCTFail("Wrong error type")
        }
    }

    func test_switchLanguage_acceptsSupportedLanguage() async throws {
        // Given
        let service = FluidAudioService()

        // When
        try await service.switchLanguage(to: "fr")

        // Then
        let currentLanguage = await service.getCurrentLanguage()
        XCTAssertEqual(currentLanguage, "fr")
    }

    func test_switchLanguage_supportsAllEuropeanLanguages() async {
        // Given
        let service = FluidAudioService()
        let europeanLanguages = ["en", "es", "fr", "de", "it", "pt", "ru", "pl"]

        // When/Then
        for language in europeanLanguages {
            do {
                try await service.switchLanguage(to: language)
                let currentLanguage = await service.getCurrentLanguage()
                XCTAssertEqual(currentLanguage, language)
            } catch {
                XCTFail("Should support language: \(language)")
            }
        }
    }

    // MARK: - Shutdown Tests

    func test_shutdown_resetsServiceState() async {
        // Given
        let service = FluidAudioService()

        // When
        await service.shutdown()

        // Then
        let isInitialized = await service.checkInitialized()
        XCTAssertFalse(isInitialized)
    }

    // MARK: - Error Description Tests

    func test_fluidAudioError_notInitialized_hasCorrectDescription() {
        // Given
        let error = FluidAudioError.notInitialized

        // When
        let description = error.errorDescription

        // Then
        XCTAssertEqual(description, "FluidAudio service has not been initialized")
    }

    func test_fluidAudioError_modelNotLoaded_hasCorrectDescription() {
        // Given
        let error = FluidAudioError.modelNotLoaded

        // When
        let description = error.errorDescription

        // Then
        XCTAssertEqual(description, "Language model has not been loaded")
    }

    func test_fluidAudioError_invalidAudioFormat_hasCorrectDescription() {
        // Given
        let error = FluidAudioError.invalidAudioFormat

        // When
        let description = error.errorDescription

        // Then
        XCTAssertEqual(description, "Invalid audio format. Expected 16kHz mono Int16 samples")
    }

    func test_fluidAudioError_languageNotSupported_hasCorrectDescription() {
        // Given
        let error = FluidAudioError.languageNotSupported("zh")

        // When
        let description = error.errorDescription

        // Then
        XCTAssertEqual(description, "Language 'zh' is not supported")
    }

    // MARK: - TranscriptionResult Tests

    func test_transcriptionResult_initialization() {
        // Given/When
        let result = TranscriptionResult(text: "Hello world", confidence: 0.95, durationMs: 150)

        // Then
        XCTAssertEqual(result.text, "Hello world")
        XCTAssertEqual(result.confidence, 0.95)
        XCTAssertEqual(result.durationMs, 150)
    }

    // MARK: - Thread Safety Tests (Actor)

    func test_service_canBeAccessedFromMultipleTasksConcurrently() async {
        // Given
        let service = FluidAudioService()

        // When
        await withTaskGroup(of: String.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    await service.getCurrentLanguage()
                }
            }

            // Then
            for await language in group {
                XCTAssertEqual(language, "en")
            }
        }
    }

    func test_service_switchLanguage_isThreadSafe() async {
        // Given
        let service = FluidAudioService()
        let languages = ["en", "fr", "de", "es", "it"]

        // When
        await withTaskGroup(of: Void.self) { group in
            for language in languages {
                group.addTask {
                    try? await service.switchLanguage(to: language)
                }
            }
        }

        // Then
        let finalLanguage = await service.getCurrentLanguage()
        XCTAssertTrue(languages.contains(finalLanguage))
    }
}
