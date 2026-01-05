// SiriStyleRingWaves.swift
// macOS Local Speech-to-Text Application
//
// Siri-inspired concentric ring waveform visualization with prismatic
// colors, audio-reactive pulsing, and spring physics animation.

import SwiftUI

// MARK: - Siri Style Ring Waves

/// A Siri-inspired concentric ring waveform that pulses outward from center
/// with prismatic gradient strokes and audio-reactive animation.
struct SiriStyleRingWaves: View {
    /// Current audio level (0.0 - 1.0)
    let audioLevel: Float

    /// Whether currently recording (changes color scheme)
    let isRecording: Bool

    /// Number of concentric rings
    private let ringCount = 5

    /// Animation time driver for breathing effect
    @State private var breathPhase: Double = 0

    /// Smooth audio level for fluid response
    @State private var smoothLevel: Float = 0

    /// Staggered ring animation phases
    @State private var ringPhases: [Double] = Array(repeating: 0, count: 5)

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let maxRadius = min(size.width, size.height) * 0.45

            // Draw rings from outer to inner for proper layering
            for ringIndex in (0..<ringCount).reversed() {
                drawRing(
                    context: context,
                    center: center,
                    maxRadius: maxRadius,
                    ringIndex: ringIndex,
                    audioLevel: CGFloat(smoothLevel),
                    breathPhase: breathPhase
                )
            }

            // Draw center glow when audio active
            if smoothLevel > 0.05 {
                drawCenterGlow(
                    context: context,
                    center: center,
                    radius: maxRadius * 0.15,
                    audioLevel: CGFloat(smoothLevel)
                )
            }
        }
        .onAppear {
            // Start breathing animation
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                breathPhase = 1
            }
        }
        .onChange(of: audioLevel) { _, newValue in
            // Smooth the audio level with spring animation
            withAnimation(.spring(response: 0.2, dampingFraction: 0.65)) {
                smoothLevel = newValue
            }
        }
    }

    // MARK: - Drawing Functions

    private func drawRing(
        context: GraphicsContext,
        center: CGPoint,
        maxRadius: CGFloat,
        ringIndex: Int,
        audioLevel: CGFloat,
        breathPhase: Double
    ) {
        let ringFraction = CGFloat(ringIndex + 1) / CGFloat(ringCount)

        // Base radius with staggered wave propagation
        let staggerDelay = Double(ringIndex) * 0.15
        let wavePhase = (breathPhase + staggerDelay).truncatingRemainder(dividingBy: 1.0)

        // Ring radius calculation
        // - Base radius from ring position
        // - Audio-reactive expansion
        // - Subtle breathing modulation
        let breathMod = sin(wavePhase * .pi * 2) * 0.03
        let audioExpansion = audioLevel * 0.2 * (1.0 - ringFraction * 0.5) // Inner rings expand more
        let baseRadius = maxRadius * ringFraction
        let radius = baseRadius * (1.0 + audioExpansion + CGFloat(breathMod))

        // Ring opacity
        // - Outer rings fade more
        // - Audio boosts opacity
        let baseOpacity = 0.8 - Double(ringIndex) * 0.12
        let audioOpacityBoost = Double(audioLevel) * 0.3 * (1.0 - Double(ringFraction) * 0.3)
        let opacity = min(1.0, baseOpacity + audioOpacityBoost)

        // Line width varies by ring and audio
        let baseLineWidth: CGFloat = 3.0 - CGFloat(ringIndex) * 0.4
        let audioLineWidth = audioLevel * 2.0 * (1.0 - ringFraction * 0.5)
        let lineWidth = max(1.0, baseLineWidth + audioLineWidth)

        // Create ring path
        let ringPath = Circle().path(in: CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))

        // Get gradient colors based on state
        let colors = ringColors(for: ringIndex, isRecording: isRecording)

        // Pre-compute gradient colors to help the type checker
        let gradientColors: [Color] = [
            colors.0.opacity(opacity),
            colors.1.opacity(opacity * 0.9),
            colors.2.opacity(opacity * 0.8),
            colors.3.opacity(opacity * 0.9),
            colors.0.opacity(opacity)
        ]

        let gradient = Gradient(colors: gradientColors)

        // Create conic (angular) gradient shading
        let conicGradient = GraphicsContext.Shading.conicGradient(
            gradient,
            center: center,
            angle: Angle.degrees(Double(ringIndex) * 30)
        )

        let strokeStyle = StrokeStyle(lineWidth: lineWidth, lineCap: .round)
        context.stroke(ringPath, with: conicGradient, style: strokeStyle)

        // Add glow effect for inner rings with high audio
        if ringIndex < 2 && audioLevel > 0.3 {
            var glowContext = context
            glowContext.blendMode = .plusLighter

            let glowOpacity = Double(audioLevel - 0.3) * 0.4
            glowContext.stroke(
                ringPath,
                with: .color(colors.0.opacity(glowOpacity)),
                style: StrokeStyle(lineWidth: lineWidth * 3)
            )
        }
    }

    private func drawCenterGlow(
        context: GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        audioLevel: CGFloat
    ) {
        let glowRadius = radius * (1.0 + audioLevel * 0.5)

        // Center glow path
        let glowPath = Circle().path(in: CGRect(
            x: center.x - glowRadius,
            y: center.y - glowRadius,
            width: glowRadius * 2,
            height: glowRadius * 2
        ))

        // Radial gradient for center glow
        let coreColor = isRecording ? Color.liquidRecordingCore : Color.liquidPrismaticBlue

        context.fill(
            glowPath,
            with: .radialGradient(
                Gradient(colors: [
                    coreColor.opacity(Double(audioLevel) * 0.6),
                    coreColor.opacity(Double(audioLevel) * 0.3),
                    .clear
                ]),
                center: center,
                startRadius: 0,
                endRadius: glowRadius
            )
        )
    }

    // MARK: - Color Helpers

    private func ringColors(for ringIndex: Int, isRecording: Bool) -> (Color, Color, Color, Color) {
        if isRecording {
            // Recording: warm coral to orange gradient
            switch ringIndex {
            case 0:
                return (
                    Color.liquidRecordingCore,
                    Color.liquidRecordingMid,
                    Color.liquidPrismaticOrange,
                    Color.liquidRecordingMid
                )
            case 1:
                return (
                    Color.liquidRecordingMid,
                    Color.liquidPrismaticOrange,
                    Color.liquidPrismaticYellow,
                    Color.liquidRecordingMid
                )
            case 2:
                return (
                    Color.liquidPrismaticOrange,
                    Color.liquidPrismaticYellow,
                    Color.liquidPrismaticPink,
                    Color.liquidPrismaticOrange
                )
            case 3:
                return (
                    Color.liquidPrismaticPink.opacity(0.8),
                    Color.liquidRecordingOuter.opacity(0.7),
                    Color.liquidPrismaticOrange.opacity(0.6),
                    Color.liquidPrismaticPink.opacity(0.8)
                )
            default:
                return (
                    Color.liquidRecordingOuter.opacity(0.5),
                    Color.liquidPrismaticPink.opacity(0.4),
                    Color.liquidPrismaticOrange.opacity(0.3),
                    Color.liquidRecordingOuter.opacity(0.5)
                )
            }
        } else {
            // Idle/Transcribing: cool prismatic colors
            switch ringIndex {
            case 0:
                return (
                    Color.liquidPrismaticBlue,
                    Color.liquidPrismaticCyan,
                    Color.liquidPrismaticPurple,
                    Color.liquidPrismaticPink
                )
            case 1:
                return (
                    Color.liquidPrismaticCyan,
                    Color.liquidPrismaticPurple,
                    Color.liquidPrismaticPink,
                    Color.liquidPrismaticBlue
                )
            case 2:
                return (
                    Color.liquidPrismaticPurple,
                    Color.liquidPrismaticBlue,
                    Color.liquidPrismaticCyan,
                    Color.liquidPrismaticPurple
                )
            case 3:
                return (
                    Color.liquidPrismaticBlue.opacity(0.7),
                    Color.liquidPrismaticCyan.opacity(0.6),
                    Color.liquidPrismaticPurple.opacity(0.5),
                    Color.liquidPrismaticBlue.opacity(0.7)
                )
            default:
                return (
                    Color.liquidPrismaticCyan.opacity(0.4),
                    Color.liquidPrismaticBlue.opacity(0.3),
                    Color.liquidPrismaticPurple.opacity(0.3),
                    Color.liquidPrismaticCyan.opacity(0.4)
                )
            }
        }
    }
}

// MARK: - Preview

#Preview("Siri Style Ring Waves") {
    SiriStyleRingWavesPreview()
}

private struct SiriStyleRingWavesPreview: View {
    @State private var level: Float = 0.0
    @State private var isRecording = false
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 24) {
            // Waveform display
            SiriStyleRingWaves(audioLevel: level, isRecording: isRecording)
                .frame(width: 200, height: 200)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                )

            // Controls
            VStack(spacing: 16) {
                // Recording toggle
                Toggle("Recording Mode", isOn: $isRecording)
                    .toggleStyle(.switch)
                    .tint(Color.liquidRecordingCore)

                // Audio level slider
                VStack(alignment: .leading, spacing: 4) {
                    Text("Audio Level: \(String(format: "%.2f", level))")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Slider(
                        value: Binding(
                            get: { Double(level) },
                            set: { level = Float($0) }
                        ),
                        in: 0...1
                    )
                    .tint(isRecording ? Color.liquidRecordingCore : Color.liquidPrismaticBlue)
                }

                // Simulate audio button
                Button(isAnimating ? "Stop Simulation" : "Simulate Audio") {
                    isAnimating.toggle()
                    if isAnimating {
                        simulateAudio()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(isRecording ? Color.liquidRecordingMid : Color.liquidPrismaticPurple)
            }
            .padding()
            .frame(width: 250)
        }
        .padding(32)
        .background(Color.black.opacity(0.85))
    }

    private func simulateAudio() {
        guard isAnimating else { return }

        // Simulate audio level changes
        let newLevel = Float.random(in: 0.1...0.9)

        withAnimation(.spring(response: 0.15, dampingFraction: 0.7)) {
            level = newLevel
        }

        // Schedule next update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            simulateAudio()
        }
    }
}
