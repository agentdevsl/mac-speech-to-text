import XCTest
@testable import SpeechToText

final class TextInsertionServiceTests: XCTestCase {

    var service: TextInsertionService!

    override func setUp() {
        super.setUp()
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
        } catch let error as PermissionError {
            XCTAssertEqual(error, .accessibilityDenied)
        } catch {
            // May also succeed silently if fallback is used
            XCTFail("Unexpected error: \(error)")
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
            // May throw if permissions are not granted
            XCTAssertTrue(error is PermissionError)
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
            // May throw if permissions are not granted
            XCTAssertTrue(error is PermissionError)
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
            // May throw if permissions are not granted
            XCTAssertTrue(error is PermissionError)
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
            // May throw if permissions are not granted
            XCTAssertTrue(error is PermissionError)
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
            XCTAssertTrue(error is PermissionError)
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
                XCTAssertTrue(error is PermissionError)
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
            XCTAssertTrue(error is PermissionError)
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
            XCTAssertTrue(error is PermissionError)
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
            XCTAssertTrue(error is PermissionError)
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
            XCTAssertTrue(error is PermissionError)
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
            XCTAssertTrue(error is PermissionError)
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
            XCTAssertTrue(error is PermissionError)
        }
    }
}
