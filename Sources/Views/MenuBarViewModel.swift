// MenuBarViewModel.swift
// macOS Local Speech-to-Text Application
//
// User Story 3: Menu Bar Quick Access and Stats
// Task T043: MenuBarViewModel - @Observable class fetching daily statistics
// and handling menu actions

import Foundation
import Observation

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

    // MARK: - Dependencies

    private let statisticsService: StatisticsService
    private let settingsService: SettingsService

    // MARK: - Initialization

    init(
        statisticsService: StatisticsService = StatisticsService(),
        settingsService: SettingsService = SettingsService()
    ) {
        self.statisticsService = statisticsService
        self.settingsService = settingsService

        // Load initial stats
        Task {
            await refreshStatistics()
        }
    }

    // MARK: - Public Methods

    /// Refresh statistics from database
    func refreshStatistics() async {
        isLoading = true

        let stats = statisticsService.getTodayStats()

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
}

// MARK: - Notification Names

extension Notification.Name {
    static let showRecordingModal = Notification.Name("showRecordingModal")
    static let showSettings = Notification.Name("showSettings")
}
