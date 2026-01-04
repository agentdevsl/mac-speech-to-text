// MenuBarViewModel.swift
// macOS Local Speech-to-Text Application
//
// Ultra-minimal ViewModel for menu bar: status icon + open/quit actions

import AppKit
import SwiftUI

/// Ultra-minimal menu bar ViewModel
@Observable
@MainActor
final class MenuBarViewModel {
    // MARK: - State

    /// Whether currently recording
    var isRecording: Bool = false

    /// Whether microphone permission is granted
    var hasPermission: Bool = false

    // MARK: - Dependencies

    @ObservationIgnored private let permissionService: PermissionService

    // MARK: - Initialization

    init(permissionService: PermissionService = PermissionService()) {
        self.permissionService = permissionService

        // Check permission status on init
        Task { [weak self] in
            await self?.refreshPermission()
        }
    }

    // MARK: - Computed Properties

    /// Status icon based on current state
    var statusIcon: String {
        if !hasPermission {
            return "mic.slash"
        }
        return isRecording ? "mic.fill" : "mic.fill"
    }

    /// Icon color based on current state
    var iconColor: Color {
        if !hasPermission {
            return .gray
        }
        return isRecording ? .red : Color("AmberPrimary", bundle: nil)
    }

    // MARK: - Actions

    /// Open the main application view
    func openMainView() {
        NotificationCenter.default.post(name: .showMainView, object: nil)
    }

    /// Quit the application
    func quit() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Private Methods

    /// Refresh microphone permission status
    private func refreshPermission() async {
        hasPermission = await permissionService.checkMicrophonePermission()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let showRecordingModal = Notification.Name("showRecordingModal")
    static let showSettings = Notification.Name("showSettings")
    static let showMainView = Notification.Name("showMainView")
    static let switchLanguage = Notification.Name("switchLanguage")
}
