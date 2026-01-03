// OnboardingComponents.swift
// macOS Local Speech-to-Text Application
//
// Helper views for the onboarding flow

import SwiftUI

// MARK: - Feature Row

/// Row displaying a feature with icon and text
struct FeatureRow: View {
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

// MARK: - Step Instruction

/// Numbered instruction step
struct StepInstruction: View {
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

// MARK: - Demo Instruction

/// Numbered demo instruction with green accent
struct DemoInstruction: View {
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

// MARK: - Key Cap View

/// Keyboard key cap visualization
struct KeyCapView: View {
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

// MARK: - Quick Tip

/// Quick tip row with icon and text
struct QuickTip: View {
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

// MARK: - Permission Status Badge

/// Badge showing permission granted/missing status
struct PermissionStatusBadge: View {
    let icon: String
    let label: String
    let isGranted: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isGranted ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(isGranted ? .green : .orange)
            }
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: isGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(isGranted ? .green : .orange)
                    .background(Circle().fill(.white).padding(-2))
            }

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Previews

#Preview("Feature Row") {
    VStack(alignment: .leading, spacing: 12) {
        FeatureRow(icon: "lock.shield.fill", text: "100% local processing")
        FeatureRow(icon: "cpu.fill", text: "Apple Neural Engine powered")
    }
    .padding()
}

#Preview("Permission Status Badge") {
    HStack(spacing: 16) {
        PermissionStatusBadge(icon: "mic.fill", label: "Microphone", isGranted: true)
        PermissionStatusBadge(icon: "hand.point.up.left.fill", label: "Accessibility", isGranted: false)
        PermissionStatusBadge(icon: "keyboard.fill", label: "Input", isGranted: true)
    }
    .padding()
}

#Preview("Key Caps") {
    HStack(spacing: 8) {
        KeyCapView(symbol: "⌘")
        Text("+")
        KeyCapView(symbol: "⌃")
        Text("+")
        KeyCapView(text: "Space")
    }
    .padding()
}
