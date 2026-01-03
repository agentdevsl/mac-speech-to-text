import AppKit
import ApplicationServices
import Foundation
import OSLog

/// Service for inserting text using Accessibility APIs
class TextInsertionService {
    private let permissionService = PermissionService()

    /// Insert text at the current cursor position
    func insertText(_ text: String) async throws {
        // Check accessibility permission
        guard permissionService.checkAccessibilityPermission() else {
            throw PermissionError.accessibilityDenied
        }

        // Get the currently focused application
        guard NSWorkspace.shared.frontmostApplication != nil else {
            // Fallback to clipboard if no focused app
            try await copyToClipboard(text)
            return
        }

        // Get focused element via Accessibility APIs
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedElement: CFTypeRef?

        let result = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        if result != .success {
            // Fallback to clipboard
            try await copyToClipboard(text)
            return
        }

        guard let element = focusedElement else {
            try await copyToClipboard(text)
            return
        }

        // element is AXUIElement (CFTypeRef) - conditional cast for safety
        guard let axElement = element as? AXUIElement else {
            try await copyToClipboard(text)
            return
        }

        // Try to insert text directly
        let insertionResult = AXUIElementSetAttributeValue(
            axElement,
            kAXValueAttribute as CFString,
            text as CFTypeRef
        )

        if insertionResult == .success {
            return
        }

        // Log why direct insertion failed before falling back
        AppLogger.service.warning("Direct insertion failed with error: \(String(describing: insertionResult), privacy: .public). Falling back to paste.")

        // Try alternative: simulate paste
        try await simulatePaste(text)
    }

    /// Copy text to clipboard (fallback method)
    private func copyToClipboard(_ text: String) async throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Simulate paste operation (alternative insertion method)
    private func simulatePaste(_ text: String) async throws {
        // Copy to clipboard first
        try await copyToClipboard(text)

        // Simulate Cmd+V
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            throw TextInsertionError.eventSourceCreationFailed
        }

        // Press Cmd
        guard let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true) else {
            throw TextInsertionError.keyEventCreationFailed("Command key down")
        }
        cmdDown.flags = .maskCommand

        // Press V
        guard let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) else {
            throw TextInsertionError.keyEventCreationFailed("V key down")
        }
        vDown.flags = .maskCommand

        // Release V
        guard let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) else {
            throw TextInsertionError.keyEventCreationFailed("V key up")
        }
        vUp.flags = .maskCommand

        // Release Cmd
        guard let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false) else {
            throw TextInsertionError.keyEventCreationFailed("Command key up")
        }

        // Post events
        cmdDown.post(tap: .cghidEventTap)
        vDown.post(tap: .cghidEventTap)
        vUp.post(tap: .cghidEventTap)
        cmdUp.post(tap: .cghidEventTap)
    }
}

/// Text insertion errors
enum TextInsertionError: Error, LocalizedError {
    case noFocusedElement
    case insertionFailed
    case clipboardFailed
    case eventSourceCreationFailed
    case keyEventCreationFailed(String)

    var errorDescription: String? {
        switch self {
        case .noFocusedElement:
            return "No active text field found"
        case .insertionFailed:
            return "Failed to insert text via Accessibility API"
        case .clipboardFailed:
            return "Failed to copy text to clipboard"
        case .eventSourceCreationFailed:
            return "Failed to create CGEventSource for keyboard simulation"
        case .keyEventCreationFailed(let key):
            return "Failed to create keyboard event for \(key)"
        }
    }
}
