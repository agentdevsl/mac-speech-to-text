// LaunchArguments.swift
// macOS Local Speech-to-Text Application - UITests
//
// Launch argument constants for XCUITest
// These must match the values in Sources/Utilities/LaunchArguments.swift

import Foundation

/// Constants for launch arguments used in UI tests
/// These are sent to the app and must match what the app expects
enum LaunchArguments {
    /// Enable UI testing mode
    static let uitesting = "--uitesting"

    /// Reset onboarding state to first-launch experience
    /// Shows the single-screen WelcomeView
    static let resetOnboarding = "--reset-onboarding"

    /// Skip all permission checks using mock service
    static let skipPermissionChecks = "--skip-permission-checks"

    /// Skip the onboarding/welcome flow entirely
    static let skipOnboarding = "--skip-onboarding"

    /// Trigger recording modal immediately on launch
    static let triggerRecording = "--trigger-recording"

    /// Enable accessibility testing mode
    static let accessibilityTesting = "--accessibility-testing"

    // MARK: - Deprecated Arguments (UI Re-Vision)
    // FloatingWidget has been replaced by GlassRecordingOverlay
    // These arguments are kept for backward compatibility but have no effect

    /// @deprecated FloatingWidget removed - GlassRecordingOverlay appears during recording only
    static let showFloatingWidget = "--show-floating-widget"

    /// @deprecated FloatingWidget removed - GlassRecordingOverlay appears during recording only
    static let hideFloatingWidget = "--hide-floating-widget"

    /// Force hold-to-record mode
    static let holdToRecordMode = "--hold-to-record"

    /// Force toggle (click-to-record) mode
    static let toggleRecordMode = "--toggle-record"

    /// Skip welcome flow (alias for skipOnboarding)
    static let skipWelcome = "--skip-welcome"

    /// Reset welcome flow state
    static let resetWelcome = "--reset-welcome"
}
