import AppKit
import ApplicationServices
import AVFoundation
import Foundation

/// Permission-related errors
enum PermissionError: Error, LocalizedError, Equatable, Sendable {
    case microphoneDenied
    case accessibilityDenied
    case inputMonitoringDenied

    var errorDescription: String? {
        switch self {
        case .microphoneDenied:
            return "Microphone permission denied. Please grant access in System Settings > Privacy & Security > Microphone"
        case .accessibilityDenied:
            return "Accessibility permission denied. Please grant access in System Settings > Privacy & Security > Accessibility"
        case .inputMonitoringDenied:
            return "Input Monitoring permission denied. Please grant access in System Settings > Privacy & Security > Input Monitoring"
        }
    }
}

/// Protocol for permission checking (enables testing with mocks)
@MainActor
protocol PermissionChecker {
    func checkMicrophonePermission() async -> Bool
    func requestMicrophonePermission() async throws
    func checkAccessibilityPermission() -> Bool
    func requestAccessibilityPermission() throws
    func checkInputMonitoringPermission() -> Bool
}

/// Real implementation of permission service
@MainActor
class PermissionService: PermissionChecker {
    /// Tracks the last known input monitoring permission status based on hotkey registration result
    private var lastKnownInputMonitoringStatus: Bool = false

    /// Update the input monitoring status based on hotkey registration result
    /// This should be called by HotkeyService after attempting to register a hotkey
    func setInputMonitoringStatus(_ granted: Bool) {
        lastKnownInputMonitoringStatus = granted
    }

    /// Check microphone permission status
    func checkMicrophonePermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        return status == .authorized
    }

    /// Request microphone permission
    func requestMicrophonePermission() async throws {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        if !granted {
            throw PermissionError.microphoneDenied
        }
    }

    /// Check accessibility permission status
    /// This is required for text insertion via Accessibility APIs
    func checkAccessibilityPermission() -> Bool {
        // Use string literal to avoid Swift 6 concurrency warnings with global kAXTrustedCheckOptionPrompt
        let options: NSDictionary = ["AXTrustedCheckOptionPrompt": false]
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Request accessibility permission
    /// Note: macOS doesn't allow programmatic granting - must guide user to System Settings
    func requestAccessibilityPermission() throws {
        // Use string literal to avoid Swift 6 concurrency warnings with global kAXTrustedCheckOptionPrompt
        let options: NSDictionary = ["AXTrustedCheckOptionPrompt": true]
        let trusted = AXIsProcessTrustedWithOptions(options)

        if !trusted {
            // Open System Settings to Accessibility
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                let opened = NSWorkspace.shared.open(url)
                if !opened {
                    AppLogger.system.error("Failed to open System Settings for Accessibility permissions")
                }
            } else {
                AppLogger.system.error("Invalid URL for Accessibility System Settings")
            }
            throw PermissionError.accessibilityDenied
        }
    }

    /// Check input monitoring permission status
    /// This is required for global hotkeys on macOS 10.15+
    /// Returns the last known status based on hotkey registration result
    func checkInputMonitoringPermission() -> Bool {
        // Input monitoring permission is implicitly checked when registering global hotkeys
        // If Carbon Event Manager APIs succeed, permission is granted
        // Return the tracked status from the last hotkey registration attempt
        return lastKnownInputMonitoringStatus
    }

    /// Get all permission statuses
    func getAllPermissionStatuses() async -> PermissionsGranted {
        let microphone = await checkMicrophonePermission()
        let accessibility = checkAccessibilityPermission()
        let inputMonitoring = checkInputMonitoringPermission()

        return PermissionsGranted(
            microphone: microphone,
            accessibility: accessibility,
            inputMonitoring: inputMonitoring
        )
    }

    /// Request all required permissions
    func requestAllPermissions() async throws {
        // Request microphone
        if !(await checkMicrophonePermission()) {
            try await requestMicrophonePermission()
        }

        // Request accessibility (opens System Settings)
        if !checkAccessibilityPermission() {
            try requestAccessibilityPermission()
        }
    }
}

/// Mock implementation for testing
@MainActor
class MockPermissionService: PermissionChecker {
    var microphoneGranted = true
    var accessibilityGranted = true
    var inputMonitoringGranted = true

    func checkMicrophonePermission() async -> Bool {
        microphoneGranted
    }

    func requestMicrophonePermission() async throws {
        if !microphoneGranted {
            throw PermissionError.microphoneDenied
        }
    }

    func checkAccessibilityPermission() -> Bool {
        accessibilityGranted
    }

    func requestAccessibilityPermission() throws {
        if !accessibilityGranted {
            throw PermissionError.accessibilityDenied
        }
    }

    func checkInputMonitoringPermission() -> Bool {
        inputMonitoringGranted
    }
}
