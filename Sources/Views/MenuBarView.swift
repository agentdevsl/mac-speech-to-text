// swiftlint:disable type_body_length
// MenuBarView.swift
// macOS Local Speech-to-Text Application
//
// User Story 3: Menu Bar Quick Access and Stats
// Task T044: MenuBarView - Menu bar content with quick stats display
// and menu options (Start Recording, Open Settings, Quit)
//
// Phase 3: UI Simplification - Inline settings replacing separate settings window

import SwiftUI

/// MenuBarView provides the menu bar dropdown content with inline settings
struct MenuBarView: View {
    // MARK: - State

    @State private var viewModel = MenuBarViewModel()
    /// Task for refreshing statistics - stored for cancellation
    @State private var refreshTask: Task<Void, Never>?

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header with app name
                headerSection

                Divider()

                // Quick stats section
                statsSection

                Divider()

                // Settings sections (Phase 3)
                settingsSections

                Divider()

                // Permissions status
                permissionsSection

                Divider()

                // Quit button
                quitSection
            }
        }
        .frame(width: 280)
        .frame(maxHeight: 480)
        .onAppear {
            // Store task for potential cancellation
            refreshTask = Task {
                await viewModel.refreshStatistics()
                await viewModel.refreshPermissions()
            }
        }
        .onDisappear {
            // Cancel any pending refresh task
            refreshTask?.cancel()
            refreshTask = nil
        }
    }

    // MARK: - Sections

    /// Header section with app name and icon
    private var headerSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "mic.circle.fill")
                .font(.title2)
                .foregroundStyle(Color("AmberPrimary", bundle: nil))

            VStack(alignment: .leading, spacing: 2) {
                Text("Speech-to-Text")
                    .font(.headline)

                Text("Version \(Constants.App.version)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    /// Quick stats section
    private var statsSection: some View {
        HStack(spacing: 16) {
            // Words today
            HStack(spacing: 6) {
                Image(systemName: "text.alignleft")
                    .font(.caption)
                    .foregroundStyle(.blue)

                Text("Words:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                } else {
                    Text("\(viewModel.wordsToday)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color("AmberPrimary", bundle: nil))
                }
            }

            // Sessions today
            HStack(spacing: 6) {
                Image(systemName: "mic.fill")
                    .font(.caption)
                    .foregroundStyle(.green)

                Text("Sessions:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                } else {
                    Text("\(viewModel.sessionsToday)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color("AmberPrimary", bundle: nil))
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    /// Settings sections with collapsible disclosure groups
    private var settingsSections: some View {
        VStack(spacing: 0) {
            // Recording section
            recordingSection

            // Language section
            languageSection

            // Audio section
            audioSection

            // Behavior section
            behaviorSection

            // Privacy section
            privacySection
        }
    }

    // MARK: - Recording Section

    private var recordingSection: some View {
        MenuBarSettingsSection(
            icon: "mic.fill",
            title: "Recording",
            subtitle: "Start Recording \(viewModel.hotkeyDisplayString)",
            isExpanded: $viewModel.recordingSectionExpanded
        ) {
            Button {
                viewModel.startRecording()
            } label: {
                HStack {
                    Image(systemName: "record.circle")
                        .foregroundStyle(.red)
                    Text("Start Recording")
                    Spacer()
                    Text(viewModel.hotkeyDisplayString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(Color("AmberPrimary", bundle: nil).opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)

            Button {
                Task {
                    await viewModel.refreshStatistics()
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh Stats")
                }
                .font(.callout)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    // MARK: - Language Section

    private var languageSection: some View {
        MenuBarSettingsSection(
            icon: "globe",
            title: "Language",
            subtitle: viewModel.currentLanguageModel.map { "\($0.flag) \($0.name)" } ?? "English",
            isExpanded: $viewModel.languageSectionExpanded
        ) {
            InlineLanguagePicker(
                selectedLanguageCode: $viewModel.currentLanguage,
                recentLanguages: viewModel.recentLanguages,
                onLanguageSelected: { language in
                    await viewModel.switchLanguage(to: language)
                }
            )
        }
    }

    // MARK: - Audio Section

    private var audioSection: some View {
        MenuBarSettingsSection(
            icon: "waveform",
            title: "Audio",
            subtitle: "Sensitivity \(String(format: "%.0f%%", viewModel.settings.audio.sensitivity * 100))",
            isExpanded: $viewModel.audioSectionExpanded
        ) {
            VStack(alignment: .leading, spacing: 12) {
                SettingsSliderRow(
                    title: "Sensitivity",
                    value: $viewModel.settings.audio.sensitivity,
                    range: 0.1...1.0,
                    step: 0.05,
                    format: "%.0f%%",
                    lowLabel: "Low",
                    highLabel: "High"
                )
                .onChange(of: viewModel.settings.audio.sensitivity) { _, newValue in
                    Task {
                        await viewModel.updateAudioSensitivity(newValue)
                    }
                }

                SettingsSliderRow(
                    title: "Silence Threshold",
                    value: $viewModel.settings.audio.silenceThreshold,
                    range: 0.5...3.0,
                    step: 0.1,
                    format: "%.1fs",
                    lowLabel: "0.5s",
                    highLabel: "3.0s"
                )
                .onChange(of: viewModel.settings.audio.silenceThreshold) { _, newValue in
                    Task {
                        await viewModel.updateSilenceThreshold(newValue)
                    }
                }
            }
        }
    }

    // MARK: - Behavior Section

    private var behaviorSection: some View {
        MenuBarSettingsSection(
            icon: "gearshape",
            title: "Behavior",
            subtitle: behaviorSubtitle,
            isExpanded: $viewModel.behaviorSectionExpanded
        ) {
            VStack(alignment: .leading, spacing: 8) {
                SettingsToggleRow(
                    title: "Launch at login",
                    isOn: $viewModel.settings.general.launchAtLogin,
                    help: "Start app when you log in"
                )
                .onChange(of: viewModel.settings.general.launchAtLogin) { _, _ in
                    Task { await viewModel.updateGeneralSetting() }
                }

                SettingsToggleRow(
                    title: "Auto-insert text",
                    isOn: $viewModel.settings.general.autoInsertText,
                    help: "Insert text at cursor after transcription"
                )
                .onChange(of: viewModel.settings.general.autoInsertText) { _, _ in
                    Task { await viewModel.updateGeneralSetting() }
                }

                SettingsToggleRow(
                    title: "Copy to clipboard",
                    isOn: $viewModel.settings.general.copyToClipboard,
                    help: "Always copy transcribed text"
                )
                .onChange(of: viewModel.settings.general.copyToClipboard) { _, _ in
                    Task { await viewModel.updateGeneralSetting() }
                }
            }
        }
    }

    private var behaviorSubtitle: String {
        var parts: [String] = []
        if viewModel.settings.general.launchAtLogin {
            parts.append("Launch")
        }
        if viewModel.settings.general.autoInsertText {
            parts.append("Auto-insert")
        }
        if parts.isEmpty {
            return "Configure behavior"
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Privacy Section

    private var privacySection: some View {
        MenuBarSettingsSection(
            icon: "lock.shield",
            title: "Privacy",
            subtitle: viewModel.settings.privacy.collectAnonymousStats ? "Stats enabled" : "Stats disabled",
            isExpanded: $viewModel.privacySectionExpanded
        ) {
            VStack(alignment: .leading, spacing: 8) {
                SettingsToggleRow(
                    title: "Anonymous statistics",
                    isOn: $viewModel.settings.privacy.collectAnonymousStats,
                    help: "Track word count and sessions locally"
                )
                .onChange(of: viewModel.settings.privacy.collectAnonymousStats) { _, _ in
                    Task { await viewModel.updatePrivacySetting() }
                }

                SettingsToggleRow(
                    title: "Store history",
                    isOn: $viewModel.settings.privacy.storeHistory,
                    help: "Keep local transcription history"
                )
                .onChange(of: viewModel.settings.privacy.storeHistory) { _, _ in
                    Task { await viewModel.updatePrivacySetting() }
                }

                // Privacy notice
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield.fill")
                        .font(.caption)
                        .foregroundStyle(Color("AmberPrimary", bundle: nil))

                    Text("100% local processing")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Permissions Section

    private var permissionsSection: some View {
        HStack(spacing: 8) {
            Text("Permissions:")
                .font(.caption)
                .foregroundStyle(.secondary)

            PermissionStatusIndicator.microphone(isGranted: viewModel.hasMicrophonePermission)
                .onTapGesture {
                    if !viewModel.hasMicrophonePermission {
                        Task {
                            await viewModel.requestMicrophonePermission()
                        }
                    }
                }

            PermissionStatusIndicator.accessibility(isGranted: viewModel.hasAccessibilityPermission)
                .onTapGesture {
                    if !viewModel.hasAccessibilityPermission {
                        viewModel.requestAccessibilityPermission()
                    }
                }

            Spacer()

            // Refresh permissions button
            Button {
                Task {
                    await viewModel.refreshPermissions()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Refresh permission status")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    /// Quit section
    private var quitSection: some View {
        Button(action: viewModel.quit) {
            HStack(spacing: 8) {
                Image(systemName: "power")
                    .foregroundStyle(.red)
                Text("Quit")
                Spacer()
                Text("Q")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut("q", modifiers: .command)
    }
}

// MARK: - Previews

#Preview("Menu Bar View") {
    MenuBarView()
}

#Preview("Menu Bar View - Scrollable") {
    MenuBarView()
        .frame(height: 400)
}

// swiftlint:enable type_body_length
