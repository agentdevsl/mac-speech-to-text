import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var hotkeyService: HotkeyService?
    private var onboardingWindow: NSWindow?
    private let settingsService = SettingsService()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure only one instance of the app runs
        if NSRunningApplication.runningApplications(withBundleIdentifier: Constants.App.bundleIdentifier).count > 1 {
            NSApp.terminate(nil)
            return
        }

        // Check if first launch (T040)
        let settings = settingsService.load()
        if !settings.onboarding.completed {
            showOnboarding()
            return
        }

        // Initialize menu bar
        Task { @MainActor in
            setupMenuBar()
        }

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

    @MainActor
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Speech to Text")
            button.imagePosition = .imageLeading
        }

        // Create SwiftUI menu content (T045)
        let menuBarView = MenuBarView()
        let hostingView = NSHostingView(rootView: menuBarView)
        hostingView.frame.size = CGSize(width: 250, height: 400)

        // Create menu and attach to status item
        let menu = NSMenu()
        let menuItem = NSMenuItem()
        menuItem.view = hostingView
        menu.addItem(menuItem)

        statusItem?.menu = menu

        // Setup notification observers for menu actions (T046, T047)
        setupMenuActionObservers()
    }

    // MARK: - Menu Action Observers

    @MainActor
    private func setupMenuActionObservers() {
        // Observer for "Start Recording" action (T046)
        NotificationCenter.default.addObserver(
            forName: .showRecordingModal,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.showRecordingModal()
        }

        // Observer for "Open Settings" action (T047)
        NotificationCenter.default.addObserver(
            forName: .showSettings,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.showSettingsWindow()
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
            ) { [weak self] in
                // Hotkey triggered - show recording modal
                Task { @MainActor in
                    self?.showRecordingModal()
                }
            }
        } catch {
            print("Failed to register global hotkey: \(error.localizedDescription)")
        }
    }

    // MARK: - Onboarding

    @MainActor
    private func showOnboarding() {
        let contentView = OnboardingView()
            .onDisappear {
                self.onboardingWindow?.close()
                self.onboardingWindow = nil

                // After onboarding completes, setup the app
                self.setupMenuBar()
                Task {
                    await self.setupGlobalHotkey()
                }
            }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "Welcome to Speech-to-Text"
        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        window.makeKeyAndOrderFront(nil)

        onboardingWindow = window
    }

    // MARK: - Recording Modal

    private var recordingWindow: NSWindow?

    @MainActor
    private func showRecordingModal() {
        // Don't show multiple modals
        if recordingWindow != nil {
            return
        }

        // Create SwiftUI view
        let contentView = RecordingModal()
            .onDisappear {
                self.recordingWindow?.close()
                self.recordingWindow = nil
            }

        // Create window for modal
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.contentView = NSHostingView(rootView: contentView)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.center()
        window.makeKeyAndOrderFront(nil)

        recordingWindow = window
    }

    // MARK: - Settings Window

    private var settingsWindow: NSWindow?

    @MainActor
    private func showSettingsWindow() {
        // If settings window already exists, bring it to front
        if let existingWindow = settingsWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }

        // Create settings view (Phase 6 implementation)
        let contentView = SettingsView()
            .onDisappear {
                self.settingsWindow?.close()
                self.settingsWindow = nil
            }

        // Create settings window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Settings"
        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        window.makeKeyAndOrderFront(nil)

        settingsWindow = window
    }
}
