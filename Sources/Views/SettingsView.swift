// SettingsView.swift
// macOS Local Speech-to-Text Application
//
// DEPRECATED: Settings are now accessible from the menu bar dropdown.
// This separate settings window has been replaced by inline settings in MenuBarView.
// This file is kept for backwards compatibility but is not shown to users.
//
// User Story 4: Customizable Settings
// Task T052: SettingsView with tabs for General, Language, Audio, and Privacy settings

import SwiftUI

/// SettingsView provides comprehensive app configuration
/// @deprecated Use menu bar settings via MenuBarView instead
struct SettingsView: View {
    // MARK: - State

    @State private var viewModel = SettingsViewModel()
    @State private var selectedTab: SettingsTab = .general

    // MARK: - Tab Enum

    enum SettingsTab: String, CaseIterable {
        case general = "General"
        case language = "Language"
        case audio = "Audio"
        case privacy = "Privacy"

        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .language: return "globe"
            case .audio: return "waveform"
            case .privacy: return "lock.shield"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        HSplitView {
            // Sidebar with tabs
            sidebar

            // Content area
            VStack(alignment: .leading, spacing: 0) {
                // Tab content
                tabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                // Footer with validation error and save button
                footer
            }
        }
        .frame(width: 640, height: 480)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Sidebar header
            Text("Settings")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)

            Divider()

            // Tab list
            List(SettingsTab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
            .listStyle(.sidebar)
        }
        .frame(minWidth: 180, idealWidth: 200, maxWidth: 220)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                switch selectedTab {
                case .general:
                    generalTab
                case .language:
                    languageTab
                case .audio:
                    audioTab
                case .privacy:
                    privacyTab
                }
            }
            .padding(24)
        }
    }

    // MARK: - General Tab

    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(
                title: "General Settings",
                subtitle: "Configure basic app behavior"
            )

            // Launch at login
            Toggle("Launch at login", isOn: $viewModel.settings.general.launchAtLogin)

            // Auto-insert text
            Toggle("Automatically insert transcribed text", isOn: $viewModel.settings.general.autoInsertText)
                .help("Insert text at cursor position after transcription")

            // Copy to clipboard
            Toggle("Copy text to clipboard", isOn: $viewModel.settings.general.copyToClipboard)
                .help("Always copy transcribed text to clipboard")

            Divider()

            // Hotkey configuration (T054)
            hotkeySection
        }
    }

    // MARK: - Hotkey Section

    private var hotkeySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Global Hotkey")
                .font(.headline)

            Text("Press the key combination to record speech")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                // Hotkey display (simplified - actual key capture would need custom view)
                Text(hotkeyDisplayString)
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                Button("Change...") {
                    // Would open hotkey recorder modal (T054)
                }
            }

            if let conflict = viewModel.validationError, conflict.contains("Hotkey conflict") {
                Text(conflict)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    /// Display string for current hotkey
    private var hotkeyDisplayString: String {
        let modifiers = viewModel.settings.hotkey.modifiers
            .map { $0.symbol }
            .joined()

        return "\(modifiers)\(viewModel.settings.hotkey.keyName)"
    }

    // MARK: - Language Tab

    private var languageTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(
                title: "Language Settings",
                subtitle: "Select transcription language"
            )

            // Auto-detect language
            Toggle("Automatically detect language", isOn: $viewModel.settings.language.autoDetectEnabled)
                .help("Let FluidAudio detect the spoken language")

            Divider()

            // Language picker (T053, T056, T061)
            Text("Default Language")
                .font(.headline)

            LanguagePicker(
                selectedLanguageCode: $viewModel.settings.language.defaultLanguage,
                onLanguageSelected: { language in
                    await viewModel.updateLanguage(language)
                }
            )
        }
    }

    // MARK: - Audio Tab

    private var audioTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(
                title: "Audio Settings",
                subtitle: "Configure microphone and detection sensitivity"
            )

            // Audio sensitivity slider (T057)
            audioSensitivitySection

            Divider()

            // Silence detection threshold (T058)
            silenceDetectionSection
        }
    }

    // MARK: - Audio Sensitivity Section

    private var audioSensitivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Audio Sensitivity")
                .font(.headline)

            Text("Adjust microphone sensitivity threshold")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Text("Low")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Slider(
                    value: $viewModel.settings.audio.sensitivity,
                    in: 0.1...1.0,
                    step: 0.05
                )
                .onChange(of: viewModel.settings.audio.sensitivity) { _, newValue in
                    Task {
                        await viewModel.updateAudioSensitivity(newValue)
                    }
                }

                Text("High")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Current: \(viewModel.settings.audio.sensitivity, specifier: "%.2f")")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Live visualization placeholder
            Text("🎤 Live microphone level visualization would appear here")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .italic()
        }
    }

    // MARK: - Silence Detection Section

    private var silenceDetectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Silence Detection")
                .font(.headline)

            Text("Stop recording after this many seconds of silence")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Text("0.5s")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Slider(
                    value: $viewModel.settings.audio.silenceThreshold,
                    in: 0.5...3.0,
                    step: 0.1
                )
                .onChange(of: viewModel.settings.audio.silenceThreshold) { _, newValue in
                    Task {
                        await viewModel.updateSilenceThreshold(newValue)
                    }
                }

                Text("3.0s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Current: \(viewModel.settings.audio.silenceThreshold, specifier: "%.1f") seconds")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Privacy Tab

    private var privacyTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(
                title: "Privacy Settings",
                subtitle: "Control data collection and storage"
            )

            // Collect statistics
            Toggle("Collect anonymous usage statistics", isOn: $viewModel.settings.privacy.collectAnonymousStats)
                .help("Track word count and session statistics locally")

            // Store history
            Toggle("Store transcription history", isOn: $viewModel.settings.privacy.storeHistory)
                .help("Keep a local history of transcriptions")

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Label("100% Local Processing", systemImage: "lock.shield.fill")
                    .font(.headline)
                    .foregroundStyle(Color("AmberPrimary", bundle: nil))

                Text("All speech recognition happens on your device using the FluidAudio SDK. No data is ever sent to external servers.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .background(Color("AmberPrimary", bundle: nil).opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            // Validation error
            if let error = viewModel.validationError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer()

            // Reset button (T060)
            Button("Reset to Defaults") {
                viewModel.resetToDefaults()
            }
            .buttonStyle(.borderless)

            // Save button (implicit via auto-save on changes)
            if viewModel.isSaving {
                ProgressView()
                    .scaleEffect(0.8)
                    .padding(.leading, 8)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .opacity(viewModel.validationError == nil ? 1.0 : 0.0)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    // MARK: - Helper Views

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)

            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Extensions

extension UserSettings.HotkeyModifier {
    /// Symbol representation for hotkey display
    var symbol: String {
        switch self {
        case .command: return "⌘"
        case .control: return "⌃"
        case .option: return "⌥"
        case .shift: return "⇧"
        }
    }
}

extension UserSettings.HotkeyConfig {
    /// Display name for key code
    var keyName: String {
        // Map common key codes to names
        switch keyCode {
        case 49: return "Space"
        case 36: return "Return"
        case 53: return "Escape"
        case 51: return "Delete"
        default: return "Key \(keyCode)"
        }
    }
}

// MARK: - Previews

#Preview("Settings View") {
    SettingsView()
}

#Preview("Settings View - Language Tab") {
    SettingsView()
        .onAppear {
            // Would set selectedTab to .language in real preview
        }
}
