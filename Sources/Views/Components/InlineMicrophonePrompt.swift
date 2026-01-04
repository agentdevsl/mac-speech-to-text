// InlineMicrophonePrompt.swift
// macOS Local Speech-to-Text Application
//
// Inline prompt shown when microphone permission is denied during recording flow
// Allows user to open System Settings or cancel the recording attempt

import SwiftUI

/// InlineMicrophonePrompt displays a blocking prompt when microphone access is denied.
/// User must either grant permission via System Settings or cancel the recording.
struct InlineMicrophonePrompt: View {
    // MARK: - Properties

    /// Called when user taps "Open Settings" to open System Settings > Privacy > Microphone
    var onOpenSettings: () -> Void

    /// Called when user taps "Cancel" to dismiss the prompt
    var onCancel: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {
            // Title
            Text("Microphone access required")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .accessibilityIdentifier("microphonePromptTitle")

            // Description
            Text("Please grant microphone access to record your voice")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("microphonePromptDescription")

            // Action buttons
            HStack(spacing: 12) {
                Button("Open Settings") {
                    onOpenSettings()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color("AmberPrimary", bundle: nil))
                .accessibilityIdentifier("microphonePromptOpenSettings")

                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("microphonePromptCancel")
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("inlineMicrophonePrompt")
    }
}

// MARK: - Previews

#Preview("Inline Microphone Prompt") {
    InlineMicrophonePrompt(
        onOpenSettings: { print("Open Settings tapped") },
        onCancel: { print("Cancel tapped") }
    )
    .padding()
    .frame(width: 400)
}

#Preview("Dark Mode") {
    InlineMicrophonePrompt(
        onOpenSettings: {},
        onCancel: {}
    )
    .padding()
    .frame(width: 400)
    .preferredColorScheme(.dark)
}

#Preview("In Context") {
    VStack(spacing: 20) {
        Text("Recording Modal Content...")
            .font(.body)
            .padding()
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))

        InlineMicrophonePrompt(
            onOpenSettings: {},
            onCancel: {}
        )
    }
    .padding()
    .frame(width: 400)
}
