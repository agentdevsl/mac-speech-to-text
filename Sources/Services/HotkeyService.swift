import Carbon
import Foundation
import OSLog

/// Service for managing global hotkey registration using Carbon Event Manager
@MainActor
class HotkeyService {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var callback: (@Sendable () -> Void)?
    private var userDataPointer: UnsafeMutableRawPointer?

    deinit {
        // Perform cleanup directly in deinit to avoid actor isolation issues
        // Carbon APIs are thread-safe for cleanup operations
        cleanupHotkeyResources()
    }

    /// Direct cleanup without actor isolation (safe for deinit)
    private nonisolated func cleanupHotkeyResources() {
        // Note: Accessing instance properties is safe here because deinit
        // guarantees no other references exist
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
        }
        if let userData = userDataPointer {
            Unmanaged<HotkeyService>.fromOpaque(userData).release()
        }
    }

    /// Register a global hotkey
    func registerHotkey(
        keyCode: Int,
        modifiers: [KeyModifier],
        callback: @escaping @Sendable () -> Void
    ) async throws {
        unregisterHotkey()
        self.callback = callback

        let carbonModifiers = convertModifiers(modifiers)
        var hotkeyID = EventHotKeyID(signature: 0x53545458, id: UInt32(keyCode))

        let userData = Unmanaged.passRetained(self).toOpaque()
        userDataPointer = userData

        try installEventHandler(userData: userData)
        try registerHotKey(keyCode: keyCode, modifiers: carbonModifiers, hotkeyID: &hotkeyID)
    }

    // MARK: - Private Helpers

    private func convertModifiers(_ modifiers: [KeyModifier]) -> UInt32 {
        var carbonModifiers: UInt32 = 0
        for modifier in modifiers {
            switch modifier {
            case .command: carbonModifiers |= UInt32(cmdKey)
            case .control: carbonModifiers |= UInt32(controlKey)
            case .option: carbonModifiers |= UInt32(optionKey)
            case .shift: carbonModifiers |= UInt32(shiftKey)
            }
        }
        return carbonModifiers
    }

    private func installEventHandler(userData: UnsafeMutableRawPointer) throws {
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let eventHandlerCallback: EventHandlerUPP = { _, _, userData -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue().callback?()
            return noErr
        }

        let status = InstallEventHandler(
            GetApplicationEventTarget(), eventHandlerCallback, 1, &eventSpec, userData, &eventHandler
        )

        guard status == noErr else {
            releaseUserData()
            throw HotkeyError.installationFailed("Failed to install event handler: \(status)")
        }
    }

    private func registerHotKey(keyCode: Int, modifiers: UInt32, hotkeyID: inout EventHotKeyID) throws {
        let status = RegisterEventHotKey(
            UInt32(keyCode), modifiers, hotkeyID, GetApplicationEventTarget(), 0, &hotKeyRef
        )

        guard status == noErr else {
            cleanupEventHandler()
            throw HotkeyError.registrationFailed("Failed to register hotkey: \(status)")
        }
    }

    private func releaseUserData() {
        if let userData = userDataPointer {
            Unmanaged<HotkeyService>.fromOpaque(userData).release()
            userDataPointer = nil
        }
    }

    private func cleanupEventHandler() {
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
        releaseUserData()
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
