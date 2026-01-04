// InlineAccessibilityPrompt.swift
// macOS Local Speech-to-Text Application
//
// Phase 2.3: Just-in-time accessibility permission prompt
// Appears in recording modal after first transcription if accessibility not granted
// Non-blocking - text is already copied to clipboard

import SwiftUI

/// InlineAccessibilityPrompt displays a non-blocking prompt for accessibility permission
/// after transcription completes. The text is already on clipboard, so this is optional.
struct InlineAccessibilityPrompt: View {
    // MARK: - Properties

    /// Called when user taps "Enable Auto-Paste" to open System Settings
    var onEnableAutoPaste: () -> Void

    /// Called when user taps "Use Clipboard Only" to dismiss and save preference
    var onUseClipboardOnly: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {
            // Header text
            Text("Auto-paste requires accessibility permission")
                .font(.subheadline)
                .foregroundStyle(.primary)

            // Action buttons
            HStack(spacing: 12) {
                Button("Enable Auto-Paste") {
                    onEnableAutoPaste()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color("AmberPrimary", bundle: nil))

                Button("Use Clipboard Only") {
                    onUseClipboardOnly()
                }
                .buttonStyle(.bordered)
            }

            // Confirmation text
            Text("Text is already copied to clipboard")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Previews

#Preview("Inline Accessibility Prompt") {
    InlineAccessibilityPrompt(
        onEnableAutoPaste: { print("Enable Auto-Paste tapped") },
        onUseClipboardOnly: { print("Use Clipboard Only tapped") }
    )
    .padding()
    .frame(width: 400)
}

#Preview("Dark Mode") {
    InlineAccessibilityPrompt(
        onEnableAutoPaste: {},
        onUseClipboardOnly: {}
    )
    .padding()
    .frame(width: 400)
    .preferredColorScheme(.dark)
}

#Preview("In Context") {
    VStack(spacing: 20) {
        Text("Your transcribed text appears here...")
            .font(.body)
            .padding()
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))

        InlineAccessibilityPrompt(
            onEnableAutoPaste: {},
            onUseClipboardOnly: {}
        )
    }
    .padding()
    .frame(width: 400)
}
