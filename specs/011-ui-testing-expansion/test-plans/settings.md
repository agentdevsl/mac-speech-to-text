# Settings View Test Plans

**Related Views**: `SettingsView.swift`, `SettingsViewModel.swift`
**Priority**: Medium

## UI Component Analysis

### SettingsView Structure

```
┌──────────────────────────────────────────────────────────────┐
│ Settings │                                                   │
├──────────┼───────────────────────────────────────────────────┤
│          │  General Settings                                 │
│ ⚙ General│  Configure basic app behavior                     │
│          ├───────────────────────────────────────────────────┤
│ 🌐 Language│ ☑ Launch at login                               │
│          │ ☑ Automatically insert transcribed text           │
│ 🔊 Audio │ ☐ Copy text to clipboard                          │
│          ├───────────────────────────────────────────────────┤
│ 🔒 Privacy│  Global Hotkey                                   │
│          │  Press the key combination to record speech       │
│          │  [⌘⌃Space]  [Change...]                          │
├──────────┴───────────────────────────────────────────────────┤
│  ⚠ Validation error here        [Reset to Defaults]  ✓      │
└──────────────────────────────────────────────────────────────┘
```

### Settings Tabs

| Tab | Icon | Key Settings |
|-----|------|--------------|
| General | gearshape | Launch at login, auto-insert, clipboard, hotkey |
| Language | globe | Auto-detect, default language picker |
| Audio | waveform | Sensitivity slider, silence threshold |
| Privacy | lock.shield | Anonymous stats, history storage |

---

## Test Cases

### T01: testSettingsWindowOpens

**Objective**: Verify settings window opens via keyboard shortcut

**Preconditions**:

- App running with `--skip-onboarding`

**Steps**:

1. Press ⌘, (Command + Comma)
2. Observe settings window

**Expected Results**:

- Settings window appears (640x480)
- Sidebar visible with 4 tabs
- General tab selected by default
- Window title: "Settings"

**UI Elements**:

```swift
app.windows["Settings"]
app.outlines.cells.count == 4 // 4 tabs
app.outlines.cells["General"].isSelected
```

---

### T02: testSettingsTabNavigation

**Objective**: Verify all settings tabs are accessible

**Preconditions**:

- Settings window open

**Steps**:

1. Click each tab in sidebar: General → Language → Audio → Privacy
2. Observe content changes

**Expected Results**:

- Each tab click changes content area
- Tab selection highlighted in sidebar
- Content scrollable if needed
- No layout issues or overlapping

**Tab Content Verification**:

```swift
// General tab
app.toggles["Launch at login"]
app.toggles["Automatically insert transcribed text"]
app.toggles["Copy text to clipboard"]

// Language tab
app.toggles["Automatically detect language"]
app.textFields["Search languages"]

// Audio tab
app.sliders["Audio Sensitivity"]
app.sliders["Silence Detection"]

// Privacy tab
app.toggles["Collect anonymous usage statistics"]
app.toggles["Store transcription history"]
```

---

### T03: testHotkeyCustomization

**Objective**: Verify hotkey configuration UI

**Preconditions**:

- Settings → General tab open

**Steps**:

1. Observe current hotkey display
2. Click "Change..." button
3. (Future: Record new hotkey)

**Expected Results**:

- Current hotkey displayed in monospace font
- Format: "⌘⌃Space" (modifiers + key name)
- "Change..." button visible
- Hotkey conflicts show error message

**Code Reference** (`SettingsView.swift:160-167`):

```swift
private var hotkeyDisplayString: String {
    let modifiers = viewModel.settings.hotkey.modifiers
        .map { $0.symbol }
        .joined()
    return "\(modifiers)\(viewModel.settings.hotkey.keyName)"
}
```

---

### T04: testAudioSensitivitySlider

**Objective**: Verify audio sensitivity slider functions correctly

**Preconditions**:

- Settings → Audio tab open

**Steps**:

1. Observe initial slider position
2. Drag slider to different positions (Low, Medium, High)
3. Observe value changes

**Expected Results**:

- Slider range: 0.1 to 1.0 (step 0.05)
- Current value displayed below slider
- "Low" label on left, "High" on right
- Changes trigger `updateAudioSensitivity()` async call
- Save indicator shows after change

**UI Elements**:

```swift
app.sliders.firstMatch // Audio Sensitivity slider
app.staticTexts["Low"]
app.staticTexts["High"]
app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Current:'"))
```

---

### T05: testSilenceThresholdSlider

**Objective**: Verify silence detection threshold slider

**Preconditions**:

- Settings → Audio tab open

**Steps**:

1. Locate silence detection slider
2. Adjust value from 1.5s to 2.5s
3. Observe value update

**Expected Results**:

- Slider range: 0.5s to 3.0s (step 0.1)
- Current value displayed: "Current: X.X seconds"
- Changes persist to UserDefaults
- Affects recording behavior (silence auto-stop)

---

### T06: testAutoLaunchToggle

**Objective**: Verify launch at login toggle

**Preconditions**:

- Settings → General tab open

**Steps**:

1. Toggle "Launch at login" ON
2. Observe change
3. Toggle OFF

**Expected Results**:

- Toggle state persists
- Login item registered/unregistered with system
- No error messages

**Note**: Actual login item registration may require entitlements and can't be fully tested in sandbox.

---

### T07: testPrivacySettings

**Objective**: Verify privacy toggles and information display

**Preconditions**:

- Settings → Privacy tab open

**Steps**:

1. Toggle "Collect anonymous usage statistics"
2. Toggle "Store transcription history"
3. Observe privacy information card

**Expected Results**:

- Toggles persist to UserDefaults
- Privacy info card visible:
  - Icon: lock.shield.fill (amber)
  - Title: "100% Local Processing"
  - Description about FluidAudio SDK
- Card has amber background (10% opacity)

---

### T08: testResetToDefaults

**Objective**: Verify reset to defaults functionality

**Preconditions**:

- Settings modified from defaults

**Steps**:

1. Change several settings
2. Click "Reset to Defaults"
3. Observe all settings

**Expected Results**:

- All settings return to default values:
  - `launchAtLogin`: false
  - `autoInsertText`: true
  - `copyToClipboard`: false
  - `sensitivity`: 0.5
  - `silenceThreshold`: 1.5
  - `defaultLanguage`: "en"
- Confirmation may be required (alert dialog)

---

### T09: testSettingsValidation

**Objective**: Verify validation error display

**Preconditions**:

- Settings open

**Steps**:

1. Trigger validation error (e.g., hotkey conflict)
2. Observe error display

**Expected Results**:

- Error shown in footer with warning icon
- Red color styling
- Specific error message
- Save indicator hidden when error present

**Code Reference** (`SettingsView.swift:335-342`):

```swift
if let error = viewModel.validationError {
    Label(error, systemImage: "exclamationmark.triangle.fill")
        .font(.caption)
        .foregroundStyle(.red)
}
```

---

### T10: testSettingsAutoSave

**Objective**: Verify settings auto-save on change

**Preconditions**:

- Settings open

**Steps**:

1. Change a toggle
2. Observe save indicator
3. Close and reopen settings

**Expected Results**:

- Save indicator (spinner then checkmark) appears after change
- Changes persisted immediately (no manual save button)
- Settings retained after window close/reopen

---

## Test Infrastructure

### Test Helpers

```swift
extension XCUIApplication {
    var settingsWindow: XCUIElement {
        windows["Settings"]
    }

    func selectSettingsTab(_ tab: String) {
        outlines.cells[tab].tap()
    }

    var audioSensitivitySlider: XCUIElement {
        // Find slider in Audio tab
        sliders.element(boundBy: 0)
    }

    var silenceThresholdSlider: XCUIElement {
        sliders.element(boundBy: 1)
    }
}
```

### Default Settings Reference

```swift
struct DefaultSettings {
    static let launchAtLogin = false
    static let autoInsertText = true
    static let copyToClipboard = false
    static let audioSensitivity = 0.5
    static let silenceThreshold = 1.5
    static let defaultLanguage = "en"
    static let autoDetectLanguage = false
    static let collectAnonymousStats = true
    static let storeHistory = true
}
```

---

## Acceptance Criteria

- [ ] All 10 test cases implemented and passing
- [ ] Tab navigation smooth and reliable
- [ ] Slider interactions work correctly
- [ ] Settings persist across app restarts
- [ ] Validation errors display properly
- [ ] Auto-save verified
- [ ] Tests run in < 45 seconds total
