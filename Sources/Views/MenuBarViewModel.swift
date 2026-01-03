// MenuBarViewModel.swift
// macOS Local Speech-to-Text Application
//
// User Story 3: Menu Bar Quick Access and Stats
// Task T043: MenuBarViewModel - @Observable class fetching daily statistics
// and handling menu actions

import AppKit
import Foundation
import Observation
import OSLog

/// MenuBarViewModel manages menu bar state and statistics
@Observable
@MainActor
final class MenuBarViewModel {
    // MARK: - Published State

    /// Today's word count
    var wordsToday: Int = 0

    /// Total sessions today
    var sessionsToday: Int = 0

    /// Whether statistics are loading
    var isLoading: Bool = false

    /// Last update timestamp
    var lastUpdated: Date = Date()

    /// Recently used languages (max 5) (T066)
    var recentLanguages: [LanguageModel] = []

    /// Current language code
    var currentLanguage: String = "en"

    /// Current language model
    var currentLanguageModel: LanguageModel? {
        LanguageModel.supportedLanguages.first { $0.code == currentLanguage }
    }

    // MARK: - Dependencies

    private let statisticsService: StatisticsService
    private let settingsService: SettingsService

    /// Task for initial data loading (stored for cleanup)
    @ObservationIgnored private var initTask: Task<Void, Never>?

    // MARK: - Initialization

    init(
        statisticsService: StatisticsService = StatisticsService(),
        settingsService: SettingsService = SettingsService()
    ) {
        self.statisticsService = statisticsService
        self.settingsService = settingsService

        // Load initial stats and language settings (store task for cleanup)
        initTask = Task { [weak self] in
            await self?.refreshStatistics()
            await self?.loadLanguageSettings()
        }
    }

    deinit {
        // Cancel any pending init task to prevent accessing deallocated memory
        initTask?.cancel()
    }

    // MARK: - Public Methods

    /// Refresh statistics from database
    func refreshStatistics() async {
        isLoading = true

        let stats = await statisticsService.getTodayStats()

        wordsToday = stats.totalWordsTranscribed
        sessionsToday = stats.totalSessions
        lastUpdated = Date()

        isLoading = false
    }

    /// Handle "Start Recording" menu action
    func startRecording() {
        // This will be triggered via NotificationCenter to AppDelegate
        NotificationCenter.default.post(name: .showRecordingModal, object: nil)
    }

    /// Handle "Open Settings" menu action
    func openSettings() {
        // This will be triggered via NotificationCenter to AppDelegate
        NotificationCenter.default.post(name: .showSettings, object: nil)
    }

    /// Handle "Quit" menu action
    func quit() {
        NSApplication.shared.terminate(nil)
    }

    /// Load language settings and recent languages (T066)
    func loadLanguageSettings() async {
        let settings = settingsService.load()
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
        var settings = settingsService.load()
        settings.language.defaultLanguage = language.code
        settings.language.recentLanguages = recentLanguages.map { $0.code }
        do {
            try settingsService.save(settings)
        } catch {
            AppLogger.viewModel.error("Failed to save language settings: \(error.localizedDescription, privacy: .public)")
        }

        // Notify FluidAudioService to switch language (T064)
        NotificationCenter.default.post(
            name: .switchLanguage,
            object: nil,
            userInfo: ["languageCode": language.code]
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let showRecordingModal = Notification.Name("showRecordingModal")
    static let showSettings = Notification.Name("showSettings")
    static let switchLanguage = Notification.Name("switchLanguage")
}
