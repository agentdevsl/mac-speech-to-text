// MiniWaveformView.swift
// macOS Local Speech-to-Text Application
//
// Phase 2.1: Compact waveform visualization for FloatingWidget
// Displays 5-7 animated bars representing audio levels

import SwiftUI

/// Compact waveform visualization with 5-7 animated bars
struct MiniWaveformView: View {
    // MARK: - Properties

    /// Current audio level (0.0 - 1.0)
    let audioLevel: Float

    /// Number of waveform bars
    private let barCount: Int = 7

    /// Bar spacing
    private let spacing: CGFloat = 2

    /// Previous audio levels for smooth wave effect
    @State private var levelHistory: [Float]

    // MARK: - Initialization

    init(audioLevel: Float) {
        self.audioLevel = audioLevel
        // Initialize with zeros, one for each bar
        self._levelHistory = State(initialValue: Array(repeating: 0.0, count: 7))
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<barCount, id: \.self) { index in
                barView(for: index)
            }
        }
        .accessibilityIdentifier("miniWaveformView")
        .accessibilityLabel("Audio level indicator")
        .accessibilityValue("\(Int(audioLevel * 100)) percent")
        .onChange(of: audioLevel) { _, newValue in
            updateLevelHistory(newLevel: newValue)
        }
    }

    // MARK: - Subviews

    /// Individual bar view with height based on level
    private func barView(for index: Int) -> some View {
        let level = levelForBar(at: index)
        let minHeight: CGFloat = 4
        let maxHeight: CGFloat = 32

        return RoundedRectangle(cornerRadius: 2)
            .fill(colorForLevel(level))
            .frame(width: 4, height: max(minHeight, CGFloat(level) * maxHeight))
            .animation(.spring(response: 0.15, dampingFraction: 0.6), value: level)
    }

    // MARK: - Private Methods

    /// Calculate level for a specific bar position (creates wave pattern)
    private func levelForBar(at index: Int) -> Float {
        guard !levelHistory.isEmpty else { return 0 }

        // Create a wave effect by using offset indices
        let centerIndex = barCount / 2
        let distanceFromCenter = abs(index - centerIndex)
        let historyIndex = min(distanceFromCenter, levelHistory.count - 1)

        // Apply decay based on distance from center
        let baseLevel = levelHistory[historyIndex]
        let decay = 1.0 - (Float(distanceFromCenter) * 0.15)

        return max(0, baseLevel * decay)
    }

    /// Update level history with new audio level
    private func updateLevelHistory(newLevel: Float) {
        guard !levelHistory.isEmpty else { return }

        // Shift history and add new level at the front
        levelHistory.removeFirst()
        let clampedLevel = min(1.0, max(0.0, newLevel))
        levelHistory.append(clampedLevel)
    }

    /// Determine color based on audio level
    private func colorForLevel(_ level: Float) -> Color {
        switch level {
        case 0.0..<0.3:
            return Color.warmAmberLight
        case 0.3..<0.7:
            return Color.warmAmber
        default:
            return Color.warmAmber.opacity(0.9)
        }
    }
}

// MARK: - Previews

#Preview("Idle") {
    MiniWaveformView(audioLevel: 0.0)
        .padding()
        .background(.ultraThinMaterial)
}

#Preview("Low Level") {
    MiniWaveformView(audioLevel: 0.3)
        .padding()
        .background(.ultraThinMaterial)
}

#Preview("High Level") {
    MiniWaveformView(audioLevel: 0.9)
        .padding()
        .background(.ultraThinMaterial)
}

#Preview("Animated") {
    MiniWaveformAnimatedPreview()
}

/// Preview helper for animated mini waveform
private struct MiniWaveformAnimatedPreview: View {
    @State private var level: Float = 0.5
    @State private var previewTimer: Timer?

    var body: some View {
        VStack(spacing: 20) {
            MiniWaveformView(audioLevel: level)
                .frame(height: 40)
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(Capsule())

            Slider(value: Binding(
                get: { Double(level) },
                set: { level = Float($0) }
            ), in: 0...1)
            .padding()

            Text("Audio Level: \(Int(level * 100))%")
                .font(.caption)
        }
        .padding()
        .onAppear {
            previewTimer?.invalidate()
            previewTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                Task { @MainActor in
                    level = Float.random(in: 0.2...0.9)
                }
            }
        }
        .onDisappear {
            previewTimer?.invalidate()
            previewTimer = nil
        }
    }
}
