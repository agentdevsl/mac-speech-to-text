# Recording Flow Test Plans

**Related Views**: `RecordingModal.swift`, `RecordingViewModel.swift`, `WaveformView.swift`
**Priority**: High

## UI Component Analysis

### RecordingModal Structure

```
┌─────────────────────────────────────────────┐
│  [Mic Icon]  Recording    [🇺🇸]  [✕ Close] │  ← Header
├─────────────────────────────────────────────┤
│  ████████████████████████████████████████   │  ← WaveformView
│  ████████  ██████  ████████████  ████████   │    (60 bars, Canvas)
├─────────────────────────────────────────────┤
│           Speak now...                      │  ← Status Text
│                                             │
│        [Transcription result here]          │  ← Transcribed Text
│           Confidence: 95%                   │  ← Confidence Score
├─────────────────────────────────────────────┤
│        [Stop Recording]  [Cancel]           │  ← Action Buttons
└─────────────────────────────────────────────┘
```

### State Machine

```
idle → recording → transcribing → inserting → completed
         ↓              ↓            ↓
       [cancel]      [error]      [error]
```

---

## Test Cases

### T01: testRecordingModalAppears

**Objective**: Verify recording modal appears with correct initial state

**Preconditions**:

- App launched with `--skip-onboarding`
- Permissions granted (or mocked with `--skip-permission-checks`)

**Steps**:

1. Trigger global hotkey (⌘⌃Space)
2. Wait for modal to appear

**Expected Results**:

- Modal appears with spring animation (scale 0.8 → 1.0)
- Microphone icon shows "mic.fill" with red color
- Status text shows "Recording"
- "Speak now..." subtitle visible
- WaveformView visible with 80px height
- "Stop Recording" button visible and enabled
- "Cancel" button visible

**UI Elements to Verify**:

```swift
app.windows.element // Modal window
app.images["mic.fill"] // Microphone icon
app.staticTexts["Recording"] // Status title
app.staticTexts["Speak now..."] // Subtitle
app.buttons["Stop Recording"] // Primary action
app.buttons["Cancel"] // Cancel action
```

---

### T02: testRecordingShowsWaveform

**Objective**: Verify waveform visualization responds to audio input

**Preconditions**:

- Recording modal is open
- Mock audio input available (`--mock-audio`)

**Steps**:

1. Start recording
2. Inject mock audio levels (0.2, 0.5, 0.8)
3. Observe waveform changes

**Expected Results**:

- WaveformView updates in real-time
- Bar heights correspond to audio levels
- Colors change based on level:
  - 0.0-0.3: AmberLight
  - 0.3-0.7: AmberPrimary
  - 0.7+: AmberBright with glow effect

**Accessibility Verification**:

```swift
let waveform = app.otherElements["Audio waveform visualization"]
XCTAssertTrue(waveform.exists)
// Value should update: "Audio level at X percent"
```

---

### T03: testRecordingShowsAudioLevel

**Objective**: Verify audio level indicator updates during recording

**Preconditions**:

- Recording modal is open
- Real or mock microphone input

**Steps**:

1. Start recording
2. Generate varying audio levels
3. Observe level updates

**Expected Results**:

- `viewModel.audioLevel` updates from level callback
- WaveformView reflects level changes
- Updates occur at 30+ fps (smooth animation)

**Technical Notes**:

- Level callback is `@Sendable` and dispatches to MainActor
- See `RecordingViewModel.swift:205-206`:

  ```swift
  try await audioService.startCapture { @Sendable [weak self] level in
      Task { @MainActor in self?.audioLevel = level }
  }
  ```

---

### T04: testRecordingCancelDismissesModal

**Objective**: Verify cancel button properly dismisses modal

**Preconditions**:

- Recording modal is open and recording

**Steps**:

1. Click "Cancel" button
2. Observe modal dismissal

**Expected Results**:

- Modal animates out (spring animation, scale 1.0 → 0.8)
- Recording stops (no audio captured)
- Session state set to `.cancelled`
- No text insertion occurs
- Modal window closes

**Alternative Flows**:

- **Escape key**: Same behavior as Cancel button
- **Click outside modal**: Same behavior as Cancel button

**Code Reference** (`RecordingModal.swift:282-296`):

```swift
private func handleDismiss() {
    guard !isDismissing else { return }
    isDismissing = true
    recordingTaskId = nil
    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
        isVisible = false
    }
    dismissTaskId = UUID()
}
```

---

### T05: testRecordingStopTriggersTranscription

**Objective**: Verify stop button triggers transcription flow

**Preconditions**:

- Recording modal is open
- Audio has been captured (non-empty buffer)

**Steps**:

1. Record for 2+ seconds
2. Click "Stop Recording"
3. Observe transcription flow

**Expected Results**:

1. **Transcribing state**:
   - `isTranscribing = true`
   - ProgressView spinner visible
   - Status text: "Transcribing..."

2. **Transcription complete**:
   - `transcribedText` populated
   - `confidence` score displayed (0-100%)
   - Status title: "Complete"

3. **Text insertion**:
   - `isInserting = true`
   - Status: "Inserting text..."
   - Text inserted at cursor position

**State Transitions**:

```
recording → transcribing → inserting → completed
```

**UI Elements**:

```swift
// During transcription
app.progressIndicators.firstMatch.exists
app.staticTexts["Transcribing..."]

// After transcription
app.staticTexts.matching(identifier: "transcribedText")
app.staticTexts["Confidence: 95%"]

// Insertion
app.staticTexts["Inserting text..."]
```

---

### T06: testRecordingEscapeKeyDismisses

**Objective**: Verify Escape key dismisses modal

**Preconditions**:

- Recording modal is open

**Steps**:

1. Press Escape key
2. Observe modal dismissal

**Expected Results**:

- Modal dismisses with animation
- Recording cancelled
- Same behavior as Cancel button

**Code Reference** (`RecordingModal.swift:121-124`):

```swift
.onKeyPress(.escape) {
    handleDismiss()
    return .handled
}
```

---

### T07: testRecordingLanguageIndicator

**Objective**: Verify language indicator displays correctly

**Preconditions**:

- Recording modal is open
- Language set to non-English (e.g., French)

**Steps**:

1. Open recording modal
2. Observe language indicator in header

**Expected Results**:

- Language flag displayed (e.g., "🇫🇷")
- Flag has amber background (15% opacity)
- Rounded corners (6pt radius)

**During Language Switch**:

- ProgressView spinner appears next to flag
- `isLanguageSwitching = true`

**Code Reference** (`RecordingModal.swift:156-170`):

```swift
if let language = viewModel.currentLanguageModel {
    HStack(spacing: 4) {
        Text(language.flag)
        if viewModel.isLanguageSwitching {
            ProgressView().scaleEffect(0.5)
        }
    }
    .background(Color("AmberPrimary").opacity(0.15))
}
```

---

### T08: testRecordingSilenceAutoStop

**Objective**: Verify automatic stop on silence detection

**Preconditions**:

- Recording modal is open
- Silence threshold configured (default: 1.5s)

**Steps**:

1. Start recording
2. Speak briefly
3. Go silent for threshold duration (1.5s)
4. Observe auto-stop

**Expected Results**:

- Recording automatically stops after silence threshold
- Transcription flow begins
- User sees state transition to "Processing"

**Code Reference** (`RecordingViewModel.swift:412-450`):

```swift
private func resetSilenceTimer() {
    if audioLevel < 0.01 {
        silenceTimer = Timer.scheduledTimer(
            withTimeInterval: silenceThreshold,
            repeats: false
        ) { _ in
            Task.detached { @MainActor [weak self] in
                await self?.onSilenceDetected()
            }
        }
    }
}
```

---

### T09: testRecordingErrorDisplay

**Objective**: Verify error messages display correctly

**Preconditions**:

- Recording modal is open
- Simulate error condition

**Steps**:

1. Trigger error (e.g., microphone access revoked)
2. Observe error display

**Expected Results**:

- Error view appears with red background
- Warning icon (exclamationmark.triangle.fill)
- Error message text displayed
- Animation: slide up + fade in

**Error View Structure**:

```swift
HStack {
    Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(.red)
    Text(errorMessage)
        .foregroundStyle(.red)
}
.background(Color.red.opacity(0.1))
.clipShape(RoundedRectangle(cornerRadius: 8))
```

---

## Test Infrastructure

### Mock Audio Service

```swift
class MockAudioCaptureService: AudioCaptureService {
    var mockAudioLevel: Double = 0.5
    var mockSamples: [Int16] = []

    override func startCapture(levelCallback: @escaping @Sendable (Double) -> Void) async throws {
        // Simulate audio levels
        for level in stride(from: 0.0, to: 1.0, by: 0.1) {
            levelCallback(level)
            try await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    override func stopCapture() async throws -> [Int16] {
        return mockSamples
    }
}
```

### Test Helpers

```swift
extension XCUIApplication {
    var recordingModal: XCUIElement {
        windows.element(boundBy: 0)
    }

    var waveformView: XCUIElement {
        otherElements["Audio waveform visualization"]
    }

    func waitForRecordingState(_ state: String, timeout: TimeInterval = 5) -> Bool {
        staticTexts[state].waitForExistence(timeout: timeout)
    }
}
```

---

## Acceptance Criteria

- [ ] All 9 test cases implemented and passing
- [ ] Tests run in < 60 seconds total
- [ ] Screenshots captured on failure
- [ ] Mock audio service available for CI
- [ ] Tests integrated into pre-push hook
