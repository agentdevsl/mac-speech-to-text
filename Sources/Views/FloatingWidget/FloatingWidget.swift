// FloatingWidget.swift
// macOS Local Speech-to-Text Application
//
// Phase 2.1: Main FloatingWidget SwiftUI view
// Compact pill-shaped widget that expands during recording
// - Idle: 64x32 capsule with microphone icon
// - Recording: Expands to 200x60 with waveform and indicator

import SwiftUI

/// Compact floating widget for speech-to-text recording
struct FloatingWidget: View {
    // MARK: - State

    /// ViewModel managing recording state and audio levels
    @State var viewModel: FloatingWidgetViewModel

    // MARK: - Constants

    /// Widget dimensions for idle state
    private let idleWidth: CGFloat = 64
    private let idleHeight: CGFloat = 32

    /// Widget dimensions for recording state
    private let recordingWidth: CGFloat = 200
    private let recordingHeight: CGFloat = 60

    // MARK: - Initialization

    init(viewModel: FloatingWidgetViewModel = FloatingWidgetViewModel()) {
        self._viewModel = State(initialValue: viewModel)
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 8) {
            // Microphone icon
            microphoneIcon

            // Show waveform and indicator when recording
            if viewModel.isRecording {
                MiniWaveformView(audioLevel: viewModel.audioLevel)
                    .frame(width: 80, height: 32)
                    .transition(.opacity.combined(with: .scale))

                recordingIndicator
                    .transition(.opacity.combined(with: .scale))
            }

            // Show progress indicator when transcribing
            if viewModel.isTranscribing {
                transcribingIndicator
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(.horizontal, viewModel.isRecording ? 16 : 12)
        .padding(.vertical, 8)
        .frame(
            width: viewModel.isRecording ? recordingWidth : idleWidth,
            height: viewModel.isRecording ? recordingHeight : idleHeight
        )
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.isRecording)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.isTranscribing)
        .onTapGesture {
            handleTap()
        }
        .accessibilityIdentifier("floatingWidget")
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Double tap to toggle recording")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Subviews

    /// Microphone icon with state-based styling
    private var microphoneIcon: some View {
        Image(systemName: iconName)
            .font(.system(size: viewModel.isRecording ? 20 : 16, weight: .medium))
            .foregroundStyle(iconColor)
            .symbolEffect(.pulse, isActive: viewModel.isRecording)
            .accessibilityHidden(true)
    }

    /// Recording duration/status indicator
    private var recordingIndicator: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 8, height: 8)
            .overlay(
                Circle()
                    .fill(Color.red.opacity(0.4))
                    .frame(width: 16, height: 16)
            )
            .accessibilityHidden(true)
    }

    /// Transcribing progress indicator
    private var transcribingIndicator: some View {
        ProgressView()
            .scaleEffect(0.6)
            .accessibilityHidden(true)
    }

    // MARK: - Computed Properties

    /// Icon name based on state
    private var iconName: String {
        if viewModel.isTranscribing {
            return "waveform"
        } else if viewModel.isRecording {
            return "mic.fill"
        } else {
            return "mic"
        }
    }

    /// Icon color based on state
    private var iconColor: Color {
        if viewModel.isRecording {
            return .red
        } else if viewModel.isTranscribing {
            return Color.warmAmber
        } else {
            return Color.warmAmber
        }
    }

    /// Accessibility label based on state
    private var accessibilityLabel: String {
        if viewModel.isTranscribing {
            return "Transcribing speech"
        } else if viewModel.isRecording {
            return "Recording in progress. Audio level at \(Int(viewModel.audioLevel * 100)) percent"
        } else {
            return "Speech to text widget. Tap to start recording"
        }
    }

    // MARK: - Actions

    /// Handle tap gesture - toggle recording
    private func handleTap() {
        Task {
            await viewModel.toggleRecording()
        }
    }
}

// MARK: - Previews

#Preview("Idle State") {
    FloatingWidget()
        .padding(40)
        .background(Color.gray.opacity(0.3))
}

#Preview("Recording State") {
    FloatingWidgetRecordingPreview()
        .padding(40)
        .background(Color.gray.opacity(0.3))
}

/// Preview helper for recording state
private struct FloatingWidgetRecordingPreview: View {
    @State private var viewModel = FloatingWidgetViewModel()
    @State private var previewTimer: Timer?

    var body: some View {
        FloatingWidget(viewModel: viewModel)
            .onAppear {
                // Simulate recording state
                viewModel.isRecording = true
                viewModel.audioLevel = 0.5

                // Animate audio levels
                previewTimer?.invalidate()
                previewTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                    Task { @MainActor in
                        viewModel.audioLevel = Float.random(in: 0.2...0.9)
                    }
                }
            }
            .onDisappear {
                previewTimer?.invalidate()
                previewTimer = nil
            }
    }
}

#Preview("Transcribing State") {
    FloatingWidgetTranscribingPreview()
        .padding(40)
        .background(Color.gray.opacity(0.3))
}

/// Preview helper for transcribing state
private struct FloatingWidgetTranscribingPreview: View {
    @State private var viewModel = FloatingWidgetViewModel()

    var body: some View {
        FloatingWidget(viewModel: viewModel)
            .onAppear {
                viewModel.isTranscribing = true
            }
    }
}
