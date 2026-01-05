// AudioCapturePulse.swift
// macOS Local Speech-to-Text Application
//
// Audio capture visualization with dynamic level bars radiating from center,
// emphasizing active audio input with warm amber aesthetics.

import SwiftUI

// MARK: - Audio Capture Pulse (replaces SiriStyleRingWaves)

/// An audio capture visualization with radial level bars that pulse with audio input
/// Creates a clear visual indication that audio is being actively captured
struct SiriStyleRingWaves: View {
    /// Current audio level (0.0 - 1.0)
    let audioLevel: Float

    /// Whether currently recording
    let isRecording: Bool

    /// Number of frequency bars
    private let barCount = 24

    /// Animation time driver
    @State private var time: Double = 0

    /// Smooth audio level
    @State private var smoothLevel: Float = 0

    /// Individual bar levels for varied animation
    @State private var barLevels: [Float] = Array(repeating: 0, count: 24)

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let maxRadius = min(size.width, size.height) * 0.45
            let minRadius = maxRadius * 0.25

            // Draw outer glow when active
            if smoothLevel > 0.05 {
                drawOuterGlow(
                    context: context,
                    center: center,
                    radius: maxRadius,
                    level: CGFloat(smoothLevel)
                )
            }

            // Draw radial audio bars
            for i in 0..<barCount {
                drawAudioBar(
                    context: context,
                    center: center,
                    index: i,
                    minRadius: minRadius,
                    maxRadius: maxRadius,
                    barLevel: CGFloat(barLevels[i]),
                    time: time
                )
            }

            // Draw center microphone indicator
            drawCenterIndicator(
                context: context,
                center: center,
                radius: minRadius * 0.7,
                level: CGFloat(smoothLevel)
            )
        }
        .onAppear {
            // Continuous subtle animation
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                time = 2 * .pi
            }
        }
        .onChange(of: audioLevel) { _, newValue in
            // Smooth the overall level
            withAnimation(.spring(response: 0.1, dampingFraction: 0.7)) {
                smoothLevel = newValue
            }

            // Update individual bar levels with variation
            updateBarLevels(baseLevel: newValue)
        }
    }

    // MARK: - Bar Level Animation

    private func updateBarLevels(baseLevel: Float) {
        for i in 0..<barCount {
            // Create variation based on bar position and randomness
            let variation = Float.random(in: 0.6...1.4)
            let positionFactor = 1.0 - abs(Float(i - barCount / 2)) / Float(barCount / 2) * 0.3

            withAnimation(.spring(response: 0.08 + Double(i) * 0.005, dampingFraction: 0.6)) {
                barLevels[i] = baseLevel * variation * positionFactor
            }
        }
    }

    // MARK: - Drawing Functions

    private func drawOuterGlow(
        context: GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        level: CGFloat
    ) {
        let glowRadius = radius * (1.1 + level * 0.2)
        let glowOpacity = 0.15 + Double(level) * 0.2

        context.fill(
            Circle().path(in: CGRect(
                x: center.x - glowRadius,
                y: center.y - glowRadius,
                width: glowRadius * 2,
                height: glowRadius * 2
            )),
            with: .radialGradient(
                Gradient(colors: [
                    Color.amberPrimary.opacity(glowOpacity),
                    Color.amberLight.opacity(glowOpacity * 0.4),
                    .clear
                ]),
                center: center,
                startRadius: radius * 0.3,
                endRadius: glowRadius
            )
        )
    }

    private func drawAudioBar(
        context: GraphicsContext,
        center: CGPoint,
        index: Int,
        minRadius: CGFloat,
        maxRadius: CGFloat,
        barLevel: CGFloat,
        time: Double
    ) {
        let angle = (Double(index) / Double(barCount)) * 2 * .pi - .pi / 2

        // Base bar extends from min to a level-dependent max
        let barMinRadius = minRadius
        let barMaxRadius = minRadius + (maxRadius - minRadius) * (0.15 + barLevel * 0.85)

        // Add subtle wave motion
        let waveOffset = sin(time * 2 + Double(index) * 0.3) * 0.03 * Double(barLevel)
        let adjustedMax = barMaxRadius * (1 + CGFloat(waveOffset))

        // Calculate bar endpoints
        let innerX = center.x + cos(angle) * barMinRadius
        let innerY = center.y + sin(angle) * barMinRadius
        let outerX = center.x + cos(angle) * adjustedMax
        let outerY = center.y + sin(angle) * adjustedMax

        // Bar width tapers slightly outward
        let barWidth: CGFloat = 4 + barLevel * 2

        // Create rounded bar path
        var barPath = Path()
        barPath.move(to: CGPoint(x: innerX, y: innerY))
        barPath.addLine(to: CGPoint(x: outerX, y: outerY))

        // Color intensity based on level
        let baseOpacity = 0.4 + Double(barLevel) * 0.6
        let barColor = Color.amberPrimary

        // Draw glow for high levels
        if barLevel > 0.5 {
            var glowContext = context
            glowContext.blendMode = .plusLighter

            glowContext.stroke(
                barPath,
                with: .color(barColor.opacity((Double(barLevel) - 0.5) * 0.6)),
                style: StrokeStyle(lineWidth: barWidth + 4, lineCap: .round)
            )
        }

        // Main bar with gradient
        context.stroke(
            barPath,
            with: .linearGradient(
                Gradient(colors: [
                    Color.amberLight.opacity(baseOpacity * 0.7),
                    barColor.opacity(baseOpacity),
                    barColor.opacity(baseOpacity * 0.9)
                ]),
                startPoint: CGPoint(x: innerX, y: innerY),
                endPoint: CGPoint(x: outerX, y: outerY)
            ),
            style: StrokeStyle(lineWidth: barWidth, lineCap: .round)
        )

        // Bright tip when level is high
        if barLevel > 0.3 {
            let tipSize = barWidth * 0.6
            context.fill(
                Circle().path(in: CGRect(
                    x: outerX - tipSize / 2,
                    y: outerY - tipSize / 2,
                    width: tipSize,
                    height: tipSize
                )),
                with: .color(Color.white.opacity(Double(barLevel) * 0.7))
            )
        }
    }

    private func drawCenterIndicator(
        context: GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        level: CGFloat
    ) {
        // Pulsing center circle
        let pulseRadius = radius * (1 + level * 0.15)

        // Outer ring
        let ringPath = Circle().path(in: CGRect(
            x: center.x - pulseRadius,
            y: center.y - pulseRadius,
            width: pulseRadius * 2,
            height: pulseRadius * 2
        ))

        context.stroke(
            ringPath,
            with: .color(Color.amberPrimary.opacity(0.6 + Double(level) * 0.4)),
            style: StrokeStyle(lineWidth: 2)
        )

        // Inner filled circle with gradient
        let innerRadius = pulseRadius * 0.7
        let innerPath = Circle().path(in: CGRect(
            x: center.x - innerRadius,
            y: center.y - innerRadius,
            width: innerRadius * 2,
            height: innerRadius * 2
        ))

        context.fill(
            innerPath,
            with: .radialGradient(
                Gradient(colors: [
                    Color.amberLight.opacity(0.8 + Double(level) * 0.2),
                    Color.amberPrimary.opacity(0.6 + Double(level) * 0.4),
                    Color.amberPrimary.opacity(0.4)
                ]),
                center: CGPoint(x: center.x - innerRadius * 0.2, y: center.y - innerRadius * 0.2),
                startRadius: 0,
                endRadius: innerRadius
            )
        )

        // Microphone icon hint (simple dot pattern)
        if level > 0.1 {
            let dotRadius: CGFloat = 2
            let dotOpacity = 0.5 + Double(level) * 0.5

            // Center dot
            context.fill(
                Circle().path(in: CGRect(
                    x: center.x - dotRadius,
                    y: center.y - dotRadius,
                    width: dotRadius * 2,
                    height: dotRadius * 2
                )),
                with: .color(Color.white.opacity(dotOpacity))
            )

            // Surrounding dots (audio wave hint)
            for i in 0..<3 {
                let dotAngle = Double(i) * 2 * .pi / 3 - .pi / 2
                let dotDist = innerRadius * 0.4
                let dotX = center.x + cos(dotAngle) * dotDist
                let dotY = center.y + sin(dotAngle) * dotDist

                context.fill(
                    Circle().path(in: CGRect(
                        x: dotX - dotRadius * 0.7,
                        y: dotY - dotRadius * 0.7,
                        width: dotRadius * 1.4,
                        height: dotRadius * 1.4
                    )),
                    with: .color(Color.white.opacity(dotOpacity * 0.6))
                )
            }
        }
    }
}

// MARK: - Preview

#Preview("Audio Capture Pulse") {
    AudioCapturePulsePreview()
}

private struct AudioCapturePulsePreview: View {
    @State private var level: Float = 0.0
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 24) {
            // Waveform display
            SiriStyleRingWaves(audioLevel: level, isRecording: true)
                .frame(width: 200, height: 200)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                )

            // Controls
            VStack(spacing: 16) {
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
                    .tint(Color.amberPrimary)
                }

                // Simulate audio button
                Button(isAnimating ? "Stop Simulation" : "Simulate Audio") {
                    isAnimating.toggle()
                    if isAnimating {
                        simulateAudio()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.amberPrimary)
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            simulateAudio()
        }
    }
}
