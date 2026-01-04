import AppKit
import Foundation
import OSLog

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

    /// Callback to invoke when hotkey is pressed
    private var callback: (@Sendable () -> Void)?

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
