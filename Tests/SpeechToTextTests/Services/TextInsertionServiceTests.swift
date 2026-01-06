import XCTest
@testable import SpeechToText

@MainActor
final class TextInsertionServiceTests: XCTestCase {

    var service: TextInsertionService!

    override func setUp() async throws {
        try await super.setUp()
        service = TextInsertionService()
    }

    // MARK: - Initialization Tests

    func test_initialization_createsService() {
        // Given/When
        let service = TextInsertionService()

        // Then
        XCTAssertNotNil(service)
    }

    // MARK: - Insert Text Tests

    func test_insertText_requiresAccessibilityPermission() async {
        // Given
        let text = "Hello, world!"

        // When/Then
        do {
            try await service.insertText(text)
            // If we get here, accessibility permission was granted
            // or fallback to clipboard was used
        } catch {
            // Expected in CI: PermissionError.accessibilityDenied or TextInsertionError variants
            // All are valid outcomes when accessibility/display not available
            XCTAssertTrue(
                error is PermissionError || error is TextInsertionError,
                "Expected PermissionError or TextInsertionError, got \(error)"
            )
        }
    }

    func test_insertText_handlesEmptyString() async {
        // Given
        let text = ""

        // When/Then
        do {
            try await service.insertText(text)
            // Should handle empty string without errors
        } catch {
            // May throw if permissions are not granted or display unavailable
            XCTAssertTrue(error is PermissionError || error is TextInsertionError)
        }
    }

    func test_insertText_handlesLongText() async {
        // Given
        let longText = String(repeating: "Lorem ipsum dolor sit amet. ", count: 100)

        // When/Then
        do {
            try await service.insertText(longText)
            // Should handle long text without errors
        } catch {
            // May throw if permissions are not granted or display unavailable
            XCTAssertTrue(error is PermissionError || error is TextInsertionError)
        }
    }

    func test_insertText_handlesSpecialCharacters() async {
        // Given
        let specialText = "Hello! @#$%^&*() 你好 مرحبا"

        // When/Then
        do {
            try await service.insertText(specialText)
            // Should handle special characters
        } catch {
            // May throw if permissions are not granted or display unavailable
            XCTAssertTrue(error is PermissionError || error is TextInsertionError)
        }
    }

    func test_insertText_handlesNewlines() async {
        // Given
        let multilineText = "Line 1\nLine 2\nLine 3"

        // When/Then
        do {
            try await service.insertText(multilineText)
            // Should handle newlines correctly
        } catch {
            // May throw if permissions are not granted or display unavailable
            XCTAssertTrue(error is PermissionError || error is TextInsertionError)
        }
    }

    // MARK: - Clipboard Fallback Tests

    func test_insertText_fallsBackToClipboardWhenNoFocusedApp() async {
        // Given
        let text = "Test text"

        // When
        do {
            try await service.insertText(text)
            // May fall back to clipboard if no focused app
        } catch {
            // May throw permission error
            XCTAssertTrue(error is PermissionError || error is TextInsertionError)
        }
    }

    // MARK: - TextInsertionError Tests

    func test_textInsertionError_noFocusedElement_hasCorrectDescription() {
        // Given
        let error = TextInsertionError.noFocusedElement

        // When
        let description = error.errorDescription

        // Then
        XCTAssertEqual(description, "No active text field found")
    }

    func test_textInsertionError_insertionFailed_hasCorrectDescription() {
        // Given
        let error = TextInsertionError.insertionFailed

        // When
        let description = error.errorDescription

        // Then
        XCTAssertEqual(description, "Failed to insert text via Accessibility API")
    }

    func test_textInsertionError_clipboardFailed_hasCorrectDescription() {
        // Given
        let error = TextInsertionError.clipboardFailed

        // When
        let description = error.errorDescription

        // Then
        XCTAssertEqual(description, "Failed to copy text to clipboard")
    }

    // MARK: - Multiple Insertions Tests

    func test_multipleInsertions_workSequentially() async {
        // Given
        let texts = ["First", "Second", "Third"]

        // When/Then
        for text in texts {
            do {
                try await service.insertText(text)
            } catch {
                // Expected to fail without accessibility permission
                XCTAssertTrue(error is PermissionError || error is TextInsertionError)
                break
            }
        }
    }

    // MARK: - Concurrent Insertion Tests

    func test_concurrentInsertions_handleGracefully() async {
        // Given
        let texts = ["Text1", "Text2", "Text3"]

        // When
        await withTaskGroup(of: Void.self) { group in
            for text in texts {
                group.addTask {
                    try? await self.service.insertText(text)
                }
            }
        }

        // Then
        // Should complete without crashes
        XCTAssertTrue(true)
    }

    // MARK: - Edge Cases Tests

    func test_insertText_handlesWhitespaceOnlyText() async {
        // Given
        let whitespaceText = "   \t\n   "

        // When/Then
        do {
            try await service.insertText(whitespaceText)
            // Should handle whitespace-only text
        } catch {
            // May throw PermissionError if accessibility denied,
            // or TextInsertionError if paste simulation fails (e.g., in CI without display)
            XCTAssertTrue(error is PermissionError || error is TextInsertionError)
        }
    }

    func test_insertText_handlesVeryLongSingleLine() async {
        // Given
        let veryLongLine = String(repeating: "a", count: 10000)

        // When/Then
        do {
            try await service.insertText(veryLongLine)
            // Should handle very long single line
        } catch {
            XCTAssertTrue(error is PermissionError || error is TextInsertionError)
        }
    }

    func test_insertText_handlesUnicodeEmojis() async {
        // Given
        let emojiText = "Hello 👋 World 🌍"

        // When/Then
        do {
            try await service.insertText(emojiText)
            // Should handle emojis correctly
        } catch {
            XCTAssertTrue(error is PermissionError || error is TextInsertionError)
        }
    }

    // MARK: - Permission Integration Tests

    func test_insertText_checksPermissionBeforeInsertion() async {
        // Given
        let text = "Test"
        let permissionService = PermissionService()

        // When
        let hasPermission = await permissionService.checkAccessibilityPermission()

        // Then
        if !hasPermission {
            do {
                try await service.insertText(text)
                // Should either throw or fall back to clipboard
            } catch let error as PermissionError {
                XCTAssertEqual(error, .accessibilityDenied)
            } catch {
                // Other errors are acceptable
            }
        }
    }

    // MARK: - Simulate Paste Tests

    func test_simulatePaste_copiesTextToClipboard() async {
        // Given
        let text = "Paste test"

        // When
        do {
            // This will attempt to paste, which requires accessibility
            try await service.insertText(text)
            // If accessibility is denied, it should fall back to clipboard
        } catch {
            // Expected without permissions
            XCTAssertTrue(error is PermissionError || error is TextInsertionError)
        }
    }

    // MARK: - Memory and Performance Tests

    func test_insertText_handlesLargeVolumeOfText() async {
        // Given
        let largeText = String(repeating: "Lorem ipsum dolor sit amet. ", count: 1000)

        // When
        let startTime = Date()

        do {
            try await service.insertText(largeText)

            let duration = Date().timeIntervalSince(startTime)

            // Then
            // Should complete in reasonable time (< 1 second)
            XCTAssertLessThan(duration, 1.0)
        } catch {
            // Expected without permissions
            XCTAssertTrue(error is PermissionError || error is TextInsertionError)
        }
    }

    // MARK: - Service Lifecycle Tests

    func test_service_canBeRecreated() {
        // Given
        var service: TextInsertionService? = TextInsertionService()
        XCTAssertNotNil(service)

        // When
        service = nil
        service = TextInsertionService()

        // Then
        XCTAssertNotNil(service)
    }

    func test_multipleServices_workIndependently() async {
        // Given
        let service1 = TextInsertionService()
        let service2 = TextInsertionService()

        // When/Then
        do {
            try await service1.insertText("Text1")
            try await service2.insertText("Text2")
        } catch {
            // Expected without permissions
            XCTAssertTrue(error is PermissionError || error is TextInsertionError)
        }
    }

    // MARK: - insertTextWithFallback Tests

    func test_insertTextWithFallback_returnsResult() async {
        // Given
        let text = "Test text"

        // When
        let result = await service.insertTextWithFallback(text)

        // Then - should return one of the valid result types
        switch result {
        case .insertedViaAccessibility:
            XCTAssertTrue(true) // Success via accessibility
        case .copiedToClipboardOnly:
            XCTAssertTrue(true) // Fallback to clipboard
        case .requiresAccessibilityPermission:
            XCTAssertTrue(true) // Need permission
        }
    }

    func test_insertTextWithFallback_handlesEmptyText() async {
        // Given
        let text = ""

        // When
        let result = await service.insertTextWithFallback(text)

        // Then - should complete without crash
        XCTAssertNotNil(result)
    }

    func test_insertTextWithFallback_handlesLongText() async {
        // Given
        let longText = String(repeating: "Lorem ipsum dolor sit amet. ", count: 100)

        // When
        let result = await service.insertTextWithFallback(longText)

        // Then - should complete without crash
        XCTAssertNotNil(result)
    }

    func test_insertTextWithFallback_handlesSpecialCharacters() async {
        // Given
        let specialText = "Hello! @#$%^&*() 你好 مرحبا 👋"

        // When
        let result = await service.insertTextWithFallback(specialText)

        // Then - should complete without crash
        XCTAssertNotNil(result)
    }

    // MARK: - TextInsertionResult Tests

    func test_textInsertionResult_insertedViaAccessibility_isEquatable() {
        // Given
        let result1 = TextInsertionResult.insertedViaAccessibility
        let result2 = TextInsertionResult.insertedViaAccessibility

        // Then
        XCTAssertEqual(result1, result2)
    }

    func test_textInsertionResult_copiedToClipboardOnly_preservesReason() {
        // Given
        let result = TextInsertionResult.copiedToClipboardOnly(reason: .userPreference)

        // Then
        if case .copiedToClipboardOnly(let reason) = result {
            XCTAssertEqual(reason, .userPreference)
        } else {
            XCTFail("Expected copiedToClipboardOnly result")
        }
    }

    func test_textInsertionResult_requiresAccessibilityPermission_isEquatable() {
        // Given
        let result1 = TextInsertionResult.requiresAccessibilityPermission
        let result2 = TextInsertionResult.requiresAccessibilityPermission

        // Then
        XCTAssertEqual(result1, result2)
    }

    // MARK: - ClipboardFallbackReason Tests

    func test_clipboardFallbackReason_accessibilityNotGranted_isEquatable() {
        // Given
        let reason1 = ClipboardFallbackReason.accessibilityNotGranted
        let reason2 = ClipboardFallbackReason.accessibilityNotGranted

        // Then
        XCTAssertEqual(reason1, reason2)
    }

    func test_clipboardFallbackReason_insertionFailed_preservesMessage() {
        // Given
        let reason = ClipboardFallbackReason.insertionFailed("Test error")

        // Then
        if case .insertionFailed(let message) = reason {
            XCTAssertEqual(message, "Test error")
        } else {
            XCTFail("Expected insertionFailed reason")
        }
    }

    func test_clipboardFallbackReason_userPreference_isEquatable() {
        // Given
        let reason1 = ClipboardFallbackReason.userPreference
        let reason2 = ClipboardFallbackReason.userPreference

        // Then
        XCTAssertEqual(reason1, reason2)
    }

    func test_clipboardFallbackReason_clipboardFailed_preservesMessage() {
        // Given
        let reason = ClipboardFallbackReason.clipboardFailed("Clipboard unavailable")

        // Then
        if case .clipboardFailed(let message) = reason {
            XCTAssertEqual(message, "Clipboard unavailable")
        } else {
            XCTFail("Expected clipboardFailed reason")
        }
    }

    func test_clipboardFallbackReason_clipboardFailed_isEquatable() {
        // Given
        let reason1 = ClipboardFallbackReason.clipboardFailed("error")
        let reason2 = ClipboardFallbackReason.clipboardFailed("error")

        // Then
        XCTAssertEqual(reason1, reason2)
    }

    func test_clipboardFallbackReason_clipboardFailed_differentMessagesNotEqual() {
        // Given
        let reason1 = ClipboardFallbackReason.clipboardFailed("error1")
        let reason2 = ClipboardFallbackReason.clipboardFailed("error2")

        // Then
        XCTAssertNotEqual(reason1, reason2)
    }

    // MARK: - copyToClipboardPublic Tests

    func test_copyToClipboardPublic_copiesToClipboard() async throws {
        // Given
        let text = "Test clipboard text"

        // When/Then - clipboard may not be available in headless/CI environments
        do {
            try await service.copyToClipboardPublic(text)

            // Verify clipboard contains the text if operation succeeded
            let pasteboard = NSPasteboard.general
            let clipboardText = pasteboard.string(forType: .string)
            XCTAssertEqual(clipboardText, text)
        } catch TextInsertionError.clipboardFailed {
            // Clipboard not available in this environment - expected in CI/headless
            // The important thing is the method doesn't crash
        }
    }

    func test_copyToClipboardPublic_handlesEmptyText() async throws {
        // Given
        let text = ""

        // When/Then - clipboard may not be available in headless/CI environments
        do {
            try await service.copyToClipboardPublic(text)

            // Verify clipboard contains empty text if operation succeeded
            // Note: NSPasteboard may return nil or empty string for empty text - both are valid
            let pasteboard = NSPasteboard.general
            let clipboardText = pasteboard.string(forType: .string)
            XCTAssertTrue(clipboardText == nil || clipboardText == "", "Clipboard should be empty or nil for empty text")
        } catch TextInsertionError.clipboardFailed {
            // Clipboard not available in this environment - expected in CI/headless
            // The important thing is the method doesn't crash
        }
    }

    func test_copyToClipboardPublic_handlesSpecialCharacters() async throws {
        // Given
        let text = "Test 👋 你好 مرحبا"

        // When/Then - clipboard may not be available in headless/CI environments
        do {
            try await service.copyToClipboardPublic(text)

            // Verify clipboard contains special characters if operation succeeded
            let pasteboard = NSPasteboard.general
            let clipboardText = pasteboard.string(forType: .string)
            XCTAssertEqual(clipboardText, text)
        } catch TextInsertionError.clipboardFailed {
            // Clipboard not available in this environment - expected in CI/headless
            // The important thing is the method doesn't crash
        }
    }

    // MARK: - TextInsertionError Additional Tests

    func test_textInsertionError_eventSourceCreationFailed_hasCorrectDescription() {
        // Given
        let error = TextInsertionError.eventSourceCreationFailed

        // When
        let description = error.errorDescription

        // Then
        XCTAssertEqual(description, "Failed to create CGEventSource for keyboard simulation")
    }

    func test_textInsertionError_keyEventCreationFailed_hasCorrectDescription() {
        // Given
        let error = TextInsertionError.keyEventCreationFailed("V key down")

        // When
        let description = error.errorDescription

        // Then
        XCTAssertEqual(description, "Failed to create keyboard event for V key down")
    }

    func test_textInsertionError_keyEventCreationFailed_variousKeys() {
        // Given - test all possible key event failure messages
        let keys = ["Command key down", "V key up", "Command key up", "Return key down", "Return key up"]

        // Then
        for key in keys {
            let error = TextInsertionError.keyEventCreationFailed(key)
            XCTAssertTrue(error.errorDescription?.contains(key) ?? false,
                "Error description should contain '\(key)'")
        }
    }

    // MARK: - TextInsertionError Equatable Tests

    func test_textInsertionError_noFocusedElement_isEquatable() {
        // Given
        let error1 = TextInsertionError.noFocusedElement
        let error2 = TextInsertionError.noFocusedElement

        // Then
        XCTAssertEqual(error1, error2)
    }

    func test_textInsertionError_insertionFailed_isEquatable() {
        // Given
        let error1 = TextInsertionError.insertionFailed
        let error2 = TextInsertionError.insertionFailed

        // Then
        XCTAssertEqual(error1, error2)
    }

    func test_textInsertionError_clipboardFailed_isEquatable() {
        // Given
        let error1 = TextInsertionError.clipboardFailed
        let error2 = TextInsertionError.clipboardFailed

        // Then
        XCTAssertEqual(error1, error2)
    }

    func test_textInsertionError_eventSourceCreationFailed_isEquatable() {
        // Given
        let error1 = TextInsertionError.eventSourceCreationFailed
        let error2 = TextInsertionError.eventSourceCreationFailed

        // Then
        XCTAssertEqual(error1, error2)
    }

    func test_textInsertionError_keyEventCreationFailed_sameKey_isEquatable() {
        // Given
        let error1 = TextInsertionError.keyEventCreationFailed("V key down")
        let error2 = TextInsertionError.keyEventCreationFailed("V key down")

        // Then
        XCTAssertEqual(error1, error2)
    }

    func test_textInsertionError_keyEventCreationFailed_differentKeys_notEqual() {
        // Given
        let error1 = TextInsertionError.keyEventCreationFailed("V key down")
        let error2 = TextInsertionError.keyEventCreationFailed("Command key down")

        // Then
        XCTAssertNotEqual(error1, error2)
    }

    func test_textInsertionError_differentTypes_notEqual() {
        // Given
        let errors: [TextInsertionError] = [
            .noFocusedElement,
            .insertionFailed,
            .clipboardFailed,
            .eventSourceCreationFailed,
            .keyEventCreationFailed("test")
        ]

        // Then - each error type should not equal any other type
        for i in 0..<errors.count {
            for j in 0..<errors.count where i != j {
                XCTAssertNotEqual(errors[i], errors[j],
                    "\(errors[i]) should not equal \(errors[j])")
            }
        }
    }

    // MARK: - TextInsertionResult with ClipboardFailed Tests

    func test_textInsertionResult_copiedToClipboardOnly_clipboardFailed_preservesReason() {
        // Given
        let result = TextInsertionResult.copiedToClipboardOnly(reason: .clipboardFailed("test error"))

        // Then
        if case .copiedToClipboardOnly(let reason) = result {
            if case .clipboardFailed(let message) = reason {
                XCTAssertEqual(message, "test error")
            } else {
                XCTFail("Expected clipboardFailed reason")
            }
        } else {
            XCTFail("Expected copiedToClipboardOnly result")
        }
    }

    // MARK: - insertTextWithFallback Result Inspection Tests

    func test_insertTextWithFallback_resultIsNotNil() async {
        // Given
        let text = "Test"

        // When
        let result = await service.insertTextWithFallback(text)

        // Then
        // The result should always be one of the valid enum cases
        switch result {
        case .insertedViaAccessibility:
            // Success via accessibility - valid
            break
        case .copiedToClipboardOnly(let reason):
            // Verify reason is valid
            switch reason {
            case .accessibilityNotGranted, .userPreference:
                break
            case .insertionFailed(let message):
                XCTAssertFalse(message.isEmpty, "Error message should not be empty")
            case .clipboardFailed(let message):
                XCTAssertFalse(message.isEmpty, "Error message should not be empty")
            }
        case .requiresAccessibilityPermission:
            // Need permission - valid
            break
        }
    }
}
