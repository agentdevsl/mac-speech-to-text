// DynamicWaveformView.swift
// macOS Local Speech-to-Text Application
//
// Part 1: Glass Recording Overlay
// Dynamic waveform visualization with 15-20 vertical bars
// Amber gradient on glass background with spring physics

import SwiftUI

/// Dynamic waveform visualization with animated vertical bars
/// Designed for the Glass Recording Overlay with spring physics and amber gradient
struct DynamicWaveformView: View {
    // MARK: - Properties

    /// Current audio level (0.0 - 1.0)
    let audioLevel: Float

    /// Number of waveform bars
    private let barCount: Int = 18

    /// Bar spacing
    private let barSpacing: CGFloat = 3

    /// Previous audio levels for smooth wave effect
    @State private var levelHistory: [Float]

    /// Controls subtle pulse animation when silent
    @State private var silentPulsePhase: CGFloat = 0

    /// Timer for silent pulse animation
    @State private var pulseTimer: Timer?

    // MARK: - Initialization

    init(audioLevel: Float) {
        self.audioLevel = audioLevel
        // Initialize with small values for subtle idle appearance
        self._levelHistory = State(initialValue: Array(repeating: 0.1, count: 18))
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                barView(for: index)
            }
        }
        .accessibilityIdentifier("dynamicWaveformView")
        .accessibilityLabel("Audio waveform visualization")
        .accessibilityValue("Audio level at \(Int(audioLevel * 100)) percent")
        .onChange(of: audioLevel) { _, newValue in
            updateLevelHistory(newLevel: newValue)
        }
        .onAppear {
            startSilentPulseAnimation()
        }
        .onDisappear {
            stopSilentPulseAnimation()
        }
    }

    // MARK: - Subviews

    /// Individual bar view with height based on level and position
    private func barView(for index: Int) -> some View {
        let level = levelForBar(at: index)
        let minHeight: CGFloat = 6
        let maxHeight: CGFloat = 40

        // Add subtle pulse when silent
        let pulseOffset = isSilent ? sin(silentPulsePhase + CGFloat(index) * 0.3) * 0.05 : 0
        let effectiveLevel = CGFloat(level) + pulseOffset

        let barHeight = max(minHeight, effectiveLevel * maxHeight)

        return RoundedRectangle(cornerRadius: 2)
            .fill(gradientForLevel(level))
            .frame(width: 4, height: barHeight)
            .animation(
                .spring(response: 0.2, dampingFraction: 0.6, blendDuration: 0.1),
                value: level
            )
    }

    // MARK: - Computed Properties

    /// Whether the audio is essentially silent
    private var isSilent: Bool {
        audioLevel < 0.05
    }

    // MARK: - Private Methods

    /// Calculate level for a specific bar position (creates wave pattern)
    private func levelForBar(at index: Int) -> Float {
        guard !levelHistory.isEmpty else { return 0.1 }

        // Create a wave effect by using offset indices from center
        let centerIndex = barCount / 2
        let distanceFromCenter = abs(index - centerIndex)

        // Use different history indices based on distance from center
        let historyIndex = min(distanceFromCenter, levelHistory.count - 1)

        // Get base level from history
        let baseLevel = levelHistory[historyIndex]

        // Apply decay based on distance from center (creates wave shape)
        let decay = 1.0 - (Float(distanceFromCenter) * 0.08)

        // Add slight randomization for organic feel
        let variation = Float.random(in: 0.95...1.05)

        return max(0.1, baseLevel * decay * variation) // Minimum 0.1 for visibility
    }

    /// Update level history with new audio level
    private func updateLevelHistory(newLevel: Float) {
        guard !levelHistory.isEmpty else { return }

        // Shift history and add new level at the front
        levelHistory.removeFirst()
        let clampedLevel = min(1.0, max(0.0, newLevel))
        levelHistory.append(clampedLevel)
    }

    /// Determine gradient fill based on audio level
    private func gradientForLevel(_ level: Float) -> LinearGradient {
        let baseColor: Color
        let highlightColor: Color

        switch level {
        case 0.0..<0.3:
            // Low level - subtle amber
            baseColor = .warmAmberLight.opacity(0.6)
            highlightColor = .warmAmberLight
        case 0.3..<0.7:
            // Medium level - warm amber
            baseColor = .warmAmber.opacity(0.8)
            highlightColor = .warmAmberLight
        default:
            // High level - bright amber with glow effect
            baseColor = .warmAmber
            highlightColor = .warmAmberLight
        }

        return LinearGradient(
            colors: [highlightColor, baseColor],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Start subtle pulsing animation when silent
    private func startSilentPulseAnimation() {
        pulseTimer?.invalidate()
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            Task { @MainActor in
                silentPulsePhase += 0.15
                if silentPulsePhase > .pi * 2 {
                    silentPulsePhase = 0
                }
            }
        }
    }

    /// Stop the pulse animation
    private func stopSilentPulseAnimation() {
        pulseTimer?.invalidate()
        pulseTimer = nil
    }
}

// MARK: - Previews

#Preview("Idle/Silent") {
    DynamicWaveformView(audioLevel: 0.0)
        .frame(width: 200, height: 50)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
}

#Preview("Low Level") {
    DynamicWaveformView(audioLevel: 0.25)
        .frame(width: 200, height: 50)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
}

#Preview("Medium Level") {
    DynamicWaveformView(audioLevel: 0.5)
        .frame(width: 200, height: 50)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
}

#Preview("High Level") {
    DynamicWaveformView(audioLevel: 0.9)
        .frame(width: 200, height: 50)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
}

#Preview("Animated") {
    DynamicWaveformAnimatedPreview()
}

/// Preview helper for animated dynamic waveform
private struct DynamicWaveformAnimatedPreview: View {
    @State private var level: Float = 0.5
    @State private var previewTimer: Timer?

    var body: some View {
        VStack(spacing: 20) {
            DynamicWaveformView(audioLevel: level)
                .frame(width: 200, height: 50)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())

            Slider(value: Binding(
                get: { Double(level) },
                set: { level = Float($0) }
            ), in: 0...1)
            .frame(width: 200)

            Text("Audio Level: \(Int(level * 100))%")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(40)
        .background(Color.gray.opacity(0.2))
        .onAppear {
            previewTimer?.invalidate()
            previewTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in
                Task { @MainActor in
                    // Simulate natural speech patterns
                    let base = Float.random(in: 0.2...0.8)
                    let variation = Float.random(in: -0.1...0.1)
                    level = max(0, min(1, base + variation))
                }
            }
        }
        .onDisappear {
            previewTimer?.invalidate()
            previewTimer = nil
        }
    }
}
