// FloatingWidgetWindow.swift
// macOS Local Speech-to-Text Application
//
// Phase 2.1: NSWindow wrapper for FloatingWidget
// Creates a floating, transparent window positioned at the bottom center of the screen
// - Window level: .floating (always on top)
// - Transparent background with no chrome
// - Visible on all spaces (Mission Control)

import AppKit
import SwiftUI

// MARK: - KeyableWindow

/// Custom NSWindow subclass that can become key even when borderless
/// Required for borderless windows to receive focus and keyboard input
private final class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// NSWindow wrapper that hosts the FloatingWidget
/// Provides floating window behavior with transparent background
@MainActor
final class FloatingWidgetWindow {
    // MARK: - Properties

    /// The underlying NSWindow
    private var window: NSWindow?

    /// The ViewModel shared between window and view
    private let viewModel: FloatingWidgetViewModel

    /// Offset from bottom of screen
    private let bottomOffset: CGFloat = 100

    // MARK: - Initialization

    init(viewModel: FloatingWidgetViewModel = FloatingWidgetViewModel()) {
        self.viewModel = viewModel
    }

    deinit {
        // Window cleanup is handled by close()
    }

    // MARK: - Public Methods

    /// Show the floating widget window
    func show() {
        guard window == nil else {
            // Window already exists, just bring to front
            window?.makeKeyAndOrderFront(nil)
            return
        }

        // Create the SwiftUI view with pre-created ViewModel
        let floatingWidget = FloatingWidget(viewModel: viewModel)

        // Create the window using KeyableWindow for focus support
        let newWindow = KeyableWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 60),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // Configure window appearance
        configureWindow(newWindow)

        // Set content view
        newWindow.contentView = NSHostingView(rootView: floatingWidget)

        // Position window
        positionWindow(newWindow)

        // Show window
        newWindow.makeKeyAndOrderFront(nil)

        window = newWindow
    }

    /// Hide the floating widget window
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

    // MARK: - Private Methods

    /// Configure window appearance and behavior
    private func configureWindow(_ window: NSWindow) {
        // Transparent background
        window.isOpaque = false
        window.backgroundColor = .clear

        // Floating level - always on top
        window.level = .floating

        // Remove title bar and chrome
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden

        // Visible on all spaces (Mission Control)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        // Don't show in window menu or expose
        window.isExcludedFromWindowsMenu = true

        // Enable live resize for smooth animations
        window.animationBehavior = .default

        // Allow dragging by background (the whole widget is draggable)
        window.isMovableByWindowBackground = true
    }

    /// Position window at bottom center of main screen
    private func positionWindow(_ window: NSWindow) {
        guard let screen = NSScreen.main else { return }

        let screenFrame = screen.visibleFrame
        let windowSize = window.frame.size

        // Calculate centered position
        let xPosition = screenFrame.midX - (windowSize.width / 2)
        let yPosition = screenFrame.minY + bottomOffset

        window.setFrameOrigin(NSPoint(x: xPosition, y: yPosition))
    }

    /// Reposition window (e.g., after screen changes)
    func repositionToBottomCenter() {
        guard let window else { return }
        positionWindow(window)
    }
}

// MARK: - FloatingWidgetWindowController

/// Controller for managing FloatingWidgetWindow lifecycle
/// Use this to integrate with AppDelegate or other window management
@MainActor
final class FloatingWidgetWindowController {
    // MARK: - Singleton

    static let shared = FloatingWidgetWindowController()

    // MARK: - Properties

    private var floatingWindow: FloatingWidgetWindow?
    private var screenChangeObserver: NSObjectProtocol?
    // nonisolated copy for deinit access (deinit cannot access MainActor-isolated state)
    private nonisolated(unsafe) var deinitScreenChangeObserver: NSObjectProtocol?

    // MARK: - Initialization

    private init() {
        setupScreenChangeObserver()
    }

    deinit {
        if let observer = deinitScreenChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public Methods

    /// Show the floating widget
    func showWidget() {
        if floatingWindow == nil {
            floatingWindow = FloatingWidgetWindow()
        }
        floatingWindow?.show()
    }

    /// Hide the floating widget
    func hideWidget() {
        floatingWindow?.hide()
    }

    /// Close and release the floating widget
    func closeWidget() {
        floatingWindow?.close()
        floatingWindow = nil
    }

    /// Toggle floating widget visibility
    func toggleWidget() {
        if floatingWindow == nil {
            floatingWindow = FloatingWidgetWindow()
        }
        floatingWindow?.toggle()
    }

    /// Check if widget is visible
    var isWidgetVisible: Bool {
        floatingWindow?.isVisible ?? false
    }

    // MARK: - Private Methods

    /// Setup observer for screen changes to reposition widget
    private func setupScreenChangeObserver() {
        let observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.floatingWindow?.repositionToBottomCenter()
            }
        }
        screenChangeObserver = observer
        deinitScreenChangeObserver = observer
    }
}
