import XCTest
@testable import SpeechToText

final class UserSettingsTests: XCTestCase {

    // MARK: - Default Values Tests

    func test_defaultSettings_hasCorrectVersion() {
        XCTAssertEqual(UserSettings.default.version, 1)
    }

    func test_defaultSettings_hotkey_hasCorrectKeyCode() {
        XCTAssertEqual(UserSettings.default.hotkey.keyCode, 49) // Space key
    }

    func test_defaultSettings_hotkey_hasCorrectModifiers() {
        XCTAssertEqual(UserSettings.default.hotkey.modifiers, [.command, .control])
    }

    func test_defaultSettings_hotkey_isEnabled() {
        XCTAssertTrue(UserSettings.default.hotkey.enabled)
    }

    func test_defaultSettings_hotkey_noConflictDetected() {
        XCTAssertFalse(UserSettings.default.hotkey.conflictDetected)
    }

    func test_defaultSettings_general_hasCorrectDefaults() {
        let general = UserSettings.default.general
        XCTAssertFalse(general.launchAtLogin)
        XCTAssertTrue(general.autoInsertText)
        XCTAssertTrue(general.copyToClipboard)
    }

    func test_defaultSettings_language_hasCorrectDefaults() {
        let language = UserSettings.default.language
        XCTAssertEqual(language.defaultLanguage, "en")
        XCTAssertFalse(language.autoDetectEnabled)
        XCTAssertEqual(language.recentLanguages, ["en"])
        XCTAssertEqual(language.downloadedModels, ["en"])
    }

    func test_defaultSettings_audio_hasCorrectDefaults() {
        let audio = UserSettings.default.audio
        XCTAssertNil(audio.inputDeviceId)
        XCTAssertEqual(audio.sensitivity, 0.3)
        XCTAssertEqual(audio.silenceThreshold, 1.5)
        XCTAssertTrue(audio.noiseSuppression)
        XCTAssertTrue(audio.autoGainControl)
    }

    func test_defaultSettings_ui_hasCorrectDefaults() {
        let ui = UserSettings.default.ui
        XCTAssertEqual(ui.theme, .system)
        XCTAssertEqual(ui.modalPosition, .center)
        XCTAssertTrue(ui.showWaveform)
        XCTAssertTrue(ui.showConfidenceIndicator)
        XCTAssertTrue(ui.animationsEnabled)
        XCTAssertEqual(ui.menuBarIcon, .default)
    }

    func test_defaultSettings_privacy_hasCorrectDefaults() {
        let privacy = UserSettings.default.privacy
        XCTAssertTrue(privacy.collectAnonymousStats)
        XCTAssertEqual(privacy.storagePolicy, .sessionOnly)
        XCTAssertEqual(privacy.dataRetentionDays, 7)
    }

    func test_defaultSettings_onboarding_hasCorrectDefaults() {
        let onboarding = UserSettings.default.onboarding
        XCTAssertFalse(onboarding.completed)
        XCTAssertEqual(onboarding.currentStep, 0)
        XCTAssertTrue(onboarding.skippedSteps.isEmpty)
        XCTAssertFalse(onboarding.permissionsGranted.microphone)
        XCTAssertFalse(onboarding.permissionsGranted.accessibility)
    }

    // MARK: - KeyModifier Tests

    func test_keyModifier_displayName_returnsCorrectSymbols() {
        XCTAssertEqual(KeyModifier.command.displayName, "\u{2318}")
        XCTAssertEqual(KeyModifier.control.displayName, "\u{2303}")
        XCTAssertEqual(KeyModifier.option.displayName, "\u{2325}")
        XCTAssertEqual(KeyModifier.shift.displayName, "\u{21E7}")
    }

    func test_keyModifier_allCases_hasFourCases() {
        XCTAssertEqual(KeyModifier.allCases.count, 4)
    }

    // MARK: - Theme Tests

    func test_theme_displayName_returnsCorrectNames() {
        XCTAssertEqual(Theme.light.displayName, "Light")
        XCTAssertEqual(Theme.dark.displayName, "Dark")
        XCTAssertEqual(Theme.system.displayName, "System")
    }

    // MARK: - ModalPosition Tests

    func test_modalPosition_displayName_returnsCorrectNames() {
        XCTAssertEqual(ModalPosition.center.displayName, "Center of screen")
        XCTAssertEqual(ModalPosition.cursor.displayName, "At cursor position")
    }

    // MARK: - MenuBarIcon Tests

    func test_menuBarIcon_displayName_returnsCorrectNames() {
        XCTAssertEqual(MenuBarIcon.default.displayName, "Default")
        XCTAssertEqual(MenuBarIcon.minimal.displayName, "Minimal")
    }

    // MARK: - StoragePolicy Tests

    func test_storagePolicy_displayName_returnsCorrectNames() {
        XCTAssertEqual(StoragePolicy.none.displayName, "Don't store")
        XCTAssertEqual(StoragePolicy.sessionOnly.displayName, "Session only")
        XCTAssertEqual(StoragePolicy.persistent.displayName, "Keep history")
    }

    // MARK: - PermissionsGranted Tests

    func test_permissionsGranted_allGranted_returnsTrueWhenAllTrue() {
        let permissions = PermissionsGranted(microphone: true, accessibility: true)
        XCTAssertTrue(permissions.allGranted)
    }

    func test_permissionsGranted_allGranted_returnsFalseWhenAnyFalse() {
        let permissions = PermissionsGranted(microphone: true, accessibility: false)
        XCTAssertFalse(permissions.allGranted)
    }

    func test_permissionsGranted_allGranted_returnsFalseWhenAllFalse() {
        let permissions = PermissionsGranted(microphone: false, accessibility: false)
        XCTAssertFalse(permissions.allGranted)
    }

    func test_permissionsGranted_hasAnyPermission_returnsTrueWhenOneTrue() {
        let permissions = PermissionsGranted(microphone: true, accessibility: false)
        XCTAssertTrue(permissions.hasAnyPermission)
    }

    func test_permissionsGranted_hasAnyPermission_returnsFalseWhenAllFalse() {
        let permissions = PermissionsGranted(microphone: false, accessibility: false)
        XCTAssertFalse(permissions.hasAnyPermission)
    }

    // MARK: - Codable Tests

    func test_userSettings_codableRoundtrip() throws {
        let settings = UserSettings.default
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(UserSettings.self, from: data)

        XCTAssertEqual(decoded.version, settings.version)
        XCTAssertEqual(decoded.hotkey.keyCode, settings.hotkey.keyCode)
        XCTAssertEqual(decoded.hotkey.modifiers, settings.hotkey.modifiers)
        XCTAssertEqual(decoded.general.launchAtLogin, settings.general.launchAtLogin)
        XCTAssertEqual(decoded.general.autoInsertText, settings.general.autoInsertText)
        XCTAssertEqual(decoded.language.defaultLanguage, settings.language.defaultLanguage)
        XCTAssertEqual(decoded.audio.sensitivity, settings.audio.sensitivity)
        XCTAssertEqual(decoded.audio.silenceThreshold, settings.audio.silenceThreshold)
        XCTAssertEqual(decoded.privacy.collectAnonymousStats, settings.privacy.collectAnonymousStats)
        XCTAssertEqual(decoded.privacy.storagePolicy, settings.privacy.storagePolicy)
    }

    func test_keyModifier_codableRoundtrip() throws {
        for modifier in KeyModifier.allCases {
            let data = try JSONEncoder().encode(modifier)
            let decoded = try JSONDecoder().decode(KeyModifier.self, from: data)
            XCTAssertEqual(decoded, modifier)
        }
    }

    func test_theme_codableRoundtrip() throws {
        let themes: [Theme] = [.light, .dark, .system]
        for theme in themes {
            let data = try JSONEncoder().encode(theme)
            let decoded = try JSONDecoder().decode(Theme.self, from: data)
            XCTAssertEqual(decoded, theme)
        }
    }

    func test_storagePolicy_codableRoundtrip() throws {
        let policies: [StoragePolicy] = [.none, .sessionOnly, .persistent]
        for policy in policies {
            let data = try JSONEncoder().encode(policy)
            let decoded = try JSONDecoder().decode(StoragePolicy.self, from: data)
            XCTAssertEqual(decoded, policy)
        }
    }

    // MARK: - Mutability Tests

    func test_userSettings_hotkeyCanBeModified() {
        var settings = UserSettings.default
        settings.hotkey.keyCode = 36 // Return key
        settings.hotkey.modifiers = [.command, .shift]

        XCTAssertEqual(settings.hotkey.keyCode, 36)
        XCTAssertEqual(settings.hotkey.modifiers, [.command, .shift])
    }

    func test_userSettings_languageCanBeModified() {
        var settings = UserSettings.default
        settings.language.defaultLanguage = "de"
        settings.language.autoDetectEnabled = true

        XCTAssertEqual(settings.language.defaultLanguage, "de")
        XCTAssertTrue(settings.language.autoDetectEnabled)
    }

    func test_userSettings_audioCanBeModified() {
        var settings = UserSettings.default
        settings.audio.sensitivity = 0.8
        settings.audio.silenceThreshold = 2.0

        XCTAssertEqual(settings.audio.sensitivity, 0.8)
        XCTAssertEqual(settings.audio.silenceThreshold, 2.0)
    }
}
