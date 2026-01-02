import SwiftUI

/// Menu bar dropdown content
struct MenuBarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 12) {
            // Stats section
            Text("Today: \(appState.statistics.today.totalWordsTranscribed) words")
                .font(.headline)

            Divider()

            // Menu options
            Button("Start Recording") {
                appState.startRecording()
            }

            Button("Open Settings") {
                appState.showSettings = true
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 200)
    }
}

#Preview {
    MenuBarView()
        .environment(AppState())
}
