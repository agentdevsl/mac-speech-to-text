# Plan: Fix Text Insertion and Overlay State

**Date**: 2026-01-05
**Status**: Partially Complete

## Completed Fixes

### 1. Fixed Carbon Event Timing (DONE)

- Changed `handleHotkeyPressed/Released` to use actual Carbon event time from `GetEventTime(event)`
- This fixes the race condition where duration was calculated incorrectly due to MainActor Task scheduling delays
- **Files Changed**: `Sources/Services/HotkeyService.swift`

### 2. Fixed Text Insertion (DONE)

- Changed from `kAXValueAttribute` (replaces entire field) to `kAXSelectedTextAttribute` (inserts at cursor)
- Added debug logging throughout the insertion flow
- **Files Changed**: `Sources/Services/TextInsertionService.swift`

### 3. Added Debug Logging

- Added comprehensive debug prints to trace the hotkey -> recording -> transcription -> insertion flow
- **Files Changed**: `AppDelegate.swift`, `TextInsertionService.swift`, `RecordingViewModel.swift`

## Remaining Issues

## Problem Summary

After fixing the audio sample rate issue, transcription now works correctly with high confidence (0.93-0.95). However:

1. **Auto-insert not working** - Text is not being inserted at cursor position
2. **Overlay possibly stuck** - May remain on "transcribing" state
3. **Paste fallback unclear** - Need to verify Cmd+V simulation works

## Issues Identified by Code Review

### Issue 1: TextInsertionService Uses Wrong Accessibility Attribute

**File**: `Sources/Services/TextInsertionService.swift`

**Problem**: The `insertViaAccessibility()` method uses `kAXValueAttribute` which **replaces the entire text field content** instead of inserting at the current cursor position.

**Current Code**:

```swift
let result = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, text as CFTypeRef)
```

**Impact**: If user has existing text in a field and triggers transcription, their existing text is completely replaced.

**Solution Options**:

1. **Use `kAXSelectedTextAttribute`** - Sets the selected text (inserts at cursor if no selection)
2. **Use `AXUIElementPerformAction` with `kAXPressAction`** after setting clipboard
3. **Fall back to paste-only approach** - More reliable across applications

### Issue 2: Double Clipboard Copy

**File**: `Sources/Views/RecordingViewModel.swift`

**Problem**: Text is copied to clipboard in two places:

1. In `transcribe()` at line ~580
2. In `performInsertion()` at line ~632

**Impact**: Redundant operations, though functionally harmless.

**Solution**: Remove duplicate clipboard copy, keep only in `performInsertion()`.

### Issue 3: Inconsistent Error Handling

**File**: `Sources/Views/RecordingViewModel.swift`

**Problem**: Error handling differs between `transcribe()` and `transcribeWithFallback()`:

- `transcribe()` sets `currentSession.error`
- `transcribeWithFallback()` only logs errors

**Solution**: Standardize error handling across both paths.

### Issue 4: Overlay State May Not Update

**Potential Issue**: After transcription completes, overlay transitions may not fire correctly due to:

- Rapid hotkey presses causing state machine confusion
- Async task completion racing with state updates

## Implementation Plan

### Phase 1: Fix Text Insertion (Priority: High)

#### Step 1.1: Update TextInsertionService to Insert at Cursor

Modify `insertViaAccessibility()` to:

```swift
private func insertViaAccessibility(_ text: String) throws {
    // Get focused element
    guard let focusedElement = getFocusedElement() else {
        throw InsertionError.noFocusedElement
    }

    // Option A: Use kAXSelectedTextAttribute (inserts at cursor/replaces selection)
    let result = AXUIElementSetAttributeValue(
        focusedElement,
        kAXSelectedTextAttribute as CFString,
        text as CFTypeRef
    )

    if result == .success {
        return
    }

    // Fallback to paste if selected text attribute not supported
    throw InsertionError.accessibilityFailed(result)
}
```

#### Step 1.2: Improve Fallback Paste Simulation

Current `simulatePaste()` uses CGEvent to simulate Cmd+V. Verify:

1. Text is on clipboard before paste
2. CGEvent is posted to correct process
3. Add small delay for clipboard sync

```swift
private func simulatePaste() throws {
    // Ensure text is on clipboard
    guard NSPasteboard.general.string(forType: .string) != nil else {
        throw InsertionError.clipboardEmpty
    }

    // Small delay for clipboard sync
    usleep(50_000) // 50ms

    // Create Cmd+V event
    guard let source = CGEventSource(stateID: .hidSystemState) else {
        throw InsertionError.eventSourceFailed
    }

    // Key down
    guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) else {
        throw InsertionError.eventCreationFailed
    }
    keyDown.flags = .maskCommand
    keyDown.post(tap: .cghidEventTap)

    // Key up
    guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) else {
        throw InsertionError.eventCreationFailed
    }
    keyUp.flags = .maskCommand
    keyUp.post(tap: .cghidEventTap)
}
```

### Phase 2: Add Debug Logging (Priority: Medium)

#### Step 2.1: TextInsertionService Logging

Add detailed logging to track insertion flow:

```swift
func insertText(_ text: String) async -> Bool {
    AppLogger.debug(AppLogger.service, "insertText called with \(text.count) chars")

    // Try accessibility first
    do {
        try insertViaAccessibility(text)
        AppLogger.info(AppLogger.service, "Accessibility insertion succeeded")
        return true
    } catch {
        AppLogger.warning(AppLogger.service, "Accessibility failed: \(error), trying paste")
    }

    // Fallback to paste
    do {
        try simulatePaste()
        AppLogger.info(AppLogger.service, "Paste simulation succeeded")
        return true
    } catch {
        AppLogger.error(AppLogger.service, "Paste simulation failed: \(error)")
        return false
    }
}
```

#### Step 2.2: Overlay State Transition Logging

Add logging to GlassOverlayViewModel state transitions:

```swift
func transition(to newState: OverlayState) {
    let oldState = currentState
    AppLogger.debug(AppLogger.ui, "Overlay: \(oldState) -> \(newState)")
    currentState = newState
}
```

### Phase 3: Fix State Management (Priority: Medium)

#### Step 3.1: Ensure Overlay Hides After Transcription

In RecordingViewModel, verify overlay hide is called:

```swift
private func transcribeWithFallback(samples: [Int16], sampleRate: Double) async throws {
    // ... transcription code ...

    // After successful insertion
    AppLogger.debug(AppLogger.viewModel, "Transcription complete, hiding overlay")
    await MainActor.run {
        glassOverlayViewModel?.hide()
    }
}
```

#### Step 3.2: Add Debounce for Rapid Hotkey Presses

Prevent issues from rapid key presses:

```swift
private var lastHotkeyTime: Date = .distantPast
private let hotkeyDebounceInterval: TimeInterval = 0.5

func handleHotkeyPressed() {
    let now = Date()
    guard now.timeIntervalSince(lastHotkeyTime) > hotkeyDebounceInterval else {
        AppLogger.debug(AppLogger.service, "Hotkey debounced")
        return
    }
    lastHotkeyTime = now
    // ... rest of handler
}
```

### Phase 4: Remove Redundant Code (Priority: Low)

#### Step 4.1: Remove Duplicate Clipboard Copy

Remove clipboard copy from `transcribe()`, keep only in `performInsertion()`.

#### Step 4.2: Standardize Error Handling

Make `transcribeWithFallback()` set session error like `transcribe()` does.

## Testing Plan

### Manual Testing

1. **Test auto-insert**:
   - Open TextEdit with existing text
   - Place cursor in middle of text
   - Press hotkey, speak, release
   - Verify: transcribed text inserted at cursor, existing text preserved

2. **Test paste fallback**:
   - Open an app that doesn't support accessibility (e.g., Terminal)
   - Trigger transcription
   - Verify: text is pasted via Cmd+V

3. **Test overlay state**:
   - Trigger multiple rapid recordings
   - Verify: overlay shows/hides correctly each time

4. **Test error cases**:
   - Revoke accessibility permission
   - Verify: graceful fallback to paste

### Automated Testing

- Add unit tests for TextInsertionService with mocked accessibility
- Add integration tests for full transcription flow

## Files to Modify

| File | Changes |
|------|---------|
| `Sources/Services/TextInsertionService.swift` | Fix accessibility attribute, improve paste |
| `Sources/Views/RecordingViewModel.swift` | Remove duplicate clipboard, add logging |
| `Sources/Views/GlassOverlay/GlassOverlayViewModel.swift` | Add state transition logging |
| `Sources/Services/HotkeyService.swift` | Add debounce for rapid presses |

## Success Criteria

1. Transcribed text inserts at cursor position without replacing existing text
2. Paste fallback works when accessibility fails
3. Overlay correctly hides after transcription completes
4. No crashes or hangs with rapid hotkey usage
5. Clear debug logs showing insertion flow

## Next Actions

1. [ ] Fix `kAXValueAttribute` → `kAXSelectedTextAttribute` in TextInsertionService
2. [ ] Add debug logging to track insertion flow
3. [ ] Test with live app
4. [ ] Fix any remaining issues found during testing
5. [ ] Commit fixes
