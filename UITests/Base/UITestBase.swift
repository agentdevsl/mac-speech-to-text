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

    /// Bundle identifier of the app under test
    private static let appBundleIdentifier = "com.speechtotext.app"

    override func setUpWithError() throws {
        try super.setUpWithError()

        // Stop immediately when a failure occurs
        continueAfterFailure = false

        // Initialize the application with explicit bundle identifier
        // This is required when the app is built externally (not through the same Xcode project)
        app = XCUIApplication(bundleIdentifier: Self.appBundleIdentifier)

        // Create screenshot directory if it doesn't exist
        createScreenshotDirectoryIfNeeded()
    }

    override func tearDownWithError() throws {
        // Capture screenshot on failure
        captureFailureScreenshot()

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

    /// Launch the app with welcome skipped (most common case)
    /// - Parameters:
    ///   - arguments: Additional launch arguments
    func launchAppSkippingWelcome(arguments: [String] = []) {
        var allArguments = [
            LaunchArguments.skipWelcome,
            LaunchArguments.skipPermissionChecks
        ]
        allArguments.append(contentsOf: arguments)
        launchApp(arguments: allArguments)
    }

    /// Launch the app with onboarding skipped (alias for launchAppSkippingWelcome)
    /// - Parameters:
    ///   - arguments: Additional launch arguments
    func launchAppSkippingOnboarding(arguments: [String] = []) {
        launchAppSkippingWelcome(arguments: arguments)
    }

    /// Launch the app with fresh welcome state
    /// Shows the single-screen WelcomeView
    /// - Parameters:
    ///   - arguments: Additional launch arguments
    func launchAppWithFreshWelcome(arguments: [String] = []) {
        var allArguments = [
            LaunchArguments.resetWelcome,
            LaunchArguments.skipPermissionChecks
        ]
        allArguments.append(contentsOf: arguments)
        launchApp(arguments: allArguments)
    }

    /// Launch the app with fresh onboarding state
    /// Alias for launchAppWithFreshWelcome for clarity
    /// - Parameters:
    ///   - arguments: Additional launch arguments
    func launchAppWithFreshOnboarding(arguments: [String] = []) {
        launchAppWithFreshWelcome(arguments: arguments)
    }

    /// Launch the app and trigger recording modal immediately
    /// - Parameters:
    ///   - arguments: Additional launch arguments
    func launchAppWithRecordingModal(arguments: [String] = []) {
        var allArguments = [
            LaunchArguments.skipWelcome,
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
    private func captureFailureScreenshot() {
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

    /// Save screenshot to file and append to manifest
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
            // Append to manifest for design evaluation
            appendToManifest(
                path: fileURL.path,
                name: sanitizedName,
                timestamp: timestamp
            )
        } catch {
            // Non-fatal - just log
            print("Failed to save screenshot: \(error)")
        }
    }

    /// Append screenshot metadata to manifest for design evaluation
    private func appendToManifest(path: String, name: String, timestamp: String) {
        let manifestURL = getScreenshotDirectoryURL().appendingPathComponent("manifest.json")

        // Read existing manifest or create new
        var manifest: [[String: String]] = []

        if FileManager.default.fileExists(atPath: manifestURL.path) {
            do {
                let data = try Data(contentsOf: manifestURL)
                if let existing = try JSONSerialization.jsonObject(with: data) as? [[String: String]] {
                    manifest = existing
                }
            } catch {
                print("Failed to read manifest: \(error)")
            }
        }

        // Add new entry
        let entry: [String: String] = [
            "path": path,
            "name": name,
            "testClass": String(describing: type(of: self)),
            "testMethod": self.name,
            "timestamp": timestamp
        ]
        manifest.append(entry)

        // Write updated manifest
        do {
            let data = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted])
            try data.write(to: manifestURL)
        } catch {
            print("Failed to write manifest: \(error)")
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
        addUIInterruptionMonitor(withDescription: "System Alert") { alert in
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

// MARK: - Welcome Flow Helpers

extension UITestBase {
    /// Wait for the welcome view to appear
    /// - Parameter timeout: Timeout in seconds
    /// - Returns: true if welcome view appears within timeout
    @discardableResult
    func waitForWelcomeView(timeout: TimeInterval? = nil) -> Bool {
        let welcomeView = app.otherElements["welcomeView"]
        return welcomeView.waitForExistence(timeout: timeout ?? extendedTimeout)
    }

    /// Dismiss the welcome screen by tapping "Get Started"
    /// - Returns: true if dismissal succeeded
    @discardableResult
    func dismissWelcome() -> Bool {
        let getStartedButton = app.buttons["getStartedButton"]
        if getStartedButton.waitForExistence(timeout: defaultTimeout) && getStartedButton.isEnabled {
            getStartedButton.tap()
            return true
        }
        return false
    }

    /// Get the welcome view element
    func getWelcomeView() -> XCUIElement? {
        let welcomeView = app.otherElements["welcomeView"]
        if welcomeView.waitForExistence(timeout: extendedTimeout) {
            return welcomeView
        }
        return nil
    }

    /// Navigate through onboarding steps by clicking Next/Continue buttons
    /// - Parameters:
    ///   - stepsToAdvance: Number of steps to advance (default: navigate to completion)
    ///   - checkForGetStarted: Whether to stop and click "Get Started" button
    /// - Returns: true if navigation succeeded
    /// - Note: Deprecated - use dismissWelcome() for new single-screen welcome flow
    @discardableResult
    func navigateOnboardingSteps(count stepsToAdvance: Int = 5, clickGetStarted: Bool = true) -> Bool {
        // For new welcome flow, just dismiss directly
        if waitForWelcomeView(timeout: 2) {
            return dismissWelcome()
        }

        // Legacy multi-step onboarding flow
        for step in 0..<stepsToAdvance {
            // Check if we've reached the completion step
            let getStartedButton = app.buttons["Get Started"]
            if getStartedButton.waitForExistence(timeout: 1) && getStartedButton.isEnabled {
                if clickGetStarted {
                    getStartedButton.tap()
                }
                return true
            }

            // Try accessibility identifier first (works for all steps)
            let nextButtonById = app.buttons.matching(
                NSPredicate(format: "identifier == 'nextButton'")
            ).firstMatch

            if nextButtonById.waitForExistence(timeout: 2) && nextButtonById.isEnabled {
                nextButtonById.tap()
            } else if step == 0 {
                // Step 0 uses "Continue" button label
                let continueButton = app.buttons["Continue"]
                if continueButton.waitForExistence(timeout: 1) && continueButton.isEnabled {
                    continueButton.tap()
                }
            } else {
                // Steps 1+ use "Next" button label
                let nextButton = app.buttons["Next"]
                if nextButton.waitForExistence(timeout: 1) && nextButton.isEnabled {
                    nextButton.tap()
                }
            }

            // Wait for UI to update after navigation
            _ = app.windows.firstMatch.waitForExistence(timeout: 1)
        }
        return true
    }

    /// Get the onboarding window (checks both identifier and title)
    /// - Note: Deprecated - use getWelcomeView() for new single-screen welcome flow
    func getOnboardingWindow() -> XCUIElement? {
        // Try new welcome view first
        let welcomeView = app.otherElements["welcomeView"]
        if welcomeView.waitForExistence(timeout: 3) {
            return welcomeView
        }

        // Legacy onboarding window
        let windowById = app.windows.matching(
            NSPredicate(format: "identifier == 'onboardingWindow'")
        ).firstMatch
        let windowByTitle = app.windows["Welcome to Speech-to-Text"]

        if windowById.waitForExistence(timeout: extendedTimeout) {
            return windowById
        } else if windowByTitle.waitForExistence(timeout: 3) {
            return windowByTitle
        }
        return nil
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
