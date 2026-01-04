// HoldToRecordOverlay.swift
// macOS Local Speech-to-Text Application
//
// Minimal overlay UI for hold-to-record mode.
// Displays status, compact waveform, and recording indicator.
// NO buttons - releasing the hotkey stops recording.

import SwiftUI

/// Minimal overlay that appears during hold-to-record mode
struct HoldToRecordOverlay: View {
    // MARK: - Properties

    /// Current recording status
    var status: RecordingStatus

    /// Current audio level (0.0 - 1.0)
    var audioLevel: Float

    // MARK: - State

    /// Controls pulsing animation for recording indicator
    @State private var isPulsing: Bool = false

    /// Controls entrance/exit animations
    @State private var isVisible: Bool = false

    // MARK: - Recording Status

    /// Represents the current state of the hold-to-record flow
    enum RecordingStatus: Equatable {
        case recording
        case transcribing
        case pasting
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 12) {
            statusText
            waveformOrProgress
            recordingIndicator
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: 200, height: 80)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
        .scaleEffect(isVisible ? 1.0 : 0.85)
        .opacity(isVisible ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isVisible = true
            }
            startPulsingAnimation()
        }
        .onChange(of: status) { _, _ in
            // Restart animation on status change with spring effect
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                // Trigger re-layout for status change
            }
        }
        .accessibilityIdentifier("holdToRecordOverlay")
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Subviews

    /// Status text based on current state
    private var statusText: some View {
        Text(statusMessage)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.primary)
            .accessibilityIdentifier("holdToRecordStatus")
    }

    /// Compact waveform during recording, progress indicator otherwise
    @ViewBuilder
    private var waveformOrProgress: some View {
        switch status {
        case .recording:
            CompactWaveformView(audioLevel: audioLevel)
                .frame(height: 20)
                .accessibilityIdentifier("compactWaveform")

        case .transcribing, .pasting:
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 12, height: 12)

                Text(status == .transcribing ? "Processing audio..." : "Inserting text...")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("progressIndicator")
        }
    }

    /// Pulsing amber recording indicator dot
    private var recordingIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(indicatorColor)
                .frame(width: 8, height: 8)
                .scaleEffect(isPulsing && status == .recording ? 1.3 : 1.0)
                .opacity(isPulsing && status == .recording ? 0.7 : 1.0)

            Text(indicatorText)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .accessibilityIdentifier("recordingIndicator")
    }

    // MARK: - Computed Properties

    /// Message displayed based on current status
    private var statusMessage: String {
        switch status {
        case .recording:
            return "Recording..."
        case .transcribing:
            return "Transcribing..."
        case .pasting:
            return "Pasting..."
        }
    }

    /// Color for the indicator dot
    private var indicatorColor: Color {
        switch status {
        case .recording:
            return .warmAmber
        case .transcribing:
            return .warmAmberLight
        case .pasting:
            return .successGreen
        }
    }

    /// Text shown below indicator
    private var indicatorText: String {
        switch status {
        case .recording:
            return "Release to stop"
        case .transcribing:
            return "Please wait"
        case .pasting:
            return "Almost done"
        }
    }

    /// Accessibility description for VoiceOver
    private var accessibilityDescription: String {
        switch status {
        case .recording:
            return "Recording in progress. Release hotkey to stop. Audio level at \(Int(audioLevel * 100)) percent."
        case .transcribing:
            return "Transcribing audio. Please wait."
        case .pasting:
            return "Pasting transcribed text."
        }
    }

    // MARK: - Private Methods

    /// Start the pulsing animation for the recording indicator
    private func startPulsingAnimation() {
        withAnimation(
            .easeInOut(duration: 0.8)
            .repeatForever(autoreverses: true)
        ) {
            isPulsing = true
        }
    }
}

// MARK: - Compact Waveform View

/// A compact waveform visualization for the hold-to-record overlay
private struct CompactWaveformView: View {
    /// Current audio level (0.0 - 1.0)
    let audioLevel: Float

    /// Number of bars in the compact waveform
    private let barCount: Int = 12

    /// Previous audio levels for smooth transitions
    @State private var levelHistory: [Float]

    init(audioLevel: Float) {
        self.audioLevel = audioLevel
        self._levelHistory = State(initialValue: Array(repeating: 0.0, count: 12))
    }

    var body: some View {
        Canvas { context, size in
            let barWidth = size.width / CGFloat(barCount)
            let spacing: CGFloat = 2
            let effectiveBarWidth = max(1, barWidth - spacing)

            for index in 0..<barCount {
                // Get historical level for this bar
                let historyIndex = (levelHistory.count - 1 - index) % levelHistory.count
                let level = CGFloat(levelHistory[historyIndex])

                // Calculate bar height with minimum
                let minHeight: CGFloat = 2
                let maxHeight = size.height * 0.9
                let barHeight = max(minHeight, level * maxHeight)

                // Calculate positions
                let xPos = CGFloat(index) * barWidth
                let yPos = (size.height - barHeight) / 2

                // Create bar rectangle
                let barRect = CGRect(
                    x: xPos,
                    y: yPos,
                    width: effectiveBarWidth,
                    height: barHeight
                )

                // Determine color based on level
                let barColor = colorForLevel(level: Float(level))

                // Draw rounded bar
                let path = RoundedRectangle(cornerRadius: effectiveBarWidth / 2)
                    .path(in: barRect)

                context.fill(path, with: .color(barColor))
            }
        }
        .onChange(of: audioLevel) { _, newValue in
            updateLevelHistory(newLevel: newValue)
        }
        .accessibilityHidden(true)
    }

    /// Update level history for smooth wave animation
    private func updateLevelHistory(newLevel: Float) {
        guard !levelHistory.isEmpty else { return }
        levelHistory.removeFirst()
        levelHistory.append(min(1.0, max(0.0, newLevel)))
    }

    /// Determine color based on audio level
    private func colorForLevel(level: Float) -> Color {
        switch level {
        case 0.0..<0.3:
            return .warmAmberLight.opacity(0.6)
        case 0.3..<0.7:
            return .warmAmber
        default:
            return .warmAmber
        }
    }
}

// MARK: - Previews

#Preview("Recording") {
    HoldToRecordOverlay(status: .recording, audioLevel: 0.5)
        .padding(40)
        .background(Color.gray.opacity(0.2))
}

#Preview("Transcribing") {
    HoldToRecordOverlay(status: .transcribing, audioLevel: 0.0)
        .padding(40)
        .background(Color.gray.opacity(0.2))
}

#Preview("Pasting") {
    HoldToRecordOverlay(status: .pasting, audioLevel: 0.0)
        .padding(40)
        .background(Color.gray.opacity(0.2))
}

#Preview("Animated") {
    HoldToRecordOverlayAnimatedPreview()
}

/// Preview helper for animated waveform
private struct HoldToRecordOverlayAnimatedPreview: View {
    @State private var level: Float = 0.5
    @State private var status: HoldToRecordOverlay.RecordingStatus = .recording
    @State private var previewTimer: Timer?

    var body: some View {
        VStack(spacing: 30) {
            HoldToRecordOverlay(status: status, audioLevel: level)

            Picker("Status", selection: $status) {
                Text("Recording").tag(HoldToRecordOverlay.RecordingStatus.recording)
                Text("Transcribing").tag(HoldToRecordOverlay.RecordingStatus.transcribing)
                Text("Pasting").tag(HoldToRecordOverlay.RecordingStatus.pasting)
            }
            .pickerStyle(.segmented)
            .frame(width: 250)
        }
        .padding(40)
        .background(Color.gray.opacity(0.2))
        .onAppear {
            previewTimer?.invalidate()
            previewTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                Task { @MainActor in
                    if status == .recording {
                        level = Float.random(in: 0.1...0.9)
                    }
                }
            }
        }
        .onDisappear {
            previewTimer?.invalidate()
            previewTimer = nil
        }
    }
}
