// MenuBarSettingsSection.swift
// macOS Local Speech-to-Text Application
//
// Phase 3: UI Simplification
// Collapsible disclosure group component for menu bar settings sections

import SwiftUI

/// Collapsible settings section for menu bar
struct MenuBarSettingsSection<Content: View>: View {
    // MARK: - Properties

    let icon: String
    let title: String
    let subtitle: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(Color("AmberPrimary", bundle: nil))
                        .frame(width: 24, alignment: .center)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.callout)

                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title): \(subtitle)")
            .accessibilityHint(isExpanded ? "Double tap to collapse" : "Double tap to expand")

            // Expandable content
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    content()
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .padding(.leading, 36) // Align with text after icon
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(isExpanded ? Color.gray.opacity(0.05) : Color.clear)
    }
}

/// Simple toggle row for settings sections
struct SettingsToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    var help: String?

    var body: some View {
        Toggle(title, isOn: $isOn)
            .font(.callout)
            .toggleStyle(.switch)
            .controlSize(.small)
            .help(help ?? "")
    }
}

/// Slider row for settings sections
struct SettingsSliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: String
    var lowLabel: String = ""
    var highLabel: String = ""
    /// Multiplier for display value (e.g., 100 for percentage)
    var displayMultiplier: Double = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.callout)
                Spacer()
                Text(String(format: format, value * displayMultiplier))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            HStack(spacing: 8) {
                if !lowLabel.isEmpty {
                    Text(lowLabel)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Slider(value: $value, in: range, step: step)
                    .controlSize(.small)

                if !highLabel.isEmpty {
                    Text(highLabel)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}

/// Picker row for settings sections with enum selection
struct SettingsPickerRow<T: Hashable>: View {
    let title: String
    @Binding var selection: T
    let options: [T]
    let displayName: (T) -> String
    var help: String?

    var body: some View {
        HStack {
            Text(title)
                .font(.callout)
            Spacer()
            Picker("", selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(displayName(option))
                        .tag(option)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .controlSize(.small)
            .help(help ?? "")
        }
    }
}

// MARK: - Previews

#Preview("Collapsed Section") {
    MenuBarSettingsSection(
        icon: "mic.fill",
        title: "Recording",
        subtitle: "Start Recording ^C^Space",
        isExpanded: .constant(false)
    ) {
        Text("Content here")
    }
    .frame(width: 280)
}

#Preview("Expanded Section") {
    MenuBarSettingsSection(
        icon: "globe",
        title: "Language",
        subtitle: "English (GB)",
        isExpanded: .constant(true)
    ) {
        VStack(alignment: .leading, spacing: 8) {
            Text("English")
            Text("French")
            Text("German")
        }
    }
    .frame(width: 280)
}

#Preview("Toggle Row") {
    VStack(alignment: .leading, spacing: 12) {
        SettingsToggleRow(
            title: "Launch at login",
            isOn: .constant(true),
            help: "Start app when you log in"
        )
        SettingsToggleRow(
            title: "Auto-insert text",
            isOn: .constant(false)
        )
    }
    .padding()
    .frame(width: 250)
}

#Preview("Slider Row") {
    SettingsSliderRow(
        title: "Sensitivity",
        value: .constant(0.5),
        range: 0.1...1.0,
        step: 0.05,
        format: "%.2f",
        lowLabel: "Low",
        highLabel: "High"
    )
    .padding()
    .frame(width: 250)
}
