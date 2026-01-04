// UITestHelpers.swift
// macOS Local Speech-to-Text Application
//
// Helper utilities for XCUITest operations
// Part of the XCUITest expansion (Issue #11)

import XCTest

// MARK: - UITestError

/// Errors that can occur during UI testing
enum UITestError: Error, LocalizedError {
    /// Element was not found within timeout
    case elementNotFound(identifier: String, timeout: TimeInterval)

    /// Element was not hittable (not visible or not interactable)
    case elementNotHittable(identifier: String)

    /// Text was not found in app
    case textNotFound(text: String)

    /// Screenshot capture failed
    case screenshotFailed(reason: String)

    /// Timeout waiting for condition
    case timeout(description: String)

    var errorDescription: String? {
        switch self {
        case .elementNotFound(let identifier, let timeout):
            return "Element '\(identifier)' not found within \(timeout) seconds"
        case .elementNotHittable(let identifier):
            return "Element '\(identifier)' is not hittable"
        case .textNotFound(let text):
            return "Text '\(text)' not found in app"
        case .screenshotFailed(let reason):
            return "Screenshot capture failed: \(reason)"
        case .timeout(let description):
            return "Timeout: \(description)"
        }
    }
}

// MARK: - UITestHelpers

/// Utility functions for XCUITest operations
enum UITestHelpers {
    /// Default timeout for waits
    static let defaultTimeout: TimeInterval = 5.0

    // MARK: - Element Waiting

    /// Wait for an element to exist with configurable timeout
    /// - Parameters:
    ///   - element: The XCUIElement to wait for
    ///   - timeout: Maximum time to wait (default: 5 seconds)
    /// - Returns: true if element exists within timeout, false otherwise
    static func waitForElement(_ element: XCUIElement, timeout: TimeInterval = defaultTimeout) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    /// Wait for an element to become hittable (visible and interactable)
    /// - Parameters:
    ///   - element: The XCUIElement to wait for
    ///   - timeout: Maximum time to wait (default: 5 seconds)
    /// - Returns: true if element is hittable within timeout, false otherwise
    static func waitForHittable(_ element: XCUIElement, timeout: TimeInterval = defaultTimeout) -> Bool {
        let predicate = NSPredicate(format: "isHittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }

    /// Wait for an element to disappear
    /// - Parameters:
    ///   - element: The XCUIElement to wait for disappearance
    ///   - timeout: Maximum time to wait (default: 5 seconds)
    /// - Returns: true if element disappears within timeout, false otherwise
    static func waitForDisappearance(_ element: XCUIElement, timeout: TimeInterval = defaultTimeout) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }

    /// Wait for an element's value to change
    /// - Parameters:
    ///   - element: The XCUIElement to monitor
    ///   - expectedValue: The expected value
    ///   - timeout: Maximum time to wait
    /// - Returns: true if value matches within timeout
    static func waitForValue(
        _ element: XCUIElement,
        toBe expectedValue: String,
        timeout: TimeInterval = defaultTimeout
    ) -> Bool {
        let predicate = NSPredicate(format: "value == %@", expectedValue)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }

    // MARK: - Element Interaction

    /// Safely tap a button, waiting for it to be hittable first
    /// - Parameters:
    ///   - button: The button element to tap
    ///   - timeout: Maximum time to wait for button (default: 5 seconds)
    /// - Throws: UITestError if button is not hittable within timeout
    static func tapButton(_ button: XCUIElement, timeout: TimeInterval = defaultTimeout) throws {
        guard waitForHittable(button, timeout: timeout) else {
            throw UITestError.elementNotHittable(identifier: button.identifier)
        }
        button.tap()
    }

    /// Type text into a text field, clearing existing content first
    /// - Parameters:
    ///   - text: The text to type
    ///   - element: The text field element
    ///   - clearFirst: Whether to clear existing content (default: true)
    static func typeText(_ text: String, in element: XCUIElement, clearFirst: Bool = true) {
        element.tap()

        if clearFirst, let existingText = element.value as? String, !existingText.isEmpty {
            // Select all and delete
            element.typeKey("a", modifierFlags: .command)
            element.typeKey(.delete, modifierFlags: [])
        }

        element.typeText(text)
    }

    /// Scroll to an element within a scroll view
    /// - Parameters:
    ///   - element: The element to scroll to
    ///   - scrollView: The containing scroll view
    ///   - maxScrolls: Maximum number of scroll attempts (default: 10)
    /// - Returns: true if element is found and scrolled to, false otherwise
    static func scrollToElement(
        _ element: XCUIElement,
        in scrollView: XCUIElement,
        maxScrolls: Int = 10
    ) -> Bool {
        var scrollCount = 0

        while !element.isHittable && scrollCount < maxScrolls {
            scrollView.swipeUp()
            scrollCount += 1
        }

        return element.isHittable
    }

    // MARK: - Text Verification

    /// Verify that text exists somewhere in the app
    /// - Parameters:
    ///   - text: The text to find
    ///   - app: The XCUIApplication to search in
    ///   - timeout: Maximum time to wait (default: 5 seconds)
    /// - Returns: true if text is found, false otherwise
    static func verifyTextExists(
        _ text: String,
        in app: XCUIApplication,
        timeout: TimeInterval = defaultTimeout
    ) -> Bool {
        let staticText = app.staticTexts[text]
        return staticText.waitForExistence(timeout: timeout)
    }

    /// Verify accessibility label exists on an element
    /// - Parameters:
    ///   - label: The accessibility label to verify
    ///   - element: The element to check
    /// - Returns: true if label matches, false otherwise
    static func verifyAccessibilityLabel(_ label: String, on element: XCUIElement) -> Bool {
        element.label == label
    }

    // MARK: - Screenshot Capture

    /// Capture a screenshot and optionally add as test attachment
    /// - Parameters:
    ///   - name: Name for the screenshot
    ///   - testCase: The XCTestCase to attach to (optional)
    /// - Returns: The captured screenshot
    @discardableResult
    static func captureScreenshot(named name: String, attachTo testCase: XCTestCase? = nil) -> XCUIScreenshot {
        let screenshot = XCUIScreen.main.screenshot()

        if let testCase = testCase {
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = name
            attachment.lifetime = .keepAlways
            testCase.add(attachment)
        }

        return screenshot
    }

    // MARK: - App State Management

    /// Launch app with specified arguments
    /// - Parameters:
    ///   - app: The XCUIApplication to launch
    ///   - arguments: Array of launch arguments
    ///   - environment: Environment variables dictionary
    static func launchApp(
        _ app: XCUIApplication,
        arguments: [String] = [],
        environment: [String: String] = [:]
    ) {
        app.launchArguments = arguments
        app.launchEnvironment = environment
        app.launch()
    }

    /// Terminate and relaunch app with new arguments
    /// - Parameters:
    ///   - app: The XCUIApplication to relaunch
    ///   - arguments: New launch arguments
    static func relaunchApp(_ app: XCUIApplication, arguments: [String] = []) {
        app.terminate()
        app.launchArguments = arguments
        app.launch()
    }

    // MARK: - Window Helpers

    /// Get the main window of the application
    /// - Parameter app: The XCUIApplication
    /// - Returns: The main window element
    static func mainWindow(of app: XCUIApplication) -> XCUIElement {
        app.windows.firstMatch
    }

    /// Check if a window with the given title exists
    /// - Parameters:
    ///   - title: The window title
    ///   - app: The XCUIApplication
    /// - Returns: true if window exists
    static func windowExists(withTitle title: String, in app: XCUIApplication) -> Bool {
        app.windows[title].exists
    }

    // MARK: - Keyboard Helpers

    /// Press escape key
    /// - Parameter app: The XCUIApplication
    static func pressEscape(in app: XCUIApplication) {
        app.typeKey(.escape, modifierFlags: [])
    }

    /// Press return/enter key
    /// - Parameter app: The XCUIApplication
    static func pressReturn(in app: XCUIApplication) {
        app.typeKey(.return, modifierFlags: [])
    }

    /// Press command + comma (open settings)
    /// - Parameter app: The XCUIApplication
    static func openSettings(in app: XCUIApplication) {
        app.typeKey(",", modifierFlags: .command)
    }

    /// Simulate global hotkey (note: may not work in XCUITest context)
    /// - Parameter app: The XCUIApplication
    static func triggerGlobalHotkey(in app: XCUIApplication) {
        // Note: XCUITest cannot truly simulate global hotkeys
        // This is for documentation purposes - actual triggering
        // should use --trigger-recording launch argument
        app.typeKey(" ", modifierFlags: [.command, .control])
    }
}

// MARK: - XCUIElement Extensions

extension XCUIElement {
    /// Wait for existence with default timeout
    /// - Parameter timeout: Timeout in seconds (default: 5)
    /// - Returns: true if element exists within timeout
    func waitForExistenceWithDefault(timeout: TimeInterval = 5.0) -> Bool {
        waitForExistence(timeout: timeout)
    }

    /// Safely tap element, waiting for it to be hittable first
    /// - Parameter timeout: Timeout in seconds (default: 5)
    /// - Throws: UITestError.elementNotHittable if not hittable
    func safeTap(timeout: TimeInterval = 5.0) throws {
        guard UITestHelpers.waitForHittable(self, timeout: timeout) else {
            throw UITestError.elementNotHittable(identifier: identifier)
        }
        tap()
    }

    /// Check if element is visible (exists and has non-zero frame)
    var isVisible: Bool {
        exists && !frame.isEmpty && frame.width > 0 && frame.height > 0
    }

    /// Get the text value of the element
    var textValue: String? {
        value as? String
    }
}

// MARK: - XCTestCase Extensions

extension XCTestCase {
    /// Capture screenshot on test failure in tearDown
    /// Call this at the start of tearDown() to capture failure states
    func captureScreenshotOnFailure() {
        guard let testRun = testRun, testRun.failureCount > 0 else { return }

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Failure-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Add screenshot attachment to test
    /// - Parameters:
    ///   - screenshot: The screenshot to attach
    ///   - name: Name for the attachment
    func attachScreenshot(_ screenshot: XCUIScreenshot, named name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
