// SettingsViewModelTests.swift
// macOS Local Speech-to-Text Application
//
// Unit tests for SettingsViewModel

import XCTest
@testable import SpeechToText

@MainActor
final class SettingsViewModelTests: XCTestCase {
    // MARK: - Properties

    var sut: SettingsViewModel!
    var mockSettingsService: MockSettingsServiceForSettings!
    var mockHotkeyService: MockHotkeyServiceForSettings!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()

        mockSettingsService = MockSettingsServiceForSettings()
        mockHotkeyService = MockHotkeyServiceForSettings()

        sut = SettingsViewModel(
            settingsService: mockSettingsService,
            hotkeyService: mockHotkeyService
        )
    }

    override func tearDown() async throws {
        sut = nil
        mockSettingsService = nil
        mockHotkeyService = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func test_initialization_loadsSettingsFromService() {
        // Given
        var customSettings = UserSettings.default
        customSettings.general.launchAtLogin = true
        mockSettingsService.mockSettings = customSettings

        // When
        let viewModel = SettingsViewModel(
            settingsService: mockSettingsService,
            hotkeyService: mockHotkeyService
        )

        // Then
        XCTAssertTrue(viewModel.settings.general.launchAtLogin)
    }

    func test_initialization_setsDefaultState() {
        // Then
        XCTAssertFalse(sut.isSaving)
        XCTAssertNil(sut.validationError)
        XCTAssertFalse(sut.isDownloadingModel)
        XCTAssertEqual(sut.downloadProgress, 0.0)
    }

    // MARK: - saveSettings Tests

    func test_saveSettings_persistsToSettingsService() async {
        // Given
        sut.settings.general.launchAtLogin = true

        // When
        await sut.saveSettings()

        // Then
        XCTAssertTrue(mockSettingsService.saveWasCalled)
        XCTAssertTrue(mockSettingsService.lastSavedSettings?.general.launchAtLogin == true)
    }

    func test_saveSettings_setsIsSavingDuringSave() async {
        // Given
        mockSettingsService.saveDelay = 100_000_000 // 100ms

        // When
        let saveTask = Task {
            await sut.saveSettings()
        }

        // Brief wait to catch saving state
        try? await Task.sleep(nanoseconds: 50_000_000)

        // Then - should be saving
        XCTAssertTrue(sut.isSaving)

        await saveTask.value

        // Then - should not be saving after completion
        XCTAssertFalse(sut.isSaving)
    }

    func test_saveSettings_clearsValidationErrorOnSuccess() async {
        // Given
        sut.validationError = "Previous error"

        // When
        await sut.saveSettings()

        // Then
        XCTAssertNil(sut.validationError)
    }

    func test_saveSettings_setsValidationErrorOnFailure() async {
        // Given
        mockSettingsService.shouldFailSave = true

        // When
        await sut.saveSettings()

        // Then
        XCTAssertNotNil(sut.validationError)
        XCTAssertTrue(sut.validationError?.contains("Failed to save") == true)
    }

    // MARK: - Validation Tests

    func test_saveSettings_failsWhenNoHotkeyModifiers() async {
        // Given
        sut.settings.hotkey.modifiers = []

        // When
        await sut.saveSettings()

        // Then
        XCTAssertEqual(sut.validationError, "Hotkey must include at least one modifier key")
        XCTAssertFalse(mockSettingsService.saveWasCalled)
    }

    func test_saveSettings_failsWhenAudioSensitivityTooLow() async {
        // Given
        sut.settings.audio.sensitivity = 0.05

        // When
        await sut.saveSettings()

        // Then
        XCTAssertEqual(sut.validationError, "Audio sensitivity must be between 0.1 and 1.0")
        XCTAssertFalse(mockSettingsService.saveWasCalled)
    }

    func test_saveSettings_failsWhenAudioSensitivityTooHigh() async {
        // Given
        sut.settings.audio.sensitivity = 1.5

        // When
        await sut.saveSettings()

        // Then
        XCTAssertEqual(sut.validationError, "Audio sensitivity must be between 0.1 and 1.0")
        XCTAssertFalse(mockSettingsService.saveWasCalled)
    }

    func test_saveSettings_failsWhenSilenceThresholdTooLow() async {
        // Given
        sut.settings.audio.silenceThreshold = 0.3

        // When
        await sut.saveSettings()

        // Then
        XCTAssertEqual(sut.validationError, "Silence detection threshold must be between 0.5 and 3.0 seconds")
        XCTAssertFalse(mockSettingsService.saveWasCalled)
    }

    func test_saveSettings_failsWhenSilenceThresholdTooHigh() async {
        // Given
        sut.settings.audio.silenceThreshold = 5.0

        // When
        await sut.saveSettings()

        // Then
        XCTAssertEqual(sut.validationError, "Silence detection threshold must be between 0.5 and 3.0 seconds")
        XCTAssertFalse(mockSettingsService.saveWasCalled)
    }

    func test_saveSettings_failsWhenLanguageNotSupported() async {
        // Given
        sut.settings.language.defaultLanguage = "unsupported_lang_xyz"

        // When
        await sut.saveSettings()

        // Then
        XCTAssertEqual(sut.validationError, "Selected language is not supported")
        XCTAssertFalse(mockSettingsService.saveWasCalled)
    }

    // MARK: - resetToDefaults Tests

    func test_resetToDefaults_setsDefaultSettings() async {
        // Given
        sut.settings.general.launchAtLogin = true
        sut.settings.audio.sensitivity = 0.9

        // When
        await sut.resetToDefaults()

        // Then
        XCTAssertEqual(sut.settings.general.launchAtLogin, UserSettings.default.general.launchAtLogin)
        XCTAssertEqual(sut.settings.audio.sensitivity, UserSettings.default.audio.sensitivity)
    }

    func test_resetToDefaults_clearsValidationError() async {
        // Given
        sut.validationError = "Some error"

        // When
        await sut.resetToDefaults()

        // Then
        XCTAssertNil(sut.validationError)
    }

    func test_resetToDefaults_savesSettingsToDisk() async {
        // When
        await sut.resetToDefaults()

        // Then
        XCTAssertTrue(mockSettingsService.saveWasCalled)
    }

    // MARK: - updateHotkey Tests

    func test_updateHotkey_detectsSpotlightConflict() async {
        // Given - Spotlight shortcut is Cmd+Space (keyCode 49)
        let keyCode = 49
        let modifiers: [UserSettings.HotkeyModifier] = [.command]

        // When
        await sut.updateHotkey(keyCode: keyCode, modifiers: modifiers)

        // Then
        XCTAssertNotNil(sut.validationError)
        XCTAssertTrue(sut.validationError?.contains("Spotlight") == true)
    }

    func test_updateHotkey_updatesSettingsWhenNoConflict() async {
        // Given - unique combination
        let keyCode = 36 // Return key
        let modifiers: [UserSettings.HotkeyModifier] = [.control, .option]

        // When
        await sut.updateHotkey(keyCode: keyCode, modifiers: modifiers)

        // Then
        XCTAssertEqual(sut.settings.hotkey.keyCode, keyCode)
        XCTAssertEqual(sut.settings.hotkey.modifiers, modifiers)
    }

    func test_updateHotkey_registersNewHotkeyWithService() async {
        // Given
        let keyCode = 36
        let modifiers: [UserSettings.HotkeyModifier] = [.command, .shift]

        // When
        await sut.updateHotkey(keyCode: keyCode, modifiers: modifiers)

        // Then
        XCTAssertTrue(mockHotkeyService.registerHotkeyCalled)
        XCTAssertEqual(mockHotkeyService.lastRegisteredKeyCode, keyCode)
    }

    func test_updateHotkey_setsErrorWhenRegistrationFails() async {
        // Given
        mockHotkeyService.shouldFailRegistration = true
        let keyCode = 36
        let modifiers: [UserSettings.HotkeyModifier] = [.command, .control]

        // When
        await sut.updateHotkey(keyCode: keyCode, modifiers: modifiers)

        // Then
        XCTAssertNotNil(sut.validationError)
        XCTAssertTrue(sut.validationError?.contains("Failed to register hotkey") == true)
    }

    // MARK: - updateLanguage Tests

    func test_updateLanguage_updatesDefaultLanguage() async {
        // Given
        let frenchLanguage = LanguageModel.supportedLanguages.first { $0.code == "fr" }!

        // When
        await sut.updateLanguage(frenchLanguage)

        // Then
        XCTAssertEqual(sut.settings.language.defaultLanguage, "fr")
    }

    func test_updateLanguage_savesSettings() async {
        // Given
        let germanLanguage = LanguageModel.supportedLanguages.first { $0.code == "de" }!

        // When
        await sut.updateLanguage(germanLanguage)

        // Then
        XCTAssertTrue(mockSettingsService.saveWasCalled)
    }

    // MARK: - updateAudioSensitivity Tests

    func test_updateAudioSensitivity_updatesSettings() async {
        // When
        await sut.updateAudioSensitivity(0.75)

        // Then
        XCTAssertEqual(sut.settings.audio.sensitivity, 0.75)
    }

    func test_updateAudioSensitivity_savesSettings() async {
        // When
        await sut.updateAudioSensitivity(0.8)

        // Then
        XCTAssertTrue(mockSettingsService.saveWasCalled)
    }

    // MARK: - updateSilenceThreshold Tests

    func test_updateSilenceThreshold_updatesSettings() async {
        // When
        await sut.updateSilenceThreshold(2.0)

        // Then
        XCTAssertEqual(sut.settings.audio.silenceThreshold, 2.0)
    }

    func test_updateSilenceThreshold_savesSettings() async {
        // When
        await sut.updateSilenceThreshold(1.5)

        // Then
        XCTAssertTrue(mockSettingsService.saveWasCalled)
    }
}

// MARK: - Mock Services

@MainActor
class MockSettingsServiceForSettings: SettingsService {
    var mockSettings = UserSettings.default
    var saveWasCalled = false
    var lastSavedSettings: UserSettings?
    var shouldFailSave = false
    var saveDelay: UInt64 = 0

    override func load() -> UserSettings {
        return mockSettings
    }

    override func save(_ settings: UserSettings) throws {
        if saveDelay > 0 {
            Thread.sleep(forTimeInterval: Double(saveDelay) / 1_000_000_000)
        }
        if shouldFailSave {
            throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Save failed"])
        }
        saveWasCalled = true
        lastSavedSettings = settings
        mockSettings = settings
    }
}

@MainActor
class MockHotkeyServiceForSettings: HotkeyService {
    var registerHotkeyCalled = false
    var lastRegisteredKeyCode: Int?
    var lastRegisteredModifiers: [KeyModifier]?
    var shouldFailRegistration = false

    override func registerHotkey(
        keyCode: Int,
        modifiers: [KeyModifier],
        handler: @escaping () -> Void
    ) async throws {
        registerHotkeyCalled = true
        lastRegisteredKeyCode = keyCode
        lastRegisteredModifiers = modifiers

        if shouldFailRegistration {
            throw NSError(
                domain: "TestError",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Registration failed"]
            )
        }
    }
}
