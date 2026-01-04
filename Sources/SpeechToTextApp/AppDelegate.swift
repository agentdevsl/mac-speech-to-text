import Cocoa
import OSLog
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotkeyService: HotkeyService?
    private var onboardingWindow: NSWindow?
    private let settingsService = SettingsService()
    private let permissionService = PermissionService()
    private var recordingModalObserver: NSObjectProtocol?
    private var settingsObserver: NSObjectProtocol?
    private var mainViewObserver: NSObjectProtocol?

    // MARK: - Hold-to-Record Recording

    /// RecordingViewModel for hold-to-record mode - handles actual audio capture and transcription
    private lazy var holdToRecordViewModel: RecordingViewModel = {
        RecordingViewModel()
    }()

    /// Session-level guard to prevent overlay/ViewModel state desynchronization during async operations
    private var isHoldToRecordSessionActive: Bool = false

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

        // Check for app identity change (bundle ID / signing) and reset if needed
        // This handles the case where app is rebuilt with different signing, invalidating permissions
        checkAndHandleIdentityChange()

        // Verify stored permission state matches actual macOS permissions
        // This catches cases where stored config says "granted" but actual permissions are revoked
        Task {
            await verifyAndCorrectPermissionState()
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
        } else if testConfig.shouldResetWelcome {
            AppLogger.app.debug("Resetting welcome state (--reset-welcome or --reset-onboarding)")
            var updatedSettings = settings
            updatedSettings.onboarding.completed = false
            try? settingsService.save(updatedSettings)
            showOnboarding()
        } else if !settings.onboarding.completed {
            // First time user - show welcome
            showOnboarding()
        }
        // Returning users with completed onboarding: app runs silently in menu bar
        // Glass overlay appears only during hold-to-record sessions

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
        // Cancel any active recording session
        Task { @MainActor in
            await holdToRecordViewModel.cancelRecording()
        }

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
        print("[DEBUG] Recording mode: \(settings.ui.recordingMode)")
        fflush(stdout)
        if settings.ui.recordingMode == .holdToRecord {
            print("[DEBUG] Setting up HOLD-TO-RECORD hotkey")
            fflush(stdout)
            await setupHoldToRecordHotkey(settings: settings)
        } else {
            print("[DEBUG] Setting up TOGGLE hotkey")
            fflush(stdout)
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
                    print("[DEBUG-SYNC] onKeyDown callback fired!")
                    fflush(stdout)
                    Task { @MainActor in
                        print("[DEBUG-ASYNC] onKeyDown Task starting...")
                        fflush(stdout)
                        await self?.startHoldToRecordSession()
                    }
                },
                onKeyUp: { [weak self] duration in
                    // Key released - stop recording, transcribe, and paste
                    print("[DEBUG-SYNC] onKeyUp callback fired! duration=\(duration)")
                    fflush(stdout)
                    Task { @MainActor in
                        print("[DEBUG-ASYNC] onKeyUp Task starting...")
                        fflush(stdout)
                        await self?.stopHoldToRecordSession(holdDuration: duration)
                    }
                }
            )
            print("[DEBUG] Hold-to-record hotkey registered successfully! keyCode=\(settings.hotkey.keyCode), modifiers=\(settings.hotkey.modifiers)")
            fflush(stdout)
            AppLogger.app.info("Registered hold-to-record hotkey: keyCode=\(settings.hotkey.keyCode)")
        } catch {
            print("[DEBUG] Failed to register hold-to-record hotkey: \(error)")
            fflush(stdout)
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
        // Session guard: prevent concurrent session operations
        guard !isHoldToRecordSessionActive else {
            AppLogger.app.warning("Hold-to-record session already active, ignoring start request")
            return
        }
        isHoldToRecordSessionActive = true
        AppLogger.app.debug("Starting hold-to-record session")

        // Cancel any previous pending recording (handles stuck state)
        await holdToRecordViewModel.cancelRecording()

        // Show glass overlay in recording state (auto-resets if stuck)
        glassOverlayController.showRecording()

        // Start actual audio recording via RecordingViewModel
        do {
            print("[DEBUG] Calling startRecording...")
            try await holdToRecordViewModel.startRecording()
            print("[DEBUG] startRecording succeeded!")

            // Connect real audio levels to overlay visualization
            startRealAudioLevelUpdates()
            AppLogger.app.debug("Hold-to-record session started successfully")
        } catch {
            print("[DEBUG] startRecording FAILED: \(error)")
            AppLogger.app.error("Failed to start hold-to-record: \(error.localizedDescription, privacy: .public)")
            glassOverlayController.hideOverlay()
            isHoldToRecordSessionActive = false
        }
    }

    /// Stop hold-to-record session and process audio
    private func stopHoldToRecordSession(holdDuration: TimeInterval) async {
        // Session guard: ignore stop if no session is active
        guard isHoldToRecordSessionActive else {
            AppLogger.app.warning("No hold-to-record session active, ignoring stop request")
            return
        }
        AppLogger.app.debug("Stopping hold-to-record session (duration: \(holdDuration)s)")

        // Stop real audio level updates
        stopRealAudioLevelUpdates()

        // Check if recording is actually active
        guard holdToRecordViewModel.isRecording else {
            AppLogger.app.warning("Stop requested but recording not active - cancelling session")
            glassOverlayController.hideOverlay()
            isHoldToRecordSessionActive = false
            return
        }

        // Transition to transcribing state
        glassOverlayController.showTranscribing()

        // Stop recording and perform actual transcription via RecordingViewModel
        do {
            print("[DEBUG] Calling onHotkeyReleased...")
            try await holdToRecordViewModel.onHotkeyReleased()
            print("[DEBUG] onHotkeyReleased completed successfully!")
            print("[DEBUG] Transcribed text: '\(holdToRecordViewModel.transcribedText)'")
            AppLogger.app.info("Hold-to-record transcription completed successfully")
        } catch {
            print("[DEBUG] onHotkeyReleased FAILED: \(error)")
            AppLogger.app.error("Hold-to-record transcription failed: \(error.localizedDescription, privacy: .public)")
            // Ensure recording is cancelled on failure
            await holdToRecordViewModel.cancelRecording()
        }

        // Hide overlay and end session
        glassOverlayController.hideOverlay()
        isHoldToRecordSessionActive = false
    }

    // MARK: - Real Audio Level Updates

    private var audioLevelTimer: Timer?

    /// Start updating overlay with real audio levels from RecordingViewModel
    private func startRealAudioLevelUpdates() {
        audioLevelTimer?.invalidate()
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.holdToRecordViewModel.isRecording else { return }
                // Get real audio level from RecordingViewModel
                let level = Float(self.holdToRecordViewModel.audioLevel)
                self.glassOverlayController.updateAudioLevel(level)
            }
        }
    }

    /// Stop real audio level updates
    private func stopRealAudioLevelUpdates() {
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

        // Create floating window for the glassmorphism recording modal
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 400),
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

    // MARK: - App Identity Change Detection

    /// Check if app identity (bundle ID / signing) has changed and reset permissions if so
    /// This handles the case where the app is rebuilt with different code signing,
    /// which invalidates macOS permission grants (microphone, accessibility)
    @MainActor
    private func checkAndHandleIdentityChange() {
        var settings = settingsService.load()
        let identityCheck = PermissionService.checkForIdentityChange(settings: settings)

        if identityCheck.hasChanged {
            AppLogger.app.warning(
                "App identity changed: \(identityCheck.reason ?? "unknown", privacy: .public). Resetting permission state."
            )

            // Reset permission-related state
            settings.onboarding.completed = false
            settings.onboarding.currentStep = 0
            settings.onboarding.permissionsGranted = PermissionsGranted(
                microphone: false,
                accessibility: false
            )

            // Store new identity
            settings.onboarding.lastKnownBundleId = identityCheck.currentBundleId
            settings.onboarding.lastKnownTeamId = identityCheck.currentTeamId

            // Save updated settings
            do {
                try settingsService.save(settings)
                AppLogger.app.info("Permission state reset due to identity change - user will be re-prompted")
            } catch {
                AppLogger.app.error("Failed to save settings after identity reset: \(error.localizedDescription, privacy: .public)")
            }
        } else if settings.onboarding.lastKnownBundleId == nil {
            // First run with permission tracking - store current identity
            settings.onboarding.lastKnownBundleId = identityCheck.currentBundleId
            settings.onboarding.lastKnownTeamId = identityCheck.currentTeamId

            do {
                try settingsService.save(settings)
                AppLogger.app.debug("Stored initial app identity for permission tracking")
            } catch {
                AppLogger.app.error("Failed to save initial identity: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - Permission State Verification

    /// Verify stored permission state matches actual macOS permissions and correct if needed
    /// This handles cases where:
    /// - User manually revoked permissions in System Settings
    /// - Identity change detection failed to catch a rebuild
    /// - Permissions were granted to a different app instance
    @MainActor
    private func verifyAndCorrectPermissionState() async {
        var settings = settingsService.load()
        let verification = await permissionService.verifyPermissionStateConsistency(settings: settings)

        if verification.hasMismatch {
            AppLogger.app.warning(
                """
                Permission state mismatch detected: \(verification.mismatchDescription ?? "unknown", privacy: .public). \
                Correcting stored state.
                """
            )

            // Correct stored state to match actual macOS state
            // Only reset permissions that claim to be granted but aren't
            if verification.storedMicrophoneGranted && !verification.actualMicrophoneGranted {
                settings.onboarding.permissionsGranted.microphone = false
            }
            if verification.storedAccessibilityGranted && !verification.actualAccessibilityGranted {
                settings.onboarding.permissionsGranted.accessibility = false
            }

            // If onboarding was marked complete but required permissions are now missing,
            // reset onboarding to guide user through re-granting
            // Microphone is required for core functionality
            let requiredPermissionsMissing = !verification.actualMicrophoneGranted
            if settings.onboarding.completed && requiredPermissionsMissing {
                AppLogger.app.info("Required permissions missing despite completed onboarding - resetting onboarding state")
                settings.onboarding.completed = false
                settings.onboarding.currentStep = 0
            }

            do {
                try settingsService.save(settings)
                AppLogger.app.info("Permission state corrected - user will be re-prompted if needed")
            } catch {
                AppLogger.app.error("Failed to save corrected permission state: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
