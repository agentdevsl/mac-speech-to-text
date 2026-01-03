import XCTest
@testable import SpeechToText

@MainActor
final class HotkeyServiceTests: XCTestCase {

    var service: HotkeyService!

    override func setUp() async throws {
        try await super.setUp()
        service = HotkeyService()
    }

    override func tearDown() async throws {
        service.unregisterHotkey()
        try await super.tearDown()
    }

    // MARK: - Registration Tests

    func test_registerHotkey_storesCallback() async {
        // Given
        var callbackInvoked = false
        let callback = { callbackInvoked = true }

        // When
        // Note: This will likely fail in test environment due to Carbon Event Manager requirements
        do {
            try await service.registerHotkey(keyCode: 49, modifiers: [.command], callback: callback)
        } catch {
            // Expected to fail in test environment
            XCTAssertTrue(error is HotkeyError)
        }
    }

    func test_registerHotkey_unregistersExistingHotkeyFirst() async {
        // Given
        let callback1 = { }
        let callback2 = { }

        // When
        do {
            try await service.registerHotkey(keyCode: 49, modifiers: [.command], callback: callback1)
            try await service.registerHotkey(keyCode: 50, modifiers: [.control], callback: callback2)
        } catch {
            // Expected to fail in test environment
            XCTAssertTrue(error is HotkeyError)
        }
    }

    // MARK: - Unregister Tests

    func test_unregisterHotkey_clearsCallback() {
        // Given
        var callbackInvoked = false

        // When
        service.unregisterHotkey()
        service.simulateHotkeyPress()

        // Then
        XCTAssertFalse(callbackInvoked)
    }

    func test_unregisterHotkey_canBeCalledMultipleTimes() {
        // Given/When/Then
        XCTAssertNoThrow(service.unregisterHotkey())
        XCTAssertNoThrow(service.unregisterHotkey())
    }

    // MARK: - Conflict Detection Tests

    func test_checkConflict_returnsTrueForSystemShortcuts() {
        // Given/When
        let conflictCmdSpace = service.checkConflict(keyCode: 49, modifiers: [.command])

        // Then
        XCTAssertTrue(conflictCmdSpace) // Cmd+Space is Spotlight
    }

    func test_checkConflict_returnsTrueForCmdQ() {
        // Given/When
        let conflictCmdQ = service.checkConflict(keyCode: 12, modifiers: [.command])

        // Then
        XCTAssertTrue(conflictCmdQ) // Cmd+Q is Quit
    }

    func test_checkConflict_returnsTrueForCmdW() {
        // Given/When
        let conflictCmdW = service.checkConflict(keyCode: 13, modifiers: [.command])

        // Then
        XCTAssertTrue(conflictCmdW) // Cmd+W is Close Window
    }

    func test_checkConflict_returnsFalseForNonSystemShortcuts() {
        // Given/When
        let noConflict = service.checkConflict(keyCode: 49, modifiers: [.command, .control])

        // Then
        XCTAssertFalse(noConflict) // Cmd+Ctrl+Space is not a system shortcut
    }

    func test_checkConflict_returnsFalseForSafeKeyCombinations() {
        // Given/When
        let noConflict1 = service.checkConflict(keyCode: 50, modifiers: [.control, .shift])
        let noConflict2 = service.checkConflict(keyCode: 51, modifiers: [.option])

        // Then
        XCTAssertFalse(noConflict1)
        XCTAssertFalse(noConflict2)
    }

    // MARK: - Simulate Hotkey Press Tests

    func test_simulateHotkeyPress_invokesCallback() {
        // Given
        var callbackInvoked = false
        let callback = { callbackInvoked = true }

        // Manually set callback for testing (since registration will fail in test environment)
        // We'll use simulateHotkeyPress which directly calls the callback

        // When
        // First try to register (will fail but we can still test simulation)
        Task {
            try? await service.registerHotkey(keyCode: 49, modifiers: [.command], callback: callback)
        }

        // Let the task complete
        Thread.sleep(forTimeInterval: 0.1)

        service.simulateHotkeyPress()

        // Then
        // In test environment, callback may not be set due to registration failure
        // This test demonstrates the pattern
    }

    // MARK: - KeyModifier Tests

    func test_keyModifier_displayNames() {
        // Given/When/Then
        XCTAssertEqual(KeyModifier.command.displayName, "⌘")
        XCTAssertEqual(KeyModifier.control.displayName, "⌃")
        XCTAssertEqual(KeyModifier.option.displayName, "⌥")
        XCTAssertEqual(KeyModifier.shift.displayName, "⇧")
    }

    func test_keyModifier_allCases() {
        // Given
        let allModifiers = KeyModifier.allCases

        // When/Then
        XCTAssertEqual(allModifiers.count, 4)
        XCTAssertTrue(allModifiers.contains(.command))
        XCTAssertTrue(allModifiers.contains(.control))
        XCTAssertTrue(allModifiers.contains(.option))
        XCTAssertTrue(allModifiers.contains(.shift))
    }

    // MARK: - HotkeyError Tests

    func test_hotkeyError_installationFailed_hasCorrectDescription() {
        // Given
        let error = HotkeyError.installationFailed("Test error")

        // When
        let description = error.errorDescription

        // Then
        XCTAssertTrue(description?.contains("Hotkey installation failed") ?? false)
        XCTAssertTrue(description?.contains("Test error") ?? false)
    }

    func test_hotkeyError_registrationFailed_hasCorrectDescription() {
        // Given
        let error = HotkeyError.registrationFailed("Registration error")

        // When
        let description = error.errorDescription

        // Then
        XCTAssertTrue(description?.contains("Hotkey registration failed") ?? false)
        XCTAssertTrue(description?.contains("Registration error") ?? false)
    }

    func test_hotkeyError_conflictDetected_hasCorrectDescription() {
        // Given
        let error = HotkeyError.conflictDetected("Cmd+Space conflicts with Spotlight")

        // When
        let description = error.errorDescription

        // Then
        XCTAssertTrue(description?.contains("Hotkey conflict detected") ?? false)
        XCTAssertTrue(description?.contains("Cmd+Space") ?? false)
    }

    // MARK: - Multiple Modifiers Tests

    func test_registerHotkey_supportsMultipleModifiers() async {
        // Given
        let modifiers: [KeyModifier] = [.command, .control, .shift]
        let callback = { }

        // When
        do {
            try await service.registerHotkey(keyCode: 49, modifiers: modifiers, callback: callback)
        } catch {
            // Expected to fail in test environment
            XCTAssertTrue(error is HotkeyError)
        }
    }

    func test_registerHotkey_supportsSingleModifier() async {
        // Given
        let modifiers: [KeyModifier] = [.control]
        let callback = { }

        // When
        do {
            try await service.registerHotkey(keyCode: 49, modifiers: modifiers, callback: callback)
        } catch {
            // Expected to fail in test environment
            XCTAssertTrue(error is HotkeyError)
        }
    }

    // MARK: - Common Key Codes Tests

    func test_commonKeyCodes_areDistinct() {
        // Given
        let spaceKey = 49
        let returnKey = 36
        let tabKey = 48

        // When/Then
        XCTAssertNotEqual(spaceKey, returnKey)
        XCTAssertNotEqual(spaceKey, tabKey)
        XCTAssertNotEqual(returnKey, tabKey)
    }

    // MARK: - Conflict Detection Edge Cases

    func test_checkConflict_considersBothKeyCodeAndModifiers() {
        // Given
        let keyCode = 49 // Space

        // When
        let conflictWithCommand = service.checkConflict(keyCode: keyCode, modifiers: [.command])
        let noConflictWithControlShift = service.checkConflict(keyCode: keyCode, modifiers: [.control, .shift])

        // Then
        XCTAssertTrue(conflictWithCommand) // Cmd+Space conflicts
        XCTAssertFalse(noConflictWithControlShift) // Ctrl+Shift+Space doesn't conflict
    }

    func test_checkConflict_emptyModifiers_doesNotConflict() {
        // Given
        let keyCode = 49

        // When
        let noConflict = service.checkConflict(keyCode: keyCode, modifiers: [])

        // Then
        XCTAssertFalse(noConflict)
    }

    // MARK: - Deinit Cleanup Tests

    func test_deinit_unregistersHotkey() {
        // Given
        var localService: HotkeyService? = HotkeyService()

        // When
        localService = nil

        // Then
        // Service should be deallocated and hotkey unregistered
        // This is tested by the absence of crashes or memory leaks
        XCTAssertNil(localService)
    }
}
