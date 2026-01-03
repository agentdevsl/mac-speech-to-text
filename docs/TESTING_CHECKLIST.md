# SpeechToText Manual Testing Checklist

## Quick Start Commands

```bash
# Run app with debug logging + Console.app
./scripts/debug-run.sh

# Run integration tests (real services)
./scripts/run-integration-tests.sh

# Run specific test categories
./scripts/run-integration-tests.sh --permissions
./scripts/run-integration-tests.sh --audio
./scripts/run-integration-tests.sh --transcription

# Build release DMG
./scripts/build-app.sh --release --dmg
```

---

## Pre-Testing Setup

### 1. Grant Permissions

- [ ] **Microphone**: System Settings > Privacy & Security > Microphone
- [ ] **Accessibility**: System Settings > Privacy & Security > Accessibility
- [ ] **Input Monitoring**: System Settings > Privacy & Security > Input Monitoring

### 2. Verify Console.app Setup

- [ ] Open Console.app
- [ ] Start Streaming (if not already)
- [ ] In search bar, enter: `subsystem:com.speechtotext.app`
- [ ] Verify logs appear when running the app

---

## Onboarding Flow Tests

### Welcome Screen

- [ ] App icon displays correctly in menu bar
- [ ] Welcome screen appears on first launch
- [ ] Progress bar shows correctly
- [ ] "Next" button advances to next step

### Microphone Permission Step

- [ ] Permission card shows current status (granted/not granted)
- [ ] "Grant Microphone Access" button triggers permission dialog
- [ ] Status updates automatically when permission granted
- [ ] Can skip step (with warning)
- [ ] "Next" button enables when permission granted

### Accessibility Permission Step

- [ ] Permission card shows current status
- [ ] "Open System Settings" button opens correct Settings pane
- [ ] Status updates when permission granted (may need to restart app)
- [ ] Instructions are clear and accurate

### Input Monitoring Permission Step

- [ ] Permission card shows current status
- [ ] "Open System Settings" button opens correct Settings pane
- [ ] Status updates when permission granted

### Demo Step

- [ ] Hotkey instructions displayed correctly (⌘⌃Space)
- [ ] KeyCap views render properly

### Completion Step

- [ ] Checkmark animation plays
- [ ] "Get Started" button dismisses onboarding
- [ ] App doesn't show onboarding again on next launch

---

## Recording Flow Tests

### Hotkey Activation

- [ ] ⌘⌃Space triggers recording modal from any app
- [ ] Hotkey works while in full-screen apps
- [ ] Hotkey works while in other apps (TextEdit, Notes, etc.)
- [ ] No conflict with system shortcuts

### Recording Modal UI

- [ ] Modal appears centered on screen
- [ ] Frosted glass background effect visible
- [ ] Microphone icon shows recording state (red when recording)
- [ ] Pulse animation active during recording
- [ ] Current language displayed correctly

### Waveform Visualization

- [ ] Waveform responds to audio input
- [ ] Smooth animation (60fps)
- [ ] Amplitude reflects actual sound level
- [ ] Silent audio shows flat line

### Recording States

- [ ] "Recording..." status shown during capture
- [ ] "Transcribing..." status shown during processing
- [ ] "Inserting..." status shown during text insertion
- [ ] Error messages display correctly in red
- [ ] "Complete" status shown when done

### Dismissal

- [ ] Escape key dismisses modal
- [ ] Click outside modal dismisses it
- [ ] X button dismisses modal
- [ ] Cancel button dismisses modal
- [ ] Spring animation on dismiss

---

## Transcription Tests

### Basic Transcription

- [ ] Clear speech produces accurate text
- [ ] Multiple sentences transcribed correctly
- [ ] Punctuation inserted appropriately
- [ ] Capitalization correct

### Edge Cases

- [ ] Silent audio produces empty/minimal text
- [ ] Very short audio (< 1 second) handled
- [ ] Long audio (> 30 seconds) handled
- [ ] Background noise handling
- [ ] Multiple speakers (if applicable)

### Language Switching

- [ ] Can switch language in settings
- [ ] New language works for transcription
- [ ] Language indicator updates in UI

---

## Text Insertion Tests

### Basic Insertion

- [ ] Text inserted at cursor in TextEdit
- [ ] Text inserted at cursor in Notes
- [ ] Text inserted at cursor in VS Code
- [ ] Text inserted at cursor in web browser form

### Special Cases

- [ ] Text with special characters inserted correctly
- [ ] Long text inserted without truncation
- [ ] Insertion works in password-protected apps (with accessibility)

---

## Settings Tests

### Hotkey Configuration

- [ ] Hotkey can be changed
- [ ] Conflict detection works
- [ ] New hotkey activates immediately

### Audio Settings

- [ ] Sensitivity slider adjusts correctly
- [ ] Silence threshold slider adjusts correctly
- [ ] Changes saved and persist

### Language Settings

- [ ] Language picker shows all 25 languages
- [ ] Search filter works
- [ ] Language selection saved

---

## Performance Tests

### Responsiveness

- [ ] Hotkey response < 50ms
- [ ] Modal appears < 100ms
- [ ] Recording starts immediately
- [ ] Transcription completes < 500ms for 5s audio

### Memory

- [ ] Memory usage stable during long session
- [ ] No memory leaks after multiple recordings
- [ ] App doesn't slow down over time

### CPU

- [ ] CPU usage minimal when idle
- [ ] CPU usage reasonable during recording
- [ ] Neural Engine used for transcription

---

## Error Handling Tests

### Permission Errors

- [ ] Clear message when microphone denied
- [ ] Clear message when accessibility denied
- [ ] Recovery instructions provided

### Audio Errors

- [ ] Handles microphone disconnect
- [ ] Handles audio format issues
- [ ] Handles no audio input

### Transcription Errors

- [ ] Handles model initialization failure
- [ ] Handles transcription timeout
- [ ] Error recovery without restart

---

## Menu Bar Tests

### Menu Bar Icon

- [ ] Icon visible in menu bar
- [ ] Icon changes state during recording
- [ ] Menu bar popover opens on click

### Menu Content

- [ ] Settings option works
- [ ] Statistics displayed correctly
- [ ] Quit option works

---

## Stress Tests

### Rapid Recording

- [ ] 10 recordings in quick succession
- [ ] No crashes or hangs
- [ ] All recordings complete successfully

### Long Session

- [ ] App stable for 1+ hour of intermittent use
- [ ] No performance degradation
- [ ] Memory usage stable

---

## Debug Logging Verification

### Log Categories Working

Open Console.app with filter `subsystem:com.speechtotext.app` and verify logs from:

- [ ] `category:app` - Lifecycle events
- [ ] `category:service` - Service operations
- [ ] `category:viewModel` - ViewModel operations
- [ ] `category:audio` - Audio capture
- [ ] `category:system` - Permission checks
- [ ] `category:analytics` - Usage stats

---

## Sign-Off

| Test Category | Passed | Failed | Notes |
|---------------|--------|--------|-------|
| Onboarding | | | |
| Recording | | | |
| Transcription | | | |
| Text Insertion | | | |
| Settings | | | |
| Performance | | | |
| Error Handling | | | |
| Menu Bar | | | |
| Stress Tests | | | |

**Tester**: ________________
**Date**: ________________
**Build Version**: ________________
**macOS Version**: ________________
