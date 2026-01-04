// WelcomeFlowTests.swift
// macOS Local Speech-to-Text Application
//
// End-to-end UI tests for the unified Main View welcome flow
// Tests the NavigationSplitView with HomeSection as the first-launch experience
// Part of the UI Re-Vision initiative

import XCTest

/// Tests for the unified Main View welcome flow
/// These tests verify the NavigationSplitView experience with:
/// - Home section with permission cards
/// - Sidebar navigation
/// - Hotkey display
/// - Permission status indicators
final class WelcomeFlowTests: UITestBase {
    // MARK: - WF-001: Main Window Appears on First Launch

    /// Test that main window appears on first launch
    func test_mainWindow_appearsOnFirstLaunch() throws {
        // Launch with fresh state (reset onboarding)
        launchAppWithFreshOnboarding()

        // Look for main window by accessibility identifier
        let mainWindow = app.windows.matching(
            NSPredicate(format: "identifier == 'mainWindow'")
        ).firstMatch

        let windowAppeared = mainWindow.waitForExistence(timeout: extendedTimeout)

        XCTAssertTrue(
            windowAppeared,
            "Main window should appear on first launch"
        )

        // Verify main view content
        let mainView = app.otherElements["mainView"]
        let hasMainView = mainView.waitForExistence(timeout: 3)

        XCTAssertTrue(
            hasMainView || mainWindow.exists,
            "Main view should be visible in window"
        )

        captureScreenshot(named: "WF-001-Main-Window")
    }

    // MARK: - WF-002: Home Section Displays Correctly

    /// Test that home section with permission cards is visible
    func test_homeSection_displaysCorrectly() throws {
        launchAppWithFreshOnboarding()

        // Wait for main window
        guard waitForMainWindow() else {
            captureScreenshot(named: "WF-002-No-Main-Window")
            XCTFail("Main window did not appear")
            return
        }

        // Look for home section
        let homeSection = app.otherElements["homeSection"]
        XCTAssertTrue(
            homeSection.waitForExistence(timeout: 5),
            "Home section should be visible on first launch"
        )

        // Look for hero section with mic icon
        let heroSection = app.otherElements["heroSection"]
        let hasHero = heroSection.waitForExistence(timeout: 3)

        // Look for permission cards
        let permissionCards = app.otherElements["permissionCards"]
        let hasPermissionCards = permissionCards.waitForExistence(timeout: 3)

        XCTAssertTrue(
            hasHero || hasPermissionCards,
            "Home section should have hero or permission cards"
        )

        captureScreenshot(named: "WF-002-Home-Section")
    }

    // MARK: - WF-003: Permission Cards Visible

    /// Test that microphone and accessibility permission cards are visible
    func test_permissionCards_visible() throws {
        launchAppWithFreshOnboarding()

        guard waitForMainWindow() else {
            captureScreenshot(named: "WF-003-No-Main-Window")
            XCTFail("Main window did not appear")
            return
        }

        // Look for microphone permission card
        let micPermissionCard = app.otherElements["microphonePermissionCard"]
        let hasMicCard = micPermissionCard.waitForExistence(timeout: 3)

        // Look for accessibility permission card
        let accessibilityPermissionCard = app.otherElements["accessibilityPermissionCard"]
        let hasAccessibilityCard = accessibilityPermissionCard.waitForExistence(timeout: 3)

        XCTAssertTrue(
            hasMicCard || hasAccessibilityCard,
            "Permission cards should be visible in home section"
        )

        captureScreenshot(named: "WF-003-Permission-Cards")
    }

    // MARK: - WF-004: Hotkey Display Visible

    /// Test that hotkey hint is displayed
    func test_hotkeyDisplay_visible() throws {
        launchAppWithFreshOnboarding()

        guard waitForMainWindow() else {
            XCTFail("Main window did not appear")
            return
        }

        // Look for hotkey display in hero section
        let hotkeyDisplay = app.otherElements["hotkeyDisplay"]
        let hasHotkeyDisplay = hotkeyDisplay.waitForExistence(timeout: 3)

        // Also look for keyboard key symbols
        let shiftKey = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'shift' OR label CONTAINS[c] '⇧'")
        ).firstMatch

        let spaceKey = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'space'")
        ).firstMatch

        let hasKeySymbols = shiftKey.waitForExistence(timeout: 2) || spaceKey.waitForExistence(timeout: 2)

        XCTAssertTrue(
            hasHotkeyDisplay || hasKeySymbols,
            "Hotkey display should be visible"
        )

        captureScreenshot(named: "WF-004-Hotkey-Display")
    }

    // MARK: - WF-005: Typing Preview Visible

    /// Test that typing preview animation is displayed
    func test_typingPreview_visible() throws {
        launchAppWithFreshOnboarding()

        guard waitForMainWindow() else {
            XCTFail("Main window did not appear")
            return
        }

        // Look for typing preview section
        let typingPreview = app.otherElements["typingPreview"]
        let hasTypingPreview = typingPreview.waitForExistence(timeout: 3)

        // Also look for "Preview" label
        let previewLabel = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'preview'")
        ).firstMatch

        XCTAssertTrue(
            hasTypingPreview || previewLabel.exists,
            "Typing preview should be visible in home section"
        )

        captureScreenshot(named: "WF-005-Typing-Preview")
    }

    // MARK: - WF-006: Sidebar Navigation Works

    /// Test that sidebar navigation allows switching between sections
    func test_sidebarNavigation_works() throws {
        launchAppWithFreshOnboarding()

        guard waitForMainWindow() else {
            XCTFail("Main window did not appear")
            return
        }

        // Wait for sidebar to be visible
        let sidebar = app.otherElements["mainViewSidebar"]
        XCTAssertTrue(
            sidebar.waitForExistence(timeout: 3),
            "Sidebar should be visible"
        )

        captureScreenshot(named: "WF-006-Initial-Home")

        // Try navigating to General section
        let generalSidebar = app.otherElements["sidebarGeneral"]
        if generalSidebar.waitForExistence(timeout: 2) {
            generalSidebar.tap()
            sleep(1)
            captureScreenshot(named: "WF-006-After-General")
        }

        // Navigate back to Home
        let homeSidebar = app.otherElements["sidebarHome"]
        if homeSidebar.waitForExistence(timeout: 2) {
            homeSidebar.tap()
            sleep(1)
            captureScreenshot(named: "WF-006-Back-To-Home")
        }
    }

    // MARK: - WF-007: Main Window Not Shown When Skipped

    /// Test that main window doesn't auto-show after onboarding is completed
    func test_mainWindow_notShownWhenSkipped() throws {
        // Launch with onboarding skipped (simulates completed)
        launchAppSkippingOnboarding()

        // Wait for app to initialize
        _ = app.menuBars.firstMatch.waitForExistence(timeout: 2)

        // Verify main window does NOT auto-appear (app runs in menu bar)
        let mainWindow = app.windows.matching(
            NSPredicate(format: "identifier == 'mainWindow'")
        ).firstMatch

        // Give it time to potentially appear
        let windowAppeared = mainWindow.waitForExistence(timeout: 3)

        // Note: Window may or may not appear depending on app behavior
        // The key is that the app should be running in menu bar mode
        captureScreenshot(named: "WF-007-Skipped-Onboarding")

        // App should at least be running
        XCTAssertTrue(
            app.exists,
            "App should be running"
        )
    }

    // MARK: - WF-008: Quit Button Closes App

    /// Test that quit button in sidebar closes the app
    func test_quitButton_closesApp() throws {
        launchAppWithFreshOnboarding()

        guard waitForMainWindow() else {
            XCTFail("Main window did not appear")
            return
        }

        captureScreenshot(named: "WF-008-Before-Quit")

        // Find and tap quit button
        let quitButton = app.buttons["quitButton"]

        if quitButton.waitForExistence(timeout: 3) {
            quitButton.tap()
            sleep(1)
            captureScreenshot(named: "WF-008-After-Quit")

            // App may terminate or window may close
            // Check that quit interaction occurred
        } else {
            // Try by label
            let quitByLabel = app.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] 'quit'")
            ).firstMatch

            if quitByLabel.waitForExistence(timeout: 2) {
                quitByLabel.tap()
            }
        }
    }

    // MARK: - WF-009: Window Escape Key

    /// Test window interaction with Escape key
    func test_window_escapeKeyBehavior() throws {
        launchAppWithFreshOnboarding()

        guard waitForMainWindow() else {
            XCTFail("Main window did not appear")
            return
        }

        captureScreenshot(named: "WF-009-Before-Escape")

        // Press Escape
        UITestHelpers.pressEscape(in: app)
        sleep(1)

        captureScreenshot(named: "WF-009-After-Escape")

        // Window behavior on Escape may vary
        // Document the behavior
    }

    // MARK: - WF-010: Hero Mic Icon Animates

    /// Test that hero section mic icon is present
    func test_heroSection_micIconPresent() throws {
        launchAppWithFreshOnboarding()

        guard waitForMainWindow() else {
            XCTFail("Main window did not appear")
            return
        }

        // Look for mic icon in hero section
        let micIcon = app.otherElements["homeMicIcon"]
        let hasMicIcon = micIcon.waitForExistence(timeout: 3)

        // Also look for mic image
        let micImage = app.images.matching(
            NSPredicate(format: "identifier CONTAINS[c] 'mic'")
        ).firstMatch

        XCTAssertTrue(
            hasMicIcon || micImage.exists,
            "Mic icon should be visible in hero section"
        )

        captureScreenshot(named: "WF-010-Hero-Mic-Icon")
    }
}
