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

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            progressBar

            // Main content area
            contentView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(40)

            // Navigation buttons
            navigationButtons
                .padding(20)
        }
        .frame(width: 600, height: 500)
        .background(.ultraThinMaterial)
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
            microphoneStep
        case 2:
            accessibilityStep
        case 3:
            inputMonitoringStep
        case 4:
            demoStep
        default:
            completionStep
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
        }
    }

    /// Step 1: Microphone permission
    private var microphoneStep: some View {
        VStack(spacing: 24) {
            stepHeader(
                icon: "mic.fill",
                title: "Microphone Access",
                subtitle: "Required to capture your voice"
            )

            PermissionCard.microphone(isGranted: viewModel.microphoneGranted) {
                await viewModel.requestMicrophonePermission()
            }

            if let error = viewModel.permissionError {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if let warning = permissionWarning {
                Text(warning)
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .padding(.top)
            }
        }
    }

    /// Step 2: Accessibility permission
    private var accessibilityStep: some View {
        VStack(spacing: 24) {
            stepHeader(
                icon: "hand.point.up.left.fill",
                title: "Accessibility Access",
                subtitle: "Required to insert text into apps"
            )

            PermissionCard.accessibility(isGranted: viewModel.accessibilityGranted) {
                await viewModel.requestAccessibilityPermission()
            }

            if let error = viewModel.permissionError {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if !viewModel.accessibilityGranted {
                VStack(alignment: .leading, spacing: 12) {
                    Text("How to grant accessibility access:")
                        .font(.headline)

                    StepInstruction(number: 1, text: "Click \"Open System Settings\" above")
                    StepInstruction(number: 2, text: "Find \"SpeechToText\" in the list")
                    StepInstruction(number: 3, text: "Toggle the switch to enable access")
                    StepInstruction(number: 4, text: "Return here and click \"Next\"")
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    /// Step 3: Input monitoring permission
    private var inputMonitoringStep: some View {
        VStack(spacing: 24) {
            stepHeader(
                icon: "keyboard.fill",
                title: "Input Monitoring",
                subtitle: "Required for global hotkey (⌘⌃Space)"
            )

            PermissionCard.inputMonitoring(isGranted: viewModel.inputMonitoringGranted) {
                await viewModel.requestInputMonitoringPermission()
            }

            if !viewModel.inputMonitoringGranted {
                VStack(alignment: .leading, spacing: 12) {
                    Text("How to grant input monitoring:")
                        .font(.headline)

                    StepInstruction(number: 1, text: "Click \"Open System Settings\" above")
                    StepInstruction(number: 2, text: "Find \"SpeechToText\" in the list")
                    StepInstruction(number: 3, text: "Toggle the switch to enable access")
                    StepInstruction(number: 4, text: "Return here and click \"Next\"")
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    /// Step 4: Demo/Try it now
    private var demoStep: some View {
        VStack(spacing: 24) {
            stepHeader(
                icon: "star.fill",
                title: "Try It Now!",
                subtitle: "Test your setup with a quick demo"
            )

            Text("Press the global hotkey to start recording:")
                .font(.title3)

            HStack(spacing: 8) {
                KeyCapView(symbol: "⌘")
                Text("+")
                KeyCapView(symbol: "⌃")
                Text("+")
                KeyCapView(text: "Space")
            }
            .font(.title2)

            VStack(alignment: .leading, spacing: 12) {
                DemoInstruction(number: 1, text: "Press ⌘⌃Space anywhere in macOS")
                DemoInstruction(number: 2, text: "Speak naturally when the modal appears")
                DemoInstruction(number: 3, text: "Recording stops automatically after 1.5s of silence")
                DemoInstruction(number: 4, text: "Your text will be inserted at the cursor")
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text("Try it in any text field, like TextEdit or Notes!")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    /// Step 5: Completion
    private var completionStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
                .symbolEffect(.bounce)

            Text("You're All Set!")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Your speech-to-text app is ready to use. Press ⌘⌃Space anytime to start dictating.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                QuickTip(icon: "mic.fill", text: "Hotkey: ⌘⌃Space")
                QuickTip(icon: "gear", text: "Settings: Click menu bar icon")
                QuickTip(icon: "chart.bar.fill", text: "Stats: View your usage in menu bar")
            }
            .padding(.top)
        }
    }

    /// Step header with icon, title, and subtitle
    private func stepHeader(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(Color("AmberPrimary", bundle: nil))

            Text(title)
                .font(.title)
                .fontWeight(.bold)

            Text(subtitle)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Computed Properties

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

// MARK: - Helper Views

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color("AmberPrimary", bundle: nil))
            Text(text)
        }
    }
}

private struct StepInstruction: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .fontWeight(.semibold)
            Text(text)
        }
        .font(.callout)
    }
}

private struct DemoInstruction: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .fontWeight(.semibold)
                .foregroundStyle(.green)
            Text(text)
        }
    }
}

private struct KeyCapView: View {
    var symbol: String?
    var text: String?

    var body: some View {
        Text(symbol ?? text ?? "")
            .font(.title2)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

private struct QuickTip: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
            Text(text)
        }
    }
}

// MARK: - Previews

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
