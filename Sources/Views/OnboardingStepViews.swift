// OnboardingStepViews.swift
// macOS Local Speech-to-Text Application
//
// Step views for the onboarding flow (extracted to reduce file size)

import SwiftUI

// MARK: - Onboarding Step Views Extension

extension OnboardingView {
    /// Step header with icon, title, and subtitle
    func stepHeader(icon: String, title: String, subtitle: String) -> some View {
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

    /// Step 1: Microphone permission
    func microphoneStepView(viewModel: OnboardingViewModel, permissionWarning: String?) -> some View {
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
    func accessibilityStepView(viewModel: OnboardingViewModel) -> some View {
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
    func inputMonitoringStepView(viewModel: OnboardingViewModel) -> some View {
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
    var demoStepView: some View {
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
                DemoInstruction(number: 3, text: "Recording stops after 1.5s of silence")
                DemoInstruction(number: 4, text: "Text will be inserted at the cursor")
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
    var completionStepView: some View {
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
}
