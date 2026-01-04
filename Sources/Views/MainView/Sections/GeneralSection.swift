// GeneralSection.swift
// macOS Local Speech-to-Text Application
//
// Main View - General Settings Section
// Recording mode, startup, text insertion, and hotkey configuration

import SwiftUI

/// GeneralSection provides configuration for recording behavior and general app settings
struct GeneralSection: View {
    // MARK: - Dependencies

    let settingsService: SettingsService

    // MARK: - State

    @State private var settings: UserSettings
    @State private var isSaving: Bool = false

    // MARK: - Initialization

    init(settingsService: SettingsService) {
        self.settingsService = settingsService
        self._settings = State(initialValue: settingsService.load())
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Section header
                sectionHeader

                // Recording mode picker
                recordingModeSection

                Divider()
                    .padding(.vertical, 4)

                // Startup and behavior toggles
                behaviorSection

                Divider()
                    .padding(.vertical, 4)

                // Hotkey display
                hotkeySection
            }
            .padding(24)
        }
        .accessibilityIdentifier("generalSection")
    }

    // MARK: - Section Header

    private var sectionHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("General")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            Text("Recording behavior and startup options")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityIdentifier("generalSectionHeader")
    }

    // MARK: - Recording Mode Section

    private var recordingModeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recording Mode")
                .font(.headline)
                .foregroundStyle(.primary)

            // Mode picker cards
            VStack(spacing: 12) {
                RecordingModeCard(
                    mode: .holdToRecord,
                    title: "Hold to Record",
                    description: "Hold the hotkey while speaking, release to transcribe",
                    icon: "hand.tap.fill",
                    isSelected: settings.ui.recordingMode == .holdToRecord,
                    onSelect: { selectRecordingMode(.holdToRecord) }
                )
                .accessibilityIdentifier("holdToRecordCard")

                RecordingModeCard(
                    mode: .toggle,
                    title: "Toggle",
                    description: "Press once to start, press again to stop and transcribe",
                    icon: "arrow.triangle.2.circlepath",
                    isSelected: settings.ui.recordingMode == .toggle,
                    onSelect: { selectRecordingMode(.toggle) }
                )
                .accessibilityIdentifier("toggleModeCard")
            }
        }
        .accessibilityIdentifier("recordingModeSection")
    }

    // MARK: - Behavior Section

    private var behaviorSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Behavior")
                .font(.headline)
                .foregroundStyle(.primary)

            VStack(spacing: 12) {
                // Launch at login
                GeneralToggleRow(
                    icon: "power",
                    title: "Launch at Login",
                    subtitle: "Start automatically when you log in",
                    isOn: Binding(
                        get: { settings.general.launchAtLogin },
                        set: { newValue in
                            settings.general.launchAtLogin = newValue
                            saveSettings()
                        }
                    )
                )
                .accessibilityIdentifier("launchAtLoginToggle")

                // Auto-insert text
                GeneralToggleRow(
                    icon: "text.cursor",
                    title: "Auto-insert Text",
                    subtitle: "Automatically insert transcribed text at cursor",
                    isOn: Binding(
                        get: { settings.general.autoInsertText },
                        set: { newValue in
                            settings.general.autoInsertText = newValue
                            saveSettings()
                        }
                    )
                )
                .accessibilityIdentifier("autoInsertToggle")

                // Copy to clipboard
                GeneralToggleRow(
                    icon: "doc.on.clipboard",
                    title: "Copy to Clipboard",
                    subtitle: "Always copy transcribed text to clipboard",
                    isOn: Binding(
                        get: { settings.general.copyToClipboard },
                        set: { newValue in
                            settings.general.copyToClipboard = newValue
                            saveSettings()
                        }
                    )
                )
                .accessibilityIdentifier("copyToClipboardToggle")
            }
        }
        .accessibilityIdentifier("behaviorSection")
    }

    // MARK: - Hotkey Section

    private var hotkeySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Hotkey")
                .font(.headline)
                .foregroundStyle(.primary)

            HStack {
                // Current hotkey display
                HStack(spacing: 4) {
                    ForEach(settings.hotkey.modifiers, id: \.self) { modifier in
                        KeyBadge(text: modifier.displayName)
                    }
                    KeyBadge(text: hotkeyKeyName)
                }

                Spacer()

                // Change button (placeholder - would open hotkey recorder)
                Button("Change") {
                    // Would open hotkey recorder modal
                    AppLogger.system.info("Hotkey change requested")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityIdentifier("changeHotkeyButton")
            }
            .padding(16)
            .background(Color.warmGray.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Hotkey hint
            Text("Use a unique key combination to avoid conflicts with other apps")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .accessibilityIdentifier("hotkeySection")
    }

    // MARK: - Computed Properties

    private var hotkeyKeyName: String {
        switch settings.hotkey.keyCode {
        case 49: return "Space"
        case 36: return "Return"
        case 53: return "Escape"
        case 51: return "Delete"
        default: return "Key \(settings.hotkey.keyCode)"
        }
    }

    // MARK: - Private Methods

    private func selectRecordingMode(_ mode: RecordingMode) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            settings.ui.recordingMode = mode
        }
        saveSettings()
    }

    private func saveSettings() {
        isSaving = true
        do {
            try settingsService.save(settings)
        } catch {
            AppLogger.service.error("Failed to save settings: \(error.localizedDescription)")
        }
        isSaving = false
    }
}

// MARK: - Recording Mode Card

/// Selectable card for recording mode options
private struct RecordingModeCard: View {
    let mode: RecordingMode
    let title: String
    let description: String
    let icon: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? Color.warmAmber : Color.warmGrayDark)
                    .frame(width: 40)

                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.warmAmber : Color.warmGrayMedium, lineWidth: 2)
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(Color.warmAmber)
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color.warmAmber : Color.warmGrayMedium.opacity(0.5),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - General Toggle Row

/// Styled toggle row for general settings
private struct GeneralToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.warmAmber)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .toggleStyle(.switch)
        .tint(Color.warmAmber)
        .padding(.vertical, 4)
    }
}

// MARK: - Key Badge

/// Styled badge for displaying keyboard keys
private struct KeyBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(.caption, design: .rounded, weight: .semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.warmGray)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.warmGrayMedium, lineWidth: 1)
            )
    }
}

// MARK: - Previews

#Preview("General Section") {
    GeneralSection(settingsService: SettingsService())
        .frame(width: 380, height: 700)
}

#Preview("General Section - Dark Mode") {
    GeneralSection(settingsService: SettingsService())
        .frame(width: 380, height: 700)
        .preferredColorScheme(.dark)
}
