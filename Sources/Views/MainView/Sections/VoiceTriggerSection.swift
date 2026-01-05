// VoiceTriggerSection.swift
// macOS Local Speech-to-Text Application
//
// Main View - Voice Trigger Settings Section
// Configuration for voice activation triggers, keywords, and feedback options

import KeyboardShortcuts
import SwiftUI

/// VoiceTriggerSection provides configuration for voice-activated recording triggers
struct VoiceTriggerSection: View {
    // MARK: - Environment

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Dependencies

    let settingsService: SettingsService

    // MARK: - State

    @State private var settings: UserSettings
    @State private var isSaving: Bool = false
    @State private var saveError: String?
    @State private var showAddKeyword: Bool = false
    @State private var newKeywordPhrase: String = ""

    // MARK: - Initialization

    init(settingsService: SettingsService) {
        self.settingsService = settingsService
        let loadedSettings = settingsService.load()
        AppLogger.system.info(
            """
            VoiceTriggerSection init: Loaded settings - \
            enabled=\(loadedSettings.voiceTrigger.enabled), \
            keywords=\(loadedSettings.voiceTrigger.keywords.count), \
            silenceThreshold=\(loadedSettings.voiceTrigger.silenceThresholdSeconds)
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
                    errorBanner(error: error)
                }

                // Section header
                sectionHeader

                // Main enable toggle
                mainToggleSection

                Divider()
                    .padding(.vertical, 4)

                // Monitoring shortcut
                monitoringShortcutSection

                Divider()
                    .padding(.vertical, 4)

                // Keywords list
                keywordsSection

                Divider()
                    .padding(.vertical, 4)

                // Silence threshold slider
                silenceThresholdSection

                Divider()
                    .padding(.vertical, 4)

                // Feedback toggles
                feedbackSection
            }
            .padding(24)
            .animation(.easeInOut(duration: 0.3), value: saveError)
        }
        .accessibilityIdentifier("voiceTriggerSection")
        .onAppear {
            // Reload settings when view appears to ensure fresh state
            let loadedSettings = settingsService.load()
            AppLogger.system.info(
                """
                VoiceTriggerSection onAppear: Reloading settings - \
                enabled=\(loadedSettings.voiceTrigger.enabled), \
                keywords=\(loadedSettings.voiceTrigger.keywords.count)
                """
            )
            settings = loadedSettings
        }
        .sheet(isPresented: $showAddKeyword) {
            addKeywordSheet
        }
    }

    // MARK: - Error Banner

    @ViewBuilder
    private func errorBanner(error: String) -> some View {
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

    // MARK: - Section Header

    private var sectionHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform.badge.mic")
                .font(.system(size: 24))
                .foregroundStyle(Color.warmAmber)

            VStack(alignment: .leading, spacing: 4) {
                Text("Voice Triggers")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text("Activate recording with voice commands")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("voiceTriggerSectionHeader")
    }

    // MARK: - Main Toggle Section

    private var mainToggleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VoiceTriggerToggleRow(
                icon: "power",
                title: "Enable Voice Triggers",
                subtitle: "Listen for trigger keywords to start recording",
                isOn: Binding(
                    get: { settings.voiceTrigger.enabled },
                    set: { newValue in
                        settings.voiceTrigger.enabled = newValue
                        saveSettings()
                    }
                )
            )
            .accessibilityIdentifier("voiceTriggerEnableToggle")
        }
        .accessibilityIdentifier("mainToggleSection")
    }

    // MARK: - Monitoring Shortcut Section

    private var monitoringShortcutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Monitoring Shortcut")
                .font(.headline)
                .foregroundStyle(.primary)

            HStack {
                HStack(spacing: 12) {
                    Image(systemName: "ear")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.warmAmber)
                        .frame(width: 24)

                    Text("Toggle Monitoring")
                        .font(.body)
                        .foregroundStyle(.primary)
                }

                Spacer()

                VStack(spacing: 6) {
                    ShortcutRecorderView(for: .toggleVoiceMonitoring, placeholder: "Set Shortcut")
                        .accessibilityIdentifier("voiceMonitoringRecorder")

                    Text("Click to change")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(white: 0.15) : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        colorScheme == .dark
                            ? Color.white.opacity(0.1)
                            : Color.black.opacity(0.08),
                        lineWidth: 1
                    )
            )

            Text("Use this shortcut to quickly toggle voice monitoring on or off.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .accessibilityIdentifier("monitoringShortcutSection")
    }

    // MARK: - Keywords Section

    private var keywordsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Trigger Keywords")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    showAddKeyword = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add")
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.warmAmber)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("addKeywordButton")
            }

            // Keywords list
            VStack(spacing: 8) {
                ForEach(settings.voiceTrigger.keywords) { keyword in
                    KeywordRow(
                        keyword: keyword,
                        onToggle: { toggleKeyword(keyword) },
                        onDelete: { deleteKeyword(keyword) }
                    )
                    .accessibilityIdentifier("keywordRow_\(keyword.id)")
                }

                if settings.voiceTrigger.keywords.isEmpty {
                    emptyKeywordsPlaceholder
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(white: 0.15) : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        colorScheme == .dark
                            ? Color.white.opacity(0.1)
                            : Color.black.opacity(0.08),
                        lineWidth: 1
                    )
            )

            Text("Say any enabled keyword to automatically start recording.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .accessibilityIdentifier("keywordsSection")
    }

    private var emptyKeywordsPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "text.bubble")
                .font(.system(size: 24))
                .foregroundStyle(.tertiary)
            Text("No keywords configured")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Add a keyword to get started")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Silence Threshold Section

    private var silenceThresholdSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Silence Detection")
                .font(.headline)
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "waveform.slash")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.warmAmber)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Silence Threshold")
                            .font(.body)
                            .foregroundStyle(.primary)

                        Text("Stop recording after \(Int(settings.voiceTrigger.silenceThresholdSeconds)) seconds of silence")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 12) {
                    Text("1s")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Slider(
                        value: Binding(
                            get: { settings.voiceTrigger.silenceThresholdSeconds },
                            set: { newValue in
                                settings.voiceTrigger.silenceThresholdSeconds = newValue
                                saveSettings()
                            }
                        ),
                        in: 1...10,
                        step: 1
                    )
                    .tint(Color.warmAmber)
                    .accessibilityIdentifier("silenceThresholdSlider")

                    Text("10s")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(white: 0.15) : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        colorScheme == .dark
                            ? Color.white.opacity(0.1)
                            : Color.black.opacity(0.08),
                        lineWidth: 1
                    )
            )

            Text("Recording stops automatically when no speech is detected for this duration.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .accessibilityIdentifier("silenceThresholdSection")
    }

    // MARK: - Feedback Section

    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Feedback")
                .font(.headline)
                .foregroundStyle(.primary)

            VStack(spacing: 12) {
                VoiceTriggerToggleRow(
                    icon: "speaker.wave.2",
                    title: "Audio Feedback",
                    subtitle: "Play a sound when a keyword is detected",
                    isOn: Binding(
                        get: { settings.voiceTrigger.feedbackSoundEnabled },
                        set: { newValue in
                            settings.voiceTrigger.feedbackSoundEnabled = newValue
                            saveSettings()
                        }
                    )
                )
                .accessibilityIdentifier("audioFeedbackToggle")

                VoiceTriggerToggleRow(
                    icon: "eye",
                    title: "Visual Feedback",
                    subtitle: "Show visual indicator when a keyword is detected",
                    isOn: Binding(
                        get: { settings.voiceTrigger.feedbackVisualEnabled },
                        set: { newValue in
                            settings.voiceTrigger.feedbackVisualEnabled = newValue
                            saveSettings()
                        }
                    )
                )
                .accessibilityIdentifier("visualFeedbackToggle")
            }
        }
        .accessibilityIdentifier("feedbackSection")
    }

    // MARK: - Add Keyword Sheet

    private var addKeywordSheet: some View {
        VStack(spacing: 20) {
            Text("Add Trigger Keyword")
                .font(.headline)
                .foregroundStyle(.primary)

            TextField("Enter keyword phrase", text: $newKeywordPhrase)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("newKeywordTextField")

            HStack(spacing: 12) {
                Button("Cancel") {
                    newKeywordPhrase = ""
                    showAddKeyword = false
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("cancelAddKeywordButton")

                Button("Add") {
                    addKeyword()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.warmAmber)
                .disabled(newKeywordPhrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("confirmAddKeywordButton")
            }
        }
        .padding(24)
        .frame(width: 300)
    }

    // MARK: - Private Methods

    private func toggleKeyword(_ keyword: TriggerKeyword) {
        if let index = settings.voiceTrigger.keywords.firstIndex(where: { $0.id == keyword.id }) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                settings.voiceTrigger.keywords[index].isEnabled.toggle()
            }
            saveSettings()
        }
    }

    private func deleteKeyword(_ keyword: TriggerKeyword) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            settings.voiceTrigger.keywords.removeAll { $0.id == keyword.id }
        }
        saveSettings()
    }

    private func addKeyword() {
        let trimmedPhrase = newKeywordPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPhrase.isEmpty else { return }

        let newKeyword = TriggerKeyword(
            phrase: trimmedPhrase,
            boostingScore: 1.5,
            triggerThreshold: 0.35,
            isEnabled: true
        )

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            settings.voiceTrigger.keywords.append(newKeyword)
        }
        saveSettings()

        newKeywordPhrase = ""
        showAddKeyword = false
    }

    private func saveSettings() {
        isSaving = true
        saveError = nil
        do {
            AppLogger.system.info(
                """
                VoiceTriggerSection: Saving settings - \
                enabled=\(settings.voiceTrigger.enabled), \
                keywords=\(settings.voiceTrigger.keywords.count), \
                silenceThreshold=\(settings.voiceTrigger.silenceThresholdSeconds)
                """
            )
            try settingsService.save(settings)
            AppLogger.system.info("VoiceTriggerSection: Settings saved successfully")
        } catch {
            AppLogger.service.error("Failed to save settings: \(error.localizedDescription)")
            saveError = "Failed to save settings. Please try again."
            // Clear error after 3 seconds
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                saveError = nil
            }
        }
        isSaving = false
    }
}

// MARK: - Keyword Row

/// Row displaying a single trigger keyword with toggle and delete controls
private struct KeywordRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let keyword: TriggerKeyword
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Keyword phrase
            VStack(alignment: .leading, spacing: 2) {
                Text(keyword.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(keyword.isEnabled ? .primary : .secondary)

                Text(keyword.isEnabled ? "Enabled" : "Disabled")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Enable/disable toggle
            Toggle("", isOn: Binding(
                get: { keyword.isEnabled },
                set: { _ in onToggle() }
            ))
            .toggleStyle(VoiceTriggerToggleStyle())
            .labelsHidden()
            .accessibilityLabel("Toggle \(keyword.displayName)")

            // Delete button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Delete keyword")
            .accessibilityLabel("Delete \(keyword.displayName)")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
}

// MARK: - Voice Trigger Toggle Row

/// Styled toggle row for voice trigger settings
private struct VoiceTriggerToggleRow: View {
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
        .toggleStyle(VoiceTriggerToggleStyle())
        .padding(.vertical, 4)
    }
}

// MARK: - Voice Trigger Toggle Style

/// Custom toggle style that shows blue when ON in both light and dark modes
private struct VoiceTriggerToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            RoundedRectangle(cornerRadius: 11)
                .fill(configuration.isOn ? Color.blue : Color(white: 0.3))
                .frame(width: 38, height: 22)
                .overlay(
                    Circle()
                        .fill(Color.white)
                        .shadow(radius: 1)
                        .padding(2)
                        .offset(x: configuration.isOn ? 8 : -8)
                )
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        configuration.isOn.toggle()
                    }
                }
        }
    }
}

// MARK: - Previews

#Preview("Voice Trigger Section") {
    VoiceTriggerSection(settingsService: SettingsService())
        .frame(width: 380, height: 800)
}

#Preview("Voice Trigger Section - Dark Mode") {
    VoiceTriggerSection(settingsService: SettingsService())
        .frame(width: 380, height: 800)
        .preferredColorScheme(.dark)
}
