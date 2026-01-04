// PermissionStatusIndicator.swift
// macOS Local Speech-to-Text Application
//
// Phase 3: UI Simplification
// Small status badges showing permission status (green checkmark for granted, amber for needed)

import SwiftUI

/// Compact permission status badge for inline display
struct PermissionStatusIndicator: View {
    // MARK: - Properties

    let icon: String
    let isGranted: Bool
    let label: String

    // MARK: - Body

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)

            if isGranted {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
            }
        }
        .foregroundStyle(isGranted ? .green : Color("AmberPrimary", bundle: nil))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isGranted ? Color.green.opacity(0.15) : Color("AmberPrimary", bundle: nil).opacity(0.15))
        )
        .help(label + (isGranted ? " - Granted" : " - Required"))
        .accessibilityLabel("\(label): \(isGranted ? "granted" : "required")")
    }
}

/// Convenience factory methods
extension PermissionStatusIndicator {
    /// Microphone permission indicator
    static func microphone(isGranted: Bool) -> PermissionStatusIndicator {
        PermissionStatusIndicator(
            icon: "mic.fill",
            isGranted: isGranted,
            label: "Microphone"
        )
    }

    /// Accessibility permission indicator
    static func accessibility(isGranted: Bool) -> PermissionStatusIndicator {
        PermissionStatusIndicator(
            icon: "hand.point.up.left.fill",
            isGranted: isGranted,
            label: "Accessibility"
        )
    }
}

// MARK: - Previews

#Preview("Both Granted") {
    HStack(spacing: 8) {
        PermissionStatusIndicator.microphone(isGranted: true)
        PermissionStatusIndicator.accessibility(isGranted: true)
    }
    .padding()
}

#Preview("Microphone Needed") {
    HStack(spacing: 8) {
        PermissionStatusIndicator.microphone(isGranted: false)
        PermissionStatusIndicator.accessibility(isGranted: true)
    }
    .padding()
}

#Preview("Both Needed") {
    HStack(spacing: 8) {
        PermissionStatusIndicator.microphone(isGranted: false)
        PermissionStatusIndicator.accessibility(isGranted: false)
    }
    .padding()
}
