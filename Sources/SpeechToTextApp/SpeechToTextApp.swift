import SwiftUI

@main
struct SpeechToTextApp: App {
    @State private var appState = AppState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(appState)
        } label: {
            MenuBarIconView(voiceTriggerState: appState.voiceTriggerState)
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Menu Bar Icon View

/// Menu bar icon with visual indicator for voice trigger monitoring
struct MenuBarIconView: View {
    let voiceTriggerState: VoiceTriggerState

    /// Whether to show the monitoring indicator
    private var isMonitoringActive: Bool {
        voiceTriggerState.isActive
    }

    /// Color for the monitoring indicator based on state
    private var indicatorColor: Color {
        switch voiceTriggerState {
        case .monitoring:
            return .amberPrimary
        case .triggered, .capturing:
            return .recordingActive
        case .transcribing, .inserting:
            return .info
        default:
            return .clear
        }
    }

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "mic.fill")
                .symbolRenderingMode(.monochrome)

            if isMonitoringActive {
                VoiceMonitoringIndicator(
                    state: voiceTriggerState,
                    color: indicatorColor
                )
            }
        }
    }
}

/// Pulsing dot indicator for voice monitoring state
struct VoiceMonitoringIndicator: View {
    let state: VoiceTriggerState
    let color: Color

    @State private var isPulsing: Bool = false

    /// Whether to animate the pulse based on state
    private var shouldPulse: Bool {
        switch state {
        case .monitoring, .capturing:
            return true
        default:
            return false
        }
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .opacity(isPulsing ? 0.5 : 1.0)
            .animation(
                shouldPulse ?
                    .easeInOut(duration: 0.8).repeatForever(autoreverses: true) :
                    .default,
                value: isPulsing
            )
            .onAppear {
                if shouldPulse {
                    isPulsing = true
                }
            }
            .onChange(of: state) { _, newState in
                // Update pulsing based on new state
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
