// UITestConfiguration.swift
// macOS Local Speech-to-Text Application
//
// Configuration parsed from launch arguments for UI testing
// Part of the XCUITest expansion (Issue #11)

import Foundation

/// Configuration for UI test runs, parsed from launch arguments
public struct UITestConfiguration: Sendable {
    /// Whether the app is running in UI test mode
    public let isUITesting: Bool

    /// Whether onboarding should be reset
    public let resetOnboarding: Bool

    /// Whether to skip permission checks
    public let skipPermissionChecks: Bool

    /// Whether to skip the onboarding flow
    public let skipOnboarding: Bool

    /// Whether to trigger recording modal on launch
    public let triggerRecordingOnLaunch: Bool

    /// Mock permission state (nil = use real permissions)
    public let mockPermissionState: MockPermissionState?

    /// Initial language code override
    public let initialLanguage: String?

    /// Whether accessibility testing is enabled
    public let accessibilityTestingEnabled: Bool

    /// Simulated error type for error testing
    public let simulatedError: SimulatedErrorType?

    /// Default configuration (no test flags)
    public static let `default` = UITestConfiguration(
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

    /// Initialize with all values
    public init(
        isUITesting: Bool,
        resetOnboarding: Bool,
        skipPermissionChecks: Bool,
        skipOnboarding: Bool,
        triggerRecordingOnLaunch: Bool,
        mockPermissionState: MockPermissionState?,
        initialLanguage: String?,
        accessibilityTestingEnabled: Bool,
        simulatedError: SimulatedErrorType?
    ) {
        self.isUITesting = isUITesting
        self.resetOnboarding = resetOnboarding
        self.skipPermissionChecks = skipPermissionChecks
        self.skipOnboarding = skipOnboarding
        self.triggerRecordingOnLaunch = triggerRecordingOnLaunch
        self.mockPermissionState = mockPermissionState
        self.initialLanguage = initialLanguage
        self.accessibilityTestingEnabled = accessibilityTestingEnabled
        self.simulatedError = simulatedError
    }

    /// Parse from ProcessInfo (convenience)
    public static func fromProcessInfo() -> UITestConfiguration {
        LaunchArgumentParser.parse(ProcessInfo.processInfo.arguments)
    }

    /// Check if any test mode is enabled
    public var isAnyTestModeEnabled: Bool {
        isUITesting || resetOnboarding || skipPermissionChecks ||
            skipOnboarding || triggerRecordingOnLaunch ||
            mockPermissionState != nil || accessibilityTestingEnabled ||
            simulatedError != nil
    }
}

// MARK: - LaunchArgumentParser

/// Parses launch arguments into structured configuration
public struct LaunchArgumentParser {
    /// Parse ProcessInfo arguments into UITestConfiguration
    /// - Parameter arguments: Array of command-line arguments (typically ProcessInfo.processInfo.arguments)
    /// - Returns: Parsed configuration
    public static func parse(_ arguments: [String]) -> UITestConfiguration {
        let isUITesting = arguments.contains(LaunchArguments.uitesting)
        let resetOnboarding = arguments.contains(LaunchArguments.resetOnboarding)
        let skipPermissionChecks = arguments.contains(LaunchArguments.skipPermissionChecks)
        let skipOnboarding = arguments.contains(LaunchArguments.skipOnboarding)
        let triggerRecordingOnLaunch = arguments.contains(LaunchArguments.triggerRecording)
        let accessibilityTestingEnabled = arguments.contains(LaunchArguments.accessibilityTesting)

        let mockPermissionState = extractMockPermissionState(from: arguments)
        let initialLanguage = extractValue(prefix: LaunchArguments.initialLanguagePrefix, from: arguments)
        let simulatedError = extractSimulatedError(from: arguments)

        return UITestConfiguration(
            isUITesting: isUITesting,
            resetOnboarding: resetOnboarding,
            skipPermissionChecks: skipPermissionChecks,
            skipOnboarding: skipOnboarding,
            triggerRecordingOnLaunch: triggerRecordingOnLaunch,
            mockPermissionState: mockPermissionState,
            initialLanguage: initialLanguage,
            accessibilityTestingEnabled: accessibilityTestingEnabled,
            simulatedError: simulatedError
        )
    }

    /// Extract value from key=value argument
    /// - Parameters:
    ///   - prefix: The prefix to look for (e.g., "--mock-permissions=")
    ///   - arguments: Array of arguments to search
    /// - Returns: The value portion, or nil if not found
    public static func extractValue(prefix: String, from arguments: [String]) -> String? {
        guard let arg = arguments.first(where: { $0.hasPrefix(prefix) }) else {
            return nil
        }
        return String(arg.dropFirst(prefix.count))
    }

    /// Extract mock permission state from arguments
    private static func extractMockPermissionState(from arguments: [String]) -> MockPermissionState? {
        guard let value = extractValue(
            prefix: LaunchArguments.mockPermissionsPrefix,
            from: arguments
        ) else {
            return nil
        }
        return MockPermissionState(rawValue: value)
    }

    /// Extract simulated error type from arguments
    private static func extractSimulatedError(from arguments: [String]) -> SimulatedErrorType? {
        guard let value = extractValue(
            prefix: LaunchArguments.simulateErrorPrefix,
            from: arguments
        ) else {
            return nil
        }
        return SimulatedErrorType(rawValue: value)
    }
}
