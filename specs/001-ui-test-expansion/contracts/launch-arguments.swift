// SPDX-License-Identifier: MIT
// Contract: LaunchArguments
// Version: 1.0.0
// Date: 2026-01-03

import Foundation

// MARK: - LaunchArguments Contract

/// Constants for all supported launch arguments
/// These arguments control app behavior for testing scenarios
enum LaunchArguments {

    // MARK: - Existing Arguments (already in codebase)

    /// Enable UI testing mode
    /// Effects: Disables animations, reduces timeouts, enables test hooks
    static let uitesting = "--uitesting"

    /// Reset onboarding state to first-launch experience
    /// Effects: Clears onboarding completion flag in UserDefaults
    static let resetOnboarding = "--reset-onboarding"

    /// Skip all permission checks using mock service
    /// Effects: PermissionService returns true for all checks
    static let skipPermissionChecks = "--skip-permission-checks"

    /// Skip the onboarding flow entirely
    /// Effects: Sets onboarding as completed, doesn't show onboarding window
    static let skipOnboarding = "--skip-onboarding"

    // MARK: - New Arguments (to be implemented)

    /// Trigger recording modal immediately on launch
    /// Effects: Posts .showRecordingModal notification after app startup
    /// Use case: Testing recording flow without hotkey triggering
    static let triggerRecording = "--trigger-recording"

    /// Set mock permission state
    /// Format: --mock-permissions=granted or --mock-permissions=denied
    /// Effects: Forces PermissionService to return specified state
    static let mockPermissionsPrefix = "--mock-permissions="

    /// Set initial language for testing
    /// Format: --initial-language=en-US
    /// Effects: Overrides default language setting
    static let initialLanguagePrefix = "--initial-language="

    /// Enable accessibility testing mode
    /// Effects: Enables verbose accessibility labels, logs a11y tree
    static let accessibilityTesting = "--accessibility-testing"

    /// Simulate error conditions for error state testing
    /// Format: --simulate-error=transcription or --simulate-error=audio
    /// Effects: Forces error state in specified component
    static let simulateErrorPrefix = "--simulate-error="
}

// MARK: - LaunchArgumentParser Contract

/// Parses launch arguments into structured configuration
struct LaunchArgumentParser {

    /// Parse ProcessInfo arguments into UITestConfiguration
    /// - Parameter arguments: Array of command-line arguments (typically ProcessInfo.processInfo.arguments)
    /// - Returns: Parsed configuration
    static func parse(_ arguments: [String]) -> UITestConfiguration {
        fatalError("Contract only - implement in LaunchArgumentParser.swift")
    }

    /// Extract value from key=value argument
    /// - Parameters:
    ///   - prefix: The prefix to look for (e.g., "--mock-permissions=")
    ///   - arguments: Array of arguments to search
    /// - Returns: The value portion, or nil if not found
    static func extractValue(prefix: String, from arguments: [String]) -> String? {
        fatalError("Contract only - implement in LaunchArgumentParser.swift")
    }
}

// MARK: - UITestConfiguration Contract

/// Configuration parsed from launch arguments
struct UITestConfiguration {
    /// Whether UI testing mode is enabled
    let isUITesting: Bool

    /// Whether to reset onboarding state
    let resetOnboarding: Bool

    /// Whether to skip permission checks
    let skipPermissionChecks: Bool

    /// Whether to skip the onboarding flow
    let skipOnboarding: Bool

    /// Whether to trigger recording on launch
    let triggerRecordingOnLaunch: Bool

    /// Mock permission state (nil = use real permissions)
    let mockPermissionState: MockPermissionState?

    /// Initial language code override
    let initialLanguage: String?

    /// Whether accessibility testing is enabled
    let accessibilityTestingEnabled: Bool

    /// Simulated error type for error testing
    let simulatedError: SimulatedErrorType?

    /// Default configuration (no test flags)
    static let `default` = UITestConfiguration(
        isUITesting: false,
        resetOnboarding: false,
        skipPermissionChecks: false,
        skipOnboarding: false,
        triggerRecordingOnLaunch: false,
        mockPermissionState: nil,
        initialLanguage: nil,
        accessibilityTestingEnabled: false,
        simulatedError: nil
    )

    /// Parse from ProcessInfo (convenience)
    static func fromProcessInfo() -> UITestConfiguration {
        LaunchArgumentParser.parse(ProcessInfo.processInfo.arguments)
    }
}

// MARK: - Supporting Types

/// Mock permission state for testing
enum MockPermissionState: String {
    case granted
    case denied

    /// Parse from string value
    init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "granted": self = .granted
        case "denied": self = .denied
        default: return nil
        }
    }
}

/// Types of errors that can be simulated for testing
enum SimulatedErrorType: String {
    /// Simulate transcription failure
    case transcription

    /// Simulate audio capture failure
    case audio

    /// Simulate model loading failure
    case modelLoading

    /// Simulate text insertion failure
    case textInsertion

    /// Parse from string value
    init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "transcription": self = .transcription
        case "audio": self = .audio
        case "model", "modelLoading", "model-loading": self = .modelLoading
        case "textinsertion", "text-insertion", "insertion": self = .textInsertion
        default: return nil
        }
    }
}

// MARK: - App Integration Contract

/// Extension for AppDelegate to check launch configuration
extension NSObject { // Would be AppDelegate in implementation
    /// Check if running in UI test mode
    var isUITestMode: Bool {
        fatalError("Contract only - check UITestConfiguration.fromProcessInfo().isUITesting")
    }

    /// Apply UI test configuration on app launch
    func applyUITestConfiguration() {
        fatalError("Contract only - implement in AppDelegate")
    }
}
