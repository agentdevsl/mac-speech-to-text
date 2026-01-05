// ParticleVortexWaveform.swift
// macOS Local Speech-to-Text Application
//
// Audio-reactive particle vortex visualization with prismatic color cycling,
// orbital motion, and glow effects.

import SwiftUI

// MARK: - Particle Model

/// Represents a single particle in the vortex system
private struct Particle: Identifiable {
    let id: Int

    /// Orbital angle around center (radians)
    var angle: Double

    /// Distance from center (0.0 - 1.0 normalized)
    var radius: Double

    /// Angular velocity (radians per frame)
    var angularVelocity: Double

    /// Radial velocity (inward/outward movement)
    var radialVelocity: Double

    /// Current opacity (0.0 - 1.0)
    var opacity: Double

    /// Target opacity for smooth transitions
    var targetOpacity: Double

    /// Particle size multiplier
    var size: Double

    /// Hue offset for color cycling (0.0 - 1.0)
    var hueOffset: Double

    /// Spawn time for trail calculation
    var spawnTime: Double

    /// Whether particle is active
    var isActive: Bool
}

// MARK: - Particle Vortex Waveform

/// A stunning audio-reactive particle vortex with orbital motion and prismatic colors
struct ParticleVortexWaveform: View {

    /// Current audio level (0.0 - 1.0)
    let audioLevel: Float

    /// Whether currently recording
    let isRecording: Bool

    // MARK: - Constants

    private let maxParticles = 40
    private let minParticles = 8
    private let baseOrbitalSpeed: Double = 0.02
    private let maxOrbitalSpeed: Double = 0.08
    private let particleFadeSpeed: Double = 0.1

    // MARK: - State

    /// Particle pool for efficient rendering
    @State private var particles: [Particle] = []

    /// Animation time driver
    @State private var time: Double = 0

    /// Smooth audio level for fluid response
    @State private var smoothLevel: Float = 0

    /// Timer for particle updates
    @State private var displayLink: Timer?

    // MARK: - Body

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let maxRadius = min(size.width, size.height) * 0.45
            let effectiveLevel = CGFloat(smoothLevel)

            // Draw background glow
            drawBackgroundGlow(context: context, center: center, radius: maxRadius, level: effectiveLevel)

            // Draw particle trails and particles
            for particle in particles where particle.isActive {
                drawParticle(
                    context: context,
                    particle: particle,
                    center: center,
                    maxRadius: maxRadius,
                    time: time
                )
            }

            // Draw center orb
            drawCenterOrb(context: context, center: center, level: effectiveLevel)
        }
        .onAppear {
            initializeParticles()
            startAnimation()
        }
        .onDisappear {
            stopAnimation()
        }
        .onChange(of: audioLevel) { _, newValue in
            withAnimation(.spring(response: 0.15, dampingFraction: 0.7)) {
                smoothLevel = newValue
            }
        }
    }

    // MARK: - Initialization

    private func initializeParticles() {
        particles = (0..<maxParticles).map { index in
            createParticle(id: index, initialActive: index < minParticles)
        }
    }

    private func createParticle(id: Int, initialActive: Bool) -> Particle {
        let angle = Double.random(in: 0...(2 * .pi))
        let radius = Double.random(in: 0.3...1.0)

        return Particle(
            id: id,
            angle: angle,
            radius: radius,
            angularVelocity: Double.random(in: 0.8...1.2),
            radialVelocity: Double.random(in: -0.002...0.002),
            opacity: initialActive ? Double.random(in: 0.4...1.0) : 0,
            targetOpacity: initialActive ? 1.0 : 0,
            size: Double.random(in: 0.6...1.4),
            hueOffset: Double(id) / Double(maxParticles),
            spawnTime: 0,
            isActive: initialActive
        )
    }

    // MARK: - Animation Loop

    private func startAnimation() {
        displayLink = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            updateParticles()
        }
    }

    private func stopAnimation() {
        displayLink?.invalidate()
        displayLink = nil
    }

    private func updateParticles() {
        time += 0.016 // ~60fps

        let audioFactor = Double(smoothLevel)
        let targetActiveCount = minParticles + Int(audioFactor * Double(maxParticles - minParticles))
        let orbitalSpeed = baseOrbitalSpeed + audioFactor * (maxOrbitalSpeed - baseOrbitalSpeed)

        for i in particles.indices {
            var particle = particles[i]

            // Update orbital position
            let speedMultiplier = particle.angularVelocity * (1 + audioFactor * 2)
            particle.angle += orbitalSpeed * speedMultiplier

            // Wrap angle
            if particle.angle > 2 * .pi {
                particle.angle -= 2 * .pi
            }

            // Update radius with subtle pulsing
            particle.radius += particle.radialVelocity * (1 + audioFactor)

            // Keep radius in bounds with smooth wrapping
            if particle.radius > 1.0 {
                particle.radius = 0.3
                particle.radialVelocity = Double.random(in: -0.002...0.002)
            } else if particle.radius < 0.2 {
                particle.radius = 0.9
                particle.radialVelocity = Double.random(in: -0.002...0.002)
            }

            // Manage particle activation based on audio
            let shouldBeActive = i < targetActiveCount
            particle.targetOpacity = shouldBeActive ? (0.5 + audioFactor * 0.5) : 0
            particle.isActive = shouldBeActive || particle.opacity > 0.01

            // Smooth opacity transition
            let opacityDiff = particle.targetOpacity - particle.opacity
            particle.opacity += opacityDiff * particleFadeSpeed

            particles[i] = particle
        }
    }

    // MARK: - Drawing

    private func drawBackgroundGlow(
        context: GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        level: CGFloat
    ) {
        let glowRadius = radius * (1.2 + level * 0.3)
        let glowOpacity = 0.15 + Double(level) * 0.15

        let baseColor = isRecording ? Color.liquidRecordingCore : Color.liquidPrismaticBlue

        context.fill(
            Circle().path(in: CGRect(
                x: center.x - glowRadius,
                y: center.y - glowRadius,
                width: glowRadius * 2,
                height: glowRadius * 2
            )),
            with: .radialGradient(
                Gradient(colors: [
                    baseColor.opacity(glowOpacity),
                    baseColor.opacity(glowOpacity * 0.5),
                    .clear
                ]),
                center: center,
                startRadius: 0,
                endRadius: glowRadius
            )
        )
    }

    private func drawParticle(
        context: GraphicsContext,
        particle: Particle,
        center: CGPoint,
        maxRadius: CGFloat,
        time: Double
    ) {
        let currentRadius = maxRadius * particle.radius

        // Calculate position with Bezier-like curve influence
        let spiralFactor = sin(particle.angle * 3 + time * 2) * 0.1
        let wobble = cos(particle.angle * 5 - time) * 0.05
        let adjustedRadius = currentRadius * (1 + spiralFactor + wobble)

        let x = center.x + cos(particle.angle) * adjustedRadius
        let y = center.y + sin(particle.angle) * adjustedRadius

        // Calculate color with prismatic cycling
        let hue = calculateHue(for: particle, time: time)
        let saturation = isRecording ? 0.85 : 0.7
        let brightness = 0.9 + Double(smoothLevel) * 0.1

        let particleColor = Color(
            hue: hue,
            saturation: saturation,
            brightness: brightness
        )

        // Particle size based on audio and individual size
        let baseSize: CGFloat = 4 + CGFloat(smoothLevel) * 6
        let particleSize = baseSize * particle.size

        // Draw glow/trail effect
        let trailLength = 3 + Int(Double(smoothLevel) * 4)
        for trailIndex in 0..<trailLength {
            let trailFactor = 1.0 - Double(trailIndex) / Double(trailLength)
            let trailAngle = particle.angle - Double(trailIndex) * 0.05 * (1 + Double(smoothLevel))
            let trailRadius = adjustedRadius * (1 - Double(trailIndex) * 0.02)

            let trailX = center.x + cos(trailAngle) * trailRadius
            let trailY = center.y + sin(trailAngle) * trailRadius
            let trailSize = particleSize * (0.5 + trailFactor * 0.5)
            let trailOpacity = particle.opacity * trailFactor * 0.5

            context.fill(
                Circle().path(in: CGRect(
                    x: trailX - trailSize / 2,
                    y: trailY - trailSize / 2,
                    width: trailSize,
                    height: trailSize
                )),
                with: .color(particleColor.opacity(trailOpacity))
            )
        }

        // Draw main particle with glow
        var glowContext = context
        glowContext.blendMode = .plusLighter

        // Outer glow
        let glowSize = particleSize * 2.5
        context.fill(
            Circle().path(in: CGRect(
                x: x - glowSize / 2,
                y: y - glowSize / 2,
                width: glowSize,
                height: glowSize
            )),
            with: .radialGradient(
                Gradient(colors: [
                    particleColor.opacity(particle.opacity * 0.4),
                    particleColor.opacity(particle.opacity * 0.1),
                    .clear
                ]),
                center: CGPoint(x: x, y: y),
                startRadius: 0,
                endRadius: glowSize / 2
            )
        )

        // Core particle
        context.fill(
            Circle().path(in: CGRect(
                x: x - particleSize / 2,
                y: y - particleSize / 2,
                width: particleSize,
                height: particleSize
            )),
            with: .color(particleColor.opacity(particle.opacity))
        )

        // Bright center highlight
        let highlightSize = particleSize * 0.4
        glowContext.fill(
            Circle().path(in: CGRect(
                x: x - highlightSize / 2,
                y: y - highlightSize / 2,
                width: highlightSize,
                height: highlightSize
            )),
            with: .color(.white.opacity(particle.opacity * 0.7))
        )
    }

    private func calculateHue(for particle: Particle, time: Double) -> Double {
        // Base hue from particle's offset
        var hue = particle.hueOffset

        // Add time-based cycling
        hue += time * 0.05

        // Add position-based variation
        hue += sin(particle.angle) * 0.1

        // Shift hue range based on recording state
        if isRecording {
            // Warm prismatic: pink -> orange -> yellow (hue 0.9-0.15)
            hue = 0.9 + (hue.truncatingRemainder(dividingBy: 1.0)) * 0.25
            if hue > 1.0 {
                hue -= 1.0
            }
        } else {
            // Cool prismatic: blue -> cyan -> purple (hue 0.5-0.85)
            hue = 0.5 + (hue.truncatingRemainder(dividingBy: 1.0)) * 0.35
        }

        return hue.truncatingRemainder(dividingBy: 1.0)
    }

    private func drawCenterOrb(
        context: GraphicsContext,
        center: CGPoint,
        level: CGFloat
    ) {
        let orbRadius: CGFloat = 8 + level * 4

        let coreColor = isRecording ? Color.liquidRecordingCore : Color.liquidPrismaticCyan
        let midColor = isRecording ? Color.liquidRecordingMid : Color.liquidPrismaticBlue

        // Outer glow
        let glowRadius = orbRadius * 3
        context.fill(
            Circle().path(in: CGRect(
                x: center.x - glowRadius,
                y: center.y - glowRadius,
                width: glowRadius * 2,
                height: glowRadius * 2
            )),
            with: .radialGradient(
                Gradient(colors: [
                    coreColor.opacity(0.4),
                    midColor.opacity(0.2),
                    .clear
                ]),
                center: center,
                startRadius: 0,
                endRadius: glowRadius
            )
        )

        // Core orb
        context.fill(
            Circle().path(in: CGRect(
                x: center.x - orbRadius,
                y: center.y - orbRadius,
                width: orbRadius * 2,
                height: orbRadius * 2
            )),
            with: .radialGradient(
                Gradient(colors: [
                    .white.opacity(0.9),
                    coreColor,
                    midColor
                ]),
                center: CGPoint(x: center.x - orbRadius * 0.2, y: center.y - orbRadius * 0.2),
                startRadius: 0,
                endRadius: orbRadius * 1.5
            )
        )
    }
}

// MARK: - Preview

#Preview("Particle Vortex Waveform") {
    ParticleVortexPreview()
}

private struct ParticleVortexPreview: View {
    @State private var level: Float = 0.5
    @State private var isRecording = true
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                // Dark background for better visibility
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.liquidGlassDeep)

                ParticleVortexWaveform(
                    audioLevel: isAnimating ? level : level,
                    isRecording: isRecording
                )
                .padding(20)
            }
            .frame(width: 250, height: 250)

            VStack(spacing: 16) {
                Toggle("Recording", isOn: $isRecording)
                    .toggleStyle(.switch)

                Toggle("Simulate Audio", isOn: $isAnimating)
                    .toggleStyle(.switch)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Audio Level: \(String(format: "%.2f", level))")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Slider(value: Binding(
                        get: { Double(level) },
                        set: { level = Float($0) }
                    ))
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            )
        }
        .padding()
        .frame(width: 320)
        .background(Color.black.opacity(0.9))
        .task {
            // Simulate audio fluctuations when animating
            while !Task.isCancelled {
                if isAnimating {
                    let newLevel = Float.random(in: 0.2...0.9)
                    withAnimation(.easeInOut(duration: 0.3)) {
                        level = newLevel
                    }
                }
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
    }
}
