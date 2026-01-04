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

    /// Whether onboarding is complete
    var isComplete: Bool = false

    /// List of skipped steps
    var skippedSteps: Set<Int> = []

    /// Whether showing skip warning
    var showSkipWarning: Bool = false

    /// Current skip warning message
    var skipWarningMessage: String = ""

    /// Permission error message to display to user
    var permissionError: String?

    // MARK: - Dependencies

    private let permissionService: any PermissionChecker
    private let settingsService: any SettingsServiceProtocol

    // MARK: - Constants

    private let totalSteps: Int = 4

    // MARK: - Initialization

    init(
        permissionService: any PermissionChecker = PermissionService(),
        settingsService: any SettingsServiceProtocol = SettingsService()
    ) {
        self.permissionService = permissionService
        self.settingsService = settingsService

        // Check initial permission status
        Task { [weak self] in
            await self?.checkAllPermissions()
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

        // Auto-skip already-granted permissions using a loop to avoid stack overflow
        while currentStep < totalSteps {
            if currentStep == 1 && microphoneGranted {
                currentStep += 1
            } else if currentStep == 2 && accessibilityGranted {
                currentStep += 1
            } else {
                break
            }
        }

        // Check if we've reached the end after skipping
        if currentStep >= totalSteps {
            completeOnboarding()
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
        skipWarningMessage = ""
        nextStep()
    }

    /// Cancel skip warning
    func cancelSkip() {
        showSkipWarning = false
        skipWarningMessage = ""
    }

    /// Request microphone permission
    func requestMicrophonePermission() async {
        permissionError = nil
        do {
            try await permissionService.requestMicrophonePermission()
            microphoneGranted = await permissionService.checkMicrophonePermission()

            if microphoneGranted {
                nextStep()
            }
        } catch {
            AppLogger.viewModel.error("Microphone permission error: \(error.localizedDescription, privacy: .public)")
            permissionError = "Microphone access was denied. Please grant access in System Settings > Privacy & Security > Microphone to enable voice recording."
        }
    }

    /// Request accessibility permission
    func requestAccessibilityPermission() async {
        permissionError = nil
        do {
            try permissionService.requestAccessibilityPermission()
            accessibilityGranted = permissionService.checkAccessibilityPermission()

            // Auto-advance when permission is granted
            if accessibilityGranted {
                nextStep()
            } else {
                // Accessibility requires manual grant in System Settings
                openSystemSettings(for: "accessibility")
            }
        } catch {
            AppLogger.viewModel.error("Accessibility permission error: \(error.localizedDescription, privacy: .public)")
            permissionError = "Accessibility access is required to insert text into apps. Please enable it in System Settings > Privacy & Security > Accessibility, then return here."
        }
    }

    /// Check all permissions status
    func checkAllPermissions() async {
        microphoneGranted = await permissionService.checkMicrophonePermission()
        accessibilityGranted = permissionService.checkAccessibilityPermission()

        // Clear permission error if the relevant permission is now granted
        if permissionError != nil {
            if (currentStep == 1 && microphoneGranted) ||
               (currentStep == 2 && accessibilityGranted) {
                permissionError = nil
            }
        }
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

        do {
            try settingsService.save(settings)
        } catch {
            AppLogger.viewModel.error("Failed to save onboarding settings: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Open System Settings for specific permission
    func openSystemSettings(for permission: String) {
        let urlString: String
        switch permission {
        case "microphone":
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        case "accessibility":
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        default:
            urlString = "x-apple.systempreferences:com.apple.preference.security"
        }

        guard let url = URL(string: urlString) else {
            AppLogger.viewModel.error("Failed to create URL for system settings: \(urlString)")
            return
        }

        let opened = NSWorkspace.shared.open(url)
        if !opened {
            AppLogger.viewModel.error("Failed to open System Settings for \(permission, privacy: .public)")
        }
    }

    // MARK: - Helper Methods

    /// Get title for step
    /// Steps: 0=Welcome, 1=Microphone, 2=Accessibility, 3=Try It Now, 4=All Set
    func stepTitle(for step: Int) -> String {
        switch step {
        case 0: return "Welcome"
        case 1: return "Microphone Access"
        case 2: return "Accessibility Access"
        case 3: return "Try It Now"
        case 4: return "All Set!"
        default: return ""
        }
    }

    /// Get subtitle for step
    func stepSubtitle(for step: Int) -> String {
        switch step {
        case 0: return "Privacy-first speech-to-text"
        case 1: return "Required for voice capture"
        case 2: return "Required for text insertion and hotkeys"
        case 3: return "Test your setup"
        case 4: return "Ready to use"
        default: return ""
        }
    }

    /// Check if current step can be skipped
    var canSkipCurrentStep: Bool {
        // Cannot skip welcome and completion screens
        guard currentStep > 0 && currentStep < totalSteps else {
            return false
        }

        // Can skip permission steps (1 and 2)
        return currentStep >= 1 && currentStep <= 2
    }

    /// Check if all required permissions are granted
    var allPermissionsGranted: Bool {
        return microphoneGranted && accessibilityGranted
    }

    /// Get warning message for missing permissions
    var missingPermissionsWarning: String? {
        var missing: [String] = []

        if !microphoneGranted { missing.append("Microphone") }
        if !accessibilityGranted { missing.append("Accessibility") }

        guard !missing.isEmpty else { return nil }

        return "Missing permissions: \(missing.joined(separator: ", ")). Some features may not work."
    }
}
