// UITestBase.swift
// macOS Local Speech-to-Text Application
//
// Base class for all UI tests providing common setup, teardown, and utilities
// Part of the XCUITest expansion (Issue #11)

import XCTest

/// Base class for UI tests providing common setup, teardown, and helper methods
///
/// Usage:
/// ```swift
/// final class MyTests: UITestBase {
///     func test_something() throws {
///         launchApp(arguments: [LaunchArguments.skipOnboarding])
///         // ... test code
///     }
/// }
/// ```
class UITestBase: XCTestCase {
    // MARK: - Properties

    /// The application instance for testing
    var app: XCUIApplication!

    /// Default timeout for element waits
    let defaultTimeout: TimeInterval = 5.0

    /// Extended timeout for longer operations
    let extendedTimeout: TimeInterval = 10.0

    /// Directory for screenshot storage
    private static let screenshotDirectory = "test-screenshots"

    // MARK: - Setup & Teardown

    override func setUpWithError() throws {
        try super.setUpWithError()

        // Stop immediately when a failure occurs
        continueAfterFailure = false

        // Initialize the application
        app = XCUIApplication()

        // Create screenshot directory if it doesn't exist
        createScreenshotDirectoryIfNeeded()
    }

    override func tearDownWithError() throws {
        // Capture screenshot on failure
        captureScreenshotOnFailure()

        // Terminate the app
        if app != nil {
            app.terminate()
            app = nil
        }

        try super.tearDownWithError()
    }

    // MARK: - App Launch Methods

    /// Launch the app with standard test configuration
    /// - Parameters:
    ///   - arguments: Additional launch arguments
    ///   - environment: Environment variables to set
    func launchApp(
        arguments: [String] = [],
        environment: [String: String] = [:]
    ) {
        // Always include --uitesting
        var allArguments = [LaunchArguments.uitesting]
        allArguments.append(contentsOf: arguments)

        app.launchArguments = allArguments
        app.launchEnvironment = environment
        app.launch()
    }

    /// Launch the app with onboarding skipped (most common case)
    /// - Parameters:
    ///   - arguments: Additional launch arguments
    func launchAppSkippingOnboarding(arguments: [String] = []) {
        var allArguments = [
            LaunchArguments.skipOnboarding,
            LaunchArguments.skipPermissionChecks
        ]
        allArguments.append(contentsOf: arguments)
        launchApp(arguments: allArguments)
    }

    /// Launch the app with fresh onboarding state
    /// - Parameters:
    ///   - arguments: Additional launch arguments
    func launchAppWithFreshOnboarding(arguments: [String] = []) {
        var allArguments = [
            LaunchArguments.resetOnboarding,
            LaunchArguments.skipPermissionChecks
        ]
        allArguments.append(contentsOf: arguments)
        launchApp(arguments: allArguments)
    }

    /// Launch the app and trigger recording modal immediately
    /// - Parameters:
    ///   - arguments: Additional launch arguments
    func launchAppWithRecordingModal(arguments: [String] = []) {
        var allArguments = [
            LaunchArguments.skipOnboarding,
            LaunchArguments.skipPermissionChecks,
            LaunchArguments.triggerRecording
        ]
        allArguments.append(contentsOf: arguments)
        launchApp(arguments: allArguments)
    }

    /// Relaunch the app with new arguments (for persistence tests)
    /// - Parameters:
    ///   - arguments: New launch arguments
    func relaunchApp(arguments: [String] = []) {
        app.terminate()
        launchApp(arguments: arguments)
    }

    // MARK: - Screenshot Capture

    /// Capture screenshot on test failure
    private func captureScreenshotOnFailure() {
        guard let testRun = testRun, testRun.failureCount > 0 else { return }

        let screenshot = XCUIScreen.main.screenshot()

        // Add as XCTest attachment for xcresult bundle
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Failure-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)

        // Also save to file for easy access
        saveScreenshotToFile(screenshot, name: "Failure-\(name)")
    }

    /// Capture and attach a screenshot during test execution
    /// - Parameter name: Name for the screenshot
    func captureScreenshot(named name: String) {
        let screenshot = XCUIScreen.main.screenshot()

        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        saveScreenshotToFile(screenshot, name: name)
    }

    /// Save screenshot to file
    private func saveScreenshotToFile(_ screenshot: XCUIScreenshot, name: String) {
        let sanitizedName = name
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")

        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")

        let filename = "\(sanitizedName)_\(timestamp).png"
        let fileURL = getScreenshotDirectoryURL().appendingPathComponent(filename)

        do {
            try screenshot.pngRepresentation.write(to: fileURL)
        } catch {
            // Non-fatal - just log
            print("Failed to save screenshot: \(error)")
        }
    }

    /// Create screenshot directory if needed
    private func createScreenshotDirectoryIfNeeded() {
        let directoryURL = getScreenshotDirectoryURL()

        if !FileManager.default.fileExists(atPath: directoryURL.path) {
            do {
                try FileManager.default.createDirectory(
                    at: directoryURL,
                    withIntermediateDirectories: true
                )
            } catch {
                print("Failed to create screenshot directory: \(error)")
            }
        }
    }

    /// Get screenshot directory URL
    private func getScreenshotDirectoryURL() -> URL {
        let projectRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()  // Base
            .deletingLastPathComponent()  // UITests
            .deletingLastPathComponent()  // workspace

        return projectRoot.appendingPathComponent(Self.screenshotDirectory)
    }

    // MARK: - Permission Dialog Handling

    /// Set up handlers for system permission dialogs
    func setupPermissionDialogHandlers() {
        // Handle microphone permission dialog
        addUIInterruptionMonitor(forInterruptionType: .alert) { alert in
            let okButton = alert.buttons["OK"]
            let allowButton = alert.buttons["Allow"]

            if okButton.exists {
                okButton.tap()
                return true
            } else if allowButton.exists {
                allowButton.tap()
                return true
            }
            return false
        }
    }
}

// MARK: - Convenience Extensions

extension UITestBase {
    /// Wait for an element to exist
    /// - Parameters:
    ///   - element: The element to wait for
    ///   - timeout: Timeout in seconds
    /// - Returns: true if element exists within timeout
    @discardableResult
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval? = nil) -> Bool {
        element.waitForExistence(timeout: timeout ?? defaultTimeout)
    }

    /// Wait for an element to disappear
    /// - Parameters:
    ///   - element: The element to wait for disappearance
    ///   - timeout: Timeout in seconds
    /// - Returns: true if element disappears within timeout
    @discardableResult
    func waitForDisappearance(_ element: XCUIElement, timeout: TimeInterval? = nil) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout ?? defaultTimeout)
        return result == .completed
    }

    /// Assert that an element exists with a descriptive message
    /// - Parameters:
    ///   - element: The element to check
    ///   - message: Custom failure message
    func assertExists(_ element: XCUIElement, message: String? = nil) {
        let exists = waitForElement(element)
        XCTAssertTrue(
            exists,
            message ?? "Expected element '\(element.identifier)' to exist"
        )
    }

    /// Assert that an element does not exist
    /// - Parameters:
    ///   - element: The element to check
    ///   - message: Custom failure message
    func assertNotExists(_ element: XCUIElement, message: String? = nil) {
        XCTAssertFalse(
            element.exists,
            message ?? "Expected element '\(element.identifier)' to not exist"
        )
    }
}
