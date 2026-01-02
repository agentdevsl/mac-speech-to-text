import Foundation

/// Service for managing user settings persistence
class SettingsService {
    private let userDefaults: UserDefaults
    private let settingsKey = "com.speechtotext.settings"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    /// Load settings from UserDefaults
    func load() -> UserSettings {
        guard let data = userDefaults.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(UserSettings.self, from: data) else {
            return .default
        }
        return settings
    }

    /// Save settings to UserDefaults
    func save(_ settings: UserSettings) throws {
        var updatedSettings = settings
        updatedSettings.lastModified = Date()

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(updatedSettings)
        userDefaults.set(data, forKey: settingsKey)
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
