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
            // Subtle background for click-to-dismiss
            Color.black.opacity(0.01)
                .ignoresSafeArea()
                .onTapGesture {
                    // T030: Dismiss on outside click
                    handleDismiss()
                }

            // Compact glass modal
            VStack(spacing: 12) {
                // Compact header
                compactHeaderView

                // Flowing sound wave visualization
                FlowingSoundWave(audioLevel: Float(viewModel.audioLevel))
                    .frame(height: 36)
                    .accessibilityIdentifier("waveformView")
                    .accessibilityLabel("Audio waveform")
                    .accessibilityValue("\(Int(viewModel.audioLevel * 100))% audio level")

                // Compact status
                compactStatusView

                // Error message (T031)
                if let errorMessage = viewModel.errorMessage, showError {
                    compactErrorView(message: errorMessage)
                }

                // Inline microphone permission prompt
                if viewModel.showMicrophonePrompt {
                    InlineMicrophonePrompt(
                        onOpenSettings: {
                            viewModel.openMicrophoneSettings()
                        },
                        onCancel: {
                            viewModel.dismissMicrophonePrompt()
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Inline accessibility prompt (Phase 2.3)
                if viewModel.showAccessibilityPrompt {
                    InlineAccessibilityPrompt(
                        onEnableAutoPaste: {
                            viewModel.openAccessibilitySettings()
                            viewModel.dismissAccessibilityPrompt()
                        },
                        onUseClipboardOnly: {
                            viewModel.setClipboardOnlyMode()
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Compact action buttons
                compactActionButtons
            }
            .padding(16)
            .frame(width: 280)
            .background(
                ZStack {
                    // Deep glass effect
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .opacity(0.95)

                    // Inner glow
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.08),
                                    Color.clear
                                ],
                                center: .top,
                                startRadius: 0,
                                endRadius: 150
                            )
                        )

                    // Subtle border
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 8)
            .scaleEffect(isVisible ? 1.0 : 0.9)
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

    // MARK: - Compact Subviews

    /// Compact header with recording indicator
    private var compactHeaderView: some View {
        HStack(spacing: 10) {
            // Recording indicator dot
            Circle()
                .fill(viewModel.isRecording ? Color.red : Color.gray.opacity(0.4))
                .frame(width: 10, height: 10)
                .shadow(color: viewModel.isRecording ? .red.opacity(0.6) : .clear, radius: 4)

            Text(statusTitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
                .accessibilityIdentifier("recordingStatus")

            Spacer()

            // Close button
            Button(action: handleDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("closeButton")
            .accessibilityLabel("Close")
        }
        .accessibilityIdentifier("recordingHeader")
    }

    /// Compact status view
    private var compactStatusView: some View {
        Group {
            if viewModel.isTranscribing {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Transcribing...")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            } else if viewModel.isInserting {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Inserting...")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            } else if !viewModel.transcribedText.isEmpty {
                Text(viewModel.transcribedText)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            } else if viewModel.isRecording {
                Text("Listening...")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minHeight: 24)
    }

    /// Compact error view
    private func compactErrorView(message: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.red)

            Text(message)
                .font(.system(size: 10))
                .foregroundStyle(.red)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .transition(.opacity)
        .accessibilityIdentifier("errorMessage")
    }

    /// Compact action buttons
    private var compactActionButtons: some View {
        HStack(spacing: 8) {
            if viewModel.isRecording {
                Button {
                    Task {
                        do {
                            try await viewModel.stopRecording()
                            // Brief delay to show result, then auto-dismiss
                            try? await Task.sleep(nanoseconds: 600_000_000) // 0.6s
                            handleDismiss()
                        } catch {
                            viewModel.errorMessage = error.localizedDescription
                            AppLogger.viewModel.error("stopRecording failed: \(error.localizedDescription, privacy: .public)")
                        }
                    }
                } label: {
                    Text("Done")
                        .font(.system(size: 12, weight: .medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .keyboardShortcut(.return)
                .accessibilityIdentifier("stopRecordingButton")
            } else if viewModel.isTranscribing || viewModel.isInserting {
                // Show processing state - no buttons during transcription
                EmptyView()
            } else if !viewModel.transcribedText.isEmpty {
                // Success - show copied indicator briefly
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(viewModel.lastTranscriptionCopiedToClipboard ? "Copied!" : "Inserted!")
                        .font(.system(size: 12, weight: .medium))
                }
                .onAppear {
                    // Auto-dismiss after showing success
                    Task {
                        try? await Task.sleep(nanoseconds: 800_000_000) // 0.8s
                        handleDismiss()
                    }
                }
            }

            if viewModel.isRecording || viewModel.errorMessage != nil {
                Button {
                    handleDismiss()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 12))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityIdentifier("cancelButton")
            }
        }
        .accessibilityIdentifier("actionButtons")
    }

    // MARK: - Legacy Subviews (kept for compatibility)

    /// Header with icon and title - enhanced contrast
    private var headerView: some View {
        HStack(spacing: 14) {
            // Microphone icon with amber/red glow
            ZStack {
                Circle()
                    .fill(viewModel.isRecording ? Color.red.opacity(0.15) : Color.amberPrimary.opacity(0.1))
                    .frame(width: 48, height: 48)

                Image(systemName: viewModel.isRecording ? "mic.fill" : "mic.slash.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(viewModel.isRecording ? .red : Color.amberPrimary)
                    .symbolEffect(.pulse, isActive: viewModel.isRecording)
            }
            .shadow(color: viewModel.isRecording ? .red.opacity(0.3) : .clear, radius: 8, x: 0, y: 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(statusTitle)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)

                if viewModel.isRecording {
                    Text("Speak now...")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Close button
            Button(action: handleDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
    }

    /// Status text based on current state - enhanced readability
    private var statusView: some View {
        Group {
            if viewModel.isTranscribing {
                HStack(spacing: 10) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Transcribing...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.8))
                }
            } else if viewModel.isInserting {
                HStack(spacing: 10) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Inserting text...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.8))
                }
            } else if !viewModel.transcribedText.isEmpty {
                VStack(spacing: 6) {
                    Text(viewModel.transcribedText)
                        .font(.system(size: 15))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)

                    if viewModel.confidence > 0 {
                        Text("Confidence: \(Int(viewModel.confidence * 100))%")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(minHeight: 50)
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
                        do {
                            try await viewModel.stopRecording()
                            // Auto-dismiss after success
                            try? await Task.sleep(nanoseconds: 600_000_000)
                            handleDismiss()
                        } catch {
                            viewModel.errorMessage = "Failed to process recording: \(error.localizedDescription)"
                            AppLogger.viewModel.error("stopRecording failed: \(error.localizedDescription, privacy: .public)")
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
            }

            if viewModel.isRecording || viewModel.errorMessage != nil {
                // Cancel button (keyboard shortcut handled by .onKeyPress above)
                Button("Cancel") {
                    handleDismiss()
                }
                .buttonStyle(.bordered)
            }
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
