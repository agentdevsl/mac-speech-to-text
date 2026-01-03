// OnboardingView.swift
// macOS Local Speech-to-Text Application
//
// User Story 2: First-Time Setup and Onboarding
// Task T035: OnboardingView - Multi-step onboarding flow
// (welcome, microphone, accessibility, demo, completion)

import SwiftUI

/// OnboardingView provides a multi-step onboarding experience
struct OnboardingView: View {
    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var viewModel = OnboardingViewModel()

    /// Task for permission checking loop (cancellable)
    @State private var permissionCheckTask: Task<Void, Never>?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            progressBar

            // Main content area with scroll support for overflow
            ScrollView {
                contentView
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Navigation buttons
            navigationButtons
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
        }
        .frame(width: 640, height: 560)
        .background(.ultraThinMaterial)
        .onAppear {
            // Cancel any existing task before creating a new one to prevent multiple loops
            permissionCheckTask?.cancel()
            // Start permission checking loop (includes Welcome step for status summary)
            permissionCheckTask = Task { @MainActor in
                while !Task.isCancelled {
                    // Check permissions on Welcome step (0) and permission steps (1-3)
                    if viewModel.currentStep >= 0 && viewModel.currentStep <= 3 {
                        await viewModel.checkAllPermissions()
                    }
                    // Sleep for 1 second before the next check
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    guard !Task.isCancelled else { break }
                }
            }
        }
        .onDisappear {
            // Cancel the permission checking task when view disappears
            permissionCheckTask?.cancel()
            permissionCheckTask = nil
        }
        .alert(
            "Skip This Step?",
            isPresented: $viewModel.showSkipWarning,
            presenting: viewModel.skipWarningMessage
        ) { _ in
            Button("Cancel", role: .cancel, action: viewModel.cancelSkip)
            Button("Skip Anyway", role: .destructive, action: viewModel.confirmSkip)
        } message: { message in
            Text(message)
        }
    }

    // MARK: - Subviews

    /// Progress bar showing current step
    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))

                Rectangle()
                    .fill(Color("AmberPrimary", bundle: nil))
                    .frame(width: geometry.size.width * progressPercentage)
            }
        }
        .frame(height: 4)
    }

    /// Main content area with step-specific views
    @ViewBuilder
    private var contentView: some View {
        switch viewModel.currentStep {
        case 0:
            welcomeStep
        case 1:
            microphoneStepView(viewModel: viewModel, permissionWarning: permissionWarning)
        case 2:
            accessibilityStepView(viewModel: viewModel)
        case 3:
            inputMonitoringStepView(viewModel: viewModel)
        case 4:
            demoStepView
        default:
            completionStepView
        }
    }

    /// Navigation buttons at bottom
    private var navigationButtons: some View {
        HStack {
            // Back button
            if viewModel.currentStep > 0 && viewModel.currentStep < 5 {
                Button("Back") {
                    viewModel.previousStep()
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            // Skip button
            if viewModel.canSkipCurrentStep {
                Button("Skip") {
                    viewModel.skipStep()
                }
                .buttonStyle(.bordered)
            }

            // Next/Done button
            Button(nextButtonTitle) {
                if viewModel.currentStep == 5 || viewModel.isComplete {
                    viewModel.completeOnboarding()
                    dismiss()
                } else {
                    viewModel.nextStep()
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return)
        }
    }

    // MARK: - Step Views

    /// Step 0: Welcome
    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color("AmberPrimary", bundle: nil))
                .symbolEffect(.pulse)

            Text("Welcome to Speech-to-Text")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("A privacy-first dictation app that runs 100% locally on your Mac. No cloud, no tracking, no data collection.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "lock.shield.fill", text: "100% local processing")
                FeatureRow(icon: "cpu.fill", text: "Apple Neural Engine powered")
                FeatureRow(icon: "globe", text: "25 languages supported")
                FeatureRow(icon: "bolt.fill", text: "<100ms transcription latency")
            }
            .padding(.top)

            // Permission status summary
            permissionStatusSummary
        }
    }

    /// Permission status summary showing granted/missing permissions
    private var permissionStatusSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Permission Status")
                .font(.headline)

            HStack(spacing: 16) {
                PermissionStatusBadge(
                    icon: "mic.fill",
                    label: "Microphone",
                    isGranted: viewModel.microphoneGranted
                )
                PermissionStatusBadge(
                    icon: "hand.point.up.left.fill",
                    label: "Accessibility",
                    isGranted: viewModel.accessibilityGranted
                )
                PermissionStatusBadge(
                    icon: "keyboard.fill",
                    label: "Input",
                    isGranted: viewModel.inputMonitoringGranted
                )
            }

            if viewModel.allPermissionsGranted {
                Label("All permissions granted!", systemImage: "checkmark.seal.fill")
                    .font(.callout)
                    .foregroundStyle(.green)
            } else {
                Text("We'll guide you through granting the required permissions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Computed Properties
    // Note: Step views (microphoneStepView, accessibilityStepView, etc.)
    // are defined in OnboardingStepViews.swift as an extension

    /// Progress percentage (0.0 - 1.0)
    private var progressPercentage: Double {
        return Double(viewModel.currentStep) / 5.0
    }

    /// Next button title
    private var nextButtonTitle: String {
        if viewModel.currentStep == 5 || viewModel.isComplete {
            return "Get Started"
        } else {
            return "Next"
        }
    }

    /// Permission warning message
    private var permissionWarning: String? {
        guard viewModel.currentStep > 0 && viewModel.currentStep <= 3 else {
            return nil
        }

        switch viewModel.currentStep {
        case 1:
            return viewModel.microphoneGranted ? nil : "Microphone access is required for recording"
        case 2:
            return viewModel.accessibilityGranted ? nil : "Accessibility access is required for text insertion"
        case 3:
            return viewModel.inputMonitoringGranted ? nil : "Input monitoring is required for the global hotkey"
        default:
            return nil
        }
    }
}

// MARK: - Previews
// Note: Helper views (FeatureRow, StepInstruction, etc.) are in OnboardingComponents.swift

#Preview("Welcome Step") {
    OnboardingView()
}

#Preview("Permissions Step") {
    OnboardingViewPreview(step: 1)
}

#Preview("Demo Step") {
    OnboardingViewPreview(step: 4)
}

#Preview("Completion Step") {
    OnboardingViewPreview(step: 5)
}

private struct OnboardingViewPreview: View {
    let step: Int

    var body: some View {
        OnboardingView()
    }
}
