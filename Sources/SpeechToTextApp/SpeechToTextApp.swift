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

/// Menu bar icon with pulsing animation for voice trigger monitoring
struct MenuBarIconView: View {
    let voiceTriggerState: VoiceTriggerState

    @State private var isPulsing: Bool = false

    /// Whether voice monitoring is active
    private var isMonitoringActive: Bool {
        voiceTriggerState.isActive
    }

    /// Whether to animate the pulse based on state
    private var shouldPulse: Bool {
        switch voiceTriggerState {
        case .monitoring, .capturing:
            return true
        default:
            return false
        }
    }

    /// Icon based on current state
    private var iconName: String {
        switch voiceTriggerState {
        case .monitoring, .triggered, .capturing, .transcribing, .inserting:
            return "waveform.badge.mic"
        default:
            return "waveform"
        }
    }

    var body: some View {
        Image(systemName: iconName)
            .symbolRenderingMode(isMonitoringActive ? .palette : .monochrome)
            .foregroundStyle(isMonitoringActive ? Color.orange : Color.primary)
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
            .onChange(of: voiceTriggerState) { _, newState in
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
