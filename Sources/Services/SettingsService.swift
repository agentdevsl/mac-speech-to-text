import Foundation
import OSLog

/// Notification posted when settings are reset due to corruption
extension Notification.Name {
    static let settingsDidReset = Notification.Name("com.speechtotext.settingsDidReset")
    static let themeDidChange = Notification.Name("com.speechtotext.themeDidChange")
    static let voiceTriggerEnabledDidChange = Notification.Name("com.speechtotext.voiceTriggerEnabledDidChange")
}

/// Protocol for settings service (enables testing with mocks)
@MainActor
protocol SettingsServiceProtocol {
    func load() -> UserSettings
    func save(_ settings: UserSettings) throws
    func reset() throws
}

/// Service for managing user settings persistence
@MainActor
class SettingsService: SettingsServiceProtocol {
    private let userDefaults: UserDefaults
    private let settingsKey = "com.speechtotext.settings"
    private let corruptedBackupKey = "com.speechtotext.settings.corrupted"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    /// Load settings from UserDefaults
    func load() -> UserSettings {
        guard let data = userDefaults.data(forKey: settingsKey) else {
            return .default
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(UserSettings.self, from: data)
        } catch {
            // Log the decode error with details
            AppLogger.service.error(
                """
                Failed to decode settings: \(error.localizedDescription, privacy: .public). \
                Data size: \(data.count, privacy: .public) bytes. \
                Backing up corrupted data and resetting to defaults.
                """
            )

            // Backup corrupted data for potential recovery
            userDefaults.set(data, forKey: corruptedBackupKey)
            AppLogger.service.info("Corrupted settings backed up to '\(self.corruptedBackupKey, privacy: .public)'")

            // Post notification about settings reset
            NotificationCenter.default.post(
                name: .settingsDidReset,
                object: nil,
                userInfo: ["reason": "decode_failure", "error": error.localizedDescription]
            )

            return .default
        }
    }

    /// Save settings to UserDefaults
    func save(_ settings: UserSettings) throws {
        var updatedSettings = settings
        updatedSettings.lastModified = Date()

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(updatedSettings)
        userDefaults.set(data, forKey: settingsKey)
        // Ensure immediate persistence for consistency in rapid save/load cycles
        userDefaults.synchronize()
    }

    /// Reset settings to defaults
    func reset() throws {
        try save(.default)
    }

    /// Update specific settings sections
    func updateHotkey(_ hotkey: HotkeyConfiguration) throws {
        var settings = load()
        settings.hotkey = hotkey
        try save(settings)
    }

    func updateLanguage(_ language: LanguageConfiguration) throws {
        var settings = load()
        settings.language = language
        try save(settings)
    }

    func updateAudio(_ audio: AudioConfiguration) throws {
        var settings = load()
        settings.audio = audio
        try save(settings)
    }

    func updateUI(_ ui: UIConfiguration) throws {
        var settings = load()
        settings.ui = ui
        try save(settings)
    }

    func updatePrivacy(_ privacy: PrivacyConfiguration) throws {
        var settings = load()
        settings.privacy = privacy
        try save(settings)
    }

    func updateOnboarding(_ onboarding: OnboardingState) throws {
        var settings = load()
        settings.onboarding = onboarding
        try save(settings)
    }

    /// Mark onboarding as complete
    func completeOnboarding() throws {
        var settings = load()
        settings.onboarding.completed = true
        settings.onboarding.currentStep = 0
        try save(settings)
    }

    /// Update permissions granted
    func updatePermissions(_ permissions: PermissionsGranted) throws {
        var settings = load()
        settings.onboarding.permissionsGranted = permissions
        try save(settings)
    }
}
