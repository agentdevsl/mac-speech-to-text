// CrystallineMorphWaveform.swift
// macOS Local Speech-to-Text Application
//
// Geometric crystalline pattern visualization with nested rotating polygons,
// Lissajous-style curves, and audio-reactive morphing. Creates a frozen
// mandala that breathes with sound.

import SwiftUI

// MARK: - Crystalline Morph Waveform

/// A geometric crystalline pattern that morphs with audio input
/// Features nested rotating polygons with prismatic gradient strokes and glow effects
struct CrystallineMorphWaveform: View {
    /// Current audio level (0.0 - 1.0)
    let audioLevel: Float

    /// Whether currently recording
    let isRecording: Bool

    /// Animation time driver for continuous rotation
    @State private var time: Double = 0

    /// Smooth audio level for fluid response
    @State private var smoothLevel: Float = 0

    /// Secondary animation phase for morphing effects
    @State private var morphPhase: Double = 0

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let baseRadius = min(size.width, size.height) * 0.4
            let effectiveLevel = CGFloat(smoothLevel)

            // Draw outer glow halo
            drawGlowHalo(
                context: context,
                center: center,
                radius: baseRadius,
                audioLevel: effectiveLevel
            )

            // Draw nested crystalline layers (outer to inner)
            // Layer 4: Octagon (8 sides)
            drawCrystallinePolygon(
                context: context,
                center: center,
                size: size,
                baseRadius: baseRadius * 0.95,
                sides: 8,
                rotationSpeed: 0.3,
                rotationDirection: 1,
                layerIndex: 0,
                audioLevel: effectiveLevel,
                time: time,
                morphPhase: morphPhase
            )

            // Layer 3: Hexagon (6 sides)
            drawCrystallinePolygon(
                context: context,
                center: center,
                size: size,
                baseRadius: baseRadius * 0.72,
                sides: 6,
                rotationSpeed: 0.5,
                rotationDirection: -1,
                layerIndex: 1,
                audioLevel: effectiveLevel,
                time: time,
                morphPhase: morphPhase
            )

            // Layer 2: Pentagon (5 sides)
            drawCrystallinePolygon(
                context: context,
                center: center,
                size: size,
                baseRadius: baseRadius * 0.50,
                sides: 5,
                rotationSpeed: 0.8,
                rotationDirection: 1,
                layerIndex: 2,
                audioLevel: effectiveLevel,
                time: time,
                morphPhase: morphPhase
            )

            // Layer 1: Square (4 sides)
            drawCrystallinePolygon(
                context: context,
                center: center,
                size: size,
                baseRadius: baseRadius * 0.30,
                sides: 4,
                rotationSpeed: 1.2,
                rotationDirection: -1,
                layerIndex: 3,
                audioLevel: effectiveLevel,
                time: time,
                morphPhase: morphPhase
            )

            // Draw central Lissajous pattern
            drawLissajousCrystal(
                context: context,
                center: center,
                size: size,
                radius: baseRadius * 0.18,
                audioLevel: effectiveLevel,
                time: time
            )

            // Draw connecting radial lines on high audio
            if smoothLevel > 0.3 {
                drawCrystallineRays(
                    context: context,
                    center: center,
                    radius: baseRadius,
                    audioLevel: effectiveLevel,
                    time: time
                )
            }
        }
        .onAppear {
            // Continuous rotation animation
            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                time = 2 * .pi
            }
            // Secondary morph phase for organic feel
            withAnimation(.linear(duration: 7).repeatForever(autoreverses: false)) {
                morphPhase = 2 * .pi
            }
        }
        .onChange(of: audioLevel) { _, newValue in
            // Smooth the audio level with spring physics for organic feel
            withAnimation(.spring(response: 0.15, dampingFraction: 0.7)) {
                smoothLevel = newValue
            }
        }
    }

    // MARK: - Glow Halo

    private func drawGlowHalo(
        context: GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        audioLevel: CGFloat
    ) {
        let glowRadius = radius * (1.1 + audioLevel * 0.3)
        let glowIntensity = 0.2 + audioLevel * 0.4

        let colors = isRecording ? [
            Color.liquidRecordingCore.opacity(glowIntensity),
            Color.liquidRecordingMid.opacity(glowIntensity * 0.5),
            Color.clear
        ] : [
            Color.liquidGlassAccent.opacity(glowIntensity),
            Color.liquidGlassAccent.opacity(glowIntensity * 0.4),
            Color.clear
        ]

        let path = Circle().path(in: CGRect(
            x: center.x - glowRadius,
            y: center.y - glowRadius,
            width: glowRadius * 2,
            height: glowRadius * 2
        ))

        context.fill(
            path,
            with: .radialGradient(
                Gradient(colors: colors),
                center: center,
                startRadius: radius * 0.3,
                endRadius: glowRadius
            )
        )
    }

    // MARK: - Crystalline Polygon

    private func drawCrystallinePolygon(
        context: GraphicsContext,
        center: CGPoint,
        size: CGSize,
        baseRadius: CGFloat,
        sides: Int,
        rotationSpeed: Double,
        rotationDirection: Double,
        layerIndex: Int,
        audioLevel: CGFloat,
        time: Double,
        morphPhase: Double
    ) {
        // Calculate rotation based on time and audio
        let baseRotation = time * rotationSpeed * rotationDirection
        let audioRotationBoost = Double(audioLevel) * 0.5 * rotationDirection
        let rotation = baseRotation + audioRotationBoost

        // Morphing amount increases with audio
        let morphAmount = 0.02 + audioLevel * 0.15

        // Build polygon path with morphing
        var path = Path()
        let detail = sides * 8 // More points for smooth curves

        for index in 0...detail {
            let progress = Double(index) / Double(detail)
            let baseAngle = progress * 2 * .pi + rotation

            // Polygon shape modulation
            let polygonAngle = progress * Double(sides) * 2 * .pi
            let polygonMod = cos(polygonAngle) * 0.1

            // Organic morphing waves
            let wave1 = sin(baseAngle * 3 + morphPhase) * Double(morphAmount)
            let wave2 = sin(baseAngle * 5 - morphPhase * 1.3) * Double(morphAmount) * 0.5
            let wave3 = cos(baseAngle * 7 + time * 0.5) * Double(morphAmount) * Double(audioLevel)

            // Audio-reactive pulse
            let audioPulse = Double(audioLevel) * 0.08 * sin(morphPhase * 2 + Double(layerIndex))

            let radiusMod = 1.0 + polygonMod + wave1 + wave2 + wave3 + audioPulse
            let radius = baseRadius * CGFloat(radiusMod)

            let x = center.x + CGFloat(cos(baseAngle)) * radius
            let y = center.y + CGFloat(sin(baseAngle)) * radius

            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()

        // Get prismatic colors for this layer
        let gradientColors = crystallineColors(for: layerIndex, audioLevel: Float(audioLevel))

        // Calculate gradient angle for prismatic effect
        let gradientAngleRadians = time * 0.5 + Double(layerIndex) * 0.5

        // Create start and end points for linear gradient that rotates
        let gradientRadius = baseRadius * 1.2
        let startPoint = CGPoint(
            x: center.x + CGFloat(cos(gradientAngleRadians)) * gradientRadius,
            y: center.y + CGFloat(sin(gradientAngleRadians)) * gradientRadius
        )
        let endPoint = CGPoint(
            x: center.x - CGFloat(cos(gradientAngleRadians)) * gradientRadius,
            y: center.y - CGFloat(sin(gradientAngleRadians)) * gradientRadius
        )

        // Stroke thickness varies with audio and layer
        let baseStrokeWidth: CGFloat = 2.5 - CGFloat(layerIndex) * 0.4
        let strokeWidth = baseStrokeWidth + audioLevel * 2

        // Outer glow (blur + blend)
        if layerIndex < 2 {
            var glowContext = context
            glowContext.blendMode = .plusLighter

            glowContext.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: gradientColors.map { $0.opacity(0.4) }),
                    startPoint: startPoint,
                    endPoint: endPoint
                ),
                style: StrokeStyle(
                    lineWidth: strokeWidth + 6 + audioLevel * 4,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }

        // Main prismatic stroke
        context.stroke(
            path,
            with: .linearGradient(
                Gradient(colors: gradientColors),
                startPoint: startPoint,
                endPoint: endPoint
            ),
            style: StrokeStyle(
                lineWidth: strokeWidth,
                lineCap: .round,
                lineJoin: .round
            )
        )

        // Inner bright highlight with perpendicular gradient
        let perpAngle = gradientAngleRadians + .pi / 2
        let highlightStart = CGPoint(
            x: center.x + CGFloat(cos(perpAngle)) * gradientRadius,
            y: center.y + CGFloat(sin(perpAngle)) * gradientRadius
        )
        let highlightEnd = CGPoint(
            x: center.x - CGFloat(cos(perpAngle)) * gradientRadius,
            y: center.y - CGFloat(sin(perpAngle)) * gradientRadius
        )

        context.stroke(
            path,
            with: .linearGradient(
                Gradient(colors: gradientColors.map { $0.opacity(0.8) }),
                startPoint: highlightStart,
                endPoint: highlightEnd
            ),
            style: StrokeStyle(
                lineWidth: strokeWidth * 0.3,
                lineCap: .round,
                lineJoin: .round
            )
        )
    }

    // MARK: - Lissajous Crystal

    private func drawLissajousCrystal(
        context: GraphicsContext,
        center: CGPoint,
        size: CGSize,
        radius: CGFloat,
        audioLevel: CGFloat,
        time: Double
    ) {
        // Lissajous parameters that create crystalline patterns
        let freqA = 5.0
        let freqB = 4.0
        let phaseShift = time * 2

        var path = Path()
        let steps = 128

        for index in 0...steps {
            let t = Double(index) / Double(steps) * 2 * .pi

            // Lissajous curve equations with audio modulation
            let audioMod = 1.0 + Double(audioLevel) * 0.3
            let x = center.x + CGFloat(cos(freqA * t + phaseShift)) * radius * CGFloat(audioMod)
            let y = center.y + CGFloat(sin(freqB * t)) * radius * CGFloat(audioMod)

            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()

        // Core glow
        let coreColor = isRecording ? Color.liquidRecordingCore : Color.liquidGlassAccent.opacity(0.8)

        var glowContext = context
        glowContext.blendMode = .plusLighter

        glowContext.stroke(
            path,
            with: .color(coreColor.opacity(0.6)),
            style: StrokeStyle(lineWidth: 6 + audioLevel * 4, lineCap: .round)
        )

        // Main stroke with rotating gradient
        let gradientAngle = time * 1.5
        let gradientRadius = radius * 1.5
        let startPoint = CGPoint(
            x: center.x + CGFloat(cos(gradientAngle)) * gradientRadius,
            y: center.y + CGFloat(sin(gradientAngle)) * gradientRadius
        )
        let endPoint = CGPoint(
            x: center.x - CGFloat(cos(gradientAngle)) * gradientRadius,
            y: center.y - CGFloat(sin(gradientAngle)) * gradientRadius
        )

        let lissajousColors: [Color] = isRecording ? [
            Color.liquidRecordingCore,
            Color.white.opacity(0.4),
            Color.liquidRecordingMid,
            Color.liquidRecordingCore
        ] : [
            Color.liquidGlassAccent.opacity(0.8),
            Color.liquidGlassAccent,
            Color.liquidGlassAccent.opacity(0.7),
            Color.liquidGlassAccent.opacity(0.8)
        ]

        context.stroke(
            path,
            with: .linearGradient(
                Gradient(colors: lissajousColors),
                startPoint: startPoint,
                endPoint: endPoint
            ),
            style: StrokeStyle(lineWidth: 2 + audioLevel * 1.5, lineCap: .round)
        )
    }

    // MARK: - Crystalline Rays

    private func drawCrystallineRays(
        context: GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        audioLevel: CGFloat,
        time: Double
    ) {
        let rayCount = 12
        let rayOpacity = Double(audioLevel - 0.3) * 1.5

        for index in 0..<rayCount {
            let angle = (Double(index) / Double(rayCount)) * 2 * .pi + time * 0.3
            let innerRadius = Double(radius) * 0.2
            let outerRadius = Double(radius) * (0.9 + Double(audioLevel) * 0.2)

            let cosAngle = cos(angle)
            let sinAngle = sin(angle)

            let innerPoint = CGPoint(
                x: center.x + CGFloat(cosAngle * innerRadius),
                y: center.y + CGFloat(sinAngle * innerRadius)
            )
            let outerPoint = CGPoint(
                x: center.x + CGFloat(cosAngle * outerRadius),
                y: center.y + CGFloat(sinAngle * outerRadius)
            )

            var rayPath = Path()
            rayPath.move(to: innerPoint)
            rayPath.addLine(to: outerPoint)

            // Color alternates based on index
            let rayColor: Color
            if isRecording {
                rayColor = index % 2 == 0 ? Color.liquidRecordingMid : Color.white.opacity(0.4)
            } else {
                rayColor = index % 2 == 0 ? Color.liquidGlassAccent.opacity(0.8) : Color.liquidGlassAccent
            }

            context.stroke(
                rayPath,
                with: .linearGradient(
                    Gradient(colors: [
                        rayColor.opacity(rayOpacity * 0.8),
                        rayColor.opacity(rayOpacity * 0.2)
                    ]),
                    startPoint: innerPoint,
                    endPoint: outerPoint
                ),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
            )
        }
    }

    // MARK: - Color Helpers

    private func crystallineColors(for layer: Int, audioLevel: Float) -> [Color] {
        if isRecording {
            // Warm crystalline palette: red core with white frost accents
            switch layer {
            case 0:
                return [
                    Color.liquidRecordingMid,
                    Color.white.opacity(0.4),
                    Color.liquidRecordingCore,
                    Color.liquidRecordingMid,
                    Color.liquidRecordingMid
                ]
            case 1:
                return [
                    Color.liquidRecordingCore,
                    Color.white.opacity(0.4),
                    Color.liquidRecordingMid,
                    Color.white.opacity(0.3),
                    Color.liquidRecordingCore
                ]
            case 2:
                return [
                    Color.white.opacity(0.4),
                    Color.liquidRecordingMid,
                    Color.liquidRecordingMid,
                    Color.white.opacity(0.4)
                ]
            default:
                return [
                    Color.liquidRecordingCore,
                    Color.white.opacity(0.4),
                    Color.liquidRecordingCore
                ]
            }
        } else {
            // Cool crystalline palette: accent blue with white frost variations
            switch layer {
            case 0:
                return [
                    Color.liquidGlassAccent,
                    Color.liquidGlassAccent.opacity(0.8),
                    Color.liquidGlassAccent.opacity(0.7),
                    Color.liquidGlassAccent,
                    Color.white.opacity(0.5)
                ]
            case 1:
                return [
                    Color.liquidGlassAccent.opacity(0.8),
                    Color.liquidGlassAccent,
                    Color.liquidGlassAccent.opacity(0.7),
                    Color.liquidGlassAccent.opacity(0.8)
                ]
            case 2:
                return [
                    Color.liquidGlassAccent.opacity(0.7),
                    Color.liquidGlassAccent,
                    Color.white.opacity(0.5),
                    Color.liquidGlassAccent.opacity(0.7)
                ]
            default:
                return [
                    Color.liquidGlassAccent,
                    Color.white.opacity(0.5),
                    Color.liquidGlassAccent
                ]
            }
        }
    }
}

// MARK: - Previews

#Preview("Crystalline Morph Waveform") {
    CrystallineMorphWaveformPreview()
}

#Preview("Crystalline - Recording State") {
    CrystallineMorphWaveform(audioLevel: 0.6, isRecording: true)
        .frame(width: 200, height: 200)
        .padding(40)
        .background(Color.black.opacity(0.9))
}

#Preview("Crystalline - Idle State") {
    CrystallineMorphWaveform(audioLevel: 0.3, isRecording: false)
        .frame(width: 200, height: 200)
        .padding(40)
        .background(Color.black.opacity(0.9))
}

private struct CrystallineMorphWaveformPreview: View {
    @State private var level: Float = 0.5
    @State private var isRecording = true
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 24) {
            Text("Crystalline Morph Waveform")
                .font(.headline)
                .foregroundStyle(.secondary)

            CrystallineMorphWaveform(audioLevel: level, isRecording: isRecording)
                .frame(width: 220, height: 220)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))

            VStack(spacing: 16) {
                Toggle("Recording", isOn: $isRecording)
                    .toggleStyle(.switch)

                Toggle("Animate Level", isOn: $isAnimating)
                    .toggleStyle(.switch)

                HStack {
                    Text("Audio Level")
                    Spacer()
                    Text(String(format: "%.2f", level))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                Slider(value: Binding(
                    get: { Double(level) },
                    set: { level = Float($0) }
                ), in: 0...1)
                .disabled(isAnimating)
            }
            .padding(.horizontal)
        }
        .padding(24)
        .frame(width: 320)
        .background(Color.black.opacity(0.85))
        .onAppear {
            startAnimationLoop()
        }
        .onChange(of: isAnimating) { _, newValue in
            if newValue {
                startAnimationLoop()
            }
        }
    }

    private func startAnimationLoop() {
        guard isAnimating else { return }

        // Simulate audio level changes
        Task {
            while isAnimating {
                let newLevel = Float.random(in: 0.2...0.9)
                await MainActor.run {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        level = newLevel
                    }
                }
                try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
            }
        }
    }
}
