// PermissionCard.swift
// macOS Local Speech-to-Text Application
//
// User Story 2: First-Time Setup and Onboarding
// Task T033: PermissionCard - Reusable component for permission request UI
// with icon, title, description, and grant button

import SwiftUI

/// PermissionCard displays a permission request with icon, description, and action button
struct PermissionCard: View {
    // MARK: - Properties

    let icon: String
    let title: String
    let description: String
    let buttonTitle: String
    let isGranted: Bool
    let action: () async -> Void

    @State private var isProcessing: Bool = false

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with icon and title
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundStyle(isGranted ? .green : Color("AmberPrimary", bundle: nil))
                    .symbolEffect(.bounce, value: isGranted)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)

                    if isGranted {
                        Label("Granted", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                Spacer()
            }

            // Description
            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Action button
            if !isGranted {
                Button {
                    Task {
                        isProcessing = true
                        defer { isProcessing = false } // Ensure reset even if action throws
                        await action()
                    }
                } label: {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(buttonTitle)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isProcessing)
            }
        }
        .padding(20)
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isGranted ? Color.green : Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Convenience Initializers

extension PermissionCard {
    /// Create microphone permission card
    static func microphone(isGranted: Bool, action: @escaping () async -> Void) -> PermissionCard {
        PermissionCard(
            icon: "mic.fill",
            title: "Microphone Access",
            description: "Required to capture your voice for transcription. All processing happens locally on your device.",
            buttonTitle: "Grant Microphone Access",
            isGranted: isGranted,
            action: action
        )
    }

    /// Create accessibility permission card
    static func accessibility(isGranted: Bool, action: @escaping () async -> Void) -> PermissionCard {
        PermissionCard(
            icon: "hand.point.up.left.fill",
            title: "Accessibility Access",
            description: "Required to insert transcribed text into other applications. This allows the app to type for you.",
            buttonTitle: "Open System Settings",
            isGranted: isGranted,
            action: action
        )
    }

    /// Create input monitoring permission card
    static func inputMonitoring(isGranted: Bool, action: @escaping () async -> Void) -> PermissionCard {
        PermissionCard(
            icon: "keyboard.fill",
            title: "Input Monitoring",
            description: "Required to detect the global hotkey (⌘⌃Space). Allows the app to respond when you trigger dictation.",
            buttonTitle: "Open System Settings",
            isGranted: isGranted,
            action: action
        )
    }
}

// MARK: - Previews

#Preview("Not Granted") {
    PermissionCard.microphone(isGranted: false) {
        try? await Task.sleep(nanoseconds: 1_000_000_000)
    }
    .padding()
}

#Preview("Granted") {
    PermissionCard.microphone(isGranted: true) {
        // No-op
    }
    .padding()
}

#Preview("Accessibility") {
    PermissionCard.accessibility(isGranted: false) {
        // No-op
    }
    .padding()
}

#Preview("Input Monitoring") {
    PermissionCard.inputMonitoring(isGranted: false) {
        // No-op
    }
    .padding()
}

#Preview("All Permissions") {
    VStack(spacing: 16) {
        PermissionCard.microphone(isGranted: false) {}
        PermissionCard.accessibility(isGranted: true) {}
        PermissionCard.inputMonitoring(isGranted: false) {}
    }
    .padding()
}
