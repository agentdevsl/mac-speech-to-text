// LiquidGlassWaveform.swift
// macOS Local Speech-to-Text Application
//
// Aurora-inspired fluid waveform visualization with organic movement,
// prismatic color shifts, and audio-reactive morphing.

import SwiftUI

// MARK: - Aurora Waveform

/// A stunning aurora-like waveform that flows organically and responds to audio
struct AuroraWaveform: View {
    /// Current audio level (0.0 - 1.0)
    let audioLevel: Float

    /// Whether currently recording
    let isRecording: Bool

    /// Animation time driver
    @State private var time: Double = 0

    /// Smooth audio level for fluid response
    @State private var smoothLevel: Float = 0

    var body: some View {
        Canvas { context, size in
            let midY = size.height / 2
            let effectiveLevel = CGFloat(smoothLevel)

            // Draw 5 layered aurora waves
            for waveIndex in 0..<5 {
                drawAuroraWave(
                    context: context,
                    size: size,
                    midY: midY,
                    waveIndex: waveIndex,
                    audioLevel: effectiveLevel,
                    time: time
                )
            }

            // Draw particle sparkles on high audio
            if smoothLevel > 0.4 {
                drawSparkles(context: context, size: size, audioLevel: effectiveLevel, time: time)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                time = 2 * .pi
            }
        }
        .onChange(of: audioLevel) { _, newValue in
            // Smooth the audio level for fluid animation
            withAnimation(.spring(response: 0.15, dampingFraction: 0.7)) {
                smoothLevel = newValue
            }
        }
    }

    private func drawAuroraWave(
        context: GraphicsContext,
        size: CGSize,
        midY: CGFloat,
        waveIndex: Int,
        audioLevel: CGFloat,
        time: Double
    ) {
        let layerOffset = CGFloat(waveIndex)
        let layerOpacity = 0.7 - Double(waveIndex) * 0.12
        let phaseShift = layerOffset * 0.4

        // Base amplitude varies by layer
        let baseAmplitude = size.height * 0.15 * (1.0 - layerOffset * 0.15)
        let audioAmplitude = baseAmplitude * (0.3 + audioLevel * 1.5)

        // Create the wave path
        var path = Path()
        var gradientPath = Path()

        let steps = Int(size.width / 2)

        for i in 0...steps {
            let x = CGFloat(i) * 2
            let progress = x / size.width

            // Complex organic wave combining multiple frequencies
            let freq1 = sin(progress * 3 * .pi + time + phaseShift)
            let freq2 = sin(progress * 5 * .pi + time * 1.3 - phaseShift) * 0.5
            let freq3 = sin(progress * 2 * .pi + time * 0.7 + phaseShift * 2) * 0.3
            let freq4 = cos(progress * 7 * .pi - time * 0.5) * audioLevel * 0.4

            // Envelope to fade edges
            let envelope = sin(progress * .pi)

            // Combine waves
            let waveValue = (freq1 + freq2 + freq3 + freq4) * envelope
            let y = midY + waveValue * audioAmplitude

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
                gradientPath.move(to: CGPoint(x: x, y: midY + size.height / 2))
                gradientPath.addLine(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
                gradientPath.addLine(to: CGPoint(x: x, y: y))
            }
        }

        // Close gradient path
        gradientPath.addLine(to: CGPoint(x: size.width, y: midY + size.height / 2))
        gradientPath.closeSubpath()

        // Choose colors based on recording state and layer
        let colors = waveColors(for: waveIndex, isRecording: isRecording, audioLevel: Float(audioLevel))

        // Draw gradient fill
        context.fill(
            gradientPath,
            with: .linearGradient(
                Gradient(colors: [
                    colors.primary.opacity(layerOpacity * 0.4),
                    colors.secondary.opacity(layerOpacity * 0.2),
                    .clear
                ]),
                startPoint: CGPoint(x: size.width / 2, y: midY - audioAmplitude),
                endPoint: CGPoint(x: size.width / 2, y: midY + size.height / 2)
            )
        )

        // Draw the wave stroke
        context.stroke(
            path,
            with: .linearGradient(
                Gradient(colors: [
                    colors.primary.opacity(layerOpacity),
                    colors.secondary.opacity(layerOpacity),
                    colors.primary.opacity(layerOpacity)
                ]),
                startPoint: CGPoint(x: 0, y: midY),
                endPoint: CGPoint(x: size.width, y: midY)
            ),
            style: StrokeStyle(
                lineWidth: 2.5 - CGFloat(waveIndex) * 0.3,
                lineCap: .round,
                lineJoin: .round
            )
        )

        // Add glow on top layers
        if waveIndex < 2 {
            var glowContext = context
            glowContext.blendMode = .plusLighter
            glowContext.stroke(
                path,
                with: .color(colors.primary.opacity(0.3)),
                style: StrokeStyle(lineWidth: 6 - CGFloat(waveIndex) * 2)
            )
        }
    }

    private func drawSparkles(
        context: GraphicsContext,
        size: CGSize,
        audioLevel: CGFloat,
        time: Double
    ) {
        let sparkleCount = Int(audioLevel * 12)

        for sparkleIndex in 0..<sparkleCount {
            let phase = time * 2 + Double(sparkleIndex) * 0.5

            let xPos = size.width * (CGFloat(sparkleIndex) / CGFloat(max(1, sparkleCount)))
            let yBase = size.height * 0.3 + sin(phase) * size.height * 0.4
            let yPos = yBase + sin(phase * 3) * audioLevel * 20

            let sparkleSize = 2 + audioLevel * 3
            let sparkleOpacity = (sin(phase * 4) + 1) / 2 * Double(audioLevel)

            // Simplified: white sparkles with slight blue tint
            context.fill(
                Circle().path(in: CGRect(x: xPos - sparkleSize / 2, y: yPos - sparkleSize / 2, width: sparkleSize, height: sparkleSize)),
                with: .color(Color.white.opacity(sparkleOpacity))
            )
        }
    }

    private struct WaveColors {
        let primary: Color
        let secondary: Color
    }

    private func waveColors(for layer: Int, isRecording: Bool, audioLevel: Float) -> WaveColors {
        // Warm Minimalism palette - always amber
        let opacity = 1.0 - Double(layer) * 0.15
        return WaveColors(
            primary: Color.amberPrimary.opacity(opacity),
            secondary: Color.amberLight.opacity(opacity * 0.7)
        )
    }
}

// MARK: - Liquid Orb Waveform

/// A circular waveform that pulses and morphs like a liquid orb
struct LiquidOrbWaveform: View {
    let audioLevel: Float
    let isRecording: Bool

    @State private var phase: Double = 0
    @State private var smoothLevel: Float = 0

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let baseRadius = min(size.width, size.height) * 0.35

            // Draw outer glow rings
            for ring in 0..<3 {
                let ringRadius = baseRadius * (1.2 + CGFloat(ring) * 0.15)
                let opacity = 0.2 - Double(ring) * 0.05
                let ringPath = createMorphingCircle(
                    center: center,
                    baseRadius: ringRadius,
                    morphAmount: CGFloat(smoothLevel) * 0.15,
                    phase: phase - Double(ring) * 0.3,
                    detail: 48
                )

                context.stroke(
                    ringPath,
                    with: .color(Color.amberPrimary.opacity(opacity)),
                    lineWidth: 1
                )
            }

            // Main morphing orb
            let orbPath = createMorphingCircle(
                center: center,
                baseRadius: baseRadius,
                morphAmount: CGFloat(smoothLevel) * 0.3 + 0.05,
                phase: phase,
                detail: 64
            )

            // Gradient fill - warm amber theme
            let gradient = Gradient(colors: [
                Color.amberPrimary,
                Color.amberLight.opacity(0.6),
                Color.white.opacity(0.3)
            ])

            // Outer glow
            context.fill(
                orbPath,
                with: .radialGradient(
                    Gradient(colors: [
                        Color.amberPrimary.opacity(0.4),
                        .clear
                    ]),
                    center: center,
                    startRadius: baseRadius * 0.5,
                    endRadius: baseRadius * 1.8
                )
            )

            // Main gradient
            context.fill(
                orbPath,
                with: .radialGradient(
                    gradient,
                    center: CGPoint(x: center.x - baseRadius * 0.2, y: center.y - baseRadius * 0.3),
                    startRadius: 0,
                    endRadius: baseRadius * 1.3
                )
            )

            // Inner highlight
            let highlightCenter = CGPoint(x: center.x - baseRadius * 0.25, y: center.y - baseRadius * 0.35)
            let highlightPath = Ellipse().path(in: CGRect(
                x: highlightCenter.x - baseRadius * 0.25,
                y: highlightCenter.y - baseRadius * 0.15,
                width: baseRadius * 0.5,
                height: baseRadius * 0.3
            ))

            context.fill(
                highlightPath,
                with: .radialGradient(
                    Gradient(colors: [.white.opacity(0.7), .clear]),
                    center: highlightCenter,
                    startRadius: 0,
                    endRadius: baseRadius * 0.3
                )
            )

            // Audio level ring
            if smoothLevel > 0.1 {
                let levelRadius = baseRadius * (1 + CGFloat(smoothLevel) * 0.3)
                let levelPath = Circle().path(in: CGRect(
                    x: center.x - levelRadius,
                    y: center.y - levelRadius,
                    width: levelRadius * 2,
                    height: levelRadius * 2
                ))

                context.stroke(
                    levelPath,
                    with: .color(Color.amberPrimary.opacity(Double(smoothLevel) * 0.5)),
                    lineWidth: 2
                )
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                phase = 2 * .pi
            }
        }
        .onChange(of: audioLevel) { _, newValue in
            withAnimation(.spring(response: 0.15, dampingFraction: 0.7)) {
                smoothLevel = newValue
            }
        }
    }

    private func createMorphingCircle(
        center: CGPoint,
        baseRadius: CGFloat,
        morphAmount: CGFloat,
        phase: Double,
        detail: Int
    ) -> Path {
        var path = Path()

        for i in 0..<detail {
            let angle = (Double(i) / Double(detail)) * 2 * .pi

            // Multiple frequencies for organic shape
            let wave1 = sin(angle * 3 + phase) * morphAmount
            let wave2 = sin(angle * 5 - phase * 1.2) * morphAmount * 0.5
            let wave3 = cos(angle * 4 + phase * 0.8) * morphAmount * 0.3

            let radiusMod = 1 + wave1 + wave2 + wave3
            let radius = baseRadius * radiusMod

            let x = center.x + cos(angle) * radius
            let y = center.y + sin(angle) * radius

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()

        return path
    }
}

// MARK: - Flowing Ribbon Waveform

/// A ribbon-like waveform that flows through space
struct FlowingRibbonWaveform: View {
    let audioLevel: Float
    let isRecording: Bool

    @State private var time: Double = 0
    @State private var smoothLevel: Float = 0

    var body: some View {
        Canvas { context, size in
            let midY = size.height / 2
            let ribbonWidth: CGFloat = 8 + CGFloat(smoothLevel) * 20

            // Draw 3 ribbon layers
            for layer in 0..<3 {
                let yOffset = CGFloat(layer - 1) * (ribbonWidth * 0.6)
                let phaseOffset = Double(layer) * 0.5
                let opacity = 1.0 - Double(layer) * 0.25

                drawRibbon(
                    context: context,
                    size: size,
                    midY: midY + yOffset,
                    width: ribbonWidth - CGFloat(layer) * 2,
                    phase: time + phaseOffset,
                    audioLevel: CGFloat(smoothLevel),
                    layer: layer,
                    opacity: opacity
                )
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 5).repeatForever(autoreverses: false)) {
                time = 2 * .pi
            }
        }
        .onChange(of: audioLevel) { _, newValue in
            withAnimation(.spring(response: 0.12, dampingFraction: 0.7)) {
                smoothLevel = newValue
            }
        }
    }

    private func drawRibbon(
        context: GraphicsContext,
        size: CGSize,
        midY: CGFloat,
        width: CGFloat,
        phase: Double,
        audioLevel: CGFloat,
        layer: Int,
        opacity: Double
    ) {
        var topPath = Path()
        var bottomPath = Path()
        var fillPath = Path()

        let amplitude = size.height * 0.25 * (0.3 + audioLevel)
        let steps = Int(size.width / 2)

        for i in 0...steps {
            let x = CGFloat(i) * 2
            let progress = x / size.width

            // Wave calculation
            let wave1 = sin(progress * 2.5 * .pi + phase)
            let wave2 = sin(progress * 4 * .pi - phase * 0.7) * 0.4
            let envelope = sin(progress * .pi)

            let waveY = (wave1 + wave2) * amplitude * envelope
            let topY = midY + waveY - width / 2
            let bottomY = midY + waveY + width / 2

            if i == 0 {
                topPath.move(to: CGPoint(x: x, y: topY))
                bottomPath.move(to: CGPoint(x: x, y: bottomY))
                fillPath.move(to: CGPoint(x: x, y: topY))
            } else {
                topPath.addLine(to: CGPoint(x: x, y: topY))
                bottomPath.addLine(to: CGPoint(x: x, y: bottomY))
                fillPath.addLine(to: CGPoint(x: x, y: topY))
            }
        }

        // Complete fill path
        for i in stride(from: steps, through: 0, by: -1) {
            let x = CGFloat(i) * 2
            let progress = x / size.width

            let wave1 = sin(progress * 2.5 * .pi + phase)
            let wave2 = sin(progress * 4 * .pi - phase * 0.7) * 0.4
            let envelope = sin(progress * .pi)

            let waveY = (wave1 + wave2) * amplitude * envelope
            let bottomY = midY + waveY + width / 2

            fillPath.addLine(to: CGPoint(x: x, y: bottomY))
        }
        fillPath.closeSubpath()

        // Colors - warm amber theme
        let colors: [Color] = [
            Color.amberPrimary,
            Color.amberLight,
            Color.white.opacity(0.4)
        ]

        // Fill with gradient
        context.fill(
            fillPath,
            with: .linearGradient(
                Gradient(colors: colors.map { $0.opacity(opacity * 0.6) }),
                startPoint: CGPoint(x: 0, y: midY),
                endPoint: CGPoint(x: size.width, y: midY)
            )
        )

        // Stroke top edge
        context.stroke(
            topPath,
            with: .linearGradient(
                Gradient(colors: colors.map { $0.opacity(opacity) }),
                startPoint: CGPoint(x: 0, y: midY),
                endPoint: CGPoint(x: size.width, y: midY)
            ),
            lineWidth: 2
        )
    }
}

// MARK: - Previews

#Preview("Aurora Waveform") {
    AuroraWaveformPreview()
}

#Preview("Liquid Orb") {
    LiquidOrbPreview()
}

#Preview("Flowing Ribbon") {
    FlowingRibbonPreview()
}

private struct AuroraWaveformPreview: View {
    @State private var level: Float = 0.5
    @State private var isRecording = true

    var body: some View {
        VStack(spacing: 20) {
            AuroraWaveform(audioLevel: level, isRecording: isRecording)
                .frame(height: 80)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                )

            Toggle("Recording", isOn: $isRecording)

            Slider(value: Binding(
                get: { Double(level) },
                set: { level = Float($0) }
            ))
        }
        .padding()
        .frame(width: 350)
        .background(Color.black.opacity(0.9))
    }
}

private struct LiquidOrbPreview: View {
    @State private var level: Float = 0.5
    @State private var isRecording = true

    var body: some View {
        VStack(spacing: 20) {
            LiquidOrbWaveform(audioLevel: level, isRecording: isRecording)
                .frame(width: 150, height: 150)

            Toggle("Recording", isOn: $isRecording)

            Slider(value: Binding(
                get: { Double(level) },
                set: { level = Float($0) }
            ))
        }
        .padding()
        .frame(width: 300)
        .background(.ultraThinMaterial)
    }
}

private struct FlowingRibbonPreview: View {
    @State private var level: Float = 0.5
    @State private var isRecording = true

    var body: some View {
        VStack(spacing: 20) {
            FlowingRibbonWaveform(audioLevel: level, isRecording: isRecording)
                .frame(height: 100)

            Toggle("Recording", isOn: $isRecording)

            Slider(value: Binding(
                get: { Double(level) },
                set: { level = Float($0) }
            ))
        }
        .padding()
        .frame(width: 350)
        .background(.ultraThinMaterial)
    }
}
