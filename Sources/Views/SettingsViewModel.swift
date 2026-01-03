// SettingsViewModel.swift
// macOS Local Speech-to-Text Application
//
// User Story 4: Customizable Settings
// Task T051: SettingsViewModel - @Observable class managing settings state and validation

import Foundation
import Observation
import AppKit

/// SettingsViewModel manages all app settings and their validation
@Observable
@MainActor
final class SettingsViewModel {
    // MARK: - Published State

    /// Current user settings
    var settings: UserSettings

    /// Whether settings are being saved
    var isSaving: Bool = false

    /// Validation error message (nil if valid)
    var validationError: String?

    /// Whether model is downloading
    var isDownloadingModel: Bool = false

    /// Model download progress (0.0 - 1.0)
    var downloadProgress: Double = 0.0

    // MARK: - Dependencies

    private let settingsService: SettingsService
    private let hotkeyService: HotkeyService

    // MARK: - Initialization

    init(
        settingsService: SettingsService = SettingsService(),
        hotkeyService: HotkeyService = HotkeyService()
    ) {
        self.settingsService = settingsService
        self.hotkeyService = hotkeyService
        self.settings = settingsService.load()
    }

    // MARK: - Public Methods

    /// Save current settings
    func saveSettings() async {
        isSaving = true
        validationError = nil

        // Validate settings (T062)
        if let error = validateSettings() {
            validationError = error
            isSaving = false
            return
        }

        // Save to disk (T059)
        do {
            try settingsService.save(settings)
            isSaving = false
        } catch {
            validationError = "Failed to save settings: \(error.localizedDescription)"
            isSaving = false
        }
    }

    /// Reset settings to defaults (T060)
    func resetToDefaults() {
        settings = UserSettings.default
        validationError = nil

        Task {
            await saveSettings()
        }
    }

    /// Update hotkey configuration
    func updateHotkey(keyCode: UInt16, modifiers: [UserSettings.HotkeyModifier]) async {
        // Check for conflicts (T055)
        if let conflict = detectHotkeyConflict(keyCode: keyCode, modifiers: modifiers) {
            validationError = "Hotkey conflict: \(conflict). Please choose a different combination."
            return
        }

        settings.hotkey.keyCode = keyCode
        settings.hotkey.modifiers = modifiers

        await saveSettings()
    }

    /// Update selected language and trigger model download if needed
    func updateLanguage(_ language: LanguageModel) async {
        settings.language.defaultLanguage = language.code

        // Check if model needs to be downloaded (T056, T061)
        if language.downloadStatus != .downloaded {
            await downloadLanguageModel(language)
        }

        await saveSettings()
    }

    /// Update audio sensitivity threshold
    func updateAudioSensitivity(_ sensitivity: Double) async {
        settings.audio.sensitivityThreshold = sensitivity
        await saveSettings()
    }

    /// Update silence detection threshold
    func updateSilenceThreshold(_ threshold: Double) async {
        settings.audio.silenceDetectionThreshold = threshold
        await saveSettings()
    }

    // MARK: - Private Methods

    /// Validate current settings (T062)
    private func validateSettings() -> String? {
        // Validate hotkey
        if settings.hotkey.modifiers.isEmpty {
            return "Hotkey must include at least one modifier key"
        }

        // Validate audio thresholds
        if settings.audio.sensitivityThreshold < 0.1 || settings.audio.sensitivityThreshold > 1.0 {
            return "Audio sensitivity must be between 0.1 and 1.0"
        }

        if settings.audio.silenceDetectionThreshold < 0.5 || settings.audio.silenceDetectionThreshold > 3.0 {
            return "Silence detection threshold must be between 0.5 and 3.0 seconds"
        }

        // Validate language
        let supportedLanguages = LanguageModel.supportedLanguages
        if !supportedLanguages.contains(where: { $0.code == settings.language.defaultLanguage }) {
            return "Selected language is not supported"
        }

        return nil
    }

    /// Detect hotkey conflicts with system shortcuts (T055)
    private func detectHotkeyConflict(
        keyCode: UInt16,
        modifiers: [UserSettings.HotkeyModifier]
    ) -> String? {
        // Common macOS system shortcuts to check
        let systemShortcuts: [(String, UInt16, [UserSettings.HotkeyModifier])] = [
            ("Spotlight", 49, [.command]),  // Cmd+Space
            ("Siri", 49, [.command, .option]),  // Cmd+Option+Space
            ("Screenshot", 52, [.command, .shift]),  // Cmd+Shift+4
            ("Force Quit", 46, [.command, .option]),  // Cmd+Option+Esc
        ]

        for (name, sysKeyCode, sysModifiers) in systemShortcuts {
            if keyCode == sysKeyCode && Set(modifiers) == Set(sysModifiers) {
                return name
            }
        }

        return nil
    }

    /// Download language model (T056, T061)
    private func downloadLanguageModel(_ language: LanguageModel) async {
        isDownloadingModel = true
        downloadProgress = 0.0

        // Simulate download progress
        // In real implementation, this would use FluidAudio SDK's download API
        for progress in stride(from: 0.0, through: 1.0, by: 0.1) {
            downloadProgress = progress
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        isDownloadingModel = false
        downloadProgress = 1.0
    }
}
