// RecordingModal.swift
// macOS Local Speech-to-Text Application
//
// User Story 1: Quick Speech-to-Text Capture
// Task T027: RecordingModal - Main recording UI with frosted glass effect,
// waveform visualization, and spring animations

import OSLog
import SwiftUI

/// RecordingModal provides the main recording interface with frosted glass effect
struct RecordingModal: View {
    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    /// ViewModel must be passed in from outside to avoid actor existential crashes
    /// during SwiftUI body evaluation. Creating RecordingViewModel inline with @State
    /// triggers executor checks that can cause EXC_BAD_ACCESS on ARM64.
    @State var viewModel: RecordingViewModel
    @State private var showError: Bool = false
    @State private var isVisible: Bool = false
    @State private var isDismissing: Bool = false
    /// Controls the recording task lifecycle - changing this cancels and restarts the task
    @State private var recordingTaskId: UUID?
    /// Controls the dismiss task lifecycle
    @State private var dismissTaskId: UUID?

    // MARK: - Initialization

    /// Initialize with an externally-created ViewModel to avoid actor existential crashes
    init(viewModel: RecordingViewModel = RecordingViewModel()) {
        self._viewModel = State(initialValue: viewModel)
    }

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
                WaveformView(audioLevel: Float(viewModel.audioLevel))
                    .frame(height: 80)
                    .accessibilityIdentifier("waveformView")
                    .accessibilityLabel("Audio waveform")
                    .accessibilityValue("\(Int(viewModel.audioLevel * 100))% audio level")

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
            // Trigger recording task
            recordingTaskId = UUID()
        }
        // Recording task - automatically cancelled when recordingTaskId changes or view disappears
        .task(id: recordingTaskId) {
            guard recordingTaskId != nil else { return }
            do {
                try await viewModel.startRecording()
            } catch {
                guard !Task.isCancelled else { return }
                viewModel.errorMessage = "Failed to start recording: \(error.localizedDescription)"
                AppLogger.viewModel.error("startRecording failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        // Dismiss task - runs when dismissTaskId is set, auto-cancelled on view disappear
        .task(id: dismissTaskId) {
            guard dismissTaskId != nil else { return }
            // Capture dismiss action eagerly before any async work to avoid dangling @Environment
            let dismissAction = dismiss
            await viewModel.cancelRecording()
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            dismissAction()
        }
        .onDisappear {
            // Cancel tasks by clearing their IDs (triggers task cancellation)
            recordingTaskId = nil
            dismissTaskId = nil

            // Cleanup only if not already dismissing (dismissTask handles cleanup in that case)
            guard !isDismissing else { return }
            // Use detached task for cleanup since view is disappearing
            // This is safe because cancelRecording is idempotent
            Task.detached { @MainActor in
                await viewModel.cancelRecording()
            }
        }
        // T030: Handle Escape key
        .onKeyPress(.escape) {
            handleDismiss()
            return .handled
        }
        .onChange(of: viewModel.errorMessage) { _, newValue in
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
                    .accessibilityIdentifier("recordingStatus")

                if viewModel.isRecording {
                    Text("Speak now...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Language indicator (T068)
            if let language = viewModel.currentLanguageModel {
                HStack(spacing: 4) {
                    Text(language.flag)
                        .font(.caption)

                    if viewModel.isLanguageSwitching {
                        ProgressView()
                            .scaleEffect(0.5)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color("AmberPrimary", bundle: nil).opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // Close button (keyboard shortcut handled by .onKeyPress above)
            Button(action: handleDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("closeButton")
            .accessibilityLabel("Close recording modal")
        }
        .accessibilityIdentifier("recordingHeader")
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
        .accessibilityIdentifier("errorMessage")
        .accessibilityLabel("Error: \(message)")
    }

    /// Action buttons
    private var actionButtons: some View {
        HStack(spacing: 12) {
            if viewModel.isRecording {
                // Stop button
                Button("Stop Recording") {
                    Task {
                        do {
                            try await viewModel.stopRecording()
                        } catch {
                            viewModel.errorMessage = "Failed to process recording: \(error.localizedDescription)"
                            AppLogger.viewModel.error("stopRecording failed: \(error.localizedDescription, privacy: .public)")
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
                .accessibilityIdentifier("stopRecordingButton")
            }

            // Cancel button (keyboard shortcut handled by .onKeyPress above)
            Button("Cancel") {
                handleDismiss()
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("cancelButton")
        }
        .accessibilityIdentifier("actionButtons")
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
        // Prevent double-dismissal
        guard !isDismissing else { return }
        isDismissing = true

        // Cancel recording task by clearing its ID
        recordingTaskId = nil

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isVisible = false
        }

        // Trigger dismiss task - it will handle cleanup and dismissal
        dismissTaskId = UUID()
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
