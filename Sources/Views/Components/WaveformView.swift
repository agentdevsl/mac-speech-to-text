// WaveformView.swift
// macOS Local Speech-to-Text Application
//
// User Story 1: Quick Speech-to-Text Capture
// Task T026: WaveformView - Real-time audio level visualization
// with 30+ fps canvas-based rendering

import SwiftUI

/// WaveformView displays real-time audio levels as animated waveform bars
struct WaveformView: View {
    // MARK: - Properties

    /// Current audio level (0.0 - 1.0)
    let audioLevel: Float

    /// Number of waveform bars
    private let barCount: Int = 60

    /// Previous audio levels for smooth transitions
    @State private var levelHistory: [Float] = Array(repeating: 0.0, count: 60)

    // MARK: - Body

    var body: some View {
        Canvas { context, size in
            let barWidth = size.width / CGFloat(barCount)
            let spacing: CGFloat = 2
            let effectiveBarWidth = barWidth - spacing

            for index in 0..<barCount {
                // Get historical level for this bar (creates wave effect)
                let historyIndex = (levelHistory.count - 1 - index) % levelHistory.count
                let level = CGFloat(levelHistory[historyIndex])

                // Calculate bar height with minimum height
                let minHeight: CGFloat = 4
                let maxHeight = size.height * 0.8
                let barHeight = max(minHeight, level * maxHeight)

                // Calculate bar position
                let xPos = CGFloat(index) * barWidth
                let yPos = (size.height - barHeight) / 2

                // Create bar rectangle
                let barRect = CGRect(
                    x: xPos,
                    y: yPos,
                    width: effectiveBarWidth,
                    height: barHeight
                )

                // Determine bar color based on level
                let barColor = colorForLevel(level: Float(level))

                // Draw rounded rectangle bar
                let path = RoundedRectangle(cornerRadius: effectiveBarWidth / 2)
                    .path(in: barRect)

                context.fill(path, with: .color(barColor))

                // Add glow effect for high levels
                if level > 0.7 {
                    context.fill(
                        path,
                        with: .color(barColor.opacity(0.3))
                    )
                }
            }
        }
        .frame(height: 80)
        .accessibilityIdentifier("waveformView")
        .accessibilityLabel("Audio waveform visualization")
        .accessibilityValue("Audio level at \(Int(audioLevel * 100)) percent")
        .onChange(of: audioLevel) { _, newValue in
            updateLevelHistory(newLevel: newValue)
        }
    }

    // MARK: - Private Methods

    /// Update level history for smooth wave animation
    private func updateLevelHistory(newLevel: Float) {
        // Guard against empty array to prevent index out of bounds crash
        guard !levelHistory.isEmpty else { return }
        // Shift history and add new level
        levelHistory.removeFirst()
        levelHistory.append(min(1.0, max(0.0, newLevel))) // Clamp to valid range
    }

    /// Determine color based on audio level
    private func colorForLevel(level: Float) -> Color {
        switch level {
        case 0.0..<0.3:
            // Low level - subtle amber
            return Color("AmberLight", bundle: nil)
        case 0.3..<0.7:
            // Medium level - warm amber
            return Color("AmberPrimary", bundle: nil)
        default:
            // High level - bright amber
            return Color("AmberBright", bundle: nil)
        }
    }
}

// MARK: - Previews

#Preview("Idle") {
    WaveformView(audioLevel: 0.0)
        .padding()
        .background(.ultraThinMaterial)
}

#Preview("Low Level") {
    WaveformView(audioLevel: 0.2)
        .padding()
        .background(.ultraThinMaterial)
}

#Preview("Medium Level") {
    WaveformView(audioLevel: 0.5)
        .padding()
        .background(.ultraThinMaterial)
}

#Preview("High Level") {
    WaveformView(audioLevel: 0.9)
        .padding()
        .background(.ultraThinMaterial)
}

#Preview("Animated") {
    WaveformAnimatedPreview()
}

/// Preview helper for animated waveform
private struct WaveformAnimatedPreview: View {
    @State private var level: Float = 0.5
    @State private var previewTimer: Timer?

    var body: some View {
        VStack(spacing: 20) {
            WaveformView(audioLevel: level)
                .padding()
                .background(.ultraThinMaterial)

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
            // Invalidate existing timer to prevent accumulation on re-appear
            previewTimer?.invalidate()
            // Simulate audio levels
            previewTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                Task { @MainActor in
                    level = Float.random(in: 0.0...1.0)
                }
            }
        }
        .onDisappear {
            previewTimer?.invalidate()
            previewTimer = nil
        }
    }
}
