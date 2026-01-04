// MenuBarViewModel.swift
// macOS Local Speech-to-Text Application
//
// User Story 3: Menu Bar Quick Access and Stats
// Task T043: MenuBarViewModel - @Observable class fetching daily statistics
// and handling menu actions
//
// Phase 3: UI Simplification - Absorbs settings functionality from SettingsViewModel

import AppKit
import AVFoundation
import Foundation
import Observation
import OSLog

/// MenuBarViewModel manages menu bar state, statistics, and inline settings
@Observable
@MainActor
final class MenuBarViewModel {
    // MARK: - Statistics State

    /// Today's word count
    var wordsToday: Int = 0

    /// Total sessions today
    var sessionsToday: Int = 0

    /// Whether statistics are loading
    var isLoading: Bool = false

    /// Last update timestamp
    var lastUpdated: Date = Date()

    // MARK: - Language State

    /// Recently used languages (max 5) (T066)
    var recentLanguages: [LanguageModel] = []

    /// Current language code
    var currentLanguage: String = "en"

    /// Current language model
    var currentLanguageModel: LanguageModel? {
        LanguageModel.supportedLanguages.first { $0.code == currentLanguage }
    }

    // MARK: - Settings State (Phase 3)

    /// Current user settings
    var settings: UserSettings

    /// Whether settings are being saved
    var isSaving: Bool = false

    /// Validation error message (nil if valid)
    var validationError: String?

    // MARK: - Permission State (Phase 3)

    /// Current microphone permission status
    var hasMicrophonePermission: Bool = false

    /// Current accessibility permission status
    var hasAccessibilityPermission: Bool = false

    // MARK: - Section Expansion State (Phase 3)

    /// Recording section expanded
    var recordingSectionExpanded: Bool = false

    /// Language section expanded
    var languageSectionExpanded: Bool = false

    /// Audio section expanded
    var audioSectionExpanded: Bool = false

    /// Behavior section expanded
    var behaviorSectionExpanded: Bool = false

    /// Privacy section expanded
    var privacySectionExpanded: Bool = false

    // MARK: - Dependencies

    @ObservationIgnored private let statisticsService: StatisticsService
    @ObservationIgnored private let settingsService: SettingsService
    @ObservationIgnored private let permissionService: PermissionService

    /// Task for initial data loading (stored for cleanup)
    @ObservationIgnored private var initTask: Task<Void, Never>?

    // MARK: - Initialization

    init(
        statisticsService: StatisticsService = StatisticsService(),
        settingsService: SettingsService = SettingsService(),
        permissionService: PermissionService = PermissionService()
    ) {
        self.statisticsService = statisticsService
        self.settingsService = settingsService
        self.permissionService = permissionService
        self.settings = settingsService.load()

        // Load initial stats and language settings (store task for cleanup)
        initTask = Task { [weak self] in
            await self?.refreshStatistics()
            await self?.loadLanguageSettings()
            await self?.refreshPermissions()
        }
    }

    deinit {
        // Cancel any pending init task to prevent accessing deallocated memory
        initTask?.cancel()
    }

    // MARK: - Public Methods - Statistics

    /// Refresh statistics from database
    func refreshStatistics() async {
        isLoading = true

        let stats = await statisticsService.getTodayStats()

        wordsToday = stats.totalWordsTranscribed
        sessionsToday = stats.totalSessions
        lastUpdated = Date()

        isLoading = false
    }

    // MARK: - Public Methods - Actions

    /// Handle "Start Recording" menu action
    func startRecording() {
        // This will be triggered via NotificationCenter to AppDelegate
        NotificationCenter.default.post(name: .showRecordingModal, object: nil)
    }

    /// Handle "Open Settings" menu action (legacy - kept for compatibility)
    func openSettings() {
        // This will be triggered via NotificationCenter to AppDelegate
        NotificationCenter.default.post(name: .showSettings, object: nil)
    }

    /// Handle "Quit" menu action
    func quit() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Public Methods - Language

    /// Load language settings and recent languages (T066)
    func loadLanguageSettings() async {
        settings = settingsService.load()
        currentLanguage = settings.language.defaultLanguage
        recentLanguages = settings.language.recentLanguages
            .compactMap { code in
                LanguageModel.supportedLanguages.first { $0.code == code }
            }

        // If no recent languages, add current language
        if recentLanguages.isEmpty {
            if let current = currentLanguageModel {
                recentLanguages = [current]
            }
        }
    }

    /// Switch to a different language (T064, T066)
    func switchLanguage(to language: LanguageModel) async {
        currentLanguage = language.code

        // Update recent languages (T066)
        // Remove if already exists
        recentLanguages.removeAll { $0.code == language.code }

        // Add to front
        recentLanguages.insert(language, at: 0)

        // Keep max 5
        if recentLanguages.count > 5 {
            recentLanguages = Array(recentLanguages.prefix(5))
        }

        // Save to settings
        settings.language.defaultLanguage = language.code
        settings.language.recentLanguages = recentLanguages.map { $0.code }
        await saveSettings()

        // Notify FluidAudioService to switch language (T064)
        NotificationCenter.default.post(
            name: .switchLanguage,
            object: nil,
            userInfo: ["languageCode": language.code]
        )
    }

    // MARK: - Public Methods - Permissions (Phase 3)

    /// Refresh permission statuses
    func refreshPermissions() async {
        hasMicrophonePermission = await permissionService.checkMicrophonePermission()
        hasAccessibilityPermission = permissionService.checkAccessibilityPermission()
    }

    /// Request microphone permission
    func requestMicrophonePermission() async {
        do {
            try await permissionService.requestMicrophonePermission()
            hasMicrophonePermission = true
        } catch {
            AppLogger.viewModel.error("Failed to request microphone permission: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Request accessibility permission (opens System Settings)
    func requestAccessibilityPermission() {
        do {
            try permissionService.requestAccessibilityPermission()
        } catch {
            // This is expected - user needs to grant in System Settings
            AppLogger.viewModel.info("Accessibility permission request sent to System Settings")
        }
    }

    // MARK: - Public Methods - Settings (Phase 3)

    /// Save current settings
    func saveSettings() async {
        isSaving = true
        validationError = nil

        // Validate settings
        if let error = validateSettings() {
            validationError = error
            isSaving = false
            return
        }

        // Save to disk
        do {
            try settingsService.save(settings)
            isSaving = false
        } catch {
            validationError = "Failed to save settings: \(error.localizedDescription)"
            isSaving = false
        }
    }

    /// Reset settings to defaults
    func resetToDefaults() {
        settings = UserSettings.default
        validationError = nil

        Task { [weak self] in
            await self?.saveSettings()
        }
    }

    /// Update audio sensitivity threshold
    func updateAudioSensitivity(_ sensitivity: Double) async {
        settings.audio.sensitivity = sensitivity
        await saveSettings()
    }

    /// Update silence detection threshold
    func updateSilenceThreshold(_ threshold: Double) async {
        settings.audio.silenceThreshold = threshold
        await saveSettings()
    }

    /// Update general setting and save
    func updateGeneralSetting() async {
        await saveSettings()
    }

    /// Update privacy setting and save
    func updatePrivacySetting() async {
        await saveSettings()
    }

    // MARK: - Computed Properties

    /// Hotkey display string
    var hotkeyDisplayString: String {
        let modifiers = settings.hotkey.modifiers
            .map { $0.displayName }
            .joined()

        return "\(modifiers)\(hotkeyKeyName)"
    }

    /// Key name for display
    private var hotkeyKeyName: String {
        switch settings.hotkey.keyCode {
        case 49: return "Space"
        case 36: return "Return"
        case 53: return "Escape"
        case 51: return "Delete"
        default: return "Key \(settings.hotkey.keyCode)"
        }
    }

    // MARK: - Private Methods

    /// Validate current settings
    private func validateSettings() -> String? {
        // Validate hotkey
        if settings.hotkey.modifiers.isEmpty {
            return "Hotkey must include at least one modifier key"
        }

        // Validate audio thresholds
        if settings.audio.sensitivity < 0.1 || settings.audio.sensitivity > 1.0 {
            return "Audio sensitivity must be between 0.1 and 1.0"
        }

        if settings.audio.silenceThreshold < 0.5 || settings.audio.silenceThreshold > 3.0 {
            return "Silence detection threshold must be between 0.5 and 3.0 seconds"
        }

        // Validate language
        let supportedLanguages = LanguageModel.supportedLanguages
        if !supportedLanguages.contains(where: { $0.code == settings.language.defaultLanguage }) {
            return "Selected language is not supported"
        }

        return nil
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let showRecordingModal = Notification.Name("showRecordingModal")
    static let showSettings = Notification.Name("showSettings")
    static let switchLanguage = Notification.Name("switchLanguage")
}
