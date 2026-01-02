import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var hotkeyService: HotkeyService?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure only one instance of the app runs
        if NSRunningApplication.runningApplications(withBundleIdentifier: Constants.App.bundleIdentifier).count > 1 {
            NSApp.terminate(nil)
            return
        }

        // Initialize menu bar
        setupMenuBar()

        // Initialize global hotkey
        Task {
            await setupGlobalHotkey()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup
        hotkeyService = nil
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep app running in menu bar even if windows are closed
        return false
    }

    // MARK: - Menu Bar Setup

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Speech to Text")
            button.imagePosition = .imageLeading
        }
    }

    // MARK: - Global Hotkey Setup

    private func setupGlobalHotkey() async {
        hotkeyService = HotkeyService()

        // Default hotkey: Cmd+Ctrl+Space
        do {
            try await hotkeyService?.registerHotkey(
                keyCode: 49, // Space
                modifiers: [.command, .control]
            ) {
                // Hotkey triggered - show recording modal
                self.showRecordingModal()
            }
        } catch {
            print("Failed to register global hotkey: \(error.localizedDescription)")
        }
    }

    // MARK: - Recording Modal

    private func showRecordingModal() {
        // This will be implemented when we create RecordingModal view
        print("Hotkey triggered - showing recording modal")
    }
}
