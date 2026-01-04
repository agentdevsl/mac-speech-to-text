// MainWindow.swift
// macOS Local Speech-to-Text Application
//
// Phase 2: Unified Main View
// NSWindow wrapper for MainView with standard macOS window behavior

import AppKit
import SwiftUI

// MARK: - MainWindow

/// NSWindow wrapper that hosts the MainView
/// Provides standard macOS window behavior with title bar and traffic lights
@MainActor
final class MainWindow: NSObject, NSWindowDelegate {
    // MARK: - Properties

    /// The underlying NSWindow
    private var window: NSWindow?

    /// The ViewModel shared between window and view
    private let viewModel: MainViewModel

    /// Dependencies for sections
    private let settingsService: SettingsService
    private let permissionService: PermissionService

    /// Window dimensions
    private static let windowWidth: CGFloat = 600
    private static let windowHeight: CGFloat = 500

    /// Window title
    private static let windowTitle = "Speech to Text"

    // MARK: - Initialization

    init(
        viewModel: MainViewModel = MainViewModel(),
        settingsService: SettingsService = SettingsService(),
        permissionService: PermissionService = PermissionService()
    ) {
        self.viewModel = viewModel
        self.settingsService = settingsService
        self.permissionService = permissionService
        super.init()
    }

    deinit {
        // Window cleanup is handled by close()
    }

    // MARK: - Public Methods

    /// Show the main window
    func show() {
        guard window == nil else {
            // Window already exists, just bring to front
            window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Create the SwiftUI view with pre-created ViewModel and dependencies
        let mainView = MainView(
            viewModel: viewModel,
            settingsService: settingsService,
            permissionService: permissionService
        )

        // Create the window with standard macOS chrome
        let newWindow = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: Self.windowWidth,
                height: Self.windowHeight
            ),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        // Configure window
        configureWindow(newWindow)

        // Set content view
        newWindow.contentView = NSHostingView(rootView: mainView)

        // Center and show window
        newWindow.center()
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        window = newWindow
    }

    /// Hide the main window
    func hide() {
        window?.orderOut(nil)
    }

    /// Close and release the window
    func close() {
        window?.close()
        window = nil
    }

    /// Toggle window visibility
    func toggle() {
        if let existingWindow = window, existingWindow.isVisible {
            hide()
        } else {
            show()
        }
    }

    /// Check if window is currently visible
    var isVisible: Bool {
        window?.isVisible ?? false
    }

    /// Navigate to a specific section
    func navigateTo(_ section: SidebarSection) {
        viewModel.navigateTo(section)
        show()
    }

    // MARK: - Private Methods

    /// Configure window appearance and behavior
    private func configureWindow(_ window: NSWindow) {
        // Set delegate to receive window events
        window.delegate = self

        // Window title
        window.title = Self.windowTitle
        window.identifier = NSUserInterfaceItemIdentifier("mainWindow")

        // Standard window appearance
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible

        // Don't restore position on relaunch
        window.isRestorable = false

        // Set minimum size
        window.minSize = NSSize(width: Self.windowWidth, height: Self.windowHeight)

        // Standard window level
        window.level = .normal

        // Close button behavior
        window.standardWindowButton(.closeButton)?.isEnabled = true
        window.standardWindowButton(.miniaturizeButton)?.isEnabled = true
        window.standardWindowButton(.zoomButton)?.isEnabled = false

        // Animation behavior
        window.animationBehavior = .documentWindow
    }

    // MARK: - NSWindowDelegate

    /// Called when window is about to close - clears reference to prevent stale state
    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}

// MARK: - MainWindowController

/// Controller for managing MainWindow lifecycle
/// Use this to integrate with AppDelegate or other window management
@MainActor
final class MainWindowController {
    // MARK: - Singleton

    static let shared = MainWindowController()

    // MARK: - Properties

    private var mainWindow: MainWindow?

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Show the main window
    func showWindow() {
        if mainWindow == nil {
            mainWindow = MainWindow()
        }
        mainWindow?.show()
    }

    /// Hide the main window
    func hideWindow() {
        mainWindow?.hide()
    }

    /// Close and release the main window
    func closeWindow() {
        mainWindow?.close()
        mainWindow = nil
    }

    /// Toggle main window visibility
    func toggleWindow() {
        if mainWindow == nil {
            mainWindow = MainWindow()
        }
        mainWindow?.toggle()
    }

    /// Check if window is visible
    var isWindowVisible: Bool {
        mainWindow?.isVisible ?? false
    }

    /// Navigate to a specific section and show window
    func showSection(_ section: SidebarSection) {
        if mainWindow == nil {
            mainWindow = MainWindow()
        }
        mainWindow?.navigateTo(section)
    }

    /// Show window with Settings (General) section pre-selected
    /// Called when user presses Cmd+, or clicks Settings
    func showSettings() {
        showSection(.general)
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    /// Posted when the main window should be shown
    static let showMainWindow = Notification.Name("showMainWindow")

    /// Posted when the main window should navigate to a specific section
    static let navigateToSection = Notification.Name("navigateToSection")
}
