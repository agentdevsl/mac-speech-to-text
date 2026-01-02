import SwiftUI

@main
struct SpeechToTextApp: App {
    @State private var appState = AppState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Speech to Text", systemImage: "mic.fill") {
            MenuBarView()
                .environment(appState)
        }
        .menuBarExtraStyle(.window)
    }

    init() {
        // Initialize FluidAudio on app startup
        Task {
            await appState.initializeFluidAudio()
        }
    }
}
