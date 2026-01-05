import Cocoa
import OSLog
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotkeyManager: HotkeyManager?
    private var onboardingWindow: NSWindow?
    private let settingsService = SettingsService()
    private let permissionService = PermissionService()
    private var recordingModalObserver: NSObjectProtocol?
    private var settingsObserver: NSObjectProtocol?
    private var mainViewObserver: NSObjectProtocol?
    private var themeChangeObserver: NSObjectProtocol?

    // MARK: - Hold-to-Record Recording

    /// RecordingViewModel for hold-to-record mode - handles actual audio capture and transcription
    private lazy var holdToRecordViewModel: RecordingViewModel = {
        RecordingViewModel()
    }()

    /// Session-level guard to prevent overlay/ViewModel state desynchronization during async operations
    private var isHoldToRecordSessionActive: Bool = false

    // MARK: - Voice Trigger Monitoring

    /// VoiceTriggerMonitoringService for wake word detection and hands-free recording
    private var voiceTriggerMonitoringService: VoiceTriggerMonitoringService?

    /// Whether voice monitoring is currently active (for mutex with manual recording)
    private var isVoiceMonitoringActive: Bool = false

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

        // Apply saved theme on launch
        let savedSettings = settingsService.load()
        NSApp.appearance = savedSettings.ui.theme.nsAppearance

        // Always setup notification observers for menu actions
        // (works with MenuBarExtra from SpeechToTextApp)
        setupMenuActionObservers()

        // Setup main menu with keyboard shortcuts (Cmd+, for Settings)
        setupMainMenu()

        // Initialize global hotkey using KeyboardShortcuts
        setupGlobalHotkey()

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
        // CRITICAL: Perform synchronous cleanup first to prevent new operations
        // This ensures no new recording sessions can start during shutdown

        // 1. Stop audio level timer immediately (prevents further updates)
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil

        // 2. Release hotkey manager to prevent new recording triggers
        hotkeyManager = nil

        // 3. Remove notification observers to prevent menu-triggered operations
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
        if let observer = themeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            themeChangeObserver = nil
        }

        // 4. Mark sessions inactive to prevent async operations from proceeding
        isHoldToRecordSessionActive = false
        isVoiceMonitoringActive = false

        // 5. Stop voice trigger state observation and monitoring
        voiceTriggerStateTimer?.invalidate()
        voiceTriggerStateTimer = nil

        // Stop voice monitoring with async cleanup using semaphore
        let voiceCleanupSemaphore = DispatchSemaphore(value: 0)
        let voiceService = voiceTriggerMonitoringService
        voiceTriggerMonitoringService = nil
        Task.detached {
            await voiceService?.stopMonitoring()
            voiceCleanupSemaphore.signal()
        }
        // Wait up to 300ms for voice monitoring cleanup
        _ = voiceCleanupSemaphore.wait(timeout: .now() + 0.3)

        // 6. Close and cleanup windows
        recordingWindow?.close()
        recordingWindow = nil
        GlassOverlayWindowController.shared.hideOverlay()
        MainWindowController.shared.closeWindow()

        // 7. Cancel active recording session (best-effort async cleanup)
        // Use semaphore with timeout to give async cleanup a chance to complete
        let cleanupSemaphore = DispatchSemaphore(value: 0)
        Task.detached { [holdToRecordViewModel] in
            await holdToRecordViewModel.cancelRecording()
            cleanupSemaphore.signal()
        }
        // Wait up to 500ms for cleanup, then proceed with termination
        _ = cleanupSemaphore.wait(timeout: .now() + 0.5)
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

        // Observer for theme changes - applies NSAppearance app-wide
        // Note: No Task wrapper - runs synchronously on main queue to prevent race conditions
        themeChangeObserver = NotificationCenter.default.addObserver(
            forName: .themeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            let settings = self.settingsService.load()
            NSApp.appearance = settings.ui.theme.nsAppearance
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

    /// Setup global hotkey using KeyboardShortcuts library
    /// The shortcut is user-configurable via Settings > General > Hotkey
    private func setupGlobalHotkey() {
        hotkeyManager = HotkeyManager()

        // Configure callbacks for hold-to-record
        hotkeyManager?.onRecordingStart = { [weak self] in
            await self?.startHoldToRecordSession()
        }

        hotkeyManager?.onRecordingStop = { [weak self] duration in
            await self?.stopHoldToRecordSession(holdDuration: duration)
        }

        hotkeyManager?.onRecordingCancel = { [weak self] in
            await self?.cancelHoldToRecordSession()
        }

        // Configure callback for voice monitoring toggle
        hotkeyManager?.onVoiceMonitoringToggle = { [weak self] in
            await self?.toggleVoiceMonitoring()
        }

        AppLogger.app.info("Global hotkey initialized via KeyboardShortcuts")
    }

    // MARK: - Voice Trigger Monitoring

    /// Initialize the VoiceTriggerMonitoringService with required dependencies
    private func initializeVoiceTriggerMonitoringService() {
        guard voiceTriggerMonitoringService == nil else {
            AppLogger.app.debug("VoiceTriggerMonitoringService already initialized")
            return
        }

        // Create WakeWordService (actor for thread-safe wake word detection)
        let wakeWordService = WakeWordService()

        // Create AudioCaptureService with settings service
        let audioService = AudioCaptureService(settingsService: settingsService)

        // Create FluidAudioService for transcription
        let fluidAudioService = FluidAudioService()

        // Create TextInsertionService for inserting transcribed text
        let textInsertionService = TextInsertionService()

        // Initialize the VoiceTriggerMonitoringService
        voiceTriggerMonitoringService = VoiceTriggerMonitoringService(
            wakeWordService: wakeWordService,
            audioService: audioService,
            fluidAudioService: fluidAudioService,
            textInsertionService: textInsertionService,
            settingsService: settingsService
        )

        AppLogger.app.info("VoiceTriggerMonitoringService initialized")
    }

    /// Toggle voice monitoring on/off
    /// Ensures mutex with manual recording modes
    private func toggleVoiceMonitoring() async {
        // Check if manual recording is in progress - can't toggle monitoring while recording
        if isHoldToRecordSessionActive {
            AppLogger.app.warning("Cannot toggle voice monitoring while manual recording is active")
            // Could show user feedback here (e.g., beep, notification)
            NSSound.beep()
            return
        }

        if isVoiceMonitoringActive {
            await stopVoiceMonitoring()
        } else {
            await startVoiceMonitoring()
        }
    }

    /// Start voice trigger monitoring
    private func startVoiceMonitoring() async {
        AppLogger.app.info("Starting voice trigger monitoring")

        // Ensure service is initialized
        initializeVoiceTriggerMonitoringService()

        guard let service = voiceTriggerMonitoringService else {
            AppLogger.app.error("VoiceTriggerMonitoringService not available")
            return
        }

        do {
            try await service.startMonitoring()
            isVoiceMonitoringActive = true
            AppLogger.app.info("Voice trigger monitoring started successfully")

            // Notify AppState of the state change
            postVoiceTriggerStateChange(service.state)

            // Start observing service state changes
            startObservingVoiceTriggerState()
        } catch {
            AppLogger.app.error("Failed to start voice monitoring: \(error.localizedDescription, privacy: .public)")
            isVoiceMonitoringActive = false

            // Notify of error state
            if let vtError = error as? VoiceTriggerError {
                postVoiceTriggerStateChange(.error(vtError))
            }

            // Show user feedback for the error
            await showVoiceMonitoringError(error)
        }
    }

    /// Stop voice trigger monitoring
    private func stopVoiceMonitoring() async {
        AppLogger.app.info("Stopping voice trigger monitoring")

        // Stop observing state changes
        stopObservingVoiceTriggerState()

        await voiceTriggerMonitoringService?.stopMonitoring()
        isVoiceMonitoringActive = false

        // Notify AppState of the state change to idle
        postVoiceTriggerStateChange(.idle)

        AppLogger.app.info("Voice trigger monitoring stopped")
    }

    /// Show error feedback for voice monitoring failures
    private func showVoiceMonitoringError(_ error: Error) async {
        // Play error sound
        NSSound.beep()

        // Log the specific error type for debugging
        if let voiceTriggerError = error as? VoiceTriggerError {
            AppLogger.app.error("Voice trigger error: \(voiceTriggerError.description, privacy: .public)")
        }

        // Could show an alert or notification to the user
        // For now, just log - the VoiceTriggerMonitoringService.errorMessage can be observed by UI
    }

    // MARK: - Voice Trigger State Observation

    /// Timer for polling voice trigger state changes
    private var voiceTriggerStateTimer: Timer?
    /// Last observed voice trigger state (to detect changes)
    private var lastObservedVoiceTriggerState: VoiceTriggerState = .idle

    /// Start observing voice trigger state changes
    private func startObservingVoiceTriggerState() {
        // Use a timer to poll state changes since @Observable doesn't have built-in KVO
        // Poll every 100ms for responsive UI updates
        voiceTriggerStateTimer?.invalidate()
        voiceTriggerStateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkVoiceTriggerStateChange()
            }
        }
    }

    /// Stop observing voice trigger state changes
    private func stopObservingVoiceTriggerState() {
        voiceTriggerStateTimer?.invalidate()
        voiceTriggerStateTimer = nil
    }

    /// Check if voice trigger state has changed and notify if so
    private func checkVoiceTriggerStateChange() {
        guard let service = voiceTriggerMonitoringService else { return }

        let currentState = service.state
        if currentState != lastObservedVoiceTriggerState {
            lastObservedVoiceTriggerState = currentState
            postVoiceTriggerStateChange(currentState)
        }
    }

    /// Post notification for voice trigger state change
    private func postVoiceTriggerStateChange(_ state: VoiceTriggerState) {
        NotificationCenter.default.post(
            name: .voiceTriggerStateChanged,
            object: nil,
            userInfo: ["state": state]
        )
        AppLogger.app.debug("Posted voice trigger state change: \(state.description, privacy: .public)")
    }

    /// Cancel hold-to-record session (e.g., when hold duration is too short)
    private func cancelHoldToRecordSession() async {
        guard isHoldToRecordSessionActive else { return }

        AppLogger.app.debug("Cancelling hold-to-record session (duration too short)")

        // Stop audio level updates
        stopRealAudioLevelUpdates()

        // Cancel the recording
        await holdToRecordViewModel.cancelRecording()

        // Hide overlay and end session
        glassOverlayController.hideOverlay()
        isHoldToRecordSessionActive = false
    }

    // MARK: - Hold-to-Record Session Management

    /// Start a hold-to-record session
    private func startHoldToRecordSession() async {
        // Mutex guard: can't start manual recording while voice monitoring is active
        if isVoiceMonitoringActive {
            print("[DEBUG] START IGNORED: voice monitoring is active")
            fflush(stdout)
            AppLogger.app.warning("Cannot start hold-to-record while voice monitoring is active")
            NSSound.beep()
            return
        }

        // Session guard: prevent concurrent session operations
        guard !isHoldToRecordSessionActive else {
            print("[DEBUG] START IGNORED: session already active")
            fflush(stdout)
            AppLogger.app.warning("Hold-to-record session already active, ignoring start request")
            return
        }
        print("[DEBUG] Starting new session...")
        fflush(stdout)
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
            print("[DEBUG] STOP IGNORED: no active session")
            fflush(stdout)
            AppLogger.app.warning("No hold-to-record session active, ignoring stop request")
            return
        }
        print("[DEBUG] Stopping session (duration: \(holdDuration)s)...")
        fflush(stdout)
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
        // Timer callback runs on main thread (RunLoop.main), and AppDelegate is @MainActor,
        // so we can safely call MainActor-isolated methods directly without spawning a Task.
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            // Must dispatch to main actor since Timer closure is not actor-isolated
            MainActor.assumeIsolated {
                guard self.holdToRecordViewModel.isRecording else { return }
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
        print("🔴🔴🔴 showRecordingModal CALLED 🔴🔴🔴")
        // Don't show multiple modals
        if recordingWindow != nil {
            print("🔴 Already have a window, returning")
            return
        }

        // Create ViewModel OUTSIDE of SwiftUI view creation to avoid
        // actor existential crashes during body evaluation.
        // The ViewModel contains `any FluidAudioServiceProtocol` which triggers
        // executor checks that can crash on ARM64 if created during rendering.
        let viewModel = RecordingViewModel()

        // Create SwiftUI view with pre-created ViewModel
        // Using LiquidGlassRecordingModal for stunning prismatic glass effects
        print("🔴 DEBUG: Creating LiquidGlassRecordingModal")
        let contentView = LiquidGlassRecordingModal(viewModel: viewModel)
            .onDisappear { [weak self] in
                print("🔴 DEBUG: LiquidGlassRecordingModal disappeared")
                self?.recordingWindow?.close()
                self?.recordingWindow = nil
            }

        // Create floating window for the liquid glass recording modal
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 450),
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
