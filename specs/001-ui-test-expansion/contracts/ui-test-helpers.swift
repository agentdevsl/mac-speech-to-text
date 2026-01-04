// SPDX-License-Identifier: MIT
// Contract: UITestHelpers
// Version: 1.0.0
// Date: 2026-01-03

import XCTest

// MARK: - UITestHelpers Contract

/// Utility functions for XCUITest operations
/// This contract defines the expected interface for UI test helper functions
enum UITestHelpers {

    // MARK: - Element Waiting

    /// Wait for an element to exist with configurable timeout
    /// - Parameters:
    ///   - element: The XCUIElement to wait for
    ///   - timeout: Maximum time to wait (default: 5 seconds)
    /// - Returns: true if element exists within timeout, false otherwise
    static func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        fatalError("Contract only - implement in UITestHelpers.swift")
    }

    /// Wait for an element to become hittable (visible and interactable)
    /// - Parameters:
    ///   - element: The XCUIElement to wait for
    ///   - timeout: Maximum time to wait (default: 5 seconds)
    /// - Returns: true if element is hittable within timeout, false otherwise
    static func waitForHittable(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        fatalError("Contract only - implement in UITestHelpers.swift")
    }

    /// Wait for an element to disappear
    /// - Parameters:
    ///   - element: The XCUIElement to wait for disappearance
    ///   - timeout: Maximum time to wait (default: 5 seconds)
    /// - Returns: true if element disappears within timeout, false otherwise
    static func waitForDisappearance(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        fatalError("Contract only - implement in UITestHelpers.swift")
    }

    // MARK: - Element Interaction

    /// Safely tap a button, waiting for it to be hittable first
    /// - Parameters:
    ///   - button: The button element to tap
    ///   - timeout: Maximum time to wait for button (default: 5 seconds)
    /// - Throws: XCTestError if button is not hittable within timeout
    static func tapButton(_ button: XCUIElement, timeout: TimeInterval = 5) throws {
        fatalError("Contract only - implement in UITestHelpers.swift")
    }

    /// Type text into a text field, clearing existing content first
    /// - Parameters:
    ///   - text: The text to type
    ///   - element: The text field element
    ///   - clearFirst: Whether to clear existing content (default: true)
    static func typeText(_ text: String, in element: XCUIElement, clearFirst: Bool = true) {
        fatalError("Contract only - implement in UITestHelpers.swift")
    }

    /// Scroll to an element within a scroll view
    /// - Parameters:
    ///   - element: The element to scroll to
    ///   - scrollView: The containing scroll view
    ///   - maxScrolls: Maximum number of scroll attempts (default: 10)
    /// - Returns: true if element is found and scrolled to, false otherwise
    static func scrollToElement(_ element: XCUIElement, in scrollView: XCUIElement, maxScrolls: Int = 10) -> Bool {
        fatalError("Contract only - implement in UITestHelpers.swift")
    }

    // MARK: - Assertions

    /// Verify that text exists somewhere in the app
    /// - Parameters:
    ///   - text: The text to find
    ///   - app: The XCUIApplication to search in
    ///   - timeout: Maximum time to wait (default: 5 seconds)
    /// - Returns: true if text is found, false otherwise
    static func verifyTextExists(_ text: String, in app: XCUIApplication, timeout: TimeInterval = 5) -> Bool {
        fatalError("Contract only - implement in UITestHelpers.swift")
    }

    /// Verify accessibility label exists on an element
    /// - Parameters:
    ///   - label: The accessibility label to verify
    ///   - element: The element to check
    /// - Returns: true if label matches, false otherwise
    static func verifyAccessibilityLabel(_ label: String, on element: XCUIElement) -> Bool {
        fatalError("Contract only - implement in UITestHelpers.swift")
    }

    // MARK: - Screenshot Capture

    /// Capture a screenshot and optionally add as test attachment
    /// - Parameters:
    ///   - name: Name for the screenshot
    ///   - testCase: The XCTestCase to attach to (optional)
    /// - Returns: The captured screenshot
    @discardableResult
    static func captureScreenshot(named name: String, attachTo testCase: XCTestCase? = nil) -> XCUIScreenshot {
        fatalError("Contract only - implement in UITestHelpers.swift")
    }

    /// Capture screenshot and save to file
    /// - Parameters:
    ///   - name: Name for the screenshot file
    ///   - directory: Directory to save to (default: test-screenshots/)
    /// - Returns: URL of saved screenshot
    static func saveScreenshot(named name: String, to directory: URL? = nil) -> URL {
        fatalError("Contract only - implement in UITestHelpers.swift")
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
        fatalError("Contract only - implement in UITestHelpers.swift")
    }

    /// Terminate and relaunch app with new arguments
    /// - Parameters:
    ///   - app: The XCUIApplication to relaunch
    ///   - arguments: New launch arguments
    static func relaunchApp(_ app: XCUIApplication, arguments: [String] = []) {
        fatalError("Contract only - implement in UITestHelpers.swift")
    }
}

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

    var errorDescription: String? {
        switch self {
        case .elementNotFound(let id, let timeout):
            return "Element '\(id)' not found within \(timeout) seconds"
        case .elementNotHittable(let id):
            return "Element '\(id)' is not hittable"
        case .textNotFound(let text):
            return "Text '\(text)' not found in app"
        case .screenshotFailed(let reason):
            return "Screenshot capture failed: \(reason)"
        }
    }
}

// MARK: - XCUIElement Extension Contract

extension XCUIElement {
    /// Wait for existence with default timeout
    /// - Parameter timeout: Timeout in seconds (default: 5)
    /// - Returns: true if element exists within timeout
    func waitForExistenceWithDefault(timeout: TimeInterval = 5) -> Bool {
        return waitForExistence(timeout: timeout)
    }

    /// Safely tap element, waiting for it to be hittable first
    /// - Parameter timeout: Timeout in seconds (default: 5)
    /// - Throws: UITestError.elementNotHittable if not hittable
    func safeTap(timeout: TimeInterval = 5) throws {
        fatalError("Contract only - implement in XCUIElement+SafeTap.swift")
    }
}

// MARK: - XCTestCase Extension Contract

extension XCTestCase {
    /// Capture screenshot on test failure in tearDown
    /// Call this at the start of tearDown() to capture failure states
    func captureScreenshotOnFailure() {
        fatalError("Contract only - implement in XCTestCase+Screenshot.swift")
    }

    /// Add screenshot attachment to test
    /// - Parameter screenshot: The screenshot to attach
    func attachScreenshot(_ screenshot: XCUIScreenshot, named name: String) {
        fatalError("Contract only - implement in XCTestCase+Screenshot.swift")
    }
}
