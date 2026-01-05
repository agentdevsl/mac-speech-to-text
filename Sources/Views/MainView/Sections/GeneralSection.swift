// GeneralSection.swift
// macOS Local Speech-to-Text Application
//
// Main View - General Settings Section
// Recording mode, startup, text insertion, and hotkey configuration

import KeyboardShortcuts
import ServiceManagement
import SwiftUI

/// GeneralSection provides configuration for recording behavior and general app settings
struct GeneralSection: View {
    // MARK: - Environment

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Dependencies

    let settingsService: SettingsService

    // MARK: - State

    @State private var settings: UserSettings
    @State private var saveError: String?
    @State private var errorDismissalTask: Task<Void, Never>?

    // MARK: - Initialization

    init(settingsService: SettingsService) {
        self.settingsService = settingsService
        let loadedSettings = settingsService.load()
        AppLogger.system.info(
            """
            GeneralSection init: Loaded settings - \
            launchAtLogin=\(loadedSettings.general.launchAtLogin), \
            autoInsertText=\(loadedSettings.general.autoInsertText), \
            copyToClipboard=\(loadedSettings.general.copyToClipboard)
            """
        )
        self._settings = State(initialValue: loadedSettings)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Error banner
                if let error = saveError {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.white)
                        Text(error)
                            .font(.callout)
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.red.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .accessibilityIdentifier("saveErrorBanner")
                }

                // Section header
                sectionHeader

                // Recording mode picker
                recordingModeSection

                Divider()
                    .padding(.vertical, 4)

                // Startup and behavior toggles
                behaviorSection

            }
            .padding(24)
            .animation(.easeInOut(duration: 0.3), value: saveError)
        }
        .accessibilityIdentifier("generalSection")
        .onAppear {
            // Reload settings when view appears to ensure fresh state
            let loadedSettings = settingsService.load()
            AppLogger.system.info(
                """
                GeneralSection onAppear: Reloading settings - \
                launchAtLogin=\(loadedSettings.general.launchAtLogin), \
                autoInsertText=\(loadedSettings.general.autoInsertText), \
                copyToClipboard=\(loadedSettings.general.copyToClipboard)
                """
            )
            settings = loadedSettings
        }
        .onDisappear {
            // Cancel any pending error dismissal task
            errorDismissalTask?.cancel()
            errorDismissalTask = nil
        }
    }

    // MARK: - Section Header

    private var sectionHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("General")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)

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
                .accessibilityAddTraits(.isHeader)

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
                .accessibilityAddTraits(.isHeader)

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
                            updateLaunchAtLogin(enabled: newValue)
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

                // Paste behavior
                PasteBehaviorRow(
                    selectedBehavior: Binding(
                        get: { settings.general.pasteBehavior },
                        set: { newValue in
                            settings.general.pasteBehavior = newValue
                            saveSettings()
                        }
                    )
                )
                .accessibilityIdentifier("pasteBehaviorPicker")
            }
        }
        .accessibilityIdentifier("behaviorSection")
    }

    // MARK: - Private Methods

    private func selectRecordingMode(_ mode: RecordingMode) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            settings.ui.recordingMode = mode
        }
        saveSettings()
    }

    private func saveSettings() {
        saveError = nil
        do {
            AppLogger.system.info(
                """
                GeneralSection: Saving settings - \
                launchAtLogin=\(settings.general.launchAtLogin), \
                autoInsertText=\(settings.general.autoInsertText), \
                copyToClipboard=\(settings.general.copyToClipboard)
                """
            )
            try settingsService.save(settings)
            AppLogger.system.info("GeneralSection: Settings saved successfully")
        } catch {
            AppLogger.service.error("Failed to save settings: \(error.localizedDescription)")
            showError("Failed to save settings. Please try again.")
        }
    }

    private func showError(_ message: String) {
        saveError = message
        // Cancel any previous dismissal task to avoid race condition
        errorDismissalTask?.cancel()
        errorDismissalTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled {
                saveError = nil
            }
        }
    }

    private func updateLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
                AppLogger.system.info("Registered app for launch at login")
            } else {
                try SMAppService.mainApp.unregister()
                AppLogger.system.info("Unregistered app from launch at login")
            }
        } catch {
            AppLogger.service.error("Failed to update launch at login: \(error.localizedDescription)")
            // Revert the setting since the system call failed
            settings.general.launchAtLogin = !enabled
            showError("Failed to update launch at login setting.")
        }
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
                // Icon (decorative, hidden from accessibility)
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? Color.iconPrimaryAdaptive : Color.textTertiaryAdaptive)
                    .frame(width: 40)
                    .accessibilityHidden(true)

                // Text content - use explicit colors for white card background
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    Text(description)
                        .font(.caption)
                        .foregroundStyle(Color.textTertiaryAdaptive)
                        .lineLimit(2)
                }

                Spacer()

                // Selection indicator (visual only, state communicated at button level)
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.iconPrimaryAdaptive : Color.cardBorderAdaptive, lineWidth: 2)
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(Color.iconPrimaryAdaptive)
                            .frame(width: 14, height: 14)
                    }
                }
                .accessibilityHidden(true)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.cardBackgroundAdaptive)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color.iconPrimaryAdaptive : Color.cardBorderAdaptive,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(description)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
        .accessibilityHint("Double-tap to select this recording mode")
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
                    .foregroundStyle(Color.iconPrimaryAdaptive)
                    .frame(width: 24)
                    .accessibilityHidden(true)  // Decorative icon

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.textTertiaryAdaptive)
                }
            }
        }
        .toggleStyle(BlueToggleStyle())
        .padding(.vertical, 4)
        .accessibilityLabel("\(title). \(subtitle)")
    }
}

// MARK: - Paste Behavior Row

/// Row for selecting paste behavior (paste only or paste and enter)
private struct PasteBehaviorRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedBehavior: PasteBehavior

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "return")
                .font(.system(size: 16))
                .foregroundStyle(Color.iconPrimaryAdaptive)
                .frame(width: 24)
                .accessibilityHidden(true)  // Decorative icon

            VStack(alignment: .leading, spacing: 2) {
                Text("After Paste")
                    .font(.body)
                    .foregroundStyle(.primary)

                Text("What to do after inserting text")
                    .font(.caption)
                    .foregroundStyle(Color.textTertiaryAdaptive)
            }

            Spacer()

            Picker("After Paste Behavior", selection: $selectedBehavior) {
                ForEach(PasteBehavior.allCases, id: \.self) { behavior in
                    Text(behavior.displayName).tag(behavior)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 140)
            .labelsHidden()  // Hide visual label since we have custom layout
            .accessibilityLabel("After paste behavior")
            .accessibilityHint("Choose what happens after text is inserted")
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Blue Toggle Style

/// Custom toggle style that shows blue when ON in both light and dark modes
private struct BlueToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            RoundedRectangle(cornerRadius: 11)
                .fill(configuration.isOn ? Color.blue : Color(white: 0.45))  // Better contrast
                .frame(width: 38, height: 22)
                .overlay(
                    Circle()
                        .fill(Color.white)
                        .shadow(radius: 1)
                        .padding(2)
                        .offset(x: configuration.isOn ? 8 : -8)
                        .animation(.easeInOut(duration: 0.15), value: configuration.isOn)
                )
        }
        .contentShape(Rectangle())  // Make entire row tappable
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
                configuration.isOn.toggle()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
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
