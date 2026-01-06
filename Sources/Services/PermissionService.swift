import AppKit
import ApplicationServices
import AVFoundation
import Foundation

/// Permission-related errors
enum PermissionError: Error, LocalizedError, Equatable, Sendable {
    case microphoneDenied
    case accessibilityDenied
    case bundleIdentifierMismatch(expected: String, actual: String?)
    case signingIdentityMismatch(reason: String)
    case multipleAppInstances(bundleId: String, count: Int)

    var errorDescription: String? {
        switch self {
        case .microphoneDenied:
            return "Microphone permission denied. Please grant access in System Settings > Privacy & Security > Microphone"
        case .accessibilityDenied:
            return "Accessibility permission denied. Please grant access in System Settings > Privacy & Security > Accessibility"
        case .bundleIdentifierMismatch(let expected, let actual):
            return "Bundle identifier mismatch. Expected '\(expected)' but got '\(actual ?? "nil")'. Please reinstall the application."
        case .signingIdentityMismatch(let reason):
            return "App signing validation failed: \(reason). Permissions may need to be re-granted in System Settings."
        case .multipleAppInstances(let bundleId, let count):
            return "Multiple instances (\(count)) of '\(bundleId)' detected. Please quit duplicate instances to avoid permission conflicts."
        }
    }
}

/// Result of app identity validation
struct AppIdentityValidation: Sendable {
    let isValid: Bool
    let bundleId: String?
    let bundlePath: String?
    let teamId: String?
    let warnings: [String]
    let errors: [PermissionError]
}

/// Result of permission state verification against actual macOS state
/// Used to detect when stored permission state is stale (e.g., user revoked permissions)
struct PermissionStateVerification: Sendable {
    let storedMicrophoneGranted: Bool
    let actualMicrophoneGranted: Bool
    let storedAccessibilityGranted: Bool
    let actualAccessibilityGranted: Bool

    /// Whether stored state claims permission is granted but actual macOS state shows it's denied
    /// Only flags as mismatch if stored=true but actual=false (stale grant)
    /// The reverse (stored=false, actual=true) is fine - user may have granted via System Settings
    var hasMismatch: Bool {
        (storedMicrophoneGranted && !actualMicrophoneGranted) ||
            (storedAccessibilityGranted && !actualAccessibilityGranted)
    }

    /// Human-readable description of the mismatch
    var mismatchDescription: String? {
        guard hasMismatch else { return nil }
        var descriptions: [String] = []
        if storedMicrophoneGranted && !actualMicrophoneGranted {
            descriptions.append("microphone (stored: granted, actual: denied)")
        }
        if storedAccessibilityGranted && !actualAccessibilityGranted {
            descriptions.append("accessibility (stored: granted, actual: denied)")
        }
        return descriptions.joined(separator: ", ")
    }
}

/// Protocol for permission checking (enables testing with mocks)
@MainActor
protocol PermissionChecker {
    func checkMicrophonePermission() async -> Bool
    func requestMicrophonePermission() async throws
    func checkAccessibilityPermission() -> Bool
    func requestAccessibilityPermission() throws

    /// Whether permission polling is currently active
    var isPolling: Bool { get }

    /// Stop any active permission polling
    func stopPolling()

    /// Poll for microphone permission changes (e.g., after user is directed to System Settings)
    /// - Parameters:
    ///   - interval: Polling interval in seconds (default 1.0)
    ///   - maxDuration: Maximum duration to poll in seconds (default 30.0)
    ///   - onGranted: Callback when permission is granted
    func pollForMicrophonePermission(
        interval: TimeInterval,
        maxDuration: TimeInterval,
        onGranted: @escaping @MainActor @Sendable () -> Void
    ) async

    /// Poll for accessibility permission changes (e.g., after user is directed to System Settings)
    /// - Parameters:
    ///   - interval: Polling interval in seconds (default 1.0)
    ///   - maxDuration: Maximum duration to poll in seconds (default 30.0)
    ///   - onGranted: Callback when permission is granted
    func pollForAccessibilityPermission(
        interval: TimeInterval,
        maxDuration: TimeInterval,
        onGranted: @escaping @MainActor @Sendable () -> Void
    ) async

    /// Verify stored permission state matches actual macOS permission state
    /// Detects stale grants (stored says granted but macOS says denied)
    /// - Parameter settings: Current user settings containing stored permission state
    /// - Returns: Verification result with details about any mismatches
    func verifyPermissionStateConsistency(settings: UserSettings) async -> PermissionStateVerification
}

/// Real implementation of permission service
@MainActor
class PermissionService: PermissionChecker {
    // MARK: - Constants

    /// Expected bundle identifier for this app
    static let expectedBundleIdentifier = "com.speechtotext.app"

    /// Default polling interval (faster for better UX)
    static let defaultPollingInterval: TimeInterval = 0.5

    /// Maximum polling duration
    static let defaultMaxPollingDuration: TimeInterval = 120.0

    // MARK: - Properties

    /// Mock permission state for testing (from launch arguments)
    private var mockState: MockPermissionState? {
        LaunchArguments.mockPermissionState
    }

    /// Whether to skip permission checks entirely
    private var skipChecks: Bool {
        LaunchArguments.shouldSkipPermissionChecks
    }

    /// Whether permission polling is currently active
    private(set) var isPolling: Bool = false

    /// Flag to signal polling should stop
    private var shouldStopPolling: Bool = false

    /// App activation observer for immediate permission detection
    private var activationObserver: NSObjectProtocol?

    /// Callback for when permission is granted during polling with activation observer
    private var onPermissionGrantedCallback: (@MainActor @Sendable () -> Void)?

    // MARK: - Initialization

    init() {
        // Validate app identity on initialization
        let validation = Self.validateAppIdentity()
        if !validation.isValid {
            for error in validation.errors {
                AppLogger.system.error("App identity validation error: \(error.localizedDescription, privacy: .public)")
            }
        }
        for warning in validation.warnings {
            AppLogger.system.warning("App identity warning: \(warning, privacy: .public)")
        }
    }

    deinit {
        // Clean up NotificationCenter observer to prevent memory leak
        // Note: NotificationCenter.removeObserver is thread-safe, so we can call it from deinit
        // even though the class is @MainActor isolated
        if let observer = activationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Polling Control

    /// Stop any active permission polling
    func stopPolling() {
        shouldStopPolling = true
        isPolling = false

        // Remove activation observer
        if let observer = activationObserver {
            NotificationCenter.default.removeObserver(observer)
            activationObserver = nil
        }
        onPermissionGrantedCallback = nil
    }

    // MARK: - App Identity Validation

    /// Validate that the app's identity is correct and there are no conflicts
    /// This helps detect issues like:
    /// - Multiple apps with the same name but different bundle IDs
    /// - Apps that have been reinstalled with different signing
    /// - Bundle ID mismatches
    static func validateAppIdentity() -> AppIdentityValidation {
        var warnings: [String] = []
        var errors: [PermissionError] = []

        // Get current bundle info
        let actualBundleId = Bundle.main.bundleIdentifier
        let bundlePath = Bundle.main.bundlePath

        // Validate bundle identifier
        if let actualId = actualBundleId {
            if actualId != expectedBundleIdentifier {
                // Log warning but don't fail - development builds may have different IDs
                warnings.append("Bundle ID '\(actualId)' differs from expected '\(expectedBundleIdentifier)'")
                AppLogger.system.debug("Bundle ID check: actual=\(actualId, privacy: .public), expected=\(expectedBundleIdentifier, privacy: .public)")
            }
        } else {
            errors.append(.bundleIdentifierMismatch(expected: expectedBundleIdentifier, actual: nil))
        }

        // Check for multiple running instances with same bundle ID
        if let bundleId = actualBundleId {
            let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
            if runningApps.count > 1 {
                warnings.append("Multiple instances (\(runningApps.count)) of '\(bundleId)' are running")
                AppLogger.system.warning("Detected \(runningApps.count) running instances of \(bundleId, privacy: .public)")
            }
        }

        // Extract team ID from code signing (if available)
        let teamId = extractTeamId(from: bundlePath)
        if teamId == nil {
            warnings.append("Could not extract team ID from code signing - app may be unsigned")
        }

        let isValid = errors.isEmpty
        return AppIdentityValidation(
            isValid: isValid,
            bundleId: actualBundleId,
            bundlePath: bundlePath,
            teamId: teamId,
            warnings: warnings,
            errors: errors
        )
    }

    /// Extract team ID from the app's code signature
    private static func extractTeamId(from bundlePath: String?) -> String? {
        guard let path = bundlePath else { return nil }

        // Use codesign to get signing info
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["-dv", "--verbose=4", path]

        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            // Team ID is in stderr output for codesign -dv
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: errorData, encoding: .utf8) {
                // Parse TeamIdentifier=XXXXXXXXXX
                let lines = output.components(separatedBy: "\n")
                for line in lines where line.contains("TeamIdentifier=") {
                    let parts = line.components(separatedBy: "=")
                    if parts.count >= 2 {
                        let teamId = parts[1].trimmingCharacters(in: .whitespaces)
                        if teamId != "not set" {
                            return teamId
                        }
                    }
                }
            }
        } catch {
            AppLogger.system.debug("Failed to extract team ID: \(error.localizedDescription, privacy: .public)")
        }

        return nil
    }

    /// Check if there are other apps with similar names that might cause confusion
    func checkForConflictingApps() -> [String] {
        var conflicts: [String] = []
        let currentBundleId = Bundle.main.bundleIdentifier ?? ""
        let currentName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "SpeechToText"

        // Get all running applications
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications

        for app in runningApps {
            guard let appBundleId = app.bundleIdentifier,
                  let appName = app.localizedName else {
                continue
            }

            // Skip our own app
            if appBundleId == currentBundleId {
                continue
            }

            // Check for similar names (case-insensitive)
            if appName.lowercased().contains("speech") && appName.lowercased().contains("text") {
                conflicts.append("'\(appName)' (bundle: \(appBundleId)) - similar name may cause permission confusion")
            }

            // Check for same name but different bundle ID
            if appName.lowercased() == currentName.lowercased() {
                conflicts.append("'\(appName)' (bundle: \(appBundleId)) - same name, different bundle ID")
            }
        }

        return conflicts
    }

    /// Check microphone permission status
    func checkMicrophonePermission() async -> Bool {
        // Handle mock state for testing
        if let mockState = mockState {
            AppLogger.system.debug("Using mock microphone permission: \(mockState.rawValue, privacy: .public)")
            return mockState == .granted
        }

        // Skip checks if requested (always return true)
        if skipChecks {
            AppLogger.system.debug("Skipping microphone permission check")
            return true
        }

        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        return status == .authorized
    }

    /// Request microphone permission
    func requestMicrophonePermission() async throws {
        // Handle mock state for testing
        if let mockState = mockState {
            if mockState == .denied {
                throw PermissionError.microphoneDenied
            }
            return
        }

        // Skip if requested
        if skipChecks {
            return
        }

        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        if !granted {
            throw PermissionError.microphoneDenied
        }
    }

    /// Check accessibility permission status
    /// This is required for text insertion via Accessibility APIs
    func checkAccessibilityPermission() -> Bool {
        // Handle mock state for testing
        if let mockState = mockState {
            AppLogger.system.debug("Using mock accessibility permission: \(mockState.rawValue, privacy: .public)")
            return mockState == .granted
        }

        // Skip checks if requested (always return true)
        if skipChecks {
            AppLogger.system.debug("Skipping accessibility permission check")
            return true
        }

        // Use string literal to avoid Swift 6 concurrency warnings with global kAXTrustedCheckOptionPrompt
        let options: NSDictionary = ["AXTrustedCheckOptionPrompt": false]
        let isTrusted = AXIsProcessTrustedWithOptions(options)

        // Debug logging for accessibility permission status
        let bundleID = Bundle.main.bundleIdentifier ?? "unknown"
        AppLogger.system.debug(
            "Accessibility check: trusted=\(isTrusted), bundleID=\(bundleID, privacy: .public)"
        )

        return isTrusted
    }

    /// Request accessibility permission
    /// Note: macOS doesn't allow programmatic granting - must guide user to System Settings
    func requestAccessibilityPermission() throws {
        // Handle mock state for testing
        if let mockState = mockState {
            if mockState == .denied {
                throw PermissionError.accessibilityDenied
            }
            return
        }

        // Skip if requested
        if skipChecks {
            return
        }

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

    /// Get all permission statuses
    func getAllPermissionStatuses() async -> PermissionsGranted {
        let microphone = await checkMicrophonePermission()
        let accessibility = checkAccessibilityPermission()

        return PermissionsGranted(
            microphone: microphone,
            accessibility: accessibility
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

    /// Poll for microphone permission changes with activation observer
    /// Uses faster 0.5s polling by default and also checks when app is activated
    /// - Parameters:
    ///   - interval: Polling interval (default 0.5s for faster UX)
    ///   - maxDuration: Maximum duration to poll (default 120s)
    ///   - onGranted: Callback when permission is granted
    func pollForMicrophonePermission(
        interval: TimeInterval = PermissionService.defaultPollingInterval,
        maxDuration: TimeInterval = PermissionService.defaultMaxPollingDuration,
        onGranted: @escaping @MainActor @Sendable () -> Void
    ) async {
        isPolling = true
        shouldStopPolling = false
        onPermissionGrantedCallback = onGranted

        // Setup activation observer for immediate detection when user switches back
        setupActivationObserver(checkMicrophone: true, checkAccessibility: false)

        let startTime = Date()
        let intervalNanoseconds = UInt64(interval * 1_000_000_000)

        AppLogger.system.debug("Starting microphone permission polling (interval: \(interval)s, maxDuration: \(maxDuration)s)")

        while !shouldStopPolling {
            // Check if we've exceeded max duration
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed >= maxDuration {
                AppLogger.system.debug("Microphone permission polling timed out after \(elapsed)s")
                break
            }

            // Check permission status
            if await checkMicrophonePermission() {
                AppLogger.system.info("Microphone permission granted during polling")
                stopPolling()
                onGranted()
                return
            }

            // Wait for the interval
            do {
                try await Task.sleep(nanoseconds: intervalNanoseconds)
            } catch {
                // Task was cancelled
                AppLogger.system.debug("Microphone permission polling cancelled")
                break
            }
        }

        stopPolling()
    }

    /// Poll for accessibility permission changes with activation observer
    /// Uses faster 0.5s polling by default and also checks when app is activated
    /// - Parameters:
    ///   - interval: Polling interval (default 0.5s for faster UX)
    ///   - maxDuration: Maximum duration to poll (default 120s)
    ///   - onGranted: Callback when permission is granted
    func pollForAccessibilityPermission(
        interval: TimeInterval = PermissionService.defaultPollingInterval,
        maxDuration: TimeInterval = PermissionService.defaultMaxPollingDuration,
        onGranted: @escaping @MainActor @Sendable () -> Void
    ) async {
        isPolling = true
        shouldStopPolling = false
        onPermissionGrantedCallback = onGranted

        // Setup activation observer for immediate detection when user switches back
        setupActivationObserver(checkMicrophone: false, checkAccessibility: true)

        let startTime = Date()
        let intervalNanoseconds = UInt64(interval * 1_000_000_000)

        AppLogger.system.debug("Starting accessibility permission polling (interval: \(interval)s, maxDuration: \(maxDuration)s)")

        while !shouldStopPolling {
            // Check if we've exceeded max duration
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed >= maxDuration {
                AppLogger.system.debug("Accessibility permission polling timed out after \(elapsed)s")
                break
            }

            // Check permission status
            if checkAccessibilityPermission() {
                AppLogger.system.info("Accessibility permission granted during polling")
                stopPolling()
                onGranted()
                return
            }

            // Wait for the interval
            do {
                try await Task.sleep(nanoseconds: intervalNanoseconds)
            } catch {
                // Task was cancelled
                AppLogger.system.debug("Accessibility permission polling cancelled")
                break
            }
        }

        stopPolling()
    }

    // MARK: - Activation Observer

    /// Setup observer for app activation to immediately check permissions when user returns
    private func setupActivationObserver(checkMicrophone: Bool, checkAccessibility: Bool) {
        // Remove existing observer first
        if let existing = activationObserver {
            NotificationCenter.default.removeObserver(existing)
            activationObserver = nil
        }

        // Create new observer
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isPolling else { return }

                AppLogger.system.debug("App activated - checking permissions immediately")

                var granted = false

                if checkMicrophone {
                    granted = await self.checkMicrophonePermission()
                }

                if checkAccessibility {
                    granted = self.checkAccessibilityPermission()
                }

                if granted {
                    AppLogger.system.info("Permission granted on app activation")
                    if let callback = self.onPermissionGrantedCallback {
                        self.stopPolling()
                        callback()
                    }
                }
            }
        }
    }

    // MARK: - Enhanced Permission Request with Validation

    /// Request microphone permission with app identity validation
    /// - Returns: Validation result including any warnings about potential conflicts
    func requestMicrophonePermissionWithValidation() async throws -> AppIdentityValidation {
        let validation = Self.validateAppIdentity()

        // Check for conflicting apps
        let conflicts = checkForConflictingApps()
        var warnings = validation.warnings
        warnings.append(contentsOf: conflicts)

        // Request the actual permission
        try await requestMicrophonePermission()

        return AppIdentityValidation(
            isValid: validation.isValid,
            bundleId: validation.bundleId,
            bundlePath: validation.bundlePath,
            teamId: validation.teamId,
            warnings: warnings,
            errors: validation.errors
        )
    }

    /// Open System Settings to Microphone privacy pane
    func openMicrophoneSettings() {
        // Use the privacy URL scheme for Microphone
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            let opened = NSWorkspace.shared.open(url)
            if !opened {
                AppLogger.system.error("Failed to open System Settings for Microphone permissions")
            } else {
                AppLogger.system.info("Opened System Settings for Microphone permissions")
            }
        } else {
            AppLogger.system.error("Invalid URL for Microphone System Settings")
        }
    }

    /// Open System Settings to Accessibility privacy pane
    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            let opened = NSWorkspace.shared.open(url)
            if !opened {
                AppLogger.system.error("Failed to open System Settings for Accessibility permissions")
            } else {
                AppLogger.system.info("Opened System Settings for Accessibility permissions")
            }
        } else {
            AppLogger.system.error("Invalid URL for Accessibility System Settings")
        }
    }

    // MARK: - App Identity Change Detection

    /// Result of identity change check
    struct IdentityChangeResult: Sendable {
        let hasChanged: Bool
        let reason: String?
        let currentBundleId: String?
        let currentTeamId: String?
        let storedBundleId: String?
        let storedTeamId: String?
    }

    /// Check if the app's signing identity has changed since permissions were granted
    /// - Parameter settings: Current user settings containing stored identity
    /// - Returns: Result indicating if identity changed and why
    static func checkForIdentityChange(settings: UserSettings) -> IdentityChangeResult {
        let validation = validateAppIdentity()
        let currentBundleId = validation.bundleId
        let currentTeamId = validation.teamId

        let storedBundleId = settings.onboarding.lastKnownBundleId
        let storedTeamId = settings.onboarding.lastKnownTeamId

        // If no stored identity, this is first run - no change
        guard storedBundleId != nil || storedTeamId != nil else {
            AppLogger.system.debug("No stored app identity - first run or fresh install")
            return IdentityChangeResult(
                hasChanged: false,
                reason: nil,
                currentBundleId: currentBundleId,
                currentTeamId: currentTeamId,
                storedBundleId: nil,
                storedTeamId: nil
            )
        }

        // Check for bundle ID change
        if let stored = storedBundleId, let current = currentBundleId, stored != current {
            let reason = "Bundle ID changed from '\(stored)' to '\(current)'"
            AppLogger.system.warning("\(reason, privacy: .public) - permissions may be invalid")
            return IdentityChangeResult(
                hasChanged: true,
                reason: reason,
                currentBundleId: currentBundleId,
                currentTeamId: currentTeamId,
                storedBundleId: storedBundleId,
                storedTeamId: storedTeamId
            )
        }

        // Check for team ID change (signing identity changed)
        if let stored = storedTeamId, let current = currentTeamId, stored != current {
            let reason = "Team ID changed from '\(stored)' to '\(current)'"
            AppLogger.system.warning("\(reason, privacy: .public) - permissions may be invalid")
            return IdentityChangeResult(
                hasChanged: true,
                reason: reason,
                currentBundleId: currentBundleId,
                currentTeamId: currentTeamId,
                storedBundleId: storedBundleId,
                storedTeamId: storedTeamId
            )
        }

        // Check if we had a team ID but now don't (or vice versa)
        if (storedTeamId != nil) != (currentTeamId != nil) {
            let reason = "Signing status changed (teamId: \(storedTeamId ?? "none") -> \(currentTeamId ?? "none"))"
            AppLogger.system.warning("\(reason, privacy: .public) - permissions may be invalid")
            return IdentityChangeResult(
                hasChanged: true,
                reason: reason,
                currentBundleId: currentBundleId,
                currentTeamId: currentTeamId,
                storedBundleId: storedBundleId,
                storedTeamId: storedTeamId
            )
        }

        AppLogger.system.debug("App identity unchanged - permissions should still be valid")
        return IdentityChangeResult(
            hasChanged: false,
            reason: nil,
            currentBundleId: currentBundleId,
            currentTeamId: currentTeamId,
            storedBundleId: storedBundleId,
            storedTeamId: storedTeamId
        )
    }

    /// Get current app identity for storing after permissions are granted
    static func getCurrentIdentity() -> (bundleId: String?, teamId: String?) {
        let validation = validateAppIdentity()
        return (validation.bundleId, validation.teamId)
    }

    // MARK: - Permission State Verification

    /// Verify that stored permission state matches actual macOS permission state
    /// This catches cases where:
    /// - User manually revoked permissions in System Settings
    /// - Identity change detection failed
    /// - Permissions were granted to a different app instance
    /// - Parameter settings: Current user settings containing stored permission state
    /// - Returns: Verification result with details about any mismatches
    func verifyPermissionStateConsistency(settings: UserSettings) async -> PermissionStateVerification {
        let storedPermissions = settings.onboarding.permissionsGranted

        // Check actual macOS permission state
        let actualMicrophone = await checkMicrophonePermission()
        let actualAccessibility = checkAccessibilityPermission()

        let verification = PermissionStateVerification(
            storedMicrophoneGranted: storedPermissions.microphone,
            actualMicrophoneGranted: actualMicrophone,
            storedAccessibilityGranted: storedPermissions.accessibility,
            actualAccessibilityGranted: actualAccessibility
        )

        if verification.hasMismatch {
            AppLogger.system.warning(
                "Permission state mismatch detected: \(verification.mismatchDescription ?? "unknown", privacy: .public)"
            )
        } else {
            AppLogger.system.debug("Permission state verification passed - stored state matches actual")
        }

        return verification
    }
}

/// Mock implementation for testing
@MainActor
class MockPermissionService: PermissionChecker {
    var microphoneGranted = true
    var accessibilityGranted = true

    /// Simulate permission being granted after a delay (for testing polling)
    var simulateMicrophoneGrantAfterDelay: TimeInterval?
    var simulateAccessibilityGrantAfterDelay: TimeInterval?

    /// Whether permission polling is currently active
    private(set) var isPolling: Bool = false

    /// Flag to signal polling should stop
    private var shouldStopPolling: Bool = false

    /// Stop any active permission polling
    func stopPolling() {
        shouldStopPolling = true
        isPolling = false
    }

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

    func pollForMicrophonePermission(
        interval: TimeInterval = 1.0,
        maxDuration: TimeInterval = 30.0,
        onGranted: @escaping @MainActor @Sendable () -> Void
    ) async {
        isPolling = true
        shouldStopPolling = false

        // If simulating a delayed grant, wait then grant and call callback
        if let delay = simulateMicrophoneGrantAfterDelay {
            let delayNanoseconds = UInt64(delay * 1_000_000_000)
            do {
                try await Task.sleep(nanoseconds: delayNanoseconds)
            } catch {
                isPolling = false
                return
            }
            if !shouldStopPolling {
                microphoneGranted = true
                isPolling = false
                onGranted()
            }
            return
        }

        // Otherwise poll like the real implementation
        let startTime = Date()
        let intervalNanoseconds = UInt64(interval * 1_000_000_000)

        while !shouldStopPolling {
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed >= maxDuration {
                break
            }

            if microphoneGranted {
                isPolling = false
                onGranted()
                return
            }

            do {
                try await Task.sleep(nanoseconds: intervalNanoseconds)
            } catch {
                break
            }
        }

        isPolling = false
    }

    func pollForAccessibilityPermission(
        interval: TimeInterval = 1.0,
        maxDuration: TimeInterval = 30.0,
        onGranted: @escaping @MainActor @Sendable () -> Void
    ) async {
        isPolling = true
        shouldStopPolling = false

        // If simulating a delayed grant, wait then grant and call callback
        if let delay = simulateAccessibilityGrantAfterDelay {
            let delayNanoseconds = UInt64(delay * 1_000_000_000)
            do {
                try await Task.sleep(nanoseconds: delayNanoseconds)
            } catch {
                isPolling = false
                return
            }
            if !shouldStopPolling {
                accessibilityGranted = true
                isPolling = false
                onGranted()
            }
            return
        }

        // Otherwise poll like the real implementation
        let startTime = Date()
        let intervalNanoseconds = UInt64(interval * 1_000_000_000)

        while !shouldStopPolling {
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed >= maxDuration {
                break
            }

            if accessibilityGranted {
                isPolling = false
                onGranted()
                return
            }

            do {
                try await Task.sleep(nanoseconds: intervalNanoseconds)
            } catch {
                break
            }
        }

        isPolling = false
    }

    /// Verify stored permission state matches actual macOS permission state
    func verifyPermissionStateConsistency(settings: UserSettings) async -> PermissionStateVerification {
        PermissionStateVerification(
            storedMicrophoneGranted: settings.onboarding.permissionsGranted.microphone,
            actualMicrophoneGranted: microphoneGranted,
            storedAccessibilityGranted: settings.onboarding.permissionsGranted.accessibility,
            actualAccessibilityGranted: accessibilityGranted
        )
    }
}
