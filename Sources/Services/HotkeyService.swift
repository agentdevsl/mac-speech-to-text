import Carbon
import Foundation
import OSLog

/// Service for managing global hotkey registration using Carbon Event Manager
class HotkeyService {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var callback: (() -> Void)?
    private var userDataPointer: UnsafeMutableRawPointer?

    deinit {
        unregisterHotkey()
        // Note: The retained self reference is released in unregisterHotkey()
    }

    /// Register a global hotkey
    func registerHotkey(
        keyCode: Int,
        modifiers: [KeyModifier],
        callback: @escaping () -> Void
    ) async throws {
        // Unregister existing hotkey first
        unregisterHotkey()

        // Store callback
        self.callback = callback

        // Convert modifiers to Carbon format
        var carbonModifiers: UInt32 = 0
        for modifier in modifiers {
            switch modifier {
            case .command:
                carbonModifiers |= UInt32(cmdKey)
            case .control:
                carbonModifiers |= UInt32(controlKey)
            case .option:
                carbonModifiers |= UInt32(optionKey)
            case .shift:
                carbonModifiers |= UInt32(shiftKey)
            }
        }

        // Create hotkey ID
        var hotkeyID = EventHotKeyID(signature: 0x53545458, id: UInt32(keyCode)) // "STXT"

        // Install event handler
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let eventHandlerCallback: EventHandlerUPP = { (_, _, userData) -> OSStatus in
            guard let service = userData?.load(as: HotkeyService.self) else {
                return OSStatus(eventNotHandledErr)
            }

            service.callback?()
            return noErr
        }

        // Create and store retained reference to self
        let userData = Unmanaged.passRetained(self).toOpaque()
        userDataPointer = userData

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            eventHandlerCallback,
            1,
            &eventSpec,
            userData,
            &eventHandler
        )

        guard status == noErr else {
            throw HotkeyError.installationFailed("Failed to install event handler: \(status)")
        }

        // Register hotkey
        let registerStatus = RegisterEventHotKey(
            UInt32(keyCode),
            carbonModifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard registerStatus == noErr else {
            throw HotkeyError.registrationFailed("Failed to register hotkey: \(registerStatus)")
        }
    }

    /// Unregister current hotkey
    func unregisterHotkey() {
        if let hotKeyRef = hotKeyRef {
            let status = UnregisterEventHotKey(hotKeyRef)
            if status != noErr {
                AppLogger.service.warning("Failed to unregister hotkey: \(status, privacy: .public)")
            }
            self.hotKeyRef = nil
        }

        if let eventHandler = eventHandler {
            let status = RemoveEventHandler(eventHandler)
            if status != noErr {
                AppLogger.service.warning("Failed to remove event handler: \(status, privacy: .public)")
            }

            // Release the retained self reference that was created in registerHotkey
            if let userData = userDataPointer {
                Unmanaged<HotkeyService>.fromOpaque(userData).release()
                userDataPointer = nil
            }

            self.eventHandler = nil
        }

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
enum HotkeyError: Error, LocalizedError {
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
