import Foundation
import ApplicationServices
import AppKit

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
        guard let focusedApp = NSWorkspace.shared.frontmostApplication else {
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

        let axElement = element as! AXUIElement

        // Try to insert text directly
        let insertionResult = AXUIElementSetAttributeValue(
            axElement,
            kAXValueAttribute as CFString,
            text as CFTypeRef
        )

        if insertionResult == .success {
            return
        }

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
        let source = CGEventSource(stateID: .hidSystemState)

        // Press Cmd
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true) // Cmd key
        cmdDown?.flags = .maskCommand

        // Press V
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // V key
        vDown?.flags = .maskCommand

        // Release V
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        vUp?.flags = .maskCommand

        // Release Cmd
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)

        // Post events
        cmdDown?.post(tap: .cghidEventTap)
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
        cmdUp?.post(tap: .cghidEventTap)
    }
}

/// Text insertion errors
enum TextInsertionError: Error, LocalizedError {
    case noFocusedElement
    case insertionFailed
    case clipboardFailed

    var errorDescription: String? {
        switch self {
        case .noFocusedElement:
            return "No active text field found"
        case .insertionFailed:
            return "Failed to insert text via Accessibility API"
        case .clipboardFailed:
            return "Failed to copy text to clipboard"
        }
    }
}
