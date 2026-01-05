// MenuBarView.swift
// macOS Local Speech-to-Text Application
//
// Ultra-minimal menu bar dropdown: Open app + Quit
// All settings moved to MainView

import SwiftUI

/// Ultra-minimal menu bar dropdown
struct MenuBarView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = MenuBarViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Voice monitoring status (when active)
            if appState.voiceTriggerState.isActive {
                VoiceMonitoringStatusRow(state: appState.voiceTriggerState)
                Divider()
            }

            // Open Speech to Text
            Button {
                viewModel.openMainView()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.statusIcon)
                        .foregroundStyle(viewModel.iconColor)
                    Text("Open Speech to Text")
                    Spacer()
                    Text(",")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            // Quit
            Button {
                viewModel.quit()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "power")
                        .foregroundStyle(.red)
                    Text("Quit")
                    Spacer()
                    Text("Q")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q", modifiers: .command)
        }
        .frame(width: 220)
    }
}

// MARK: - Voice Monitoring Status Row

/// Status row showing voice monitoring state in the menu dropdown
struct VoiceMonitoringStatusRow: View {
    let state: VoiceTriggerState

    @State private var isPulsing: Bool = false

    private var statusIcon: String {
        switch state {
        case .monitoring:
            return "waveform.circle.fill"
        case .triggered, .capturing:
            return "mic.circle.fill"
        case .transcribing:
            return "text.bubble.fill"
        case .inserting:
            return "text.cursor"
        default:
            return "waveform.circle"
        }
    }

    private var statusColor: Color {
        switch state {
        case .monitoring:
            return .amberPrimary
        case .triggered, .capturing:
            return .recordingActive
        case .transcribing, .inserting:
            return .info
        default:
            return .textSecondary
        }
    }

    private var shouldPulse: Bool {
        switch state {
        case .monitoring, .capturing:
            return true
        default:
            return false
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
                .opacity(isPulsing ? 0.6 : 1.0)
                .animation(
                    shouldPulse ?
                        .easeInOut(duration: 0.8).repeatForever(autoreverses: true) :
                        .default,
                    value: isPulsing
                )

            Text(state.description)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .onAppear {
            if shouldPulse {
                isPulsing = true
            }
        }
        .onChange(of: state) { _, newState in
            let newShouldPulse: Bool
            switch newState {
            case .monitoring, .capturing:
                newShouldPulse = true
            default:
                newShouldPulse = false
            }

            if newShouldPulse && !isPulsing {
                isPulsing = true
            } else if !newShouldPulse {
                isPulsing = false
            }
        }
    }
}

#Preview("Menu Bar View") {
    MenuBarView()
        .environment(AppState())
}

#Preview("Menu Bar View - Voice Monitoring Active") {
    let appState = AppState()
    appState.voiceTriggerState = .monitoring
    return MenuBarView()
        .environment(appState)
}

#Preview("Menu Bar View - Capturing") {
    let appState = AppState()
    appState.voiceTriggerState = .capturing
    return MenuBarView()
        .environment(appState)
}
