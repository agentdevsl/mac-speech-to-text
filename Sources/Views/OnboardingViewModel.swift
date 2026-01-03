// OnboardingViewModel.swift
// macOS Local Speech-to-Text Application
//
// User Story 2: First-Time Setup and Onboarding
// Task T034: OnboardingViewModel - @Observable class managing onboarding state
// and permission flow

import AppKit
import AVFoundation
import Foundation
import Observation
import OSLog

/// OnboardingViewModel manages the onboarding flow and permission state
@Observable
@MainActor
final class OnboardingViewModel {
    // MARK: - Published State

    /// Current onboarding step (0-5)
    var currentStep: Int = 0

    /// Permission status
    var microphoneGranted: Bool = false
    var accessibilityGranted: Bool = false
    var inputMonitoringGranted: Bool = false

    /// Whether onboarding is complete
    var isComplete: Bool = false

    /// List of skipped steps
    var skippedSteps: Set<Int> = []

    /// Whether showing skip warning
    var showSkipWarning: Bool = false

    /// Current skip warning message
    var skipWarningMessage: String = ""

    // MARK: - Dependencies

    private let permissionService: PermissionService
    private let settingsService: SettingsService

    // MARK: - Constants

    private let totalSteps: Int = 5

    // MARK: - Initialization

    init(
        permissionService: PermissionService = PermissionService(),
        settingsService: SettingsService = SettingsService()
    ) {
        self.permissionService = permissionService
        self.settingsService = settingsService

        // Check initial permission status
        Task {
            await checkAllPermissions()
        }
    }

    // MARK: - Public Methods

    /// Move to next step
    func nextStep() {
        guard currentStep < totalSteps else {
            completeOnboarding()
            return
        }

        currentStep += 1

        // Auto-skip already-granted permissions
        if currentStep == 1 && microphoneGranted {
            nextStep()
        } else if currentStep == 2 && accessibilityGranted {
            nextStep()
        } else if currentStep == 3 && inputMonitoringGranted {
            nextStep()
        }
    }

    /// Move to previous step
    func previousStep() {
        guard currentStep > 0 else { return }
        currentStep -= 1
    }

    /// Skip current step with warning
    func skipStep() {
        let stepName = stepTitle(for: currentStep)
        skipWarningMessage = "Skipping \"\(stepName)\" will limit functionality. Continue?"
        showSkipWarning = true
    }

    /// Confirm skip and move to next step
    func confirmSkip() {
        skippedSteps.insert(currentStep)
        showSkipWarning = false
        nextStep()
    }

    /// Cancel skip warning
    func cancelSkip() {
        showSkipWarning = false
        skipWarningMessage = ""
    }

    /// Request microphone permission
    func requestMicrophonePermission() async {
        do {
            try await permissionService.requestMicrophonePermission()
            microphoneGranted = await permissionService.checkMicrophonePermission()

            if microphoneGranted {
                nextStep()
            }
        } catch {
            AppLogger.viewModel.error("Microphone permission error: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Request accessibility permission
    func requestAccessibilityPermission() async {
        do {
            try permissionService.requestAccessibilityPermission()
            accessibilityGranted = permissionService.checkAccessibilityPermission()

            // Note: Accessibility requires manual grant in System Settings
            // Open System Settings for user
            if !accessibilityGranted {
                openSystemSettings(for: "accessibility")
            }
        } catch {
            AppLogger.viewModel.error("Accessibility permission error: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Request input monitoring permission (not implemented yet)
    func requestInputMonitoringPermission() async {
        // Input monitoring permission is checked when registering hotkeys
        inputMonitoringGranted = permissionService.checkInputMonitoringPermission()

        // Note: Input monitoring requires manual grant in System Settings
        if !inputMonitoringGranted {
            openSystemSettings(for: "input-monitoring")
        }
    }

    /// Check all permissions status
    func checkAllPermissions() async {
        microphoneGranted = await permissionService.checkMicrophonePermission()
        accessibilityGranted = permissionService.checkAccessibilityPermission()
        inputMonitoringGranted = permissionService.checkInputMonitoringPermission()
    }

    /// Complete onboarding
    func completeOnboarding() {
        isComplete = true

        // Save onboarding state
        var settings = settingsService.load()
        settings.onboarding.completed = true
        settings.onboarding.currentStep = currentStep
        settings.onboarding.skippedSteps = Array(skippedSteps).map { String($0) }
        settings.onboarding.permissionsGranted.microphone = microphoneGranted
        settings.onboarding.permissionsGranted.accessibility = accessibilityGranted
        settings.onboarding.permissionsGranted.inputMonitoring = inputMonitoringGranted

        do {
            try settingsService.save(settings)
        } catch {
            AppLogger.viewModel.error("Failed to save onboarding settings: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Open System Settings for specific permission
    func openSystemSettings(for permission: String) {
        let url: URL
        switch permission {
        case "microphone":
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        case "accessibility":
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        case "input-monitoring":
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
        default:
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security")!
        }

        NSWorkspace.shared.open(url)
    }

    // MARK: - Helper Methods

    /// Get title for step
    func stepTitle(for step: Int) -> String {
        switch step {
        case 0: return "Welcome"
        case 1: return "Microphone Access"
        case 2: return "Accessibility Access"
        case 3: return "Input Monitoring"
        case 4: return "Try It Now"
        case 5: return "All Set!"
        default: return ""
        }
    }

    /// Get subtitle for step
    func stepSubtitle(for step: Int) -> String {
        switch step {
        case 0: return "Privacy-first speech-to-text"
        case 1: return "Required for voice capture"
        case 2: return "Required for text insertion"
        case 3: return "Required for global hotkey"
        case 4: return "Test your setup"
        case 5: return "Ready to use"
        default: return ""
        }
    }

    /// Check if current step can be skipped
    var canSkipCurrentStep: Bool {
        // Cannot skip welcome and completion screens
        guard currentStep > 0 && currentStep < totalSteps else {
            return false
        }

        // Can skip permission steps
        return currentStep >= 1 && currentStep <= 3
    }

    /// Check if all required permissions are granted
    var allPermissionsGranted: Bool {
        return microphoneGranted && accessibilityGranted && inputMonitoringGranted
    }

    /// Get warning message for missing permissions
    var missingPermissionsWarning: String? {
        var missing: [String] = []

        if !microphoneGranted { missing.append("Microphone") }
        if !accessibilityGranted { missing.append("Accessibility") }
        if !inputMonitoringGranted { missing.append("Input Monitoring") }

        guard !missing.isEmpty else { return nil }

        return "Missing permissions: \(missing.joined(separator: ", ")). Some features may not work."
    }
}
