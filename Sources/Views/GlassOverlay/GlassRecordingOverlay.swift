// GlassRecordingOverlay.swift
// macOS Local Speech-to-Text Application
//
// Simplified Liquid Glass Recording Overlay
// Clean glass background with Aurora waveform focus

import SwiftUI

/// Liquid Glass Recording Overlay - Clean floating glass indicator
/// Features Aurora waveform visualization with subtle prismatic effects
struct GlassRecordingOverlay: View {
    // MARK: - State Enum

    enum OverlayState: Equatable {
        case recording
        case transcribing

        var statusText: String {
            switch self {
            case .recording: return "Recording..."
            case .transcribing: return "Transcribing..."
            }
        }

        var accessibilityLabel: String {
            switch self {
            case .recording: return "Recording in progress"
            case .transcribing: return "Transcribing audio"
            }
        }
    }

    // MARK: - Properties

    let state: OverlayState
    let audioLevel: Float
    let elapsedTime: TimeInterval
    let waveformStyle: WaveformStyleOption

    // MARK: - Animation State

    @State private var isVisible: Bool = false
    @State private var glassRotation: Double = 0

    // MARK: - Constants

    private let overlayWidth: CGFloat = 300
    private let overlayHeight: CGFloat = 80
    private let cornerRadius: CGFloat = 24

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            // Glowing orb indicator
            orbIndicator

            // Aurora waveform or transcribing animation
            centerVisualization
                .frame(width: 100, height: 44)

            // Status and timer
            VStack(alignment: .leading, spacing: 2) {
                statusTextView
                if state == .recording {
                    timerView
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(width: overlayWidth, height: overlayHeight)
        .background { glassBackground }
        .overlay { glassOverlay }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 10)
        .shadow(color: .black.opacity(0.05), radius: 40, x: 0, y: 20)
        .scaleEffect(isVisible ? 1.0 : 0.85)
        .opacity(isVisible ? 1.0 : 0.0)
        .onAppear {
            startAnimations()
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("glassRecordingOverlay")
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Glass Background (Apple Liquid Glass Style)

    private var glassBackground: some View {
        ZStack {
            // Base: Ultra-transparent frosted glass
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.25))

            // Very soft white fill for the frosted look
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.08))

            // Inner glow effect (soft white around edges)
            RoundedRectangle(cornerRadius: cornerRadius - 2, style: .continuous)
                .stroke(Color.white.opacity(0.3), lineWidth: 3)
                .blur(radius: 3)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

            // Top specular highlight
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.25),
                            Color.white.opacity(0.05),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: UnitPoint(x: 0.5, y: 0.35)
                    )
                )
        }
    }

    // MARK: - Glass Overlay (Soft Edge Glow)

    private var glassOverlay: some View {
        ZStack {
            // Soft outer glow (creates the floating glass effect)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                .blur(radius: 0.5)

            // Very subtle inner border
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
        }
    }

    // MARK: - Orb Indicator

    private var orbIndicator: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            (state == .recording ? Color.liquidRecordingCore : Color.liquidPrismaticBlue).opacity(0.25),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 16
                    )
                )
                .frame(width: 32, height: 32)

            // Main orb
            Circle()
                .fill(
                    RadialGradient(
                        colors: state == .recording ? [
                            Color.liquidRecordingCore,
                            Color.liquidRecordingMid
                        ] : [
                            Color.liquidPrismaticBlue,
                            Color.liquidPrismaticPurple
                        ],
                        center: UnitPoint(x: 0.35, y: 0.35),
                        startRadius: 0,
                        endRadius: 10
                    )
                )
                .frame(width: 12, height: 12)

            // Inner highlight
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.8),
                            Color.white.opacity(0.2),
                            .clear
                        ],
                        center: UnitPoint(x: 0.3, y: 0.3),
                        startRadius: 0,
                        endRadius: 4
                    )
                )
                .frame(width: 5, height: 5)
                .offset(x: -2, y: -2)
        }
        .accessibilityIdentifier("recordingIndicatorDot")
    }

    // MARK: - Center Visualization

    @ViewBuilder
    private var centerVisualization: some View {
        switch state {
        case .recording:
            // Dynamic waveform based on user settings
            WaveformVisualization(style: waveformStyle, audioLevel: audioLevel, isRecording: true)
                .accessibilityIdentifier("overlayWaveform")

        case .transcribing:
            // Prismatic spinner
            ZStack {
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [
                                Color.liquidPrismaticBlue,
                                Color.liquidPrismaticPurple,
                                Color.liquidPrismaticPink,
                                Color.liquidPrismaticBlue
                            ],
                            center: .center,
                            angle: .degrees(glassRotation * 2)
                        ),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )
                    .frame(width: 28, height: 28)

                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(Color.white.opacity(0.8), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .frame(width: 28, height: 28)
                    .rotationEffect(.degrees(glassRotation * 3))
            }
            .accessibilityIdentifier("transcribingSpinner")
        }
    }

    // MARK: - Status Text

    private var statusTextView: some View {
        Text(state.statusText)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary)
            .accessibilityIdentifier("overlayStatusText")
    }

    // MARK: - Timer View

    private var timerView: some View {
        Text(formattedTime)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color.liquidPrismaticCyan,
                        Color.liquidPrismaticBlue
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .accessibilityIdentifier("overlayTimer")
            .accessibilityLabel("Recording time \(formattedTimeAccessible)")
    }

    // MARK: - Computed Properties

    private var formattedTime: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var formattedTimeAccessible: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        if minutes > 0 {
            return "\(minutes) minute\(minutes == 1 ? "" : "s") \(seconds) second\(seconds == 1 ? "" : "s")"
        } else {
            return "\(seconds) second\(seconds == 1 ? "" : "s")"
        }
    }

    private var accessibilityDescription: String {
        switch state {
        case .recording:
            return "\(state.accessibilityLabel). \(formattedTimeAccessible). Audio level at \(Int(audioLevel * 100)) percent."
        case .transcribing:
            return "\(state.accessibilityLabel). Please wait."
        }
    }

    // MARK: - Animations

    private func startAnimations() {
        // Entrance animation
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
            isVisible = true
        }

        // Slow continuous glass rotation for prismatic effect
        withAnimation(.linear(duration: 25).repeatForever(autoreverses: false)) {
            glassRotation = 360
        }
    }
}

// MARK: - Overlay Container

struct GlassRecordingOverlayContainer: View {
    let state: GlassRecordingOverlay.OverlayState
    let audioLevel: Float
    let elapsedTime: TimeInterval
    let waveformStyle: WaveformStyleOption

    private let bottomOffset: CGFloat = 100

    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()
                GlassRecordingOverlay(
                    state: state,
                    audioLevel: audioLevel,
                    elapsedTime: elapsedTime,
                    waveformStyle: waveformStyle
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

#Preview("Recording") {
    ZStack {
        LinearGradient(
            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        GlassRecordingOverlayContainer(
            state: .recording,
            audioLevel: 0.6,
            elapsedTime: 5,
            waveformStyle: .aurora
        )
    }
}

#Preview("Transcribing") {
    ZStack {
        LinearGradient(
            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        GlassRecordingOverlayContainer(
            state: .transcribing,
            audioLevel: 0.0,
            elapsedTime: 15,
            waveformStyle: .aurora
        )
    }
}
