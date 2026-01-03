# Error State Test Plans

**Related Views**: `RecordingModal.swift`, `OnboardingView.swift`, `PermissionCard.swift`
**Priority**: High

## Overview

These tests verify the application handles error conditions gracefully and provides clear feedback to users.

---

## Test Cases

### T01: testMicrophonePermissionDenied

**Objective**: Verify UI when microphone permission is denied

**Preconditions**:

- Microphone permission NOT granted
- `--skip-onboarding` flag set

**Steps**:

1. Trigger recording (⌘⌃Space)
2. Observe error handling

**Expected Results**:

- Recording modal may open briefly
- Error message displayed: "Microphone permission required" or similar
- Error view styled with red background
- Clear instruction to grant permission
- Link/button to open System Settings

**Error Flow**:

```
startRecording() → audioService.startCapture() throws
→ catch: RecordingError.audioCaptureFailed
→ errorMessage = "Failed to start recording: ..."
→ showError = true
→ errorView displayed
```

**Code Reference** (`RecordingViewModel.swift:202-215`):

```swift
do {
    try await audioService.startCapture { ... }
    isAudioCaptureActive = true
} catch {
    isRecording = false
    currentSession = nil
    throw RecordingError.audioCaptureFailed(error.localizedDescription)
}
```

---

### T02: testAccessibilityPermissionDenied

**Objective**: Verify UI when accessibility permission is denied

**Preconditions**:

- Accessibility permission NOT granted
- Recording completed with transcription

**Steps**:

1. Complete a recording
2. Transcription succeeds
3. Text insertion fails (no accessibility)
4. Observe error

**Expected Results**:

- Transcription result displayed
- Error on text insertion: "Text insertion failed"
- Error message mentions accessibility permission
- System Settings prompt available

**Error Type**:

```swift
RecordingError.textInsertionFailed(error.localizedDescription)
```

---

### T03: testOnboardingPermissionError

**Objective**: Verify error handling during onboarding permission requests

**Preconditions**:

- Onboarding active on permission step

**Steps**:

1. Navigate to microphone permission step
2. Deny permission (or simulate denial)
3. Observe error display

**Expected Results**:

- `PermissionErrorView` displayed
- Red text with error message
- Clear instructions provided
- Skip option available (with warning)

**Code Reference** (`OnboardingView.swift:202-209`):

```swift
if let error = viewModel.permissionError {
    PermissionErrorView(message: error)
} else if let warning = permissionWarning {
    Text(warning)
        .foregroundStyle(.orange)
}
```

---

### T04: testTranscriptionError

**Objective**: Verify UI when transcription fails

**Preconditions**:

- Recording modal open
- Audio captured successfully

**Steps**:

1. Record audio
2. Simulate transcription failure (FluidAudio error)
3. Observe error handling

**Expected Results**:

- Error view appears with message
- `isTranscribing` returns to false
- Session state: `.cancelled`
- Error logged via AppLogger

**Error Type**:

```swift
RecordingError.transcriptionFailed(error.localizedDescription)
// errorMessage = "Transcription failed: ..."
```

---

### T05: testNoAudioCaptured

**Objective**: Verify handling when no audio is captured

**Preconditions**:

- Recording modal open

**Steps**:

1. Start recording
2. Immediately stop (no audio input)
3. Observe error

**Expected Results**:

- Error: "No audio was captured"
- Clear message about minimum recording duration
- Option to try again

**Code Reference** (`RecordingViewModel.swift:245-248`):

```swift
guard !samples.isEmpty else {
    throw RecordingError.noAudioCaptured
}
```

---

### T06: testLanguageSwitchError

**Objective**: Verify error handling when language switch fails

**Preconditions**:

- Recording modal open
- Different language selected

**Steps**:

1. Trigger language switch
2. Simulate FluidAudio model switch failure
3. Observe error

**Expected Results**:

- `isLanguageSwitching` returns to false
- Error message: "Failed to switch language: ..."
- Previous language retained
- Recording can continue

**Code Reference** (`RecordingViewModel.swift:160-166`):

```swift
do {
    try await fluidAudioService.switchLanguage(to: languageCode)
} catch {
    errorMessage = "Failed to switch language: \(error.localizedDescription)"
}
isLanguageSwitching = false
```

---

### T07: testNetworkErrorForModelDownload

**Objective**: Verify error handling when model download fails

**Preconditions**:

- Language picker open
- Network unavailable or simulated failure

**Steps**:

1. Select language that requires download
2. Simulate network error
3. Observe error display

**Expected Results**:

- Download status badge: exclamationmark.triangle.fill (orange)
- Error message available
- Retry option available
- Other languages still selectable

---

### T08: testInputMonitoringPermissionDenied

**Objective**: Verify behavior when input monitoring denied

**Preconditions**:

- Input monitoring permission NOT granted

**Steps**:

1. Attempt to use global hotkey (⌘⌃Space)
2. Observe behavior

**Expected Results**:

- Hotkey doesn't trigger (system-level block)
- User must grant permission in System Settings
- Onboarding step shows warning if not granted

---

### T09: testErrorDismissal

**Objective**: Verify error messages can be dismissed

**Preconditions**:

- Error currently displayed

**Steps**:

1. Observe error view
2. Take action to dismiss (close modal, retry, etc.)
3. Observe error clears

**Expected Results**:

- Error view animates out
- `errorMessage` set to nil
- UI returns to normal state

---

### T10: testMultipleErrorsQueued

**Objective**: Verify handling of multiple rapid errors

**Preconditions**:

- Rapid error conditions

**Steps**:

1. Trigger multiple errors quickly
2. Observe error display

**Expected Results**:

- Most recent error displayed
- Previous errors logged
- UI doesn't freeze or crash
- Clear recovery path

---

## Error Message Reference

| Error | User Message | Recovery Action |
|-------|--------------|-----------------|
| `alreadyRecording` | "Recording is already in progress" | Wait or cancel |
| `notRecording` | "No active recording to stop" | Start recording |
| `audioCaptureFailed` | "Audio capture failed: [details]" | Check permissions |
| `noAudioCaptured` | "No audio was captured" | Try again, speak louder |
| `noActiveSession` | "No active recording session" | Start new recording |
| `transcriptionFailed` | "Transcription failed: [details]" | Try again |
| `textInsertionFailed` | "Text insertion failed: [details]" | Check accessibility |

---

## Test Infrastructure

### Error Simulation

```swift
class MockFluidAudioService: FluidAudioServiceProtocol {
    var shouldFailTranscription = false
    var shouldFailLanguageSwitch = false

    func transcribe(samples: [Int16]) async throws -> TranscriptionResult {
        if shouldFailTranscription {
            throw NSError(domain: "FluidAudio", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Model not loaded"])
        }
        return TranscriptionResult(text: "Test", confidence: 0.95, durationMs: 100)
    }

    func switchLanguage(to code: String) async throws {
        if shouldFailLanguageSwitch {
            throw NSError(domain: "FluidAudio", code: -2,
                         userInfo: [NSLocalizedDescriptionKey: "Model download failed"])
        }
    }
}
```

### Test Helpers

```swift
extension XCUIApplication {
    var errorView: XCUIElement {
        otherElements.containing(.image, identifier: "exclamationmark.triangle.fill").element
    }

    var errorMessage: String? {
        staticTexts.matching(NSPredicate(format: "label CONTAINS 'failed' OR label CONTAINS 'error'"))
            .firstMatch.label
    }

    func waitForError(timeout: TimeInterval = 5) -> Bool {
        errorView.waitForExistence(timeout: timeout)
    }
}
```

---

## Acceptance Criteria

- [ ] All 10 error scenarios tested
- [ ] Error messages are clear and actionable
- [ ] Recovery paths verified
- [ ] No crashes on error conditions
- [ ] Errors logged appropriately
- [ ] Tests run in < 45 seconds total
