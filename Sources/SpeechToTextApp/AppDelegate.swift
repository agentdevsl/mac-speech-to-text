import Cocoa
import OSLog
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotkeyService: HotkeyService?
    private var onboardingWindow: NSWindow?
    private let settingsService = SettingsService()
    private var recordingModalObserver: NSObjectProtocol?
    private var settingsObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure only one instance of the app runs
        if NSRunningApplication.runningApplications(withBundleIdentifier: Constants.App.bundleIdentifier).count > 1 {
            NSApp.terminate(nil)
            return
        }

        // Always setup notification observers for menu actions
        // (works with MenuBarExtra from SpeechToTextApp)
        setupMenuActionObservers()

        // Initialize global hotkey
        Task {
            await setupGlobalHotkey()
        }

        // Check if first launch - show onboarding (T040)
        let settings = settingsService.load()
        if !settings.onboarding.completed {
            showOnboarding()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup NotificationCenter observers
        if let observer = recordingModalObserver {
            NotificationCenter.default.removeObserver(observer)
            recordingModalObserver = nil
        }
        if let observer = settingsObserver {
            NotificationCenter.default.removeObserver(observer)
            settingsObserver = nil
        }
        // Cleanup hotkey service
        hotkeyService = nil
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep app running in menu bar even if windows are closed
        return false
    }

    // MARK: - Menu Action Observers
    // Note: Menu bar is handled by MenuBarExtra in SpeechToTextApp.swift
    // AppDelegate only handles notification observers for modal/settings windows

    @MainActor
    private func setupMenuActionObservers() {
        // Observer for "Start Recording" action (T046)
        recordingModalObserver = NotificationCenter.default.addObserver(
            forName: .showRecordingModal,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.showRecordingModal()
            }
        }

        // Observer for "Open Settings" action (T047)
        settingsObserver = NotificationCenter.default.addObserver(
            forName: .showSettings,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.showSettingsWindow()
            }
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
            AppLogger.app.error("Failed to register global hotkey: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Onboarding

    @MainActor
    private func showOnboarding() {
        let contentView = OnboardingView()
            .onDisappear { [weak self] in
                guard let self else { return }
                self.onboardingWindow?.close()
                self.onboardingWindow = nil
                // Observers and hotkey are already set up in applicationDidFinishLaunching
            }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "Welcome to Speech-to-Text"
        window.contentView = NSHostingView(rootView: contentView)
        window.center()

        // Ensure app is active and window is visible
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        onboardingWindow = window
    }

    // MARK: - Recording Modal

    private var recordingWindow: NSWindow?
    private var recordingViewModel: RecordingViewModel?
    private let permissionService = PermissionService()

    @MainActor
    private func showRecordingModal() {
        // Don't show multiple modals
        if recordingWindow != nil {
            return
        }

        // Check permissions before showing modal
        Task {
            await checkPermissionsAndShowModal()
        }
    }

    @MainActor
    private func checkPermissionsAndShowModal() async {
        // Check microphone permission first (required)
        let hasMicrophone = await permissionService.checkMicrophonePermission()
        if !hasMicrophone {
            showPermissionAlert(
                title: "Microphone Access Required",
                message: "Speech-to-Text needs microphone access to record your voice. Please grant permission in System Settings > Privacy & Security > Microphone.",
                settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
            )
            return
        }

        // Check accessibility permission (required for text insertion)
        let hasAccessibility = permissionService.checkAccessibilityPermission()
        if !hasAccessibility {
            showPermissionAlert(
                title: "Accessibility Access Required",
                message: "Speech-to-Text needs accessibility access to insert transcribed text into other applications. Please grant permission in System Settings > Privacy & Security > Accessibility.",
                settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            )
            return
        }

        // All permissions granted - show the modal
        showRecordingModalWindow()
    }

    @MainActor
    private func showPermissionAlert(title: String, message: String, settingsURL: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: settingsURL) {
                NSWorkspace.shared.open(url)
            }
        }
    }

    @MainActor
    private func showRecordingModalWindow() {
        // Create viewModel on MainActor (fixes @State + @Observable + @MainActor race condition)
        let viewModel = RecordingViewModel()
        recordingViewModel = viewModel

        // Create SwiftUI view with the viewModel
        let contentView = RecordingModal(viewModel: viewModel)
            .onDisappear { [weak self] in
                self?.recordingWindow?.close()
                self?.recordingWindow = nil
                self?.recordingViewModel = nil
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
            .onDisappear { [weak self] in
                self?.settingsWindow?.close()
                self?.settingsWindow = nil
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
