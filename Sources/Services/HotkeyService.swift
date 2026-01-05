import AppKit
import Carbon
import Foundation
import OSLog

/// State machine for hold-to-record tracking
enum HoldState: Sendable {
    case idle
    case keyDown(startTime: Date)
    case recording(startTime: Date, carbonEventTime: Double)
    case releasing
}

/// Service for managing global hotkey registration using Carbon APIs
/// Note: Carbon RegisterEventHotKey does NOT require Input Monitoring permission
@MainActor
class HotkeyService {
    /// Carbon event handler reference
    private var eventHandlerRef: EventHandlerRef?

    /// Registered hotkey reference
    private var hotkeyRef: EventHotKeyRef?

    /// Hotkey ID for Carbon
    private var hotkeyID: EventHotKeyID

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

    /// Singleton instance for Carbon callback access (fileprivate for callback, nonisolated for deinit)
    fileprivate nonisolated(unsafe) static var sharedInstance: HotkeyService?

    /// Copies of Carbon refs for nonisolated deinit cleanup
    private nonisolated(unsafe) var deinitHotkeyRef: EventHotKeyRef?
    private nonisolated(unsafe) var deinitEventHandlerRef: EventHandlerRef?

    init() {
        // Create a unique hotkey ID
        hotkeyID = EventHotKeyID(signature: OSType(0x5354_5854), id: 1) // "STXT"
        HotkeyService.sharedInstance = self
    }

    deinit {
        // Clean up Carbon resources from nonisolated context
        if let hotkey = deinitHotkeyRef {
            UnregisterEventHotKey(hotkey)
        }
        if let handler = deinitEventHandlerRef {
            RemoveEventHandler(handler)
        }
        HotkeyService.sharedInstance = nil
    }

    /// Register a global hotkey (toggle mode)
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
        self.isHoldMode = false

        try registerCarbonHotkey(keyCode: keyCode, modifiers: modifiers)

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

        try registerCarbonHotkey(keyCode: keyCode, modifiers: modifiers)

        AppLogger.service.info(
            "Registered hold-to-record hotkey: keyCode=\(keyCode), modifiers=\(modifiers.map { $0.rawValue })"
        )
    }

    // MARK: - Carbon Hotkey Registration

    /// Register hotkey using Carbon API
    private func registerCarbonHotkey(keyCode: Int, modifiers: [KeyModifier]) throws {
        print("[DEBUG-CARBON-REG] registerCarbonHotkey called: keyCode=\(keyCode), modifiers=\(modifiers)")
        fflush(stdout)

        // Convert modifiers to Carbon format
        var carbonModifiers: UInt32 = 0
        for modifier in modifiers {
            switch modifier {
            case .command: carbonModifiers |= UInt32(cmdKey)
            case .control: carbonModifiers |= UInt32(controlKey)
            case .option: carbonModifiers |= UInt32(optionKey)
            case .shift: carbonModifiers |= UInt32(shiftKey)
            }
        }
        print("[DEBUG-CARBON-REG] carbonModifiers=\(carbonModifiers)")
        fflush(stdout)

        // Set up event type spec for hotkey events
        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]

        // Install event handler
        print("[DEBUG-CARBON-REG] Installing event handler...")
        fflush(stdout)
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            carbonHotkeyCallback,
            eventTypes.count,
            &eventTypes,
            nil,
            &eventHandlerRef
        )

        print("[DEBUG-CARBON-REG] InstallEventHandler returned status=\(status) (noErr=\(noErr))")
        fflush(stdout)
        guard status == noErr else {
            throw HotkeyError.installationFailed("Failed to install Carbon event handler: \(status)")
        }

        // Register the hotkey
        print("[DEBUG-CARBON-REG] Registering hotkey with RegisterEventHotKey...")
        fflush(stdout)
        let registerStatus = RegisterEventHotKey(
            UInt32(keyCode),
            carbonModifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )

        print("[DEBUG-CARBON-REG] RegisterEventHotKey returned status=\(registerStatus) (noErr=\(noErr)), hotkeyRef=\(String(describing: hotkeyRef))")
        fflush(stdout)
        guard registerStatus == noErr else {
            // Clean up event handler if registration failed
            if let handler = eventHandlerRef {
                RemoveEventHandler(handler)
                eventHandlerRef = nil
                deinitEventHandlerRef = nil
            }
            throw HotkeyError.registrationFailed("Failed to register hotkey: \(registerStatus)")
        }
        print("[DEBUG-CARBON-REG] Hotkey registered successfully!")
        fflush(stdout)

        // Sync deinit copies for nonisolated cleanup
        deinitHotkeyRef = hotkeyRef
        deinitEventHandlerRef = eventHandlerRef
    }

    /// Unregister current hotkey
    func unregisterHotkey() {
        // Unregister hotkey
        if let hotkey = hotkeyRef {
            UnregisterEventHotKey(hotkey)
            hotkeyRef = nil
            deinitHotkeyRef = nil
            AppLogger.service.debug("Unregistered Carbon hotkey")
        }

        // Remove event handler
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
            deinitEventHandlerRef = nil
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

    // MARK: - Event Handling

    /// Handle hotkey pressed event from Carbon
    /// - Parameter carbonEventTime: The time when the Carbon event actually fired (from GetEventTime)
    func handleHotkeyPressed(carbonEventTime: Double) {
        print("[DEBUG-HOTKEY] handleHotkeyPressed() called, isHoldMode=\(isHoldMode), carbonEventTime=\(carbonEventTime)")
        fflush(stdout)
        if isHoldMode {
            // Hold-to-record mode: start recording
            let startTime = Date()
            holdState = .recording(startTime: startTime, carbonEventTime: carbonEventTime)
            AppLogger.service.debug("Hold hotkey: pressed")
            print("[DEBUG-HOTKEY] Calling onKeyDownCallback...")
            fflush(stdout)
            onKeyDownCallback?()
            print("[DEBUG-HOTKEY] onKeyDownCallback returned")
            fflush(stdout)
        } else {
            // Toggle mode: invoke callback
            callback?()
        }
    }

    /// Handle hotkey released event from Carbon
    /// - Parameter carbonEventTime: The time when the Carbon event actually fired (from GetEventTime)
    func handleHotkeyReleased(carbonEventTime: Double) {
        guard isHoldMode else { return }

        switch holdState {
        case .recording(_, let pressEventTime):
            // Use Carbon event times for accurate duration (not affected by MainActor Task scheduling)
            let duration = carbonEventTime - pressEventTime
            print("[DEBUG-HOTKEY] handleHotkeyReleased: pressTime=\(pressEventTime), releaseTime=\(carbonEventTime), duration=\(duration)")
            fflush(stdout)
            AppLogger.service.debug("Hold hotkey: released after \(duration)s")

            if duration >= minimumHoldDuration {
                print("[DEBUG-HOTKEY] Duration OK, calling onKeyUpCallback...")
                fflush(stdout)
                onKeyUpCallback?(duration)
            } else {
                print("[DEBUG-HOTKEY] Duration TOO SHORT: \(duration)s < \(minimumHoldDuration)s")
                fflush(stdout)
                AppLogger.service.debug("Hold too short (\(duration)s), minimum is \(self.minimumHoldDuration)s")
            }
            holdState = .idle

        default:
            print("[DEBUG-HOTKEY] handleHotkeyReleased: holdState is not .recording, ignoring")
            fflush(stdout)
            holdState = .idle
        }
    }

    /// Check if a hotkey conflicts with system shortcuts
    func checkConflict(keyCode: Int, modifiers: [KeyModifier]) -> Bool {
        // Common system shortcuts to avoid
        let systemShortcuts: [(keyCode: Int, modifiers: Set<KeyModifier>)] = [
            (36, [.command]),          // Cmd+Enter
            (48, [.command]),          // Cmd+Tab
            (49, [.command]),          // Cmd+Space (Spotlight)
            (49, [.command, .control]), // Cmd+Ctrl+Space (Emoji picker)
            (12, [.command]),          // Cmd+Q (Quit)
            (13, [.command])           // Cmd+W (Close window)
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
            callback?()
            return
        }

        onKeyDownCallback?()
        if duration >= minimumHoldDuration {
            onKeyUpCallback?(duration)
        }
    }

    /// Get current hold state (for testing/debugging)
    var currentHoldState: HoldState {
        holdState
    }
}

// MARK: - Carbon Callback

// Carbon event handler callback (must be a C function pointer with @convention(c))
// Note: @convention(c) is required for Swift functions to be callable from Carbon APIs
private let carbonHotkeyCallback: EventHandlerUPP = { (_: EventHandlerCallRef?, event: EventRef?, _: UnsafeMutableRawPointer?) -> OSStatus in
    print("[DEBUG-CARBON] carbonHotkeyCallback called!")
    fflush(stdout)
    guard let event = event else {
        print("[DEBUG-CARBON] event is nil, returning")
        fflush(stdout)
        return OSStatus(eventNotHandledErr)
    }

    let eventKind = GetEventKind(event)
    // Get the actual Carbon event time (accurate, unaffected by Task scheduling delays)
    let carbonEventTime = GetEventTime(event)
    print("[DEBUG-CARBON] eventKind=\(eventKind), carbonEventTime=\(carbonEventTime)")
    fflush(stdout)

    // Dispatch to main actor - capture the event time to pass to handlers
    Task { @MainActor in
        print("[DEBUG-CARBON] Inside MainActor Task, sharedInstance=\(HotkeyService.sharedInstance != nil ? "exists" : "NIL")")
        fflush(stdout)
        guard let service = HotkeyService.sharedInstance else {
            print("[DEBUG-CARBON] sharedInstance is nil, returning")
            fflush(stdout)
            return
        }

        if eventKind == UInt32(kEventHotKeyPressed) {
            print("[DEBUG-CARBON] Calling handleHotkeyPressed with carbonEventTime=\(carbonEventTime)")
            fflush(stdout)
            service.handleHotkeyPressed(carbonEventTime: carbonEventTime)
        } else if eventKind == UInt32(kEventHotKeyReleased) {
            print("[DEBUG-CARBON] Calling handleHotkeyReleased with carbonEventTime=\(carbonEventTime)")
            fflush(stdout)
            service.handleHotkeyReleased(carbonEventTime: carbonEventTime)
        }
    }

    return noErr
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
