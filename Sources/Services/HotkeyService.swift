import AppKit
import Foundation
import OSLog

/// State machine for hold-to-record tracking
enum HoldState: Sendable {
    case idle
    case keyDown(startTime: Date)
    case recording
    case releasing
}

/// Service for managing global hotkey registration using NSEvent global monitoring
/// Note: Requires Accessibility permission (not Input Monitoring) to work
@MainActor
class HotkeyService {
    /// Global event monitor for key events
    /// Mark as nonisolated(unsafe) to allow cleanup in deinit
    private nonisolated(unsafe) var eventMonitor: Any?

    /// Registered hotkey configuration
    private var registeredKeyCode: Int?
    private var registeredModifiers: Set<KeyModifier> = []

    /// Callback to invoke when hotkey is pressed (toggle mode)
    private var callback: (@Sendable () -> Void)?

    /// Callbacks for hold-to-record mode
    private var onKeyDownCallback: (@Sendable () -> Void)?
    private var onKeyUpCallback: (@Sendable (TimeInterval) -> Void)?

    /// Current hold state
    private var holdState: HoldState = .idle

    /// Minimum hold duration to trigger recording (100ms)
    private let minimumHoldDuration: TimeInterval = 0.1

    /// Whether using hold-to-record mode
    private var isHoldMode: Bool = false

    deinit {
        // Clean up event monitor - safe due to nonisolated(unsafe)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    /// Register a global hotkey
    /// - Parameters:
    ///   - keyCode: The virtual key code (e.g., 49 for Space)
    ///   - modifiers: Array of modifier keys (e.g., [.command, .control])
    ///   - callback: Closure to call when hotkey is pressed
    func registerHotkey(
        keyCode: Int,
        modifiers: [KeyModifier],
        callback: @escaping @Sendable () -> Void
    ) async throws {
        unregisterHotkey()

        self.callback = callback
        self.registeredKeyCode = keyCode
        self.registeredModifiers = Set(modifiers)

        // Convert our modifiers to NSEvent.ModifierFlags for comparison
        let requiredFlags = convertToNSEventModifiers(modifiers)

        // Install global monitor for key down events
        // Note: This requires Accessibility permission, NOT Input Monitoring
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }

            // Check if the pressed key matches our registered hotkey
            let eventKeyCode = Int(event.keyCode)

            // Check modifiers - we need to match exactly the required modifiers
            // Use intersection to only compare the modifier keys we care about
            let relevantFlags: NSEvent.ModifierFlags = [.command, .control, .option, .shift]
            let eventModifiers = event.modifierFlags.intersection(relevantFlags)

            if eventKeyCode == keyCode && eventModifiers == requiredFlags {
                // Dispatch callback to MainActor
                Task { @MainActor in
                    self.callback?()
                }
            }
        }

        guard eventMonitor != nil else {
            throw HotkeyError.installationFailed("Failed to install global event monitor. Ensure Accessibility permission is granted.")
        }

        AppLogger.service.info("Registered global hotkey: keyCode=\(keyCode), modifiers=\(modifiers.map { $0.rawValue })")
    }

    /// Register a hold-to-record hotkey with separate keyDown and keyUp callbacks
    /// - Parameters:
    ///   - keyCode: The virtual key code (e.g., 49 for Space)
    ///   - modifiers: Array of modifier keys (e.g., [.command, .control])
    ///   - onKeyDown: Closure called when hotkey is pressed (start recording)
    ///   - onKeyUp: Closure called when hotkey is released with hold duration
    func registerHoldHotkey(
        keyCode: Int,
        modifiers: [KeyModifier],
        onKeyDown: @escaping @Sendable () -> Void,
        onKeyUp: @escaping @Sendable (TimeInterval) -> Void
    ) async throws {
        unregisterHotkey()

        self.isHoldMode = true
        self.onKeyDownCallback = onKeyDown
        self.onKeyUpCallback = onKeyUp
        self.registeredKeyCode = keyCode
        self.registeredModifiers = Set(modifiers)
        self.holdState = .idle

        let requiredFlags = convertToNSEventModifiers(modifiers)
        let relevantFlags: NSEvent.ModifierFlags = [.command, .control, .option, .shift]

        // Monitor keyDown, keyUp, and flagsChanged events for hold detection
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.keyDown, .keyUp, .flagsChanged]
        ) { [weak self] event in
            guard let self = self else { return }

            let eventKeyCode = Int(event.keyCode)
            let eventModifiers = event.modifierFlags.intersection(relevantFlags)
            let modifiersMatch = eventModifiers == requiredFlags

            Task { @MainActor in
                self.handleHoldEvent(
                    event: event,
                    eventKeyCode: eventKeyCode,
                    targetKeyCode: keyCode,
                    modifiersMatch: modifiersMatch,
                    requiredFlags: requiredFlags
                )
            }
        }

        guard eventMonitor != nil else {
            throw HotkeyError.installationFailed(
                "Failed to install global event monitor for hold-to-record. Ensure Accessibility permission is granted."
            )
        }

        AppLogger.service.info(
            "Registered hold-to-record hotkey: keyCode=\(keyCode), modifiers=\(modifiers.map { $0.rawValue })"
        )
    }

    /// Handle events for hold-to-record mode
    private func handleHoldEvent(
        event: NSEvent,
        eventKeyCode: Int,
        targetKeyCode: Int,
        modifiersMatch: Bool,
        requiredFlags: NSEvent.ModifierFlags
    ) {
        switch event.type {
        case .keyDown:
            handleKeyDown(
                eventKeyCode: eventKeyCode,
                targetKeyCode: targetKeyCode,
                modifiersMatch: modifiersMatch,
                isRepeat: event.isARepeat
            )

        case .keyUp:
            handleKeyUp(
                eventKeyCode: eventKeyCode,
                targetKeyCode: targetKeyCode
            )

        case .flagsChanged:
            // Handle modifier key release (e.g., user releases Cmd before Space)
            handleModifierChange(
                currentFlags: event.modifierFlags,
                requiredFlags: requiredFlags
            )

        default:
            break
        }
    }

    /// Handle keyDown event for hold-to-record
    private func handleKeyDown(
        eventKeyCode: Int,
        targetKeyCode: Int,
        modifiersMatch: Bool,
        isRepeat: Bool
    ) {
        // Ignore key repeat events
        guard !isRepeat else { return }

        // Check if this is our registered hotkey
        guard eventKeyCode == targetKeyCode && modifiersMatch else { return }

        // Only start if we're idle
        guard case .idle = holdState else { return }

        holdState = .keyDown(startTime: Date())
        AppLogger.service.debug("Hold hotkey: keyDown detected")

        // Trigger onKeyDown callback immediately
        onKeyDownCallback?()

        // Transition to recording state
        holdState = .recording
    }

    /// Handle keyUp event for hold-to-record
    private func handleKeyUp(
        eventKeyCode: Int,
        targetKeyCode: Int
    ) {
        // Check if this is our registered hotkey being released
        guard eventKeyCode == targetKeyCode else { return }

        // Only process if we're in recording state
        guard case .recording = holdState else {
            // If we're in keyDown but not yet recording, still handle release
            if case let .keyDown(startTime) = holdState {
                let duration = Date().timeIntervalSince(startTime)
                completeHold(duration: duration)
            }
            return
        }

        // Calculate hold duration (use minimum if we don't have start time)
        let duration = minimumHoldDuration
        completeHold(duration: duration)
    }

    /// Handle modifier key changes for hold-to-record
    private func handleModifierChange(
        currentFlags: NSEvent.ModifierFlags,
        requiredFlags: NSEvent.ModifierFlags
    ) {
        let relevantFlags: NSEvent.ModifierFlags = [.command, .control, .option, .shift]
        let currentRelevant = currentFlags.intersection(relevantFlags)

        // If modifiers no longer match while recording, treat as release
        if case .recording = holdState {
            if currentRelevant != requiredFlags {
                AppLogger.service.debug("Hold hotkey: modifier released during recording")
                completeHold(duration: minimumHoldDuration)
            }
        }
    }

    /// Complete the hold-to-record cycle
    private func completeHold(duration: TimeInterval) {
        holdState = .releasing
        AppLogger.service.debug("Hold hotkey: completing hold, duration=\(duration)s")

        // Only trigger if held for minimum duration
        if duration >= minimumHoldDuration {
            onKeyUpCallback?(duration)
        } else {
            AppLogger.service.debug("Hold too short (\(duration)s), minimum is \(self.minimumHoldDuration)s")
        }

        // Reset to idle
        holdState = .idle
    }

    // MARK: - Private Helpers

    /// Convert our KeyModifier array to NSEvent.ModifierFlags
    private func convertToNSEventModifiers(_ modifiers: [KeyModifier]) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        for modifier in modifiers {
            switch modifier {
            case .command: flags.insert(.command)
            case .control: flags.insert(.control)
            case .option: flags.insert(.option)
            case .shift: flags.insert(.shift)
            }
        }
        return flags
    }

    /// Unregister current hotkey
    func unregisterHotkey() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
            AppLogger.service.debug("Unregistered global hotkey")
        }

        registeredKeyCode = nil
        registeredModifiers = []
        callback = nil

        // Clear hold-mode state
        isHoldMode = false
        onKeyDownCallback = nil
        onKeyUpCallback = nil
        holdState = .idle
    }

    /// Check if a hotkey conflicts with system shortcuts
    func checkConflict(keyCode: Int, modifiers: [KeyModifier]) -> Bool {
        // Common system shortcuts
        let systemShortcuts: [(keyCode: Int, modifiers: Set<KeyModifier>)] = [
            (36, [.command]), // Cmd+Enter
            (48, [.command]), // Cmd+Tab
            (49, [.command]), // Cmd+Space (Spotlight)
            (12, [.command]), // Cmd+Q (Quit)
            (13, [.command]) // Cmd+W (Close window)
        ]

        let modifierSet = Set(modifiers)

        for shortcut in systemShortcuts {
            if shortcut.keyCode == keyCode && shortcut.modifiers == modifierSet {
                return true
            }
        }

        return false
    }

    /// Simulate hotkey press (for testing)
    func simulateHotkeyPress() {
        callback?()
    }

    /// Simulate hold-to-record cycle (for testing)
    /// - Parameter duration: Simulated hold duration
    func simulateHoldCycle(duration: TimeInterval = 0.5) {
        guard isHoldMode else {
            // Fall back to regular press if not in hold mode
            callback?()
            return
        }

        // Simulate keyDown
        onKeyDownCallback?()

        // Simulate keyUp after duration
        if duration >= minimumHoldDuration {
            onKeyUpCallback?(duration)
        }
    }

    /// Get current hold state (for testing/debugging)
    var currentHoldState: HoldState {
        holdState
    }
}

/// Errors related to hotkey registration
enum HotkeyError: Error, LocalizedError, Equatable, Sendable {
    case installationFailed(String)
    case registrationFailed(String)
    case conflictDetected(String)

    var errorDescription: String? {
        switch self {
        case .installationFailed(let message):
            return "Hotkey installation failed: \(message)"
        case .registrationFailed(let message):
            return "Hotkey registration failed: \(message)"
        case .conflictDetected(let message):
            return "Hotkey conflict detected: \(message)"
        }
    }
}
