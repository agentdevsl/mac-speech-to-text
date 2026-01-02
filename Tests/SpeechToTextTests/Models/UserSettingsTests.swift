import XCTest
@testable import SpeechToText

final class UserSettingsTests: XCTestCase {

    // MARK: - Default Initialization Tests

    func testInitialization_CreatesDefaultSettings() {
        // Given/When
        let settings = UserSettings()

        // Then
        XCTAssertEqual(settings.hotkey.modifiers, [.command, .control])
        XCTAssertEqual(settings.hotkey.key, .space)
        XCTAssertEqual(settings.language.defaultLanguage, "en-US")
        XCTAssertTrue(settings.language.autoDetect)
        XCTAssertTrue(settings.insertion.autoInsert)
        XCTAssertTrue(settings.insertion.copyToClipboard)
        XCTAssertTrue(settings.application.launchAtLogin)
        XCTAssertTrue(settings.application.showMenuBarIcon)
        XCTAssertFalse(settings.advanced.debug Mode)
        XCTAssertEqual(settings.advanced.audioSensitivity, 0.5)
    }

    // MARK: - Hotkey Configuration Tests

    func testHotkeyUpdate_ChangesModifiersAndKey() {
        // Given
        var settings = UserSettings()

        // When
        settings.hotkey.modifiers = [.command, .shift]
        settings.hotkey.key = .f1

        // Then
        XCTAssertEqual(settings.hotkey.modifiers, [.command, .shift])
        XCTAssertEqual(settings.hotkey.key, .f1)
    }

    func testHotkeyDescription_FormatsCorrectly() {
        // Given
        let settings = UserSettings()

        // Then
        XCTAssertEqual(settings.hotkey.description, "⌘⌃Space")
    }

    // MARK: - Language Configuration Tests

    func testLanguageUpdate_ChangesDefaultLanguage() {
        // Given
        var settings = UserSettings()

        // When
        settings.language.defaultLanguage = "es-ES"

        // Then
        XCTAssertEqual(settings.language.defaultLanguage, "es-ES")
    }

    func testAutoDetectToggle_ChangesState() {
        // Given
        var settings = UserSettings()
        XCTAssertTrue(settings.language.autoDetect)

        // When
        settings.language.autoDetect = false

        // Then
        XCTAssertFalse(settings.language.autoDetect)
    }

    func testSupportedLanguages_ContainsExpectedLanguages() {
        // Given
        let settings = UserSettings()

        // Then
        XCTAssertTrue(settings.language.supportedLanguages.contains("en-US"))
        XCTAssertTrue(settings.language.supportedLanguages.contains("es-ES"))
        XCTAssertTrue(settings.language.supportedLanguages.contains("fr-FR"))
        XCTAssertEqual(settings.language.supportedLanguages.count, 25)
    }

    // MARK: - Insertion Configuration Tests

    func testAutoInsertToggle_ChangesState() {
        // Given
        var settings = UserSettings()

        // When
        settings.insertion.autoInsert = false

        // Then
        XCTAssertFalse(settings.insertion.autoInsert)
    }

    func testReturnFocusToggle_ChangesState() {
        // Given
        var settings = UserSettings()

        // When
        settings.insertion.returnFocus = false

        // Then
        XCTAssertFalse(settings.insertion.returnFocus)
    }

    // MARK: - Application Configuration Tests

    func testLaunchAtLoginToggle_ChangesState() {
        // Given
        var settings = UserSettings()

        // When
        settings.application.launchAtLogin = false

        // Then
        XCTAssertFalse(settings.application.launchAtLogin)
    }

    func testShowMenuBarIconToggle_ChangesState() {
        // Given
        var settings = UserSettings()

        // When
        settings.application.showMenuBarIcon = false

        // Then
        XCTAssertFalse(settings.application.showMenuBarIcon)
    }

    // MARK: - Advanced Configuration Tests

    func testDebugModeToggle_ChangesState() {
        // Given
        var settings = UserSettings()

        // When
        settings.advanced.debugMode = true

        // Then
        XCTAssertTrue(settings.advanced.debugMode)
    }

    func testAudioSensitivityUpdate_ClampsToRange() {
        // Given
        var settings = UserSettings()

        // When
        settings.advanced.audioSensitivity = 1.5 // Out of range

        // Then - Should clamp to [0.0, 1.0]
        XCTAssertLessThanOrEqual(settings.advanced.audioSensitivity, 1.0)
        XCTAssertGreaterThanOrEqual(settings.advanced.audioSensitivity, 0.0)
    }

    func testModelCacheSizeUpdate_ChangesValue() {
        // Given
        var settings = UserSettings()

        // When
        settings.advanced.modelCacheSize = 2048

        // Then
        XCTAssertEqual(settings.advanced.modelCacheSize, 2048)
    }

    // MARK: - Codable Tests

    func testEncode_ProducesValidJSON() throws {
        // Given
        let settings = UserSettings()
        let encoder = JSONEncoder()

        // When
        let data = try encoder.encode(settings)

        // Then
        XCTAssertFalse(data.isEmpty)
    }

    func testDecode_RestoresSettings() throws {
        // Given
        let original = UserSettings()
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(original)

        // When
        let decoded = try decoder.decode(UserSettings.self, from: data)

        // Then
        XCTAssertEqual(decoded.hotkey.modifiers, original.hotkey.modifiers)
        XCTAssertEqual(decoded.language.defaultLanguage, original.language.defaultLanguage)
        XCTAssertEqual(decoded.insertion.autoInsert, original.insertion.autoInsert)
    }
}
