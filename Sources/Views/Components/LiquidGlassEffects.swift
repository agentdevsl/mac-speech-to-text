// LiquidGlassEffects.swift
// macOS Local Speech-to-Text Application
//
// Liquid Glass design system - Premium glass effects with prismatic
// refractions, caustic light patterns, and organic morphing animations.
// Inspired by light passing through water and crystalline structures.

import SwiftUI

// MARK: - Liquid Glass Container

/// A container that applies the full liquid glass effect stack
struct LiquidGlassContainer<Content: View>: View {
    let audioLevel: Float
    let isActive: Bool
    @ViewBuilder let content: () -> Content

    @State private var time: Double = 0
    @State private var breatheScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Layer 1: Deep background glass with caustics
            LiquidGlassBackground(time: time, audioLevel: audioLevel)

            // Layer 2: Prismatic edge glow
            PrismaticEdgeGlow(intensity: isActive ? 0.8 : 0.4, audioLevel: audioLevel)

            // Layer 3: Floating caustic highlights
            CausticLightOverlay(time: time, intensity: Double(audioLevel))

            // Layer 4: Content
            content()
        }
        .background(
            LiquidGlassShape(audioLevel: audioLevel)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            // Inner highlight rim
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.5),
                            .white.opacity(0.1),
                            .clear,
                            .white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .overlay(
            // Outer prismatic rim
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    AngularGradient(
                        colors: [
                            Color.liquidPrismaticPink.opacity(0.3),
                            Color.liquidPrismaticBlue.opacity(0.3),
                            Color.liquidPrismaticCyan.opacity(0.3),
                            Color.liquidPrismaticGreen.opacity(0.2),
                            Color.liquidPrismaticYellow.opacity(0.3),
                            Color.liquidPrismaticPink.opacity(0.3)
                        ],
                        center: .center,
                        angle: .degrees(time * 20)
                    ),
                    lineWidth: 2
                )
                .blur(radius: 2)
        )
        .scaleEffect(breatheScale)
        .shadow(color: Color.liquidGlassShadow.opacity(0.3), radius: 30, x: 0, y: 15)
        .shadow(color: Color.liquidPrismaticBlue.opacity(0.15), radius: 40, x: -10, y: 20)
        .shadow(color: Color.liquidPrismaticPink.opacity(0.1), radius: 40, x: 10, y: 20)
        .onAppear {
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                time = 360
            }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                breatheScale = 1.008
            }
        }
        .onChange(of: audioLevel) { _, newValue in
            // Pulse slightly with audio
            let extraScale = CGFloat(newValue) * 0.015
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                breatheScale = 1.0 + extraScale
            }
        }
    }
}

// MARK: - Liquid Glass Background

/// Multi-layer glass background with depth and refraction
struct LiquidGlassBackground: View {
    let time: Double
    let audioLevel: Float

    var body: some View {
        ZStack {
            // Base frosted glass
            Rectangle()
                .fill(.ultraThinMaterial)

            // Deep glass tint
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.liquidGlassDeep.opacity(0.4),
                            Color.liquidGlassMid.opacity(0.2),
                            Color.liquidGlassLight.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Animated gradient mesh (simulated caustics)
            CausticMesh(time: time, audioLevel: audioLevel)
                .opacity(0.4)

            // Noise texture for glass depth
            GlassNoiseTexture()
                .opacity(0.03)
        }
    }
}

// MARK: - Caustic Mesh

/// Simulates light refraction patterns like sunlight through water
struct CausticMesh: View {
    let time: Double
    let audioLevel: Float

    var body: some View {
        Canvas { context, size in
            let cellSize: CGFloat = 60
            let cols = Int(size.width / cellSize) + 2
            let rows = Int(size.height / cellSize) + 2

            for row in 0..<rows {
                for col in 0..<cols {
                    let baseX = CGFloat(col) * cellSize
                    let baseY = CGFloat(row) * cellSize

                    // Organic movement
                    let phase1 = time * 0.02 + Double(row) * 0.3
                    let phase2 = time * 0.015 + Double(col) * 0.4
                    let offsetX = sin(phase1) * 15 * (1 + Double(audioLevel) * 0.5)
                    let offsetY = cos(phase2) * 15 * (1 + Double(audioLevel) * 0.5)

                    let center = CGPoint(
                        x: baseX + offsetX,
                        y: baseY + offsetY
                    )

                    // Caustic intensity varies
                    let intensity = (sin(phase1 * 2) + cos(phase2 * 1.5) + 2) / 4
                    let radius = cellSize * 0.4 * (0.5 + intensity * 0.5)

                    let gradient = Gradient(colors: [
                        Color.white.opacity(intensity * 0.3),
                        Color.white.opacity(0)
                    ])

                    context.fill(
                        Circle().path(in: CGRect(
                            x: center.x - radius,
                            y: center.y - radius,
                            width: radius * 2,
                            height: radius * 2
                        )),
                        with: .radialGradient(
                            gradient,
                            center: center,
                            startRadius: 0,
                            endRadius: radius
                        )
                    )
                }
            }
        }
    }
}

// MARK: - Prismatic Edge Glow

/// Rainbow light bleeding effect around edges
struct PrismaticEdgeGlow: View {
    let intensity: Double
    let audioLevel: Float

    @State private var rotation: Double = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Outer prismatic glow
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(
                        AngularGradient(
                            colors: prismaticColors,
                            center: .center,
                            angle: .degrees(rotation)
                        ),
                        lineWidth: 20 + CGFloat(audioLevel) * 15
                    )
                    .blur(radius: 25)
                    .opacity(intensity * 0.5)

                // Inner concentrated glow
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(
                        AngularGradient(
                            colors: prismaticColors,
                            center: .center,
                            angle: .degrees(-rotation * 0.7)
                        ),
                        lineWidth: 8 + CGFloat(audioLevel) * 8
                    )
                    .blur(radius: 10)
                    .opacity(intensity * 0.6)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onAppear {
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }

    private var prismaticColors: [Color] {
        [
            Color.liquidPrismaticPink,
            Color.liquidPrismaticPurple,
            Color.liquidPrismaticBlue,
            Color.liquidPrismaticCyan,
            Color.liquidPrismaticGreen,
            Color.liquidPrismaticYellow,
            Color.liquidPrismaticOrange,
            Color.liquidPrismaticPink
        ]
    }
}

// MARK: - Caustic Light Overlay

/// Floating light spots that dance across the surface
struct CausticLightOverlay: View {
    let time: Double
    let intensity: Double

    var body: some View {
        Canvas { context, size in
            let spotCount = 5

            for index in 0..<spotCount {
                let phase = time * 0.03 + Double(index) * 1.2

                // Organic path
                let x = size.width * (0.2 + 0.6 * (sin(phase) + 1) / 2)
                let y = size.height * (0.2 + 0.6 * (cos(phase * 0.7) + 1) / 2)

                let spotIntensity = (sin(phase * 2) + 1) / 2 * intensity
                let radius = 30 + spotIntensity * 40

                // Pick color based on index
                let hue = Double(index) / Double(spotCount)
                let color = Color(hue: hue, saturation: 0.6, brightness: 1.0)

                let gradient = Gradient(colors: [
                    color.opacity(spotIntensity * 0.4),
                    color.opacity(0)
                ])

                context.fill(
                    Ellipse().path(in: CGRect(
                        x: x - radius,
                        y: y - radius * 0.6,
                        width: radius * 2,
                        height: radius * 1.2
                    )),
                    with: .radialGradient(
                        gradient,
                        center: CGPoint(x: x, y: y),
                        startRadius: 0,
                        endRadius: radius
                    )
                )
            }
        }
        .blendMode(.plusLighter)
    }
}

// MARK: - Liquid Glass Shape

/// The main glass container shape with layered materials
struct LiquidGlassShape: View {
    let audioLevel: Float

    var body: some View {
        ZStack {
            // Base glass layer
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)

            // Warm tint layer
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [
                            Color.amberLight.opacity(0.08),
                            Color.clear
                        ],
                        center: .top,
                        startRadius: 0,
                        endRadius: 200
                    )
                )

            // Depth gradient
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.1),
                            Color.clear,
                            Color.black.opacity(0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
    }
}

// MARK: - Glass Noise Texture

/// Subtle noise for glass material depth
struct GlassNoiseTexture: View {
    var body: some View {
        Canvas { context, size in
            for _ in 0..<800 {
                let x = CGFloat.random(in: 0...size.width)
                let y = CGFloat.random(in: 0...size.height)
                let opacity = Double.random(in: 0.3...1.0)

                context.fill(
                    Circle().path(in: CGRect(x: x, y: y, width: 1, height: 1)),
                    with: .color(.white.opacity(opacity))
                )
            }
        }
    }
}

// MARK: - Morphing Orb

/// An organic blob that morphs based on audio level
struct MorphingOrb: View {
    let audioLevel: Float
    let isRecording: Bool

    @State private var morphPhase: Double = 0

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let baseRadius = min(size.width, size.height) * 0.35
            let morphAmount = CGFloat(audioLevel) * 0.3 + 0.1

            // Create morphing blob path
            var path = Path()
            let points = 64

            for i in 0..<points {
                let angle = (Double(i) / Double(points)) * 2 * .pi

                // Multiple sine waves for organic shape
                let wave1 = sin(angle * 3 + morphPhase) * morphAmount
                let wave2 = sin(angle * 5 - morphPhase * 1.3) * morphAmount * 0.5
                let wave3 = sin(angle * 7 + morphPhase * 0.7) * morphAmount * 0.3

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

            // Gradient fill
            let gradient = Gradient(colors: [
                isRecording ? Color.liquidRecordingCore : Color.amberBright,
                isRecording ? Color.liquidRecordingMid : Color.amberPrimary,
                isRecording ? Color.liquidRecordingOuter : Color.amberDark
            ])

            // Outer glow
            context.fill(
                path,
                with: .radialGradient(
                    Gradient(colors: [
                        (isRecording ? Color.liquidRecordingCore : Color.amberBright).opacity(0.4),
                        .clear
                    ]),
                    center: center,
                    startRadius: baseRadius * 0.8,
                    endRadius: baseRadius * 1.5
                )
            )

            // Main orb
            context.fill(
                path,
                with: .radialGradient(
                    gradient,
                    center: CGPoint(x: center.x - baseRadius * 0.2, y: center.y - baseRadius * 0.2),
                    startRadius: 0,
                    endRadius: baseRadius * 1.2
                )
            )

            // Inner highlight
            let highlightPath = Circle().path(in: CGRect(
                x: center.x - baseRadius * 0.5,
                y: center.y - baseRadius * 0.6,
                width: baseRadius * 0.5,
                height: baseRadius * 0.3
            ))

            context.fill(
                highlightPath,
                with: .radialGradient(
                    Gradient(colors: [.white.opacity(0.6), .clear]),
                    center: CGPoint(x: center.x - baseRadius * 0.25, y: center.y - baseRadius * 0.5),
                    startRadius: 0,
                    endRadius: baseRadius * 0.3
                )
            )
        }
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                morphPhase = 2 * .pi
            }
        }
    }
}

// MARK: - Recording Pulse Ring

/// Animated concentric rings that pulse outward during recording
struct RecordingPulseRings: View {
    let isRecording: Bool
    let audioLevel: Float

    @State private var ring1Scale: CGFloat = 0.8
    @State private var ring2Scale: CGFloat = 0.8
    @State private var ring3Scale: CGFloat = 0.8
    @State private var ring1Opacity: Double = 0.6
    @State private var ring2Opacity: Double = 0.6
    @State private var ring3Opacity: Double = 0.6

    var body: some View {
        ZStack {
            // Ring 1
            Circle()
                .stroke(Color.liquidRecordingCore.opacity(ring1Opacity), lineWidth: 2)
                .scaleEffect(ring1Scale)

            // Ring 2
            Circle()
                .stroke(Color.liquidRecordingMid.opacity(ring2Opacity), lineWidth: 1.5)
                .scaleEffect(ring2Scale)

            // Ring 3
            Circle()
                .stroke(Color.liquidRecordingOuter.opacity(ring3Opacity), lineWidth: 1)
                .scaleEffect(ring3Scale)
        }
        .onChange(of: isRecording) { _, newValue in
            if newValue {
                startPulsing()
            }
        }
        .onAppear {
            if isRecording {
                startPulsing()
            }
        }
    }

    private func startPulsing() {
        // Staggered ring animations
        withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
            ring1Scale = 1.8
            ring1Opacity = 0
        }

        withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false).delay(0.3)) {
            ring2Scale = 1.8
            ring2Opacity = 0
        }

        withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false).delay(0.6)) {
            ring3Scale = 1.8
            ring3Opacity = 0
        }
    }
}

// MARK: - Shimmer Effect

/// A traveling shimmer highlight
struct ShimmerEffect: View {
    @State private var shimmerOffset: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [
                    .clear,
                    .white.opacity(0.2),
                    .white.opacity(0.4),
                    .white.opacity(0.2),
                    .clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geo.size.width * 0.5)
            .offset(x: shimmerOffset * geo.size.width)
            .onAppear {
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: false)) {
                    shimmerOffset = 1.5
                }
            }
        }
        .mask(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
    }
}

// MARK: - Previews

#Preview("Liquid Glass Container") {
    LiquidGlassContainer(audioLevel: 0.5, isActive: true) {
        VStack(spacing: 16) {
            Text("Recording")
                .font(.system(size: 18, weight: .semibold))

            MorphingOrb(audioLevel: 0.5, isRecording: true)
                .frame(width: 80, height: 80)

            Text("Listening...")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .padding(24)
    }
    .frame(width: 300, height: 250)
    .padding(60)
    .background(Color.black.opacity(0.8))
}

#Preview("Morphing Orb") {
    MorphingOrbPreview()
}

private struct MorphingOrbPreview: View {
    @State private var level: Float = 0.5

    var body: some View {
        VStack {
            MorphingOrb(audioLevel: level, isRecording: true)
                .frame(width: 120, height: 120)

            Slider(value: Binding(
                get: { Double(level) },
                set: { level = Float($0) }
            ))
            .padding()
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}
