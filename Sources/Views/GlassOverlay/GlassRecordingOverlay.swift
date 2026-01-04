// GlassRecordingOverlay.swift
// macOS Local Speech-to-Text Application
//
// Part 1: Glass Recording Overlay
// Main glass panel view for recording/transcribing status
// Positioned at bottom center of screen with pill-shaped design

import SwiftUI

/// Glass Recording Overlay - A minimal, pill-shaped status indicator
/// Displays recording waveform, status text, and timer
struct GlassRecordingOverlay: View {
    // MARK: - State Enum

    /// Represents the current state of the overlay
    enum OverlayState: Equatable {
        case recording
        case transcribing

        var statusText: String {
            switch self {
            case .recording:
                return "Recording..."
            case .transcribing:
                return "Transcribing..."
            }
        }

        var accessibilityLabel: String {
            switch self {
            case .recording:
                return "Recording in progress"
            case .transcribing:
                return "Transcribing audio"
            }
        }
    }

    // MARK: - Properties

    /// Current state of the overlay
    let state: OverlayState

    /// Current audio level (0.0 - 1.0) for waveform visualization
    let audioLevel: Float

    /// Elapsed recording time in seconds
    let elapsedTime: TimeInterval

    // MARK: - State

    /// Controls entrance/exit animations
    @State private var isVisible: Bool = false

    /// Controls pulsing animation for recording indicator
    @State private var isPulsing: Bool = false

    // MARK: - Constants

    /// Overlay dimensions
    private let overlayWidth: CGFloat = 300
    private let overlayHeight: CGFloat = 80
    private let cornerRadius: CGFloat = 24

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            // Recording indicator dot
            recordingIndicator

            // Waveform or spinner based on state
            centerContent

            // Status text
            statusTextView

            // Timer display (only in recording state)
            if state == .recording {
                timerView
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(width: overlayWidth, height: overlayHeight)
        .background {
            // Glass material background
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.ultraThinMaterial)
                .overlay {
                    // Subtle white border for glass edge effect
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        }
        .scaleEffect(isVisible ? 1.0 : 0.85)
        .opacity(isVisible ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                isVisible = true
            }
            startPulsingAnimation()
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("glassRecordingOverlay")
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Subviews

    /// Pulsing recording indicator dot
    private var recordingIndicator: some View {
        Circle()
            .fill(indicatorColor)
            .frame(width: 12, height: 12)
            .scaleEffect(isPulsing && state == .recording ? 1.2 : 1.0)
            .opacity(isPulsing && state == .recording ? 0.7 : 1.0)
            .accessibilityIdentifier("recordingIndicatorDot")
    }

    /// Center content - waveform for recording, spinner for transcribing
    @ViewBuilder
    private var centerContent: some View {
        switch state {
        case .recording:
            DynamicWaveformView(audioLevel: audioLevel)
                .frame(width: 120, height: 40)
                .accessibilityIdentifier("overlayWaveform")

        case .transcribing:
            ProgressView()
                .scaleEffect(0.8)
                .frame(width: 40, height: 40)
                .accessibilityIdentifier("transcribingSpinner")
        }
    }

    /// Status text view
    private var statusTextView: some View {
        Text(state.statusText)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.primary)
            .accessibilityIdentifier("overlayStatusText")
    }

    /// Timer display showing elapsed recording time
    private var timerView: some View {
        Text(formattedTime)
            .font(.system(size: 14, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("overlayTimer")
            .accessibilityLabel("Recording time \(formattedTimeAccessible)")
    }

    // MARK: - Computed Properties

    /// Color for the recording indicator dot
    private var indicatorColor: Color {
        switch state {
        case .recording:
            return .warmAmber
        case .transcribing:
            return .warmAmberLight.opacity(0.6)
        }
    }

    /// Formatted time string (M:SS format)
    private var formattedTime: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Accessible time description
    private var formattedTimeAccessible: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        if minutes > 0 {
            return "\(minutes) minute\(minutes == 1 ? "" : "s") \(seconds) second\(seconds == 1 ? "" : "s")"
        } else {
            return "\(seconds) second\(seconds == 1 ? "" : "s")"
        }
    }

    /// Full accessibility description
    private var accessibilityDescription: String {
        switch state {
        case .recording:
            return "\(state.accessibilityLabel). \(formattedTimeAccessible). Audio level at \(Int(audioLevel * 100)) percent."
        case .transcribing:
            return "\(state.accessibilityLabel). Please wait."
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

// MARK: - Overlay Container

/// Container view that positions the overlay at the bottom center of the screen
struct GlassRecordingOverlayContainer: View {
    /// Current state of the overlay
    let state: GlassRecordingOverlay.OverlayState

    /// Current audio level (0.0 - 1.0)
    let audioLevel: Float

    /// Elapsed recording time in seconds
    let elapsedTime: TimeInterval

    /// Distance from bottom of screen
    private let bottomOffset: CGFloat = 100

    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()

                GlassRecordingOverlay(
                    state: state,
                    audioLevel: audioLevel,
                    elapsedTime: elapsedTime
                )
                .padding(.bottom, bottomOffset)
            }
            .frame(width: geometry.size.width)
        }
        .ignoresSafeArea()
        .accessibilityIdentifier("glassRecordingOverlayContainer")
    }
}

// MARK: - Previews

#Preview("Recording State") {
    ZStack {
        // Simulated desktop background
        LinearGradient(
            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        GlassRecordingOverlayContainer(
            state: .recording,
            audioLevel: 0.5,
            elapsedTime: 3
        )
    }
}

#Preview("Transcribing State") {
    ZStack {
        // Simulated desktop background
        LinearGradient(
            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        GlassRecordingOverlayContainer(
            state: .transcribing,
            audioLevel: 0.0,
            elapsedTime: 15
        )
    }
}

#Preview("Recording - Long Duration") {
    ZStack {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()

        GlassRecordingOverlay(
            state: .recording,
            audioLevel: 0.7,
            elapsedTime: 125 // 2:05
        )
    }
}

#Preview("Overlay Only - Recording") {
    GlassRecordingOverlay(
        state: .recording,
        audioLevel: 0.6,
        elapsedTime: 5
    )
    .padding(40)
    .background(Color.gray.opacity(0.2))
}

#Preview("Overlay Only - Transcribing") {
    GlassRecordingOverlay(
        state: .transcribing,
        audioLevel: 0.0,
        elapsedTime: 10
    )
    .padding(40)
    .background(Color.gray.opacity(0.2))
}

#Preview("Animated Demo") {
    GlassRecordingOverlayAnimatedPreview()
}

/// Preview helper for animated overlay demo
private struct GlassRecordingOverlayAnimatedPreview: View {
    @State private var audioLevel: Float = 0.5
    @State private var elapsedTime: TimeInterval = 0
    @State private var state: GlassRecordingOverlay.OverlayState = .recording
    @State private var audioTimer: Timer?
    @State private var timeTimer: Timer?

    var body: some View {
        ZStack {
            // Simulated desktop background
            LinearGradient(
                colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack {
                // State picker at top
                Picker("State", selection: $state) {
                    Text("Recording").tag(GlassRecordingOverlay.OverlayState.recording)
                    Text("Transcribing").tag(GlassRecordingOverlay.OverlayState.transcribing)
                }
                .pickerStyle(.segmented)
                .frame(width: 250)
                .padding(.top, 40)

                Spacer()

                // Overlay at bottom
                GlassRecordingOverlay(
                    state: state,
                    audioLevel: audioLevel,
                    elapsedTime: elapsedTime
                )
                .padding(.bottom, 100)
            }
        }
        .onAppear {
            startAnimations()
        }
        .onDisappear {
            stopAnimations()
        }
        .onChange(of: state) { _, _ in
            // Reset audio when switching states
            if state == .transcribing {
                audioLevel = 0
            }
        }
    }

    private func startAnimations() {
        // Simulate audio level changes
        audioTimer?.invalidate()
        audioTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in
            Task { @MainActor in
                if state == .recording {
                    // Simulate natural speech patterns
                    let base = Float.random(in: 0.3...0.8)
                    let variation = Float.random(in: -0.15...0.15)
                    audioLevel = max(0, min(1, base + variation))
                }
            }
        }

        // Increment timer
        timeTimer?.invalidate()
        timeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                elapsedTime += 1
            }
        }
    }

    private func stopAnimations() {
        audioTimer?.invalidate()
        audioTimer = nil
        timeTimer?.invalidate()
        timeTimer = nil
    }
}
