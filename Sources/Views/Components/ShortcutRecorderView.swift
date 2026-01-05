// ShortcutRecorderView.swift
// macOS Local Speech-to-Text Application
//
// Custom shortcut recorder that avoids Bundle.module crashes in SPM executable targets.
// Uses KeyboardShortcuts library for storage but custom UI for recording.

import AppKit
import KeyboardShortcuts
import SwiftUI

/// Custom keyboard shortcut recorder view that works in SPM executable targets.
/// Avoids the Bundle.module crash that occurs with KeyboardShortcuts.Recorder.
struct ShortcutRecorderView: View {
    // MARK: - Properties

    let shortcutName: KeyboardShortcuts.Name
    let placeholder: String

    @State private var isRecording = false
    @State private var currentShortcut: KeyboardShortcuts.Shortcut?
    @State private var keyEventMonitor: Any?
    @State private var mouseEventMonitor: Any?

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Initialization

    init(for name: KeyboardShortcuts.Name, placeholder: String = "Record Shortcut") {
        self.shortcutName = name
        self.placeholder = placeholder
        // Initialize current shortcut from stored value
        self._currentShortcut = State(initialValue: KeyboardShortcuts.getShortcut(for: name))
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 4) {
            // Shortcut display or placeholder
            Text(displayText)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(isRecording ? Color.warmAmber : .primary)
                .frame(minWidth: 80)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(backgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(borderColor, lineWidth: 1)
                )

            // Clear button (only when shortcut is set and not recording)
            if currentShortcut != nil && !isRecording {
                Button(action: clearShortcut) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear shortcut")
            }
        }
        .onTapGesture {
            startRecording()
        }
        .onAppear {
            // Refresh shortcut on appear
            currentShortcut = KeyboardShortcuts.getShortcut(for: shortcutName)
        }
        .onDisappear {
            // Ensure monitors are cleaned up when view disappears
            if isRecording {
                stopRecording()
            }
        }
    }

    // MARK: - Computed Properties

    private var displayText: String {
        if isRecording {
            return "Press shortcut…"
        } else if let shortcut = currentShortcut {
            return formatShortcut(shortcut)
        } else {
            return placeholder
        }
    }

    private var backgroundColor: Color {
        if isRecording {
            return colorScheme == .dark
                ? Color.warmAmber.opacity(0.15)
                : Color.warmAmber.opacity(0.1)
        } else {
            return colorScheme == .dark
                ? Color.white.opacity(0.08)
                : Color.white
        }
    }

    private var borderColor: Color {
        if isRecording {
            return Color.warmAmber
        } else {
            return colorScheme == .dark
                ? Color.white.opacity(0.15)
                : Color.black.opacity(0.1)
        }
    }

    // MARK: - Private Methods

    private func startRecording() {
        guard !isRecording else { return }

        isRecording = true

        // Start monitoring key events
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [self] event in
            if event.type == .keyDown {
                handleKeyDown(event)
                return nil // Consume the event
            } else if event.type == .flagsChanged {
                // Just modifier key pressed/released - don't end recording yet
                return event
            }
            return event
        }

        // Also monitor for clicks outside to cancel (store monitor for proper cleanup)
        // Use [self] capture and verify still recording to avoid setting up monitor after view disappears
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            // Bail out if recording was cancelled (e.g., view disappeared)
            guard isRecording else { return }
            mouseEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [self] event in
                if isRecording {
                    stopRecording()
                }
                return event
            }
        }
    }

    private func stopRecording() {
        isRecording = false
        // Clean up key event monitor
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
            keyEventMonitor = nil
        }
        // Clean up mouse event monitor
        if let monitor = mouseEventMonitor {
            NSEvent.removeMonitor(monitor)
            mouseEventMonitor = nil
        }
    }

    private func handleKeyDown(_ event: NSEvent) {
        // Check for Escape to cancel
        if event.keyCode == 53 { // Escape key
            stopRecording()
            return
        }

        // Get modifiers
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Require at least one modifier (Cmd, Ctrl, Option, or Shift with function key)
        let hasRequiredModifier = modifiers.contains(.command) ||
            modifiers.contains(.control) ||
            modifiers.contains(.option)

        // Allow Shift alone only with function keys
        let isFunctionKey = event.keyCode >= 122 && event.keyCode <= 126 // F1-F12 range varies

        if !hasRequiredModifier && !(modifiers.contains(.shift) && isFunctionKey) {
            // Invalid shortcut - need modifier keys
            return
        }

        // Create and save the shortcut
        let key = KeyboardShortcuts.Key(rawValue: Int(event.keyCode))
        var shortcutModifiers: NSEvent.ModifierFlags = []
        if modifiers.contains(.command) { shortcutModifiers.insert(.command) }
        if modifiers.contains(.control) { shortcutModifiers.insert(.control) }
        if modifiers.contains(.option) { shortcutModifiers.insert(.option) }
        if modifiers.contains(.shift) { shortcutModifiers.insert(.shift) }

        let newShortcut = KeyboardShortcuts.Shortcut(key, modifiers: shortcutModifiers)

        // Check if shortcut conflicts with system shortcuts
        // For now, just save it - the library handles conflict detection
        KeyboardShortcuts.setShortcut(newShortcut, for: shortcutName)
        currentShortcut = newShortcut

        AppLogger.app.debug("ShortcutRecorderView: Set shortcut \(formatShortcut(newShortcut)) for \(shortcutName.rawValue)")

        stopRecording()
    }

    private func clearShortcut() {
        KeyboardShortcuts.setShortcut(nil, for: shortcutName)
        currentShortcut = nil
        AppLogger.app.debug("ShortcutRecorderView: Cleared shortcut for \(shortcutName.rawValue)")
    }

    private func formatShortcut(_ shortcut: KeyboardShortcuts.Shortcut) -> String {
        var parts: [String] = []

        // Add modifier symbols in standard order
        if shortcut.modifiers.contains(.control) {
            parts.append("⌃")
        }
        if shortcut.modifiers.contains(.option) {
            parts.append("⌥")
        }
        if shortcut.modifiers.contains(.shift) {
            parts.append("⇧")
        }
        if shortcut.modifiers.contains(.command) {
            parts.append("⌘")
        }

        // Add key name
        parts.append(keyName(for: shortcut.key))

        return parts.joined()
    }

    private func keyName(for key: KeyboardShortcuts.Key?) -> String {
        guard let key = key else { return "" }

        // Use dictionary for special keys to reduce cyclomatic complexity
        let specialKeys: [KeyboardShortcuts.Key: String] = [
            .space: "Space", .return: "↩", .tab: "⇥", .delete: "⌫", .escape: "⎋",
            .upArrow: "↑", .downArrow: "↓", .leftArrow: "←", .rightArrow: "→",
            .f1: "F1", .f2: "F2", .f3: "F3", .f4: "F4", .f5: "F5", .f6: "F6",
            .f7: "F7", .f8: "F8", .f9: "F9", .f10: "F10", .f11: "F11", .f12: "F12"
        ]

        if let name = specialKeys[key] {
            return name
        }

        // For letter/number keys, use key code mapping
        return keyCodeToCharacter(key.rawValue)
    }

    private func keyCodeToCharacter(_ keyCode: Int) -> String {
        // Map key codes to characters for common keys
        let keyCodeMap: [Int: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
            38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
            45: "N", 46: "M", 47: "."
        ]

        return keyCodeMap[keyCode] ?? "?"
    }
}

// MARK: - Preview

#Preview("Shortcut Recorder") {
    VStack(spacing: 20) {
        ShortcutRecorderView(for: .holdToRecord)
        ShortcutRecorderView(for: .toggleRecording, placeholder: "Set Toggle Key")
    }
    .padding()
    .frame(width: 200)
}
