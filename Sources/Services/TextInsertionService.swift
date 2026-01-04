import AppKit
import ApplicationServices
import Foundation
import OSLog

/// Result of a text insertion attempt with fallback handling
enum TextInsertionResult: Sendable, Equatable {
    /// Text was successfully inserted via Accessibility APIs
    case insertedViaAccessibility
    /// Text was copied to clipboard only (not inserted)
    case copiedToClipboardOnly(reason: ClipboardFallbackReason)
    /// Accessibility permission is required but not granted
    case requiresAccessibilityPermission
}

/// Reason why text was copied to clipboard instead of inserted
enum ClipboardFallbackReason: Sendable, Equatable {
    /// User has not granted accessibility permission
    case accessibilityNotGranted
    /// Accessibility insertion failed with an error
    case insertionFailed(String)
    /// User prefers clipboard-only mode
    case userPreference
}

/// Service for inserting text using Accessibility APIs
@MainActor
class TextInsertionService {
    private let permissionService = PermissionService()
    private let settingsService: SettingsService

    init(settingsService: SettingsService = SettingsService()) {
        self.settingsService = settingsService
    }

    /// Insert text at the current cursor position
    func insertText(_ text: String) async throws {
        // Check accessibility permission
        guard permissionService.checkAccessibilityPermission() else {
            throw PermissionError.accessibilityDenied
        }

        // Get the currently focused application
        guard NSWorkspace.shared.frontmostApplication != nil else {
            // Fallback to clipboard if no focused app
            AppLogger.service.info("No frontmost application detected. Falling back to clipboard copy.")
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
            AppLogger.service.info("Failed to get focused UI element (error: \(String(describing: result), privacy: .public)). Falling back to clipboard copy.")
            try await copyToClipboard(text)
            return
        }

        guard let element = focusedElement else {
            AppLogger.service.info("Focused element is nil after successful query. Falling back to clipboard copy.")
            try await copyToClipboard(text)
            return
        }

        // element is CFTypeRef from AXUIElementCopyAttributeValue - cast to AXUIElement
        // Note: In Swift 6, CFTypeRef to AXUIElement cast always succeeds, so we use unsafeBitCast
        let axElement = unsafeBitCast(element, to: AXUIElement.self)

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
        let success = pasteboard.setString(text, forType: .string)
        guard success else {
            throw TextInsertionError.clipboardFailed
        }
    }

    /// Simulate paste operation (alternative insertion method)
    private func simulatePaste(_ text: String) async throws {
        // Copy to clipboard first
        try await copyToClipboard(text)

        // Small delay to ensure clipboard content is fully committed
        // This prevents race condition where keyboard events execute before pasteboard is ready
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

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

        // Post events with small delays for reliable processing across all applications
        cmdDown.post(tap: .cghidEventTap)
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms delay
        vDown.post(tap: .cghidEventTap)
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms delay
        vUp.post(tap: .cghidEventTap)
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms delay
        cmdUp.post(tap: .cghidEventTap)
    }

    // MARK: - Fallback-Aware Insertion

    /// Insert text with fallback to clipboard if accessibility is not available
    ///
    /// This method provides a graceful degradation path:
    /// 1. If user prefers clipboard-only mode, copy to clipboard
    /// 2. If accessibility permission is not granted, copy to clipboard and indicate prompt needed
    /// 3. Try to insert via accessibility APIs
    /// 4. Fall back to clipboard if insertion fails
    ///
    /// - Parameter text: The text to insert
    /// - Returns: Result indicating how the text was handled
    func insertTextWithFallback(_ text: String) async -> TextInsertionResult {
        let settings = settingsService.load()

        // Check if user prefers clipboard-only mode
        if settings.general.clipboardOnlyMode {
            AppLogger.service.info("Using clipboard-only mode (user preference)")
            do {
                try await copyToClipboardPublic(text)
                return .copiedToClipboardOnly(reason: .userPreference)
            } catch {
                AppLogger.service.error("Clipboard copy failed in clipboard-only mode: \(error.localizedDescription, privacy: .public)")
                // Even if clipboard fails, return user preference reason since that was the intent
                return .copiedToClipboardOnly(reason: .userPreference)
            }
        }

        // Check accessibility permission
        guard permissionService.checkAccessibilityPermission() else {
            AppLogger.service.info("Accessibility not granted, falling back to clipboard")
            do {
                try await copyToClipboardPublic(text)
                // Check if user has dismissed the accessibility prompt before
                if settings.general.accessibilityPromptDismissed {
                    return .copiedToClipboardOnly(reason: .accessibilityNotGranted)
                } else {
                    return .requiresAccessibilityPermission
                }
            } catch {
                AppLogger.service.error("Clipboard copy failed: \(error.localizedDescription, privacy: .public)")
                return .requiresAccessibilityPermission
            }
        }

        // Try to insert via accessibility
        do {
            try await insertText(text)
            return .insertedViaAccessibility
        } catch {
            AppLogger.service.warning("Accessibility insertion failed, falling back to clipboard: \(error.localizedDescription, privacy: .public)")
            // Already copied to clipboard as part of simulatePaste fallback in insertText
            // But if that also failed, try explicit clipboard copy
            do {
                try await copyToClipboardPublic(text)
            } catch {
                AppLogger.service.error("Final clipboard fallback failed: \(error.localizedDescription, privacy: .public)")
            }
            return .copiedToClipboardOnly(reason: .insertionFailed(error.localizedDescription))
        }
    }

    /// Public method to copy text to clipboard
    /// - Parameter text: The text to copy
    func copyToClipboardPublic(_ text: String) async throws {
        try await copyToClipboard(text)
    }
}

/// Text insertion errors
enum TextInsertionError: Error, LocalizedError, Equatable, Sendable {
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
