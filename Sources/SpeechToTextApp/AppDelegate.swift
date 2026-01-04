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
    private var mainViewObserver: NSObjectProtocol?

    // MARK: - Glass Overlay

    /// Controller for the glass recording overlay (appears during hold-to-record)
    /// Uses singleton pattern for easy access from hotkey callbacks
    private var glassOverlayController: GlassOverlayWindowController {
        GlassOverlayWindowController.shared
    }

    /// Controller for the main unified view (Welcome + Settings combined)
    private var mainWindowController: MainWindowController {
        MainWindowController.shared
    }

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

        // Check if first launch - show welcome/onboarding (T040)
        // Skip if --skip-welcome/--skip-onboarding or reset if --reset-welcome/--reset-onboarding
        let settings = settingsService.load()

        if testConfig.shouldSkipWelcome {
            AppLogger.app.debug("Skipping welcome (--skip-welcome or --skip-onboarding)")
            // Mark onboarding as completed
            var updatedSettings = settings
            updatedSettings.onboarding.completed = true
            try? settingsService.save(updatedSettings)
            // Show floating widget for returning users
            showFloatingWidgetIfEnabled()
        } else if testConfig.shouldResetWelcome {
            AppLogger.app.debug("Resetting welcome state (--reset-welcome or --reset-onboarding)")
            var updatedSettings = settings
            updatedSettings.onboarding.completed = false
            try? settingsService.save(updatedSettings)
            showOnboarding()
        } else if !settings.onboarding.completed {
            // First time user - show welcome
            showOnboarding()
        } else {
            // Returning user with completed onboarding - show floating widget
            showFloatingWidgetIfEnabled()
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

    /// Previously showed floating widget - now a no-op since glass overlay only appears during recording
    /// The app now uses a clean desktop with overlay only during hold-to-record
    private func showFloatingWidgetIfEnabled() {
        // Glass overlay only shows during active recording - no persistent widget
        AppLogger.app.debug("Floating widget deprecated - glass overlay shows only during recording")
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
            - skipWelcome: \(self.testConfig.skipWelcome)
            - resetWelcome: \(self.testConfig.resetWelcome)
            - shouldSkipWelcome: \(self.testConfig.shouldSkipWelcome)
            - shouldResetWelcome: \(self.testConfig.shouldResetWelcome)
            - triggerRecordingOnLaunch: \(self.testConfig.triggerRecordingOnLaunch)
            - mockPermissionState: \(String(describing: self.testConfig.mockPermissionState))
            - simulatedError: \(String(describing: self.testConfig.simulatedError))
            """)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Stop and cleanup audio level simulation timer
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil

        // Close and cleanup recording window
        recordingWindow?.close()
        recordingWindow = nil

        // Cleanup NotificationCenter observers
        if let observer = recordingModalObserver {
            NotificationCenter.default.removeObserver(observer)
            recordingModalObserver = nil
        }
        if let observer = settingsObserver {
            NotificationCenter.default.removeObserver(observer)
            settingsObserver = nil
        }
        if let observer = mainViewObserver {
            NotificationCenter.default.removeObserver(observer)
            mainViewObserver = nil
        }

        // Cleanup hotkey service (unregisters Carbon hotkeys on deinit)
        hotkeyService = nil

        // Cleanup singleton window controllers
        GlassOverlayWindowController.shared.hideOverlay()
        MainWindowController.shared.closeWindow()
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

        // Observer for "Open Main View" action (from ultra-minimal menu bar)
        mainViewObserver = NotificationCenter.default.addObserver(
            forName: .showMainView,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.showMainView()
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

        // Add Open Speech to Text item with Cmd+, shortcut
        let openItem = NSMenuItem(
            title: "Open Speech to Text",
            action: #selector(openMainViewFromMenu),
            keyEquivalent: ","
        )
        openItem.keyEquivalentModifierMask = .command
        appMenu.addItem(openItem)

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

    /// Action for Open Speech to Text menu item
    @objc private func openMainViewFromMenu() {
        showMainView()
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

        // Show glass overlay in recording state
        glassOverlayController.showRecording()

        // NOTE: Integrate with actual audio recording service in future
        // Currently simulating audio levels for visual feedback
        startAudioLevelSimulation()
    }

    /// Stop hold-to-record session and process audio
    private func stopHoldToRecordSession(holdDuration: TimeInterval) async {
        AppLogger.app.debug("Stopping hold-to-record session (duration: \(holdDuration)s)")

        // Stop audio simulation
        stopAudioLevelSimulation()

        // Transition to transcribing state
        glassOverlayController.showTranscribing()

        // NOTE: Integrate with actual transcription service in future
        // Currently simulating brief transcription delay
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s

        // Hide overlay after transcription completes
        glassOverlayController.hideOverlay()
    }

    // MARK: - Audio Level Simulation (Temporary)

    private var audioLevelTimer: Timer?

    /// Simulate audio levels for waveform visualization (temporary until real audio integration)
    private func startAudioLevelSimulation() {
        audioLevelTimer?.invalidate()
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                // Simulate varying audio levels
                let level = Float.random(in: 0.1...0.8)
                self?.glassOverlayController.updateAudioLevel(level)
            }
        }
    }

    /// Stop audio level simulation
    private func stopAudioLevelSimulation() {
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
    }

    // MARK: - Welcome / Onboarding

    @MainActor
    private func showOnboarding() {
        // Use the unified MainView for first launch (Welcome = Settings)
        // The Home section serves as the welcome screen with permission status
        mainWindowController.showSection(.home)
        AppLogger.app.info("Showing MainView for first-time onboarding")
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

    // MARK: - Main View Window

    /// Show the main application view (unified Welcome + Settings)
    @MainActor
    private func showMainView() {
        mainWindowController.showWindow()
    }

    // MARK: - Settings Window

    /// Show the settings view (General section of unified MainView)
    @MainActor
    private func showSettingsWindow() {
        // Settings are now in the unified MainView under General section
        mainWindowController.showSettings()
    }
}
