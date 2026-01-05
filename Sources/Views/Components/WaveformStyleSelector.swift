// WaveformStyleSelector.swift
// macOS Local Speech-to-Text Application
//
// Unified waveform visualization selector
// Renders the appropriate waveform based on the selected style from settings

import SwiftUI

// MARK: - Unified Waveform View

/// Unified waveform visualization that switches between styles based on settings
struct WaveformVisualization: View {
    let style: WaveformStyleOption
    let audioLevel: Float
    let isRecording: Bool

    var body: some View {
        Group {
            switch style {
            case .aurora:
                AuroraWaveform(audioLevel: audioLevel, isRecording: isRecording)

            case .siriRings:
                SiriStyleRingWaves(audioLevel: audioLevel, isRecording: isRecording)

            case .particleVortex:
                ParticleVortexWaveform(audioLevel: audioLevel, isRecording: isRecording)

            case .crystalline:
                CrystallineMorphWaveform(audioLevel: audioLevel, isRecording: isRecording)

            case .liquidOrb:
                LiquidOrbWaveform(audioLevel: audioLevel, isRecording: isRecording)

            case .flowingRibbon:
                FlowingRibbonWaveform(audioLevel: audioLevel, isRecording: isRecording)
            }
        }
    }
}

// MARK: - Waveform Style Picker (Compact)

/// Compact picker for waveform style in settings
struct WaveformStyleCompactPicker: View {
    @Binding var selectedStyle: WaveformStyleOption

    var body: some View {
        Picker("Waveform Style", selection: $selectedStyle) {
            ForEach(WaveformStyleOption.allCases, id: \.self) { style in
                Label(style.displayName, systemImage: style.iconName)
                    .tag(style)
            }
        }
        .pickerStyle(.menu)
    }
}

// MARK: - Preview

#Preview("Waveform Visualization") {
    WaveformVisualizationPreview()
}

private struct WaveformVisualizationPreview: View {
    @State private var selectedStyle: WaveformStyleOption = .aurora
    @State private var audioLevel: Float = 0.5
    @State private var isRecording = true
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 24) {
            // Preview area
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)

                WaveformVisualization(
                    style: selectedStyle,
                    audioLevel: audioLevel,
                    isRecording: isRecording
                )
                .frame(width: 180, height: 80)
            }
            .frame(height: 120)

            // Style picker
            Picker("Style", selection: $selectedStyle) {
                ForEach(WaveformStyleOption.allCases, id: \.self) { style in
                    Text(style.displayName).tag(style)
                }
            }
            .pickerStyle(.segmented)

            // Controls
            VStack(spacing: 12) {
                Toggle("Recording", isOn: $isRecording)

                Toggle("Animate", isOn: $isAnimating)
                    .onChange(of: isAnimating) { _, newValue in
                        if newValue { startAnimation() }
                    }

                HStack {
                    Text("Level")
                    Slider(value: Binding(
                        get: { Double(audioLevel) },
                        set: { audioLevel = Float($0) }
                    ))
                    .disabled(isAnimating)
                }
            }
        }
        .padding()
        .frame(width: 350)
        .background(Color.black.opacity(0.9))
    }

    private func startAnimation() {
        guard isAnimating else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            audioLevel = Float.random(in: 0.2...0.85)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            startAnimation()
        }
    }
}
