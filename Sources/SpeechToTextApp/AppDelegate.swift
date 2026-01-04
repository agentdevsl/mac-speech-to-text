// swiftlint:disable file_length type_body_length
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

    // MARK: - Floating Widget Window

    /// Window for the floating widget (always-visible compact recording UI)
    private var floatingWidgetWindow: NSWindow?

    /// ViewModel shared between floating widget and hold-to-record overlay
    private var floatingWidgetViewModel: FloatingWidgetViewModel?

    // MARK: - Hold-to-Record Overlay

    /// Window for the hold-to-record overlay (appears during hold-to-record mode)
    private var holdToRecordWindow: NSWindow?

    /// UI test configuration parsed from launch arguments
    private lazy var testConfig: UITestConfiguration = {
        UITestConfiguration.fromProcessInfo()
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure only one instance of the app runs
        if NSRunningApplication.runningApplications(withBundleIdentifier: Constants.App.bundleIdentifier).count > 1 {
            NSApp.terminate(nil)
            return
        }

        // Apply UI test configuration if in test mode
        applyUITestConfiguration()

        // Always setup notification observers for menu actions
        // (works with MenuBarExtra from SpeechToTextApp)
        setupMenuActionObservers()

        // Setup main menu with keyboard shortcuts (Cmd+, for Settings)
        setupMainMenu()

        // Initialize global hotkey
        Task {
            await setupGlobalHotkey()
        }

        // Check if first launch - show onboarding (T040)
        // Skip if --skip-onboarding or reset if --reset-onboarding
        if testConfig.skipOnboarding {
            AppLogger.app.debug("Skipping onboarding (--skip-onboarding)")
            // Mark onboarding as completed
            var settings = settingsService.load()
            settings.onboarding.completed = true
            try? settingsService.save(settings)
        } else if testConfig.resetOnboarding {
            AppLogger.app.debug("Resetting onboarding state (--reset-onboarding)")
            var settings = settingsService.load()
            settings.onboarding.completed = false
            try? settingsService.save(settings)
            showOnboarding()
        } else {
            let settings = settingsService.load()
            if !settings.onboarding.completed {
                showOnboarding()
            }
        }

        // Trigger recording modal if requested (for UI tests)
        if testConfig.triggerRecordingOnLaunch {
            AppLogger.app.debug("Triggering recording modal on launch (--trigger-recording)")
            // Small delay to ensure app is fully loaded
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                self.showRecordingModal()
            }
        }
    }

    // MARK: - UI Test Configuration

    /// Apply UI test configuration settings
    private func applyUITestConfiguration() {
        guard testConfig.isUITesting else { return }

        AppLogger.app.info("Running in UI test mode")

        // Disable animations for faster tests
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
        }

        // Apply initial language if specified
        if let language = testConfig.initialLanguage {
            AppLogger.app.debug("Setting initial language to: \(language, privacy: .public)")
            var settings = settingsService.load()
            settings.language.defaultLanguage = language
            try? settingsService.save(settings)
        }

        // Log configuration for debugging
        AppLogger.app.debug("""
            UI Test Configuration:
            - skipPermissionChecks: \(self.testConfig.skipPermissionChecks)
            - skipOnboarding: \(self.testConfig.skipOnboarding)
            - resetOnboarding: \(self.testConfig.resetOnboarding)
            - triggerRecordingOnLaunch: \(self.testConfig.triggerRecordingOnLaunch)
            - mockPermissionState: \(String(describing: self.testConfig.mockPermissionState))
            - simulatedError: \(String(describing: self.testConfig.simulatedError))
            """)
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

    // MARK: - Main Menu Setup

    /// Setup the main application menu with keyboard shortcuts
    @MainActor
    private func setupMainMenu() {
        // Create main menu bar
        let mainMenu = NSMenu()

        // Create application menu (first menu item)
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        // Add Settings item with Cmd+, shortcut
        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettingsFromMenu),
            keyEquivalent: ","
        )
        settingsItem.keyEquivalentModifierMask = .command
        appMenu.addItem(settingsItem)

        // Add separator
        appMenu.addItem(NSMenuItem.separator())

        // Add Quit item with Cmd+Q shortcut
        let quitItem = NSMenuItem(
            title: "Quit SpeechToText",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = .command
        appMenu.addItem(quitItem)

        // Set as main menu
        NSApp.mainMenu = mainMenu
    }

    /// Action for Settings menu item
    @objc private func openSettingsFromMenu() {
        showSettingsWindow()
    }

    // MARK: - Global Hotkey Setup

    private func setupGlobalHotkey() async {
        hotkeyService = HotkeyService()

        let settings = settingsService.load()

        // Check recording mode from settings
        if settings.ui.recordingMode == .holdToRecord {
            await setupHoldToRecordHotkey(settings: settings)
        } else {
            await setupToggleHotkey(settings: settings)
        }
    }

    /// Setup hotkey for hold-to-record mode
    private func setupHoldToRecordHotkey(settings: UserSettings) async {
        do {
            try await hotkeyService?.registerHoldHotkey(
                keyCode: settings.hotkey.keyCode,
                modifiers: settings.hotkey.modifiers,
                onKeyDown: { [weak self] in
                    // Key pressed - start recording and show overlay
                    Task { @MainActor in
                        await self?.startHoldToRecordSession()
                    }
                },
                onKeyUp: { [weak self] duration in
                    // Key released - stop recording, transcribe, and paste
                    Task { @MainActor in
                        await self?.stopHoldToRecordSession(holdDuration: duration)
                    }
                }
            )
            AppLogger.app.info("Registered hold-to-record hotkey: keyCode=\(settings.hotkey.keyCode)")
        } catch {
            AppLogger.app.error("Failed to register hold-to-record hotkey: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Setup hotkey for toggle mode (legacy behavior)
    private func setupToggleHotkey(settings: UserSettings) async {
        do {
            try await hotkeyService?.registerHotkey(
                keyCode: settings.hotkey.keyCode,
                modifiers: settings.hotkey.modifiers
            ) { [weak self] in
                // Hotkey triggered - show recording modal
                Task { @MainActor in
                    self?.showRecordingModal()
                }
            }
            AppLogger.app.info("Registered toggle hotkey: keyCode=\(settings.hotkey.keyCode)")
        } catch {
            AppLogger.app.error("Failed to register global hotkey: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Hold-to-Record Session Management

    /// Start a hold-to-record session
    private func startHoldToRecordSession() async {
        AppLogger.app.debug("Starting hold-to-record session")

        // Create or reuse ViewModel
        if floatingWidgetViewModel == nil {
            floatingWidgetViewModel = FloatingWidgetViewModel()
        }

        // Show hold-to-record overlay
        showHoldToRecordOverlay()

        // Start recording
        await floatingWidgetViewModel?.startRecording()
    }

    /// Stop hold-to-record session and process audio
    private func stopHoldToRecordSession(holdDuration: TimeInterval) async {
        AppLogger.app.debug("Stopping hold-to-record session (duration: \(holdDuration)s)")

        // Stop recording (this triggers transcription and paste)
        await floatingWidgetViewModel?.stopRecording()

        // Hide overlay after a short delay to show pasting state
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
            self.hideHoldToRecordOverlay()
        }
    }

    // MARK: - Welcome / Onboarding

    @MainActor
    private func showOnboarding() {
        // Use the new single-screen WelcomeView instead of multi-step wizard
        let contentView = WelcomeView()
            .onDisappear { [weak self] in
                guard let self else { return }
                self.onboardingWindow?.close()
                self.onboardingWindow = nil
                // Observers and hotkey are already set up in applicationDidFinishLaunching
            }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "Welcome"
        window.identifier = NSUserInterfaceItemIdentifier("welcomeWindow")
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

    @MainActor
    private func showRecordingModal() {
        // Don't show multiple modals
        if recordingWindow != nil {
            return
        }

        // Create ViewModel OUTSIDE of SwiftUI view creation to avoid
        // actor existential crashes during body evaluation.
        // The ViewModel contains `any FluidAudioServiceProtocol` which triggers
        // executor checks that can crash on ARM64 if created during rendering.
        let viewModel = RecordingViewModel()

        // Create SwiftUI view with pre-created ViewModel
        let contentView = RecordingModal(viewModel: viewModel)
            .onDisappear { [weak self] in
                self?.recordingWindow?.close()
                self?.recordingWindow = nil
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

    // MARK: - Floating Widget

    /// Show the floating widget (compact always-visible recording UI)
    @MainActor
    func showFloatingWidget() {
        // Don't create duplicate windows
        guard floatingWidgetWindow == nil else {
            floatingWidgetWindow?.makeKeyAndOrderFront(nil)
            return
        }

        // Create or reuse ViewModel
        if floatingWidgetViewModel == nil {
            floatingWidgetViewModel = FloatingWidgetViewModel()
        }

        guard let viewModel = floatingWidgetViewModel else { return }

        // Create FloatingWidget view
        let contentView = FloatingWidget(viewModel: viewModel)

        // Create borderless, transparent window
        // Use 200x60 to accommodate expanded recording state
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 60),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.contentView = NSHostingView(rootView: contentView)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]

        // Position: centered horizontally, 100px from bottom
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowWidth: CGFloat = 200
            let windowHeight: CGFloat = 60
            let xPosition = (screenFrame.width - windowWidth) / 2 + screenFrame.origin.x
            let yPosition = screenFrame.origin.y + 100
            window.setFrame(NSRect(x: xPosition, y: yPosition, width: windowWidth, height: windowHeight), display: true)
        }

        window.makeKeyAndOrderFront(nil)
        floatingWidgetWindow = window

        AppLogger.app.info("Floating widget window displayed")
    }

    /// Hide the floating widget
    @MainActor
    func hideFloatingWidget() {
        floatingWidgetWindow?.close()
        floatingWidgetWindow = nil
        AppLogger.app.debug("Floating widget window hidden")
    }

    // MARK: - Hold-to-Record Overlay

    /// Show the hold-to-record overlay during active recording
    @MainActor
    private func showHoldToRecordOverlay() {
        // Don't create duplicate windows
        guard holdToRecordWindow == nil else {
            holdToRecordWindow?.makeKeyAndOrderFront(nil)
            return
        }

        // Determine current recording status
        let status: HoldToRecordOverlay.RecordingStatus = .recording
        let audioLevel: Float = floatingWidgetViewModel?.audioLevel ?? 0.0

        // Create overlay view
        let contentView = HoldToRecordOverlay(status: status, audioLevel: audioLevel)

        // Create borderless, transparent window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 80),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.contentView = NSHostingView(rootView: contentView)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.hasShadow = true
        window.ignoresMouseEvents = true // Overlay is non-interactive
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]

        // Position: centered horizontally, 100px from bottom (same as floating widget)
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowWidth: CGFloat = 200
            let windowHeight: CGFloat = 80
            let xPosition = (screenFrame.width - windowWidth) / 2 + screenFrame.origin.x
            let yPosition = screenFrame.origin.y + 100
            window.setFrame(NSRect(x: xPosition, y: yPosition, width: windowWidth, height: windowHeight), display: true)
        }

        window.orderFront(nil)
        holdToRecordWindow = window

        AppLogger.app.debug("Hold-to-record overlay displayed")
    }

    /// Hide the hold-to-record overlay
    @MainActor
    private func hideHoldToRecordOverlay() {
        holdToRecordWindow?.close()
        holdToRecordWindow = nil
        AppLogger.app.debug("Hold-to-record overlay hidden")
    }

    // MARK: - Settings Window (Deprecated)

    private var settingsWindow: NSWindow?

    @MainActor
    private func showSettingsWindow() {
        // Settings are now in the menu bar dropdown
        // Show a brief tooltip/message directing users there
        if let existingWindow = settingsWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }

        // Create a simple redirect message view
        let contentView = VStack(spacing: 24) {
            Image(systemName: "menubar.arrow.down.rectangle")
                .font(.system(size: 48))
                .foregroundStyle(Color("AmberPrimary", bundle: nil))

            Text("Settings Moved")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Settings are now in the menu bar.\nClick the Speech-to-Text icon to access them.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Got it") {
                NSApp.keyWindow?.close()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(width: 320, height: 260)
        .background(.ultraThinMaterial)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 260),
            styleMask: [.titled, .closable],
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

// swiftlint:enable file_length type_body_length
