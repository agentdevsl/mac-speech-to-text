# Accessibility Test Plans

**Related**: All views, VoiceOver, Keyboard Navigation
**Priority**: Lower (Compliance)

## Overview

These tests ensure the application is accessible to users with disabilities, following macOS accessibility guidelines and WCAG standards.

---

## VoiceOver Tests

### T01: testVoiceOverRecordingModal

**Objective**: Verify VoiceOver announces recording modal elements correctly

**Preconditions**:

- VoiceOver enabled (⌘F5)
- Recording modal open

**Navigation Order** (expected):

1. Close button ("Close, button")
2. Status title ("Recording")
3. Subtitle ("Speak now...")
4. Language indicator (if present)
5. Waveform ("Audio waveform visualization, Audio level at X percent")
6. Transcribed text (if present)
7. Action buttons ("Stop Recording, button", "Cancel, button")

**Expected Announcements**:

```
- Header: "Recording, mic.fill"
- Waveform: "Audio waveform visualization, Audio level at [X] percent"
- Status: "Transcribing..." with ProgressView announcement
- Buttons: "Stop Recording, button" / "Cancel, button"
```

**Code Reference** (`WaveformView.swift:72-73`):

```swift
.accessibilityLabel("Audio waveform visualization")
.accessibilityValue("Audio level at \(Int(audioLevel * 100)) percent")
```

---

### T02: testVoiceOverOnboarding

**Objective**: Verify VoiceOver navigation through onboarding

**Steps**:

1. Start app fresh (first launch)
2. Navigate each onboarding step with VoiceOver
3. Verify announcements

**Expected Announcements**:

**Welcome Step**:

- "Welcome to Speech-to-Text"
- Feature rows with icons and descriptions
- "Continue, button"

**Permission Steps**:

- Step title and description
- Permission card status ("granted" / "not granted")
- Action button ("Grant Microphone Access, button")
- Instructions (numbered steps)

**Completion Step**:

- "You're All Set!"
- Quick tips with icons
- "Get Started, button"

---

### T03: testVoiceOverSettings

**Objective**: Verify VoiceOver navigation in settings

**Expected Navigation**:

1. Sidebar tabs (General, Language, Audio, Privacy)
2. Section headers
3. Toggle controls with states
4. Sliders with values
5. Footer elements

**Slider Announcements**:

```
"Audio Sensitivity, [value], adjustable"
"Silence Detection, [value] seconds, adjustable"
```

---

### T04: testVoiceOverLanguagePicker

**Objective**: Verify VoiceOver in language picker

**Expected Announcements**:

```swift
// Language row
"\(language.name), \(isSelected ? "selected" : "not selected"), \(downloadStatusText)"

// Hints
"Double tap to select this language"
"Currently selected language"

// Search field
"Search languages, text field"
"Clear search, button"
```

**Code Reference** (`LanguagePicker.swift:126-128`):

```swift
.accessibilityLabel("\(language.name), \(isSelected ? "selected" : "not selected"), \(downloadStatusText)")
.accessibilityHint(isSelected ? "Currently selected language" : "Double tap to select this language")
```

---

## Keyboard Navigation Tests

### T05: testKeyboardNavigationRecordingModal

**Objective**: Verify full keyboard access in recording modal

**Key Bindings**:

| Key | Action |
|-----|--------|
| `⏎ Return` | Stop Recording (when recording) |
| `⎋ Escape` | Cancel/Dismiss |
| `Tab` | Move focus between elements |
| `Space` | Activate focused button |

**Focus Order**:

1. Stop Recording button (default focus when recording)
2. Cancel button
3. Close button (in header)

**Code References**:

```swift
// Escape key
.onKeyPress(.escape) {
    handleDismiss()
    return .handled
}

// Return key for Stop button
.keyboardShortcut(.return)
```

---

### T06: testKeyboardNavigationOnboarding

**Objective**: Verify keyboard navigation through onboarding

**Key Bindings**:

| Key | Action |
|-----|--------|
| `⏎ Return` | Continue/Next step |
| `Tab` | Move focus |
| `Shift+Tab` | Move focus backward |

**Expected Behavior**:

- Tab through all interactive elements
- Return activates primary button
- Focus visible (ring indicator)

---

### T07: testKeyboardNavigationSettings

**Objective**: Verify keyboard access in settings

**Key Bindings**:

| Key | Action |
|-----|--------|
| `⌘,` | Open settings |
| `⌘W` | Close settings |
| `Tab` | Navigate elements |
| `Space` | Toggle switches |
| `←→` | Adjust sliders |

**Expected Behavior**:

- Tab cycles through sidebar and content
- Arrow keys adjust sliders
- Space toggles checkboxes

---

### T08: testGlobalHotkeyAccessibility

**Objective**: Verify global hotkey is accessible

**Default Hotkey**: ⌘⌃Space (Command + Control + Space)

**Considerations**:

- Hotkey doesn't conflict with VoiceOver commands
- Hotkey works with various keyboard layouts
- Alternative activation method (menu bar click)

---

## Color and Contrast Tests

### T09: testColorContrastCompliance

**Objective**: Verify color contrast meets WCAG AA standards

**Elements to Check**:

| Element | Foreground | Background | Ratio Required |
|---------|------------|------------|----------------|
| Body text | Primary | Clear | 4.5:1 |
| Large text | Primary | Clear | 3:1 |
| Error text | Red | Red 10% | 4.5:1 |
| Amber accent | AmberPrimary | Clear | 3:1 |

**Amber Palette** (from `Color+Theme.swift`):

```swift
AmberLight: rgb(1.0, 0.9, 0.7)
AmberPrimary: rgb(1.0, 0.75, 0.3)
AmberBright: rgb(1.0, 0.6, 0.0)
```

---

### T10: testReducedMotionSupport

**Objective**: Verify app respects reduced motion preference

**System Setting**: Accessibility → Display → Reduce motion

**Expected Behavior**:

- Spring animations simplified or disabled
- Waveform animation less dynamic
- Modal transitions faster/simpler

**Code Check**:

```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

// Conditional animation
.animation(reduceMotion ? .none : .spring(...), value: state)
```

---

### T11: testIncreasedContrastSupport

**Objective**: Verify app works with increased contrast

**System Setting**: Accessibility → Display → Increase contrast

**Expected Behavior**:

- Borders more visible
- Colors more saturated
- Focus rings more prominent

---

## Focus and Selection Tests

### T12: testFocusRingVisibility

**Objective**: Verify focus rings are visible on all interactive elements

**Elements to Check**:

- Buttons (standard, bordered, borderedProminent)
- Text fields
- Toggles
- Sliders
- Language rows

**Expected**:

- Clear visual indicator when element has focus
- Focus follows tab order
- No "invisible" focusable elements

---

### T13: testTouchBarSupport

**Objective**: Verify Touch Bar support (if applicable)

**Touch Bar Elements** (MacBooks with Touch Bar):

- Recording state indicator
- Quick actions (Stop, Cancel)
- Language selector

---

## Test Infrastructure

### Accessibility Audit Helper

```swift
extension XCUIApplication {
    func performAccessibilityAudit() throws {
        // iOS 17+ / macOS 14+ accessibility audit
        try performAccessibilityAudit(for: .all)
    }

    func verifyAccessibilityLabels(for element: XCUIElement) {
        XCTAssertFalse(element.label.isEmpty, "Missing accessibility label")
    }

    func verifyFocusOrder(_ elements: [XCUIElement]) {
        for (index, element) in elements.enumerated() {
            element.tap()
            if index < elements.count - 1 {
                XCUIApplication().typeKey(.tab, modifierFlags: [])
                XCTAssertTrue(elements[index + 1].hasFocus)
            }
        }
    }
}
```

### VoiceOver Test Helpers

```swift
extension XCUIElement {
    var voiceOverLabel: String {
        return value(forKey: "accessibilityLabel") as? String ?? label
    }

    var voiceOverHint: String? {
        return value(forKey: "accessibilityHint") as? String
    }
}
```

---

## Accessibility Checklist

### Per-View Checklist

- [ ] All interactive elements have accessibility labels
- [ ] Images have descriptive labels (not "image")
- [ ] Buttons have clear action labels ("Stop Recording" not "Stop")
- [ ] State changes announced (recording → transcribing)
- [ ] Error messages accessible
- [ ] Focus order logical (top to bottom, left to right)
- [ ] Keyboard shortcuts documented
- [ ] Color not sole indicator of state

### Global Checklist

- [ ] VoiceOver navigation complete
- [ ] Full keyboard access possible
- [ ] Reduced motion respected
- [ ] Increased contrast supported
- [ ] Touch Bar support (if applicable)
- [ ] No accessibility audit failures

---

## Acceptance Criteria

- [ ] All 13 test cases implemented and passing
- [ ] VoiceOver announces all elements correctly
- [ ] Full keyboard navigation possible
- [ ] Color contrast meets WCAG AA
- [ ] Reduced motion preference respected
- [ ] Accessibility audit passes
- [ ] Tests run in < 60 seconds total
