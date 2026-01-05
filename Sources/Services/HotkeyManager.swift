import Foundation
import KeyboardShortcuts

/// HotkeyManager handles global keyboard shortcut detection for hold-to-record functionality.
/// Uses the KeyboardShortcuts library for reliable cross-app hotkey handling.
@MainActor
class HotkeyManager {
    // MARK: - State Tracking

    private var keyPressStartTime: Date?
    private var isProcessing: Bool = false

    // MARK: - Callbacks

    /// Called when the hotkey is pressed down and recording should start
    var onRecordingStart: (() async -> Void)?

    /// Called when the hotkey is released and recording should stop (with hold duration)
    var onRecordingStop: ((TimeInterval) async -> Void)?

    /// Called when recording is cancelled (e.g., hold duration too short)
    var onRecordingCancel: (() async -> Void)?

    // MARK: - Configuration

    /// Minimum hold duration required to trigger transcription (prevents accidental taps)
    let minimumHoldDuration: TimeInterval

    /// Cooldown interval between actions to prevent rapid re-triggers
    let cooldownInterval: TimeInterval

    /// Last completed action time for cooldown tracking
    private(set) var lastActionTime: Date = .distantPast

    // MARK: - Testability

    /// Allows injecting a custom time provider for deterministic testing
    var currentTimeProvider: () -> Date = { Date() }

    /// Exposes processing state for testing
    var isCurrentlyProcessing: Bool { isProcessing }

    // MARK: - Lifecycle

    /// Initialize with default configuration
    convenience init() {
        self.init(minimumHoldDuration: 0.1, cooldownInterval: 0.3, skipHotkeySetup: false)
    }

    /// Initialize with custom configuration (for testing)
    init(minimumHoldDuration: TimeInterval = 0.1, cooldownInterval: TimeInterval = 0.3, skipHotkeySetup: Bool = false) {
        self.minimumHoldDuration = minimumHoldDuration
        self.cooldownInterval = cooldownInterval

        if !skipHotkeySetup {
            setupHotkey()
        }
    }

    deinit {
        // Clean up KeyboardShortcuts handlers to prevent orphaned callbacks
        KeyboardShortcuts.disable(.holdToRecord)
    }

    // MARK: - Hotkey Setup

    private func setupHotkey() {
        // Verify hotkey is configured
        guard KeyboardShortcuts.getShortcut(for: .holdToRecord) != nil else {
            AppLogger.app.warning("No hotkey configured for hold-to-record, using default")
            // Default is set in ShortcutNames.swift, so this should rarely happen
            return
        }

        KeyboardShortcuts.onKeyDown(for: .holdToRecord) { [weak self] in
            Task { @MainActor in
                await self?.handleKeyDown()
            }
        }

        KeyboardShortcuts.onKeyUp(for: .holdToRecord) { [weak self] in
            Task { @MainActor in
                await self?.handleKeyUp()
            }
        }

        AppLogger.app.debug("HotkeyManager: Registered handlers for .holdToRecord")
    }

    // MARK: - Key Event Handlers (internal for testability)

    /// Handle key down event - starts recording if not already processing and not in cooldown
    func handleKeyDown() async {
        // Guard: already processing
        guard !isProcessing else {
            AppLogger.app.debug("HotkeyManager: Ignoring keyDown - already processing")
            return
        }

        // Guard: in cooldown period
        let now = currentTimeProvider()
        guard now.timeIntervalSince(lastActionTime) > cooldownInterval else {
            AppLogger.app.debug("HotkeyManager: Ignoring keyDown - in cooldown")
            return
        }

        // Start recording
        isProcessing = true
        keyPressStartTime = now
        AppLogger.app.debug("HotkeyManager: keyDown - starting recording")
        await onRecordingStart?()
    }

    /// Handle key up event - stops recording and invokes appropriate callback
    func handleKeyUp() async {
        guard isProcessing, let startTime = keyPressStartTime else {
            AppLogger.app.debug("HotkeyManager: Ignoring keyUp - not processing")
            return
        }

        // Calculate hold duration and apply cooldown immediately
        let now = currentTimeProvider()
        let duration = now.timeIntervalSince(startTime)
        lastActionTime = now // Apply cooldown immediately on key release

        // Use defer to ensure state is always cleaned up
        defer {
            keyPressStartTime = nil
            isProcessing = false
        }

        AppLogger.app.debug("HotkeyManager: keyUp - duration: \(duration)s")

        if duration >= minimumHoldDuration {
            await onRecordingStop?(duration)
        } else {
            AppLogger.app.debug("HotkeyManager: Duration too short (\(duration)s < \(self.minimumHoldDuration)s) - cancelling")
            await onRecordingCancel?()
        }
    }

    // MARK: - Public Methods

    /// Cancel any in-progress recording without invoking callbacks
    func cancel() {
        let wasProcessing = isProcessing
        isProcessing = false
        keyPressStartTime = nil

        if wasProcessing {
            AppLogger.app.debug("HotkeyManager: Recording cancelled")
        }
    }
}
