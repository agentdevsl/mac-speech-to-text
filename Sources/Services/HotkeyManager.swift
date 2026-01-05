import Foundation
import KeyboardShortcuts

@MainActor
@Observable
class HotkeyManager {
    // State tracking
    private var keyPressStartTime: Date?
    private var isProcessing: Bool = false

    // Callbacks
    var onRecordingStart: (() async -> Void)?
    var onRecordingStop: ((TimeInterval) async -> Void)?

    // Minimum hold duration
    private let minimumHoldDuration: TimeInterval = 0.1

    // Cooldown to prevent rapid re-triggers
    private var lastActionTime: Date = .distantPast
    private let cooldownInterval: TimeInterval = 0.3

    init() {
        setupHotkey()
    }

    private func setupHotkey() {
        KeyboardShortcuts.onKeyDown(for: .holdToRecord) { [weak self] in
            Task { @MainActor in
                await self?.handleKeyDown()
            }
        }

        KeyboardShortcuts.onKeyUp(for: .holdToRecord) { [weak self] in
            Task { @MainActor in
                await self?.handleKeyUp()
            }
        }
    }

    private func handleKeyDown() async {
        // Guard: already processing or in cooldown
        guard !isProcessing else {
            print("[DEBUG-HM] Ignoring keyDown - already processing")
            return
        }

        let now = Date()
        guard now.timeIntervalSince(lastActionTime) > cooldownInterval else {
            print("[DEBUG-HM] Ignoring keyDown - in cooldown")
            return
        }

        // Start recording
        isProcessing = true
        keyPressStartTime = now
        print("[DEBUG-HM] keyDown - starting recording")
        await onRecordingStart?()
    }

    private func handleKeyUp() async {
        guard isProcessing, let startTime = keyPressStartTime else {
            print("[DEBUG-HM] Ignoring keyUp - not processing")
            return
        }

        let duration = Date().timeIntervalSince(startTime)
        keyPressStartTime = nil

        print("[DEBUG-HM] keyUp - duration: \(duration)s")

        if duration >= minimumHoldDuration {
            await onRecordingStop?(duration)
        } else {
            print("[DEBUG-HM] Duration too short: \(duration)s < \(minimumHoldDuration)s")
        }

        lastActionTime = Date()
        isProcessing = false
    }

    /// Cancel any in-progress recording
    func cancel() {
        isProcessing = false
        keyPressStartTime = nil
    }
}
