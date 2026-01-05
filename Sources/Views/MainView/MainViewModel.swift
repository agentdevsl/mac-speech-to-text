// MainViewModel.swift
// macOS Local Speech-to-Text Application
//
// Phase 2: Unified Main View
// ViewModel managing sidebar navigation and section state

import AppKit
import Foundation
import Observation
import OSLog

// MARK: - Sidebar Section

/// Represents the available sections in the main view sidebar
enum SidebarSection: String, CaseIterable, Identifiable, Codable {
    case home
    case general
    case audio
    case voiceTrigger
    case language
    case theme
    case privacy
    case about

    var id: String { rawValue }

    /// Display title for the section
    var title: String {
        switch self {
        case .home: return "Home"
        case .general: return "General"
        case .audio: return "Audio"
        case .voiceTrigger: return "Voice Trigger"
        case .language: return "Language"
        case .theme: return "Theme"
        case .privacy: return "Privacy"
        case .about: return "About"
        }
    }

    /// SF Symbol name for the section icon
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .general: return "gear"
        case .audio: return "waveform"
        case .voiceTrigger: return "mic.badge.waveform"
        case .language: return "globe"
        case .theme: return "paintbrush"
        case .privacy: return "lock.shield"
        case .about: return "info.circle"
        }
    }

    /// Accessibility label for the section
    var accessibilityLabel: String {
        "\(title) section"
    }
}

// MARK: - MainViewModel

/// MainViewModel manages the main window's state and navigation
@Observable
@MainActor
final class MainViewModel {
    // MARK: - Constants

    /// UserDefaults key for persisting selected section
    private static let selectedSectionKey = "MainView.selectedSection"

    /// UserDefaults key for tracking first launch
    private static let hasLaunchedBeforeKey = "MainView.hasLaunchedBefore"

    // MARK: - Published State

    /// Currently selected sidebar section
    var selectedSection: SidebarSection {
        didSet {
            persistSelectedSection()
        }
    }

    /// Whether the app is in first-launch state (shows Home by default)
    var isFirstLaunch: Bool

    // MARK: - Dependencies

    @ObservationIgnored private let userDefaults: UserDefaults

    /// Unique ID for logging (MainActor-isolated)
    @ObservationIgnored private let viewModelId: String

    /// Shadow copy of viewModelId for use in nonisolated deinit (HIGH-12 fix)
    /// Required because deinit is nonisolated but viewModelId is @MainActor
    /// Note: String is Sendable so nonisolated(unsafe) not strictly needed, but kept for clarity
    @ObservationIgnored private let viewModelIdForDeinit: String

    // MARK: - Initialization

    init(userDefaults: UserDefaults = .standard) {
        let id = UUID().uuidString.prefix(8).description
        self.viewModelId = id
        self.viewModelIdForDeinit = id  // Shadow copy for nonisolated deinit
        self.userDefaults = userDefaults

        // Check if this is first launch
        let hasLaunchedBefore = userDefaults.bool(forKey: Self.hasLaunchedBeforeKey)
        self.isFirstLaunch = !hasLaunchedBefore

        // Load persisted section or default to .home on first launch
        if let savedSection = userDefaults.string(forKey: Self.selectedSectionKey),
           let section = SidebarSection(rawValue: savedSection) {
            self.selectedSection = section
        } else {
            // First launch - default to Home
            self.selectedSection = .home
        }

        AppLogger.lifecycle(AppLogger.viewModel, self, event: "init[\(viewModelId)]")
        AppLogger.debug(
            AppLogger.viewModel,
            "[\(viewModelId)] Initialized: isFirstLaunch=\(isFirstLaunch), section=\(selectedSection.rawValue)"
        )
    }

    deinit {
        // Use nonisolated(unsafe) shadow copy since deinit is nonisolated (HIGH-12 fix)
        AppLogger.trace(AppLogger.viewModel, "MainViewModel[\(viewModelIdForDeinit)] deallocating")
    }

    // MARK: - Public Methods

    /// Navigate to a specific section
    func navigateTo(_ section: SidebarSection) {
        AppLogger.info(AppLogger.viewModel, "[\(viewModelId)] Navigating to: \(section.rawValue)")
        selectedSection = section
    }

    /// Mark first launch as complete (called after user interacts with Home)
    func markFirstLaunchComplete() {
        guard isFirstLaunch else { return }

        isFirstLaunch = false
        userDefaults.set(true, forKey: Self.hasLaunchedBeforeKey)
        AppLogger.info(AppLogger.viewModel, "[\(viewModelId)] First launch marked complete")
    }

    /// Quit the application
    func quitApplication() {
        AppLogger.info(AppLogger.viewModel, "[\(viewModelId)] Quit requested")
        NSApplication.shared.terminate(nil)
    }

    /// Reset state (useful for testing)
    /// Note: Order matters - clear UserDefaults AFTER setting selectedSection to avoid
    /// didSet re-persisting the value we just tried to clear (MED-4 fix)
    func reset() {
        // Set state first (triggers didSet which persists)
        selectedSection = .home
        isFirstLaunch = true
        // Then clear UserDefaults to ensure clean state
        userDefaults.removeObject(forKey: Self.selectedSectionKey)
        userDefaults.removeObject(forKey: Self.hasLaunchedBeforeKey)
        AppLogger.debug(AppLogger.viewModel, "[\(viewModelId)] State reset")
    }

    // MARK: - Private Methods

    /// Persist selected section to UserDefaults
    private func persistSelectedSection() {
        userDefaults.set(selectedSection.rawValue, forKey: Self.selectedSectionKey)
        AppLogger.debug(AppLogger.viewModel, "[\(viewModelId)] Persisted section: \(selectedSection.rawValue)")
    }
}
