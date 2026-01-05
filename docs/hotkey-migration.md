# Plan: Migrate to KeyboardShortcuts Library

**Date**: 2026-01-05
**Status**: Planning

## Overview

Migrate from custom Carbon hotkey implementation to [sindresorhus/KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) library to:

1. Fix Task interleaving / race conditions
2. Simplify hotkey handling code
3. Add user-customizable shortcut UI
4. Improve reliability

## Current Issues with Carbon Implementation

1. **Task Interleaving**: Multiple Carbon events queue up, spawning interleaving MainActor Tasks
2. **Complex State Management**: Manual `HoldState` enum with race-prone async handling
3. **No UI**: Users cannot customize shortcuts without editing code
4. **Manual Carbon API**: Low-level, error-prone, deprecated but necessary

## KeyboardShortcuts Benefits

| Feature | Current (Carbon) | KeyboardShortcuts |
|---------|-----------------|-------------------|
| Event handling | Manual Task dispatch | Built-in callbacks |
| User customization | None | SwiftUI Recorder component |
| Conflict detection | Manual | Built-in system conflict warnings |
| Key up/down | Manual state machine | `onKeyDown()` / `onKeyUp()` |
| Persistence | Manual UserDefaults | Automatic UserDefaults |

## VoiceInk Reference Implementation

VoiceInk (similar app) uses KeyboardShortcuts with these patterns:

### Race Condition Prevention

```swift
// State guard - prevent duplicate processing
guard isKeyPressed != currentKeyState else { return }

// Cooldown interval
private let briefPressThreshold: TimeInterval = 1.7
private let cooldownInterval: TimeInterval = 0.5

// Block during transcription
var canProcessHotkeyAction: Bool {
    !isTranscribing && !isEnhancing
}
```

### Duration Tracking

```swift
KeyboardShortcuts.onKeyDown(for: .toggleMiniRecorder) { [weak self] in
    self?.shortcutKeyPressStartTime = Date()
    self?.handleRecordingStart()
}

KeyboardShortcuts.onKeyUp(for: .toggleMiniRecorder) { [weak self] in
    guard let startTime = self?.shortcutKeyPressStartTime else { return }
    let pressDuration = Date().timeIntervalSince(startTime)
    self?.handleRecordingStop(duration: pressDuration)
}
```

## Migration Plan

### Phase 1: Add KeyboardShortcuts Dependency

File: `Package.swift`

```swift
dependencies: [
    .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
    // ... existing dependencies
],
targets: [
    .executableTarget(
        name: "SpeechToText",
        dependencies: [
            .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            // ... existing dependencies
        ]
    )
]
```

### Phase 2: Define Shortcut Names

**File: Sources/Services/ShortcutNames.swift** (new)

```swift
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Hold-to-record shortcut
    static let holdToRecord = Self("holdToRecord", default: .init(.space, modifiers: [.control, .shift]))

    /// Toggle recording (for toggle mode)
    static let toggleRecording = Self("toggleRecording")
}
```

### Phase 3: Create New HotkeyManager

**File: Sources/Services/HotkeyManager.swift** (new)

Replace `HotkeyService.swift` with a simpler manager using KeyboardShortcuts:

```swift
import KeyboardShortcuts
import Foundation

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
```

### Phase 4: Add Shortcut Recorder to Settings

**File: Sources/Views/SettingsView.swift** (update)

Add a keyboard shortcut recorder to settings:

```swift
import KeyboardShortcuts

struct HotkeySettingsSection: View {
    var body: some View {
        Form {
            KeyboardShortcuts.Recorder("Hold-to-Record:", name: .holdToRecord)
                .padding(.vertical, 4)
        }
    }
}
```

### Phase 5: Update AppDelegate

**File: Sources/SpeechToTextApp/AppDelegate.swift** (update)

Replace `hotkeyService` with `hotkeyManager`:

```swift
// Replace:
private var hotkeyService: HotkeyService?

// With:
private var hotkeyManager: HotkeyManager?

// In setup:
hotkeyManager = HotkeyManager()
hotkeyManager?.onRecordingStart = { [weak self] in
    await self?.startHoldToRecordSession()
}
hotkeyManager?.onRecordingStop = { [weak self] duration in
    await self?.stopHoldToRecordSession(holdDuration: duration)
}
```

### Phase 6: Remove Old Code

**Files to Delete:**

- `Sources/Services/HotkeyService.swift` (replaced by HotkeyManager)

**Files to Update:**

- Remove `KeyModifier` enum if only used by HotkeyService
- Update any tests referencing HotkeyService

## File Changes Summary

| File | Action |
|------|--------|
| `Package.swift` | Add KeyboardShortcuts dependency |
| `Sources/Services/ShortcutNames.swift` | New - define shortcut names |
| `Sources/Services/HotkeyManager.swift` | New - simplified hotkey manager |
| `Sources/Services/HotkeyService.swift` | Delete - replaced by HotkeyManager |
| `Sources/Views/SettingsView.swift` | Update - add shortcut recorder |
| `Sources/SpeechToTextApp/AppDelegate.swift` | Update - use HotkeyManager |

## Testing Plan

1. **Basic hold-to-record**: Press shortcut, speak, release → text transcribed
2. **Rapid key presses**: Quick press/release cycles → only one session at a time
3. **Cooldown**: Rapid succession → ignored within cooldown
4. **Settings UI**: Change shortcut in Settings → new shortcut works
5. **Conflict detection**: Try system shortcut → warning shown

## Rollback Plan

If issues arise:

1. Keep `HotkeyService.swift` in git history
2. Remove KeyboardShortcuts dependency
3. Revert AppDelegate to use HotkeyService

## Success Criteria

1. ✓ Single press/release triggers recording and transcription
2. ✓ Rapid key presses don't cause overlapping sessions
3. ✓ Users can customize shortcut in Settings
4. ✓ System shortcut conflicts are detected
5. ✓ No Task interleaving issues

## Implementation Order

1. [ ] Add KeyboardShortcuts to Package.swift
2. [ ] Create ShortcutNames.swift with shortcut definitions
3. [ ] Create HotkeyManager.swift with new implementation
4. [ ] Update AppDelegate to use HotkeyManager
5. [ ] Add shortcut recorder to Settings
6. [ ] Test thoroughly
7. [ ] Delete HotkeyService.swift
8. [ ] Commit changes

## Sources

- [KeyboardShortcuts GitHub](https://github.com/sindresorhus/KeyboardShortcuts)
- [VoiceInk HotkeyManager](https://github.com/Beingpax/VoiceInk) - reference implementation
