// ThemeSection.swift
// macOS Local Speech-to-Text Application
//
// Theme & Appearance settings section
// Allows customization of visual appearance including waveform style

import SwiftUI

struct ThemeSection: View {
    // MARK: - Dependencies

    let settingsService: SettingsService

    // MARK: - State

    @State private var settings: UserSettings
    @State private var isSaving: Bool = false
    @State private var saveError: String?
    @State private var previewAudioLevel: Float = 0.5
    @State private var isAnimatingPreview = false

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
                headerView

                // App Theme
                themeSelector

                Divider()

                // Waveform Style
                waveformStyleSection

                Divider()

                // Animation toggle
                animationToggle

                // Save error message
                if let error = saveError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.top, 8)
                }

                Spacer(minLength: 20)
            }
            .padding(24)
        }
        .accessibilityIdentifier("themeSection")
        .onAppear {
            settings = settingsService.load()
            startPreviewAnimation()
        }
        .onDisappear {
            isAnimatingPreview = false
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Theme & Appearance", systemImage: "paintbrush")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)

            Text("Customize the visual style of the recording overlay")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Theme Selector

    private var themeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("App Theme")
                .font(.headline)

            HStack(spacing: 12) {
                Image(systemName: "circle.lefthalf.filled")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.iconPrimaryAdaptive)
                    .frame(width: 24)

                Text("Theme")
                    .font(.body)
                    .foregroundStyle(.primary)

                Spacer()

                Picker("Theme", selection: Binding(
                    get: { settings.ui.theme },
                    set: { newValue in
                        settings.ui.theme = newValue
                        saveSettings()
                    }
                )) {
                    ForEach([Theme.system, .light, .dark], id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                .labelsHidden()
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        }
    }

    // MARK: - Waveform Style Section

    private var waveformStyleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Waveform Style")
                    .font(.headline)

                Text("Choose the audio visualization style for the recording overlay")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Preview area
            waveformPreview

            // Style grid
            waveformStyleGrid
        }
    }

    private var waveformPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.cardBorderAdaptive, lineWidth: 1)
                }

            VStack(spacing: 8) {
                waveformPreviewContent
                    .frame(height: 80)
                    .padding(.horizontal, 24)

                Text(settings.ui.waveformStyle.displayName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.textTertiaryAdaptive)
            }
        }
        .frame(height: 130)
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }

    @ViewBuilder
    private var waveformPreviewContent: some View {
        WaveformVisualization(
            style: settings.ui.waveformStyle,
            audioLevel: previewAudioLevel,
            isRecording: false  // Show idle state (amber) in preview
        )
    }

    private var waveformStyleGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            ForEach(WaveformStyleOption.allCases, id: \.self) { style in
                WaveformStyleCard(
                    style: style,
                    isSelected: settings.ui.waveformStyle == style
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        settings.ui.waveformStyle = style
                        saveSettings()
                    }
                }
            }
        }
    }

    // MARK: - Animation Toggle

    private var animationToggle: some View {
        Toggle(isOn: Binding(
            get: { settings.ui.animationsEnabled },
            set: { newValue in
                settings.ui.animationsEnabled = newValue
                saveSettings()
            }
        )) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Enable Animations")
                    .font(.headline)
                Text("Smooth transitions and visual effects throughout the app")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch)
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        }
    }

    // MARK: - Preview Animation

    private func startPreviewAnimation() {
        isAnimatingPreview = true
        animatePreviewLevel()
    }

    private func animatePreviewLevel() {
        guard isAnimatingPreview else { return }

        withAnimation(.easeInOut(duration: 0.15)) {
            previewAudioLevel = Float.random(in: 0.3...0.8)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            animatePreviewLevel()
        }
    }

    // MARK: - Save Settings

    private func saveSettings() {
        do {
            try settingsService.save(settings)
            saveError = nil
            NotificationCenter.default.post(name: .themeDidChange, object: nil)
        } catch {
            saveError = "Failed to save settings"
            AppLogger.service.error("Failed to save theme settings: \(error.localizedDescription)")
        }
    }
}

// MARK: - Waveform Style Card

private struct WaveformStyleCard: View {
    let style: WaveformStyleOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: style.iconName)
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? Color.iconPrimaryAdaptive : Color.textTertiaryAdaptive)

                Text(style.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSelected ? .primary : Color.textTertiaryAdaptive)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.iconPrimaryAdaptive.opacity(0.12) : Color(nsColor: .controlBackgroundColor))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(
                                isSelected ? Color.iconPrimaryAdaptive : Color.cardBorderAdaptive,
                                lineWidth: isSelected ? 2 : 1
                            )
                    }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(style.displayName) waveform style")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Preview

#Preview("Theme Section") {
    ThemeSection(settingsService: SettingsService())
        .frame(width: 450, height: 600)
}

#Preview("Theme Section - Dark Mode") {
    ThemeSection(settingsService: SettingsService())
        .frame(width: 450, height: 600)
        .preferredColorScheme(.dark)
}
