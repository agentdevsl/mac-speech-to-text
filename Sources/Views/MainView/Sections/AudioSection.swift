// swiftlint:disable file_length
// AudioSection.swift
// macOS Local Speech-to-Text Application
//
// Main View - Audio Settings Section
// Audio sensitivity, silence threshold, microphone selection, and audio processing options

import AVFoundation
import SwiftUI

/// AudioSection provides configuration for microphone and audio processing settings
struct AudioSection: View {
    // MARK: - Dependencies

    let settingsService: SettingsService

    // MARK: - State

    @State private var settings: UserSettings
    @State private var isSaving: Bool = false
    @State private var availableDevices: [AudioDevice] = []
    @State private var selectedDeviceId: String?

    // MARK: - Initialization

    init(settingsService: SettingsService) {
        self.settingsService = settingsService
        self._settings = State(initialValue: settingsService.load())
        self._selectedDeviceId = State(initialValue: settingsService.load().audio.inputDeviceId)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Section header
                sectionHeader

                // Audio sensitivity slider
                sensitivitySection

                Divider()
                    .padding(.vertical, 4)

                // Silence threshold slider
                silenceThresholdSection

                Divider()
                    .padding(.vertical, 4)

                // Microphone device picker (if multiple devices)
                if availableDevices.count > 1 {
                    microphonePickerSection

                    Divider()
                        .padding(.vertical, 4)
                }

                // Audio processing toggles
                processingSection
            }
            .padding(24)
        }
        .accessibilityIdentifier("audioSection")
        .task {
            await loadAudioDevices()
        }
    }

    // MARK: - Section Header

    private var sectionHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Audio")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            Text("Microphone and audio processing settings")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityIdentifier("audioSectionHeader")
    }

    // MARK: - Sensitivity Section

    private var sensitivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Audio Sensitivity")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Text(String(format: "%.0f%%", settings.audio.sensitivity * 100))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.warmAmber)
                    .monospacedDigit()
            }

            Text("Adjust the microphone sensitivity for voice detection")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Slider with labels
            VStack(spacing: 8) {
                Slider(
                    value: Binding(
                        get: { settings.audio.sensitivity },
                        set: { newValue in
                            settings.audio.sensitivity = newValue
                            saveSettings()
                        }
                    ),
                    in: 0.0...1.0,
                    step: 0.05
                )
                .tint(Color.warmAmber)
                .accessibilityIdentifier("sensitivitySlider")

                HStack {
                    Text("Low")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Spacer()

                    Text("High")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            // Sensitivity indicator bar
            SensitivityIndicator(level: settings.audio.sensitivity)
                .accessibilityIdentifier("sensitivityIndicator")
        }
        .accessibilityIdentifier("sensitivitySection")
    }

    // MARK: - Silence Threshold Section

    private var silenceThresholdSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Silence Threshold")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Text(String(format: "%.1fs", settings.audio.silenceThreshold))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.warmAmber)
                    .monospacedDigit()
            }

            Text("Stop recording after this duration of silence")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Slider with labels
            VStack(spacing: 8) {
                Slider(
                    value: Binding(
                        get: { settings.audio.silenceThreshold },
                        set: { newValue in
                            settings.audio.silenceThreshold = newValue
                            saveSettings()
                        }
                    ),
                    in: 0.5...3.0,
                    step: 0.1
                )
                .tint(Color.warmAmber)
                .accessibilityIdentifier("silenceThresholdSlider")

                HStack {
                    Text("0.5s")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Spacer()

                    Text("3.0s")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            // Visual timeline indicator
            SilenceTimelineIndicator(threshold: settings.audio.silenceThreshold)
                .accessibilityIdentifier("silenceTimelineIndicator")
        }
        .accessibilityIdentifier("silenceThresholdSection")
    }

    // MARK: - Microphone Picker Section

    private var microphonePickerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Microphone")
                .font(.headline)
                .foregroundStyle(.primary)

            Text("Select which microphone to use for recording")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Device picker
            VStack(spacing: 8) {
                ForEach(availableDevices) { device in
                    MicrophoneDeviceRow(
                        device: device,
                        isSelected: selectedDeviceId == device.id || (selectedDeviceId == nil && device.isDefault),
                        onSelect: { selectDevice(device) }
                    )
                }
            }
        }
        .accessibilityIdentifier("microphonePickerSection")
    }

    // MARK: - Processing Section

    private var processingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Audio Processing")
                .font(.headline)
                .foregroundStyle(.primary)

            VStack(spacing: 12) {
                // Noise suppression
                AudioToggleRow(
                    icon: "waveform.path.ecg",
                    title: "Noise Suppression",
                    subtitle: "Reduce background noise during recording",
                    isOn: Binding(
                        get: { settings.audio.noiseSuppression },
                        set: { newValue in
                            settings.audio.noiseSuppression = newValue
                            saveSettings()
                        }
                    )
                )
                .accessibilityIdentifier("noiseSuppressionToggle")

                // Auto gain control
                AudioToggleRow(
                    icon: "speaker.wave.3.fill",
                    title: "Auto Gain Control",
                    subtitle: "Automatically adjust microphone volume",
                    isOn: Binding(
                        get: { settings.audio.autoGainControl },
                        set: { newValue in
                            settings.audio.autoGainControl = newValue
                            saveSettings()
                        }
                    )
                )
                .accessibilityIdentifier("autoGainControlToggle")
            }
        }
        .accessibilityIdentifier("processingSection")
    }

    // MARK: - Private Methods

    private func loadAudioDevices() async {
        // Get available audio input devices
        var devices: [AudioDevice] = []

        #if os(macOS)
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )

        let defaultDevice = AVCaptureDevice.default(for: .audio)

        for device in discoverySession.devices {
            devices.append(AudioDevice(
                id: device.uniqueID,
                name: device.localizedName,
                isDefault: device.uniqueID == defaultDevice?.uniqueID
            ))
        }
        #endif

        // If no devices found, add a placeholder
        if devices.isEmpty {
            devices.append(AudioDevice(
                id: "default",
                name: "System Default",
                isDefault: true
            ))
        }

        availableDevices = devices
    }

    private func selectDevice(_ device: AudioDevice) {
        selectedDeviceId = device.id
        settings.audio.inputDeviceId = device.id
        saveSettings()
    }

    private func saveSettings() {
        isSaving = true
        do {
            try settingsService.save(settings)
        } catch {
            AppLogger.service.error("Failed to save audio settings: \(error.localizedDescription)")
        }
        isSaving = false
    }
}

// MARK: - Audio Device Model

/// Represents an available audio input device
private struct AudioDevice: Identifiable {
    let id: String
    let name: String
    let isDefault: Bool
}

// MARK: - Sensitivity Indicator

/// Visual indicator showing current sensitivity level
private struct SensitivityIndicator: View {
    let level: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.warmGray)

                // Filled portion
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * level)
            }
        }
        .frame(height: 8)
    }

    private var gradientColors: [Color] {
        if level < 0.3 {
            return [Color.warmAmberLight, Color.warmAmber]
        } else if level < 0.7 {
            return [Color.warmAmber, Color.warningOrange]
        } else {
            return [Color.warningOrange, Color.errorRed]
        }
    }
}

// MARK: - Silence Timeline Indicator

/// Visual timeline showing silence threshold
private struct SilenceTimelineIndicator: View {
    let threshold: TimeInterval

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.warmGray)

                // Speaking segment (always at start)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.warmAmber)
                    .frame(width: geometry.size.width * 0.3)

                // Silence segment
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.warmGrayMedium)
                    .frame(width: geometry.size.width * (threshold / 3.0) * 0.7)
                    .offset(x: geometry.size.width * 0.3)

                // Threshold marker
                Rectangle()
                    .fill(Color.errorRed)
                    .frame(width: 2)
                    .offset(x: geometry.size.width * (0.3 + (threshold / 3.0) * 0.7))
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Microphone Device Row

/// Row displaying a microphone device option
private struct MicrophoneDeviceRow: View {
    let device: AudioDevice
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Microphone icon
                Image(systemName: "mic.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? Color.warmAmber : Color.warmGrayDark)
                    .frame(width: 24)

                // Device info
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(.body)
                        .foregroundStyle(.primary)

                    if device.isDefault {
                        Text("System Default")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.warmAmber)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.warmAmber.opacity(0.1) : Color.warmGray.opacity(0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.warmAmber : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("microphoneDevice_\(device.id)")
    }
}

// MARK: - Audio Toggle Row

/// Styled toggle row for audio settings
private struct AudioToggleRow: View {
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

// MARK: - Previews

#Preview("Audio Section") {
    AudioSection(settingsService: SettingsService())
        .frame(width: 380, height: 800)
}

#Preview("Audio Section - Dark Mode") {
    AudioSection(settingsService: SettingsService())
        .frame(width: 380, height: 800)
        .preferredColorScheme(.dark)
}
