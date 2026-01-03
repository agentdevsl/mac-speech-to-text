// RecordingModal.swift
// macOS Local Speech-to-Text Application
//
// User Story 1: Quick Speech-to-Text Capture
// Task T027: RecordingModal - Main recording UI with frosted glass effect,
// waveform visualization, and spring animations

import SwiftUI

/// RecordingModal provides the main recording interface with frosted glass effect
struct RecordingModal: View {
    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var viewModel = RecordingViewModel()
    @State private var showError: Bool = false
    @State private var isVisible: Bool = false

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background dimming
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .onTapGesture {
                    // T030: Dismiss on outside click
                    handleDismiss()
                }

            // Main modal content
            VStack(spacing: 24) {
                // Header
                headerView

                // Waveform visualization (T026)
                WaveformView(audioLevel: viewModel.audioLevel)
                    .frame(height: 80)

                // Status text
                statusView

                // Error message (T031)
                if let errorMessage = viewModel.errorMessage, showError {
                    errorView(message: errorMessage)
                }

                // Action buttons
                actionButtons
            }
            .padding(32)
            .frame(width: 400)
            .background(.ultraThinMaterial) // Frosted glass effect
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            .scaleEffect(isVisible ? 1.0 : 0.8)
            .opacity(isVisible ? 1.0 : 0.0)
        }
        .onAppear {
            // Spring animation on appear
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                isVisible = true
            }
            // Auto-start recording
            Task {
                try? await viewModel.startRecording()
            }
        }
        .onDisappear {
            // Cleanup
            Task {
                await viewModel.cancelRecording()
            }
        }
        // T030: Handle Escape key
        .onKeyPress(.escape) {
            handleDismiss()
            return .handled
        }
        .onChange(of: viewModel.errorMessage) { oldValue, newValue in
            showError = newValue != nil
        }
    }

    // MARK: - Subviews

    /// Header with icon and title
    private var headerView: some View {
        HStack(spacing: 12) {
            // Microphone icon
            Image(systemName: viewModel.isRecording ? "mic.fill" : "mic.slash.fill")
                .font(.system(size: 32))
                .foregroundStyle(viewModel.isRecording ? .red : .gray)
                .symbolEffect(.pulse, isActive: viewModel.isRecording)

            VStack(alignment: .leading, spacing: 4) {
                Text(statusTitle)
                    .font(.title2)
                    .fontWeight(.semibold)

                if viewModel.isRecording {
                    Text("Speak now...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Close button
            Button(action: handleDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
        }
    }

    /// Status text based on current state
    private var statusView: some View {
        Group {
            if viewModel.isTranscribing {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Transcribing...")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } else if viewModel.isInserting {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Inserting text...")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } else if !viewModel.transcribedText.isEmpty {
                VStack(spacing: 8) {
                    Text(viewModel.transcribedText)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    if viewModel.confidence > 0 {
                        Text("Confidence: \(Int(viewModel.confidence * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(minHeight: 60)
    }

    /// Error message view
    private func errorView(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)

            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
        }
        .padding(12)
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    /// Action buttons
    private var actionButtons: some View {
        HStack(spacing: 12) {
            if viewModel.isRecording {
                // Stop button
                Button("Stop Recording") {
                    Task {
                        try? await viewModel.stopRecording()
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
            }

            // Cancel button
            Button("Cancel") {
                handleDismiss()
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.escape)
        }
    }

    // MARK: - Computed Properties

    /// Status title based on current state
    private var statusTitle: String {
        if viewModel.isRecording {
            return "Recording"
        } else if viewModel.isTranscribing {
            return "Processing"
        } else if viewModel.isInserting {
            return "Inserting"
        } else if !viewModel.transcribedText.isEmpty {
            return "Complete"
        } else {
            return "Ready"
        }
    }

    // MARK: - Private Methods

    /// Handle modal dismissal with animation
    private func handleDismiss() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isVisible = false
        }

        // Delay actual dismissal for animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dismiss()
        }

        // Cancel recording
        Task {
            await viewModel.cancelRecording()
        }
    }
}

// MARK: - Previews

#Preview("Recording") {
    RecordingModal()
}

#Preview("With Error") {
    RecordingModalPreview(showError: true)
}

#Preview("Transcribing") {
    RecordingModalPreview(transcribing: true)
}

/// Preview helper with customizable state
private struct RecordingModalPreview: View {
    let showError: Bool
    let transcribing: Bool

    init(showError: Bool = false, transcribing: Bool = false) {
        self.showError = showError
        self.transcribing = transcribing
    }

    var body: some View {
        RecordingModal()
    }
}
