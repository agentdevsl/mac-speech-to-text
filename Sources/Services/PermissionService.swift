import AppKit
import ApplicationServices
import AVFoundation
import Foundation

/// Permission-related errors
enum PermissionError: Error, LocalizedError {
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
protocol PermissionChecker {
    func checkMicrophonePermission() async -> Bool
    func requestMicrophonePermission() async throws
    func checkAccessibilityPermission() -> Bool
    func requestAccessibilityPermission() throws
    func checkInputMonitoringPermission() -> Bool
}

/// Real implementation of permission service
class PermissionService: PermissionChecker {

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
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Request accessibility permission
    /// Note: macOS doesn't allow programmatic granting - must guide user to System Settings
    func requestAccessibilityPermission() throws {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options)

        if !trusted {
            // Open System Settings to Accessibility
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
            throw PermissionError.accessibilityDenied
        }
    }

    /// Check input monitoring permission status
    /// This is required for global hotkeys on macOS 10.15+
    func checkInputMonitoringPermission() -> Bool {
        // Input monitoring permission is implicitly checked when registering global hotkeys
        // If Carbon Event Manager APIs succeed, permission is granted
        // We'll check this when actually registering the hotkey
        return true
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
