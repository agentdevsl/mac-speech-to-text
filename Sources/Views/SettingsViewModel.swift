// SettingsViewModel.swift
// macOS Local Speech-to-Text Application
//
// User Story 4: Customizable Settings
// Task T051: SettingsViewModel - @Observable class managing settings state and validation

import AppKit
import Foundation
import Observation

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
    func updateHotkey(keyCode: Int, modifiers: [UserSettings.HotkeyModifier]) async {
        // Check for conflicts (T055)
        if let conflict = detectHotkeyConflict(keyCode: keyCode, modifiers: modifiers) {
            validationError = "Hotkey conflict: \(conflict). Please choose a different combination."
            return
        }

        settings.hotkey.keyCode = keyCode
        settings.hotkey.modifiers = modifiers

        await saveSettings()

        // Register the new hotkey with the system (critical fix - was unused before)
        // Note: UserSettings.HotkeyModifier is a typealias for KeyModifier, so direct cast works
        do {
            try await hotkeyService.registerHotkey(
                keyCode: keyCode,
                modifiers: modifiers // KeyModifier array is compatible directly
            ) {
                // Hotkey triggered - post notification to show recording modal
                NotificationCenter.default.post(name: .showRecordingModal, object: nil)
            }
        } catch {
            validationError = "Failed to register hotkey: \(error.localizedDescription)"
        }
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
        settings.audio.sensitivity = sensitivity
        await saveSettings()
    }

    /// Update silence detection threshold
    func updateSilenceThreshold(_ threshold: Double) async {
        settings.audio.silenceThreshold = threshold
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

    /// Detect hotkey conflicts with system shortcuts (T055)
    private func detectHotkeyConflict(
        keyCode: Int,
        modifiers: [UserSettings.HotkeyModifier]
    ) -> String? {
        // Common macOS system shortcuts to check
        let systemShortcuts: [SystemShortcut] = [
            SystemShortcut(name: "Spotlight", keyCode: 49, modifiers: [.command]),
            SystemShortcut(name: "Siri", keyCode: 49, modifiers: [.command, .option]),
            SystemShortcut(name: "Screenshot", keyCode: 52, modifiers: [.command, .shift]),
            SystemShortcut(name: "Force Quit", keyCode: 46, modifiers: [.command, .option])
        ]

        for shortcut in systemShortcuts where keyCode == shortcut.keyCode
            && Set(modifiers) == Set(shortcut.modifiers) {
            return shortcut.name
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
            do {
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            } catch {
                // Task was cancelled, exit early
                isDownloadingModel = false
                return
            }
        }

        isDownloadingModel = false
        downloadProgress = 1.0
    }
}

// MARK: - System Shortcut

/// Represents a macOS system keyboard shortcut for conflict detection
private struct SystemShortcut {
    let name: String
    let keyCode: Int
    let modifiers: [UserSettings.HotkeyModifier]
}
