// LaunchArguments.swift
// macOS Local Speech-to-Text Application
//
// Constants for all supported launch arguments
// Part of the XCUITest expansion (Issue #11)

import Foundation

/// Constants for all supported launch arguments
/// These arguments control app behavior for testing scenarios
public enum LaunchArguments {
    // MARK: - Existing Arguments

    /// Enable UI testing mode
    /// Effects: Disables animations, reduces timeouts, enables test hooks
    public static let uitesting = "--uitesting"

    /// Reset onboarding state to first-launch experience
    /// Effects: Clears onboarding completion flag in UserDefaults
    public static let resetOnboarding = "--reset-onboarding"

    /// Skip all permission checks using mock service
    /// Effects: PermissionService returns true for all checks
    public static let skipPermissionChecks = "--skip-permission-checks"

    /// Skip the onboarding flow entirely
    /// Effects: Sets onboarding as completed, doesn't show onboarding window
    public static let skipOnboarding = "--skip-onboarding"

    // MARK: - New Arguments

    /// Trigger recording modal immediately on launch
    /// Effects: Posts .showRecordingModal notification after app startup
    /// Use case: Testing recording flow without hotkey triggering
    public static let triggerRecording = "--trigger-recording"

    /// Set mock permission state
    /// Format: --mock-permissions=granted or --mock-permissions=denied
    /// Effects: Forces PermissionService to return specified state
    public static let mockPermissionsPrefix = "--mock-permissions="

    /// Set initial language for testing
    /// Format: --initial-language=en-US
    /// Effects: Overrides default language setting
    public static let initialLanguagePrefix = "--initial-language="

    /// Enable accessibility testing mode
    /// Effects: Enables verbose accessibility labels, logs a11y tree
    public static let accessibilityTesting = "--accessibility-testing"

    /// Simulate error conditions for error state testing
    /// Format: --simulate-error=transcription or --simulate-error=audio
    /// Effects: Forces error state in specified component
    public static let simulateErrorPrefix = "--simulate-error="

    // MARK: - Argument Checking Helpers

    /// Check if a specific argument is present
    /// - Parameter argument: The argument to check for
    /// - Returns: true if the argument is present
    public static func isPresent(_ argument: String) -> Bool {
        ProcessInfo.processInfo.arguments.contains(argument)
    }

    /// Check if running in UI test mode
    public static var isUITesting: Bool {
        isPresent(uitesting)
    }

    /// Check if onboarding should be reset
    public static var shouldResetOnboarding: Bool {
        isPresent(resetOnboarding)
    }

    /// Check if permission checks should be skipped
    public static var shouldSkipPermissionChecks: Bool {
        isPresent(skipPermissionChecks)
    }

    /// Check if onboarding should be skipped
    public static var shouldSkipOnboarding: Bool {
        isPresent(skipOnboarding)
    }

    /// Check if recording modal should be triggered on launch
    public static var shouldTriggerRecording: Bool {
        isPresent(triggerRecording)
    }

    /// Check if accessibility testing mode is enabled
    public static var isAccessibilityTesting: Bool {
        isPresent(accessibilityTesting)
    }

    /// Get mock permission state if specified
    /// - Returns: MockPermissionState if --mock-permissions is present
    public static var mockPermissionState: MockPermissionState? {
        guard let arg = ProcessInfo.processInfo.arguments.first(where: {
            $0.hasPrefix(mockPermissionsPrefix)
        }) else {
            return nil
        }

        let value = String(arg.dropFirst(mockPermissionsPrefix.count))
        return MockPermissionState(rawValue: value)
    }

    /// Get initial language if specified
    /// - Returns: Language code if --initial-language is present
    public static var initialLanguage: String? {
        guard let arg = ProcessInfo.processInfo.arguments.first(where: {
            $0.hasPrefix(initialLanguagePrefix)
        }) else {
            return nil
        }

        return String(arg.dropFirst(initialLanguagePrefix.count))
    }

    /// Get simulated error type if specified
    /// - Returns: SimulatedErrorType if --simulate-error is present
    public static var simulatedError: SimulatedErrorType? {
        guard let arg = ProcessInfo.processInfo.arguments.first(where: {
            $0.hasPrefix(simulateErrorPrefix)
        }) else {
            return nil
        }

        let value = String(arg.dropFirst(simulateErrorPrefix.count))
        return SimulatedErrorType(rawValue: value)
    }
}

// MARK: - Supporting Types

/// Mock permission state for testing
public enum MockPermissionState: String, Sendable {
    case granted
    case denied

    /// Parse from string value (case-insensitive)
    public init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "granted":
            self = .granted
        case "denied":
            self = .denied
        default:
            return nil
        }
    }
}

/// Types of errors that can be simulated for testing
public enum SimulatedErrorType: String, Sendable {
    /// Simulate transcription failure
    case transcription

    /// Simulate audio capture failure
    case audio

    /// Simulate model loading failure
    case modelLoading

    /// Simulate text insertion failure
    case textInsertion

    /// Parse from string value (case-insensitive, supports multiple formats)
    public init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "transcription":
            self = .transcription
        case "audio":
            self = .audio
        case "model", "modelloading", "model-loading":
            self = .modelLoading
        case "textinsertion", "text-insertion", "insertion":
            self = .textInsertion
        default:
            return nil
        }
    }
}
