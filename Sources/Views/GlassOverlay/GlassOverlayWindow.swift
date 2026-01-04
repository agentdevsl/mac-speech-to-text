// GlassOverlayWindow.swift
// macOS Local Speech-to-Text Application
//
// Glass Recording Overlay - NSWindow wrapper
// Creates a floating, transparent, click-through window for recording feedback
// - Borderless, transparent NSWindow
// - Float above all other windows (.floating level)
// - Centered horizontally, 100px from bottom of screen
// - Size: 300x80
// - Ignores mouse events (click-through)

import AppKit
import SwiftUI

// MARK: - ClickThroughWindow

/// Custom NSWindow subclass that ignores all mouse events (click-through)
private final class ClickThroughWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Ignore all mouse events - clicks pass through to windows below
    override func sendEvent(_ event: NSEvent) {
        // Only pass through mouse events; other events (like display updates) proceed normally
        switch event.type {
        case .leftMouseDown, .leftMouseUp, .leftMouseDragged,
             .rightMouseDown, .rightMouseUp, .rightMouseDragged,
             .otherMouseDown, .otherMouseUp, .otherMouseDragged,
             .scrollWheel, .mouseMoved, .mouseEntered, .mouseExited:
            // Ignore mouse events - let them pass through
            return
        default:
            super.sendEvent(event)
        }
    }
}

// MARK: - GlassOverlayWindow

/// NSWindow wrapper that hosts the GlassRecordingOverlay SwiftUI view
/// Provides floating window behavior with transparent, click-through background
@MainActor
final class GlassOverlayWindow {
    // MARK: - Constants

    /// Window size
    private static let windowWidth: CGFloat = 300
    private static let windowHeight: CGFloat = 80

    /// Offset from bottom of screen
    private static let bottomOffset: CGFloat = 100

    // MARK: - Properties

    /// The underlying NSWindow (reusable - show/hide, not recreate)
    private var window: ClickThroughWindow?

    /// The ViewModel shared between window and view
    private let viewModel: GlassOverlayViewModel

    /// Screen change observer
    private var screenChangeObserver: NSObjectProtocol?
    // nonisolated copy for deinit access
    private nonisolated(unsafe) var deinitScreenChangeObserver: NSObjectProtocol?

    // MARK: - Initialization

    init(viewModel: GlassOverlayViewModel = GlassOverlayViewModel()) {
        self.viewModel = viewModel
        setupScreenChangeObserver()
    }

    deinit {
        if let observer = deinitScreenChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public Methods

    /// Show the overlay window
    func show() {
        if let existingWindow = window {
            // Window already exists, just bring to front
            existingWindow.orderFront(nil)
            AppLogger.debug(AppLogger.viewModel, "GlassOverlayWindow: showing existing window")
            return
        }

        // Create window on first show
        let newWindow = createWindow()
        window = newWindow
        newWindow.orderFront(nil)
        AppLogger.info(AppLogger.viewModel, "GlassOverlayWindow: created and showing new window")
    }

    /// Hide the overlay window (keeps it in memory for reuse)
    func hide() {
        window?.orderOut(nil)
        AppLogger.debug(AppLogger.viewModel, "GlassOverlayWindow: hidden")
    }

    /// Close and release the window
    func close() {
        window?.close()
        window = nil
        AppLogger.debug(AppLogger.viewModel, "GlassOverlayWindow: closed and released")
    }

    /// Check if window is currently visible
    var isVisible: Bool {
        window?.isVisible ?? false
    }

    /// Access the ViewModel for state updates
    var overlayViewModel: GlassOverlayViewModel {
        viewModel
    }

    // MARK: - Private Methods

    /// Create the NSWindow with proper configuration
    private func createWindow() -> ClickThroughWindow {
        let window = ClickThroughWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: Self.windowWidth,
                height: Self.windowHeight
            ),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        configureWindow(window)
        positionWindow(window)

        // Create SwiftUI view with ViewModel
        // Note: GlassRecordingOverlay is the SwiftUI view that will be created separately
        // For now, create a placeholder that will be replaced with the actual view
        let contentView = GlassOverlayContentView(viewModel: viewModel)
        window.contentView = NSHostingView(rootView: contentView)

        return window
    }

    /// Configure window appearance and behavior
    private func configureWindow(_ window: NSWindow) {
        // Transparent background
        window.isOpaque = false
        window.backgroundColor = .clear

        // Floating level - above all other windows
        window.level = .floating

        // Remove title bar and chrome
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden

        // No shadow from window chrome (the SwiftUI view can add its own shadow)
        window.hasShadow = false

        // Visible on all spaces (Mission Control)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        // Don't show in window menu or expose
        window.isExcludedFromWindowsMenu = true

        // Ignore mouse events at window level (click-through)
        window.ignoresMouseEvents = true

        // Animation behavior
        window.animationBehavior = .none
    }

    /// Position window at bottom center of main screen
    private func positionWindow(_ window: NSWindow) {
        guard let screen = NSScreen.main else { return }

        let screenFrame = screen.visibleFrame

        // Calculate centered position
        let xPosition = screenFrame.midX - (Self.windowWidth / 2)
        let yPosition = screenFrame.minY + Self.bottomOffset

        window.setFrameOrigin(NSPoint(x: xPosition, y: yPosition))
    }

    /// Reposition window (e.g., after screen changes)
    func repositionToBottomCenter() {
        guard let window else { return }
        positionWindow(window)
    }

    /// Setup observer for screen changes to reposition overlay
    private func setupScreenChangeObserver() {
        let observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.repositionToBottomCenter()
            }
        }
        screenChangeObserver = observer
        deinitScreenChangeObserver = observer
    }
}

// MARK: - GlassOverlayWindowController

/// Controller for managing GlassOverlayWindow lifecycle
/// Use this to integrate with AppDelegate or other window management
@MainActor
final class GlassOverlayWindowController {
    // MARK: - Singleton

    static let shared = GlassOverlayWindowController()

    // MARK: - Properties

    private var overlayWindow: GlassOverlayWindow?

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Show the glass overlay in recording state
    func showRecording() {
        ensureWindow()
        overlayWindow?.overlayViewModel.showRecording()
        overlayWindow?.show()
    }

    /// Transition to transcribing state
    func showTranscribing() {
        overlayWindow?.overlayViewModel.showTranscribing()
    }

    /// Hide the glass overlay
    func hideOverlay() {
        overlayWindow?.overlayViewModel.hide()
        overlayWindow?.hide()
    }

    /// Update audio level for waveform visualization
    func updateAudioLevel(_ level: Float) {
        overlayWindow?.overlayViewModel.updateAudioLevel(level)
    }

    /// Close and release the overlay
    func closeOverlay() {
        overlayWindow?.close()
        overlayWindow = nil
    }

    /// Check if overlay is visible
    var isVisible: Bool {
        overlayWindow?.isVisible ?? false
    }

    /// Access the underlying ViewModel
    var viewModel: GlassOverlayViewModel? {
        overlayWindow?.overlayViewModel
    }

    // MARK: - Private Methods

    private func ensureWindow() {
        if overlayWindow == nil {
            overlayWindow = GlassOverlayWindow()
        }
    }
}

// MARK: - Placeholder Content View

/// Placeholder SwiftUI view for the glass overlay content
/// This will be replaced with GlassRecordingOverlay when that view is created
private struct GlassOverlayContentView: View {
    let viewModel: GlassOverlayViewModel

    var body: some View {
        // Placeholder content - will be replaced with actual GlassRecordingOverlay
        ZStack {
            // Glass background
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)

            // Content based on state
            Group {
                switch viewModel.state {
                case .hidden:
                    EmptyView()

                case .recording:
                    HStack(spacing: 12) {
                        // Recording indicator
                        Circle()
                            .fill(.red)
                            .frame(width: 12, height: 12)

                        Text("Recording...")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Spacer()

                        Text(viewModel.formattedDuration)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 20)

                case .transcribing:
                    HStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(0.8)

                        Text("Transcribing...")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Spacer()

                        Text(viewModel.formattedDuration)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .frame(width: 300, height: 80)
        .opacity(viewModel.state == .hidden ? 0 : 1)
    }
}

// MARK: - Preview

#Preview("Recording State") {
    let vm = GlassOverlayViewModel()
    vm.state = .recording
    vm.recordingDuration = 5
    return GlassOverlayContentView(viewModel: vm)
        .frame(width: 320, height: 100)
        .background(Color.gray.opacity(0.3))
}

#Preview("Transcribing State") {
    let vm = GlassOverlayViewModel()
    vm.state = .transcribing
    vm.recordingDuration = 12
    return GlassOverlayContentView(viewModel: vm)
        .frame(width: 320, height: 100)
        .background(Color.gray.opacity(0.3))
}
