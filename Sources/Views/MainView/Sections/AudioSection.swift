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
    // HIGH-8 Fix: Use settings.audio.inputDeviceId as single source of truth
    // Removed duplicate @State selectedDeviceId - now derived from settings

    @State private var settings: UserSettings
    @State private var isSaving: Bool = false
    @State private var availableDevices: [AudioDevice] = []

    // Loading & Error States
    @State private var isLoadingDevices: Bool = false
    @State private var deviceError: AudioDeviceError?
    @State private var showDeviceReconnectHint: Bool = false
    @State private var saveError: String?

    // HIGH-7 Fix: Device change observer for connect/disconnect events
    #if os(macOS)
    @State private var deviceObserver: NSObjectProtocol?
    #endif

    // MARK: - Computed Properties

    /// Single source of truth for selected device ID (HIGH-8 fix)
    private var selectedDeviceId: String? {
        settings.audio.inputDeviceId
    }

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

                // Audio sensitivity slider
                sensitivitySection

                Divider()
                    .padding(.vertical, 4)

                // Silence threshold slider
                silenceThresholdSection

                Divider()
                    .padding(.vertical, 4)

                // Microphone device picker section with loading/error states
                microphonePickerSection

                Divider()
                    .padding(.vertical, 4)

                // Audio processing toggles
                processingSection
            }
            .padding(24)
        }
        .accessibilityIdentifier("audioSection")
        .task {
            await loadAudioDevices()
        }
        .onAppear {
            setupDeviceObserver()
        }
        .onDisappear {
            removeDeviceObserver()
        }
        // MED-11 Fix: Show save error alert
        .alert("Save Error", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK") { saveError = nil }
        } message: {
            if let error = saveError {
                Text(error)
            }
        }
    }

    // MARK: - Device Observation (HIGH-7 Fix)

    /// Set up observer for audio device connect/disconnect events
    private func setupDeviceObserver() {
        #if os(macOS)
        // Remove any existing observer first
        removeDeviceObserver()

        // Observe audio hardware configuration changes
        // This notification is posted when devices are connected/disconnected
        deviceObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.AVCaptureDeviceWasConnected,
            object: nil,
            queue: .main
        ) { [self] _ in
            Task { @MainActor in
                await loadAudioDevices()
            }
        }

        // Also observe device disconnection
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.AVCaptureDeviceWasDisconnected,
            object: nil,
            queue: .main
        ) { [self] _ in
            Task { @MainActor in
                await loadAudioDevices()
            }
        }
        #endif
    }

    /// Remove the device observer when view disappears
    private func removeDeviceObserver() {
        #if os(macOS)
        if let observer = deviceObserver {
            NotificationCenter.default.removeObserver(observer)
            deviceObserver = nil
        }
        // Also remove the disconnection observer
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name.AVCaptureDeviceWasDisconnected,
            object: nil
        )
        #endif
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
            HStack {
                Text("Microphone")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                // Refresh button
                Button {
                    Task {
                        await loadAudioDevices()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundStyle(Color.warmAmber)
                }
                .buttonStyle(.plain)
                .disabled(isLoadingDevices)
                .accessibilityLabel("Refresh audio devices")
                .accessibilityIdentifier("refreshDevicesButton")
            }

            Text("Select which microphone to use for recording")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Loading state
            if isLoadingDevices {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Detecting audio devices...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 12)
                .accessibilityLabel("Loading audio devices")
            }
            // Error state
            else if let error = deviceError {
                AudioDeviceErrorBanner(
                    error: error,
                    onRetry: {
                        Task {
                            await loadAudioDevices()
                        }
                    },
                    onDismiss: {
                        deviceError = nil
                    }
                )
            }
            // Device list
            else if availableDevices.isEmpty {
                // Empty state - no devices found
                VStack(spacing: 12) {
                    Image(systemName: "mic.slash")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.warmGrayMedium)

                    Text("No microphones detected")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Text("Please connect a microphone and tap refresh")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .accessibilityIdentifier("noDevicesMessage")
            } else {
                // Device picker
                VStack(spacing: 8) {
                    ForEach(availableDevices) { device in
                        MicrophoneDeviceRow(
                            device: device,
                            isSelected: selectedDeviceId == device.id || (selectedDeviceId == nil && device.isDefault),
                            isDisconnected: device.isDisconnected,
                            onSelect: { selectDevice(device) }
                        )
                    }
                }

                // Reconnection hint (shown when selected device was disconnected)
                if showDeviceReconnectHint {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(Color.info)
                            .font(.caption)

                        Text("Your previously selected device was disconnected. System default is now being used.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button {
                            showDeviceReconnectHint = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.tertiary)
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(10)
                    .background(Color.info.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
                    .accessibilityIdentifier("deviceReconnectHint")
                }
            }
        }
        .accessibilityIdentifier("microphonePickerSection")
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isLoadingDevices)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: deviceError != nil)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showDeviceReconnectHint)
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
        // Clear previous error and show loading state
        deviceError = nil
        isLoadingDevices = true

        // MED-10 Fix: Removed 300ms artificial delay - it's unnecessary
        // and creates poor UX. Loading indicator will show briefly if needed.

        // Get available audio input devices
        var devices: [AudioDevice] = []
        let previousSelectedId = selectedDeviceId

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
                isDefault: device.uniqueID == defaultDevice?.uniqueID,
                isDisconnected: false
            ))
        }

        // Check if previously selected device is no longer available
        if let previousId = previousSelectedId,
           !devices.contains(where: { $0.id == previousId }) {
            // Device was disconnected - show hint and reset to default
            showDeviceReconnectHint = true
            // HIGH-8 Fix: Only update settings (single source of truth)
            settings.audio.inputDeviceId = nil
            saveSettings()
        }
        #endif

        // If no devices found, show error
        if devices.isEmpty {
            deviceError = .noDevicesFound
        }

        availableDevices = devices
        isLoadingDevices = false
    }

    private func selectDevice(_ device: AudioDevice) {
        // HIGH-8 Fix: Only update settings (single source of truth)
        // The selectedDeviceId computed property automatically reflects this change
        settings.audio.inputDeviceId = device.id
        saveSettings()
    }

    private func saveSettings() {
        isSaving = true
        do {
            try settingsService.save(settings)
            // MED-11 Fix: Clear any previous save error on success
            saveError = nil
        } catch {
            // MED-11 Fix: Set saveError to show alert to user instead of silently swallowing
            saveError = "Failed to save audio settings: \(error.localizedDescription)"
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
    var isDisconnected: Bool = false
}

// MARK: - Audio Device Error

/// Errors that can occur when detecting audio devices
private enum AudioDeviceError: Equatable {
    case noDevicesFound
    case detectionFailed(String)
    case deviceDisconnected(String)

    var title: String {
        switch self {
        case .noDevicesFound:
            return "No Microphones Found"
        case .detectionFailed:
            return "Detection Failed"
        case .deviceDisconnected:
            return "Device Disconnected"
        }
    }

    var message: String {
        switch self {
        case .noDevicesFound:
            return "No audio input devices were detected. Please connect a microphone and try again."
        case .detectionFailed(let detail):
            return "Failed to detect audio devices: \(detail)"
        case .deviceDisconnected(let deviceName):
            return "The microphone '\(deviceName)' has been disconnected."
        }
    }

    var icon: String {
        switch self {
        case .noDevicesFound:
            return "mic.slash"
        case .detectionFailed:
            return "exclamationmark.triangle.fill"
        case .deviceDisconnected:
            return "cable.connector.horizontal"
        }
    }
}

// MARK: - Audio Device Error Banner

/// Error banner for audio device issues
private struct AudioDeviceErrorBanner: View {
    let error: AudioDeviceError
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: error.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(Color.errorRed)

                VStack(alignment: .leading, spacing: 2) {
                    Text(error.title)
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    Text(error.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                Spacer()

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss error")
            }

            // Retry button
            Button(action: onRetry) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .font(.caption)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.warmAmber)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Retry device detection")
        }
        .padding(12)
        .background(Color.errorRed.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.errorRed.opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(error.title). \(error.message)")
        .accessibilityIdentifier("audioDeviceErrorBanner")
    }
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
    var isDisconnected: Bool = false
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Microphone icon
                Image(systemName: isDisconnected ? "mic.slash" : "mic.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(iconColor)
                    .frame(width: 24)

                // Device info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(device.name)
                            .font(.body)
                            .foregroundStyle(isDisconnected ? .secondary : .primary)

                        if isDisconnected {
                            Text("Disconnected")
                                .font(.caption2)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.errorRed)
                                .clipShape(Capsule())
                        }
                    }

                    if device.isDefault && !isDisconnected {
                        Text("System Default")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Selection indicator
                if isSelected && !isDisconnected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.warmAmber)
                }
            }
            .padding(12)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(borderOverlay)
        }
        .buttonStyle(.plain)
        .disabled(isDisconnected)
        .accessibilityIdentifier("microphoneDevice_\(device.id)")
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Computed Properties

    private var iconColor: Color {
        if isDisconnected {
            return Color.errorRed
        } else if isSelected {
            return Color.warmAmber
        } else {
            return Color.warmGrayDark
        }
    }

    private var backgroundColor: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(backgroundFillColor)
    }

    private var backgroundFillColor: Color {
        if isDisconnected {
            return Color.errorRed.opacity(0.05)
        } else if isSelected {
            return Color.warmAmber.opacity(0.1)
        } else {
            return Color.warmGray.opacity(0.3)
        }
    }

    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(borderColor, lineWidth: 1)
    }

    private var borderColor: Color {
        if isDisconnected {
            return Color.errorRed.opacity(0.3)
        } else if isSelected {
            return Color.warmAmber
        } else {
            return Color.clear
        }
    }

    private var accessibilityDescription: String {
        var description = device.name
        if isSelected {
            description += ", selected"
        }
        if device.isDefault {
            description += ", system default"
        }
        if isDisconnected {
            description += ", disconnected"
        }
        return description
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
