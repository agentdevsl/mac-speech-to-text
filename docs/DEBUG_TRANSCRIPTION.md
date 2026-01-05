# Transcription Debugging Report

**Date**: 2026-01-05
**Issue**: Transcription not working in hold-to-record mode

## Summary

After implementing the hold-to-record integration with RecordingViewModel, transcription appears to partially work but text is not appearing. Audio capture is confirmed working, but clipboard remains empty after recording.

## Code Changes Made

### 1. RecordingViewModel.swift

- Fixed `isTransitioning` race condition with `defer { isTransitioning = false }` pattern
- Renamed variable shadowing: `currentSession` -> `updatedSession` in staleness checks

### 2. AppDelegate.swift

- Added `holdToRecordViewModel` property for actual transcription
- Added `isHoldToRecordSessionActive` session-level guard
- Wired `startHoldToRecordSession()` to call `holdToRecordViewModel.startRecording()`
- Wired `stopHoldToRecordSession()` to call `holdToRecordViewModel.onHotkeyReleased()`
- Added `isRecording` check in timer callback
- Added `cancelRecording()` on app termination

### 3. GlassOverlayViewModel.swift

- Added state check in timer callback to prevent orphaned Task updates
- Enhanced `showTranscribing()` to return Bool and log detailed failure info

## Observations from Logs

### What's Working

1. **Audio capture starts and stops correctly**:
   - AVAudioEngine starts: `Engine@0xb114cdcf0: start, was running 0`
   - AVAudioEngine stops: `Engine@0xb114cdcf0: stop, was running 1`
   - Recording duration: ~3 seconds

2. **FluidAudio model loads**:
   - ANEServices: `Selected ANEDriver device` (Neural Engine accessed)
   - MIL memory mapping for model

3. **Hotkey triggers recording flow**:
   - Glass overlay appears
   - Overlay transitions through states

### What's Not Working

1. **AppLogger custom logs not appearing in unified logging**
   - Logs like `[com.speechtotext.app:viewModel]` not showing
   - Only framework logs (AVFAudio, CoreAudio) visible

2. **Clipboard remains empty after transcription**
   - `pbpaste` shows empty content after test

3. **No visible transcription/insertion logs**
   - Expected: `Transcription complete: Xms, confidence=Y`
   - Expected: `Text inserted via accessibility` or `Direct insertion failed`

## Earlier Session (Different App Instance)

In an earlier test (09:42), we DID see app logs:

```
[com.speechtotext.app:service] Direct insertion failed with error: AXError(rawValue: -25205). Falling back to paste.
```

This indicates:

- Transcription WAS working (got to insertion phase)
- AXError -25205 = `kAXErrorAPIDisabled` (Accessibility not granted)
- Fallback to paste was triggered

## Possible Root Causes

### 1. Accessibility Permission Issue

- AXError -25205 indicates Accessibility permission is disabled
- `simulatePaste()` uses `CGEvent.post()` which ALSO requires Accessibility permission
- Without Accessibility, BOTH insertion methods fail silently

### 2. Log Level Configuration

- AppLogger may use Debug/Trace level which is filtered by unified logging
- Need to verify log level settings or use `.default` level

### 3. Async/Await Flow Issue

- The recording flow is async, potential for dropped errors
- Need to verify error propagation from FluidAudio service

## Initial Next Steps

1. **Grant Accessibility Permission**
   - System Settings > Privacy & Security > Accessibility
   - Add SpeechToText.app

2. **Verify Log Levels**
   - Check `AppLogger` configuration
   - Consider using `.default` or `.error` level for critical logs

3. **Add Console Logging**
   - Use `print()` statements for immediate debugging
   - Or configure OSLog to show debug-level messages

4. **Test Clipboard Directly**
   - Verify `copyToClipboard()` function works
   - Test with simple text before transcription

## Files Modified

| File | Changes |
|------|---------|
| `Sources/Views/RecordingViewModel.swift` | isTransitioning fix, variable shadowing fix |
| `Sources/SpeechToTextApp/AppDelegate.swift` | Session guard, timer check, termination cleanup |
| `Sources/Views/GlassOverlay/GlassOverlayViewModel.swift` | Timer state check, showTranscribing enhancement |

## Build Status

- Build: SUCCESS
- App Bundle: `/Users/simon.lynch/git/mac-speech-to-text/build/SpeechToText.app`
- Signing: Apple Development (QMT565BG3C)

---

## Progress Update (Latest Session)

### FluidAudio Initialization Confirmed

Ran app from terminal to capture stdout. FluidAudio initialization fully successful:

```
[09:50:12.469] [INFO] [FluidAudio.AsrModels] Downloading ASR models to: .../FluidAudio/Models/parakeet-tdt-0.6b-v3-coreml
[09:50:12.470] [INFO] [FluidAudio.AsrModels] ASR models already present
[09:50:12.471] [INFO] [FluidAudio.DownloadUtils] Host environment: macOS Version 26.1 (Build 25B78), arch=arm64, chip=Apple M1 Pro
[09:50:12.487] [INFO] [FluidAudio.AsrModels] Loaded Preprocessor.mlmodelc with compute units: cpuOnly
[09:50:12.611] [INFO] [FluidAudio.AsrModels] Loaded Encoder.mlmodelc with compute units: cpuAndNeuralEngine
[09:50:12.641] [INFO] [FluidAudio.AsrModels] Loaded vocabulary with 8192 tokens
[09:50:12.643] [INFO] [FluidAudio.ASR] AsrManager initialized successfully with provided models
[09:50:12.643] [INFO] [FluidAudio.MLArrayCache] Pre-warming cache with 3 shapes
```

**Key Findings:**

- Neural Engine is being used for the Encoder (fast inference)
- 8192 token vocabulary loaded
- Cache pre-warming complete
- All 4 models loaded: Preprocessor, Encoder, Decoder, JointDecision

### DEBUG Print Statements Not Appearing

Added `print()` statements to `startHoldToRecordSession()` and `stopHoldToRecordSession()`:

```swift
print("[DEBUG] Calling startRecording...")
print("[DEBUG] startRecording succeeded!")
print("[DEBUG] Calling onHotkeyReleased...")
print("[DEBUG] onHotkeyReleased completed successfully!")
print("[DEBUG] Transcribed text: '\(holdToRecordViewModel.transcribedText)'")
```

**Result:** None of these DEBUG statements appear in stdout when hotkey is pressed.

### Critical Finding: Hotkey Callbacks May Not Be Reaching Our Code

The absence of DEBUG prints suggests:

1. The hotkey handler code may not be calling `startHoldToRecordSession()`/`stopHoldToRecordSession()`
2. Or the calls are being made on a different execution path
3. Or there's an early return/guard blocking execution

### Investigation Needed

Check the hotkey registration and callback chain:

1. **HotkeyService.swift** - Where is `onKeyDown`/`onKeyUp` called?
2. **AppDelegate hotkey wiring** - Are the closures properly connected?
3. **Early guards** - Is `isHoldToRecordSessionActive` incorrectly set?

### Hypothesis

The hotkey callback may be hitting a different code path (possibly the old simulated path) rather than our new `startHoldToRecordSession()` async function.

## Current Debugging Stack

```
User presses hotkey
    ↓
HotkeyService.onKeyDown callback
    ↓
??? (Missing link)
    ↓
startHoldToRecordSession() [NOT REACHED - DEBUG prints missing]
    ↓
holdToRecordViewModel.startRecording()
    ↓
FluidAudioService.transcribe()
```

## Immediate Next Steps

1. **Find the hotkey callback wiring** in AppDelegate
2. **Verify the callback closure** actually calls `startHoldToRecordSession()`
3. **Add DEBUG print at very start** of hotkey callback (before any guards)
4. **Check for Task/async issues** - async functions in callbacks may need `Task { }`

---

## Progress Update 2 (Carbon Hotkey Investigation)

### Carbon Hotkey Registration Succeeds

Added extensive debug prints to Carbon registration. All succeeded:

```
[DEBUG-CARBON-REG] registerCarbonHotkey called: keyCode=49, modifiers=[control, shift]
[DEBUG-CARBON-REG] carbonModifiers=4608
[DEBUG-CARBON-REG] Installing event handler...
[DEBUG-CARBON-REG] InstallEventHandler returned status=0 (noErr=0)
[DEBUG-CARBON-REG] Registering hotkey with RegisterEventHotKey...
[DEBUG-CARBON-REG] RegisterEventHotKey returned status=0 (noErr=0), hotkeyRef=Optional(0x0000000965258de0)
[DEBUG-CARBON-REG] Hotkey registered successfully!
[DEBUG] Hold-to-record hotkey registered successfully! keyCode=49, modifiers=[control, shift]
```

### BUT: Carbon Callback Never Called

Added debug print to `carbonHotkeyCallback()`:

```swift
print("[DEBUG-CARBON] carbonHotkeyCallback called!")
```

**Result**: This print NEVER appears when pressing Control+Shift+Space.

### Key Finding

| Step | Status |
|------|--------|
| Recording mode = holdToRecord | ✓ Confirmed |
| HotkeyService created | ✓ Confirmed |
| Carbon InstallEventHandler | ✓ status=0 (success) |
| Carbon RegisterEventHotKey | ✓ status=0 (success) |
| hotkeyRef valid | ✓ Non-nil pointer |
| carbonHotkeyCallback invoked | ✗ NEVER CALLED |

### Analysis

The Carbon hotkey is **successfully registered** with macOS at the system level:

- `InstallEventHandler()` succeeded
- `RegisterEventHotKey()` succeeded
- Valid `EventHotKeyRef` returned

But when pressing Control+Shift+Space, the `carbonHotkeyCallback` function is **never invoked** by the Carbon Event Manager.

### Possible Causes

1. **System shortcut conflict** - macOS may be capturing Ctrl+Shift+Space for input source switching (even though symbolic hotkeys show `enabled = 0`)

2. **App not receiving events** - The app may need to be in foreground or have specific entitlements

3. **Carbon event loop issue** - The main event loop may not be processing Carbon events properly

4. **Another app capturing the key** - Some other app may have registered the same hotkey first

### Hotkey Details

From user preferences (`com.speechtotext.app.plist`):

- keyCode: 49 (Space bar)
- modifiers: ["control", "shift"]
- carbonModifiers: 4608 (0x1200 = controlKey | shiftKey)

### Carbon Investigation Next Steps

1. **Try a different hotkey** - Use Control+Option+R to rule out system conflict
2. **Check for competing hotkey registrations**
3. **Verify Carbon event loop is running**
4. **Add entitlements if needed**

---

## Progress Update 3 (FIX FOUND!)

### Root Cause Identified: EventHandlerUPP Type Annotation

Changed the Carbon callback from a Swift function to a closure typed as `EventHandlerUPP`:

**Before (broken):**

```swift
private func carbonHotkeyCallback(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
```

**After (working):**

```swift
private let carbonHotkeyCallback: EventHandlerUPP = { (
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus in
```

The `EventHandlerUPP` type alias ensures the closure has the correct C calling convention (`@convention(c)`).

### Hotkey Pipeline Now Working

After the fix, full callback chain confirmed:

```
[DEBUG-CARBON] carbonHotkeyCallback called!
[DEBUG-CARBON] eventKind=5, kEventHotKeyPressed=5
[DEBUG-CARBON] Calling handleHotkeyPressed
[DEBUG-HOTKEY] handleHotkeyPressed() called, isHoldMode=true
[DEBUG-SYNC] onKeyDown callback fired!
[DEBUG-ASYNC] onKeyDown Task starting...
[DEBUG] Calling startRecording...
[DEBUG] startRecording succeeded!
[DEBUG-CARBON] carbonHotkeyCallback called!
[DEBUG-CARBON] eventKind=6, kEventHotKeyReleased=6
[DEBUG-SYNC] onKeyUp callback fired! duration=3.14s
```

### New Issue: Empty Transcription

Transcription completes but returns empty text:

```
[DEBUG] onHotkeyReleased completed successfully!
[DEBUG] Transcribed text: ''
```

FluidAudio models load successfully after key release:

- Preprocessor: 16.84 ms (CPU)
- Encoder: 153.56 ms (cpuAndNeuralEngine)
- Decoder: 12.50 ms
- JointDecision: 12.58 ms
- Vocabulary: 8192 tokens

### Next Investigation

1. **Check audio buffer contents** - Is audio being captured properly?
2. **Verify transcription call** - Is `FluidAudioService.transcribe()` receiving audio?
3. **Check for empty audio** - Maybe microphone permission issue?

---

## Progress Update 4 (Sample Rate Conversion Fix)

### Root Cause: Wrong Sample Rate

Debug output revealed the issue:

```
[DEBUG] onHotkeyReleased: Starting transcription with 129600 samples...
[DEBUG] Calling FluidAudio transcribe with 129600 samples...
[DEBUG] FluidAudio result: text='', confidence=0.1, durationMs=120
```

Key finding:

- 129,600 samples at **native rate** (~48kHz) = ~2.7 seconds
- But FluidAudio expects **16kHz** audio
- At 16kHz, 129,600 samples would be 8.1 seconds of audio (wrong!)
- FluidAudio reported `durationMs=120` (0.12 seconds) - processing tiny fraction

### The Fix: AVAudioConverter Resampling

Added AVAudioConverter to `AudioBufferProcessor` to resample from native microphone rate to 16kHz:

**AudioCaptureService.swift changes:**

```swift
// AudioBufferProcessor now takes nativeFormat and creates converter
init(streamingBuffer: StreamingAudioBuffer, nativeFormat: AVAudioFormat, levelCallback: @escaping @Sendable (Double) -> Void) {
    // Create target format: 16kHz mono Int16
    self.targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: Double(Constants.Audio.sampleRate), // 16000
        channels: 1,
        interleaved: false
    )!

    // Create converter from native to 16kHz
    self.audioConverter = AVAudioConverter(from: nativeFormat, to: targetFormat)
}

// New resampleBuffer function using AVAudioConverter
private func resampleBuffer(_ buffer: AVAudioPCMBuffer, using converter: AVAudioConverter, bufferNumber: Int) -> [Int16] {
    // Calculate output capacity based on sample rate ratio
    let ratio = outputSampleRate / inputSampleRate
    let outputFrameCapacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * ratio))

    // Use AVAudioConverter to resample
    let status = converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)

    // Return resampled Int16 samples
    return Array(UnsafeBufferPointer(start: int16Data[0], count: frameCount))
}
```

### VoiceInk Reference

Researched how [VoiceInk](https://github.com/Beingpax/VoiceInk) handles this:

- Uses AVAudioConverter from native format to 16kHz
- Creates target format: `AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000.0, channels: 1, interleaved: false)`
- Converts during audio capture, not at transcription time

### Interim Build Status

- Build: SUCCESS
- Resampling integrated into AudioBufferProcessor
- Ready for manual testing

### To Test

Run the app and press Control+Shift+Space while speaking:

```bash
./build/SpeechToText.app/Contents/MacOS/SpeechToText
```

---

## Progress Update 5 (FIX VERIFIED - SUCCESS!)

### Final Solution: Resample at Transcription Time

Per-buffer AVAudioConverter resampling didn't work (stateful converter issue). The correct approach:

1. **Capture at native rate** (e.g., 48kHz) - no conversion during capture
2. **Store native sample rate** alongside samples
3. **Resample at transcription time** using FluidAudio's `AudioConverter.resampleBuffer()`

### Code Changes

**AudioCaptureService.swift:**

- `AudioBufferProcessor` stores `nativeSampleRate` property
- `stopCapture()` returns tuple: `(samples: [Int16], sampleRate: Double)`
- Samples stored at native rate, no per-buffer conversion

**FluidAudioService.swift:**

- `transcribe(samples:sampleRate:)` now accepts sample rate
- Uses FluidAudio's `AudioConverter().resampleBuffer()` when rate != 16kHz
- Converts Int16 → Float32 → AVAudioPCMBuffer → resample → [Float]

**RecordingViewModel.swift:**

- Updated `stopCapture()` call to destructure tuple
- Updated `transcribe()` and `transcribeWithFallback()` to accept sampleRate

### Test Results

```
[DEBUG] stopCapture: 244800 samples at 48000Hz
[DEBUG] onHotkeyReleased: Starting transcription with 244800 samples at 48000Hz...
[DEBUG] Resampling from 48000Hz to 16000Hz...
[DEBUG] Resampled: 244800 samples -> 81600 samples
[DEBUG] Calling FluidAudio ASR with 81600 samples at 16kHz...
[DEBUG] FluidAudio result: text='This is a test: one two three four five six seven eight nine ten', confidence=0.95707566, durationMs=219
```

### Issue Summary

| Issue | Root Cause | Solution |
|-------|-----------|----------|
| Empty transcription | 48kHz samples sent to 16kHz-expecting model | Resample to 16kHz at transcription time |
| Per-buffer conversion failed | AVAudioConverter is stateful | Resample full audio at once, not per-buffer |
| Only 1600 samples captured | Stateful converter mangled buffers | Store native rate, convert once at end |

### Status: RESOLVED ✓

Transcription now works correctly:

- 5+ seconds of audio → 244,800 samples at 48kHz
- Resampled to 81,600 samples at 16kHz (3:1 ratio)
- FluidAudio transcription: 0.957 confidence
- Text correctly transcribed and ready for insertion

---

## Progress Update 6 (Text Insertion Fix - 2026-01-05)

### Issue: Text Replacing Instead of Inserting

The original code used `kAXValueAttribute` which **replaces the entire text field content** instead of inserting at cursor.

### Fix: Use kAXSelectedTextAttribute

Changed `TextInsertionService.swift` line 85:

**Before:**

```swift
let insertionResult = AXUIElementSetAttributeValue(
    axElement,
    kAXValueAttribute as CFString,  // WRONG - replaces all text
    text as CFTypeRef
)
```

**After:**

```swift
let insertionResult = AXUIElementSetAttributeValue(
    axElement,
    kAXSelectedTextAttribute as CFString,  // CORRECT - inserts at cursor
    text as CFTypeRef
)
```

### Fix: Carbon Event Timing Race Condition

The duration calculation was wrong because `startTime` was set when the MainActor Task ran (after Carbon event), not when the actual key was pressed.

**Solution:** Use `GetEventTime(event)` from the Carbon event itself:

```swift
// In carbonHotkeyCallback:
let carbonEventTime = GetEventTime(event)

// Pass to handler:
service.handleHotkeyPressed(carbonEventTime: carbonEventTime)

// Calculate accurate duration:
let duration = releaseEventTime - pressEventTime  // Carbon event times
```

### Test Results (Latest)

```
[DEBUG] FluidAudio result: text='This is a test one, two, three, four, five, six', confidence=0.95196855
[DEBUG-INSERT] insertText() called with 47 chars
[DEBUG-INSERT] kAXSelectedTextAttribute result: 0
[DEBUG-INSERT] Insertion via kAXSelectedTextAttribute succeeded!
[DEBUG] insertionResult: insertedViaAccessibility
```

Status: TEXT INSERTION WORKING ✓

---

## Known Issue: Task Interleaving on Rapid Key Presses

### Symptom

When pressing the hotkey rapidly (before previous transcription completes), Tasks interleave and sessions overlap:

```
[DEBUG-CARBON] carbonHotkeyCallback called! eventKind=5  # Press 1
[DEBUG-CARBON] carbonHotkeyCallback called! eventKind=6  # Release 1
[DEBUG-CARBON] carbonHotkeyCallback called! eventKind=5  # Press 2
[DEBUG-CARBON] carbonHotkeyCallback called! eventKind=6  # Release 2
[DEBUG-ASYNC] onKeyDown Task starting...      # Task 1
[DEBUG] startRecording succeeded!
[DEBUG-ASYNC] onKeyUp Task starting...        # Task 2 (interleaves!)
[DEBUG] Stopping session...
[DEBUG-ASYNC] onKeyDown Task starting...      # Task 3
[DEBUG] START IGNORED: session already active  # Guard works
[DEBUG-ASYNC] onKeyUp Task starting...        # Task 4
[DEBUG] stopCapture: 0 samples                # No audio!
```

### Cause

1. Carbon events queue up rapidly
2. All MainActor Tasks get scheduled nearly simultaneously
3. When one Task awaits (e.g., `startRecording()`), others run
4. Session guards catch some but not all conflicts

### Workaround

**Wait for transcription to complete** before pressing hotkey again. Single clean press/release works correctly.

### Future Fix

Consider VoiceInk's approach: simpler clipboard+paste without accessibility insertion, or add proper session locking with async mutexes.
