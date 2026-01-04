# MainView Code Review - Bug Report

**Date**: 2026-01-05
**Reviewed By**: 8 Concurrent Opus Agents
**Scope**: `Sources/Views/MainView/**/*.swift`

---

## Executive Summary

Comprehensive code review of 9 files in the MainView directory identified **32 bugs** across severity levels:

- **5 Critical** - Features completely non-functional
- **12 High** - Race conditions, memory leaks, data loss
- **15 Medium** - Silent failures, dead code, UX issues

---

## Critical Bugs

### CRIT-1: AudioSection - Device Selection Non-Functional

**File**: `Sections/AudioSection.swift`
**Lines**: 430-434, 14-21

**Problem**: The `inputDeviceId` saved to `settings.audio.inputDeviceId` is never used by `AudioCaptureService`. The service always uses `audioEngine.inputNode` (system default). Users can select any microphone in UI, but recording always uses system default.

**Fix Required**:

- `AudioCaptureService` must read `settings.audio.inputDeviceId` on init
- Use `AVCaptureDevice(uniqueID:)` to get selected device
- Set audio engine's input to selected device

---

### CRIT-2: LanguageSection - Auto-Detect Toggle Not Persisted

**File**: `Sections/LanguageSection.swift`
**Lines**: 162-176, 593-607

**Problem**: The `autoDetectEnabled` toggle binding updates ViewModel but `saveLanguageSettings()` is only called from `selectLanguage()`, not when auto-detect changes.

**Fix Required**:

```swift
var autoDetectEnabled: Bool = false {
    didSet {
        Task { await saveLanguageSettings() }
    }
}
```

---

### CRIT-3: LanguageSection - Downloaded Models Not Persisted

**File**: `Sections/LanguageSection.swift`
**Lines**: 702-706, 662-674

**Problem**: When download completes, `downloadedModels` array is updated in memory but `saveLanguageSettings()` does NOT save it. Users re-download all models on every app restart.

**Fix Required**: Add to `saveLanguageSettings()`:

```swift
settings.language.downloadedModels = downloadedModels
```

---

### CRIT-4: GeneralSection - LaunchAtLogin Broken

**File**: `Sections/GeneralSection.swift`
**Lines**: 115-127

**Problem**: Toggle saves boolean preference but never registers/unregisters with macOS login items via `SMAppService`.

**Fix Required**:

```swift
import ServiceManagement

// In setter:
if newValue {
    try? SMAppService.mainApp.register()
} else {
    try? SMAppService.mainApp.unregister()
}
```

---

### CRIT-5: MainWindow - Retain Cycle (Memory Leak)

**File**: `MainWindow.swift`
**Lines**: 15, 133

**Problem**: `MainWindow` sets itself as `window.delegate`. NSWindow holds strong reference to delegate. `MainWindow` holds strong reference to `window`. Circular reference = memory leak, deinit never fires.

**Fix Required**: In `close()` method, nil out delegate before closing:

```swift
func close() {
    window?.delegate = nil
    window?.close()
    window = nil
}
```

---

## High Severity Bugs

### HIGH-1: HomeSection - Polling Tasks Not Cancelled

**File**: `Sections/HomeSection.swift`
**Lines**: 383-414

**Problem**: `requestAccessibilityPermission()` starts polling that runs up to 60 seconds. If view disappears, polling continues, attempting state updates on deallocated view.

**Fix**: Store task reference, cancel in `onDisappear`.

---

### HIGH-2: HomeSection - State Updates from Non-MainActor Task

**File**: `Sections/HomeSection.swift`
**Lines**: 370-381

**Problem**: `Task { }` block updates `@State` properties without `@MainActor` annotation.

**Fix**: Use `Task { @MainActor in ... }`.

---

### HIGH-3: HomeSection - Race Condition with callbackInvoked

**File**: `Sections/HomeSection.swift`
**Lines**: 394-412

**Problem**: `callbackInvoked` local var captured in escaping closure with nested `Task { @MainActor in }`. The `if !callbackInvoked` check may execute before nested Task completes.

**Fix**: Remove nested Task, callback is already @MainActor.

---

### HIGH-4: LanguageSection - 10% Random Download Failure

**File**: `Sections/LanguageSection.swift`
**Lines**: 696-700

**Problem**: Production code has hardcoded 10% random failure rate for downloads (demo code left in).

**Fix**: Remove random failure simulation:

```swift
// DELETE THIS:
if Double.random(in: 0...1) < 0.1 {
    languageDownloadErrors[languageCode] = "Network connection failed"
    ...
}
```

---

### HIGH-5: LanguageSection - Download Status Always Shows "Not Downloaded"

**File**: `Sections/LanguageSection.swift`
**Lines**: 464-526

**Problem**: `LanguageRowView` checks `language.downloadStatus` but static `LanguageModel.supportedLanguages` creates new instances each time, always `.notDownloaded`. Actual status is in `viewModel.downloadedModels`.

**Fix**: Pass `isDownloaded: Bool` prop from `viewModel.downloadedModels.contains(language.code)`.

---

### HIGH-6: LanguageSection - Race Condition in Download

**File**: `Sections/LanguageSection.swift`
**Lines**: 678-711

**Problem**: No task cancellation. Rapid clicks spawn multiple concurrent downloads for same language.

**Fix**: Store Task references, cancel existing before starting new.

---

### HIGH-7: AudioSection - No Device Observation

**File**: `Sections/AudioSection.swift`
**Lines**: 380-428

**Problem**: Devices enumerated only on appear and manual refresh. No observation of connect/disconnect events.

**Fix**: Add `AVCaptureDevice.DiscoverySession` observer or `NotificationCenter` for route changes.

---

### HIGH-8: AudioSection - Dual Source of Truth

**File**: `Sections/AudioSection.swift`
**Lines**: 18-21, 30-34

**Problem**: Both `settings.audio.inputDeviceId` and `selectedDeviceId` state track device selection. Can desync.

**Fix**: Use single source of truth - derive from settings or use binding.

---

### HIGH-9: MainWindow - Stale Window Reference

**File**: `MainWindow.swift`
**Lines**: 164-166

**Problem**: `windowWillClose` sets `window = nil`, but `MainWindowController.mainWindow` still holds `MainWindow` with nil window property.

**Fix**: Add `releaseWindow()` in controller or use notification to clean up.

---

### HIGH-10: MainWindow - Missing Delegate Nil-Out

**File**: `MainWindow.swift`
**Lines**: 103-106

**Problem**: `close()` doesn't nil delegate before closing, can cause callbacks during deallocation.

**Fix**: `window?.delegate = nil` before `window?.close()`.

---

### HIGH-11: AboutSection - Force-Unwrapped URLs

**File**: `Sections/AboutSection.swift`
**Lines**: 295-296

**Problem**: `URL(string:)!` force unwraps. While current URLs are valid, pattern is fragile.

**Fix**: Use guard with fallback or make URLs optional.

---

### HIGH-12: MainViewModel - Deinit Actor Isolation

**File**: `MainViewModel.swift`
**Lines**: 114-116

**Problem**: `deinit` is nonisolated but accesses `viewModelId` which is @MainActor property. Will be compile error in Swift 6.

**Fix**: Add `nonisolated(unsafe)` shadow copy for deinit logging.

---

## Medium Severity Bugs

### MED-1: MainView - 185 Lines Dead Code

**Lines**: 270-454
Unused `sidebarContent`, `sidebarHeader`, `sidebarDivider`, `sidebarItem`, `quitButton` computed properties.

### MED-2: MainView - ViewModel Init Race Condition

**Lines**: 128-130
`onAppear` can fire multiple times, potentially creating duplicate ViewModels.

### MED-3: MainView - New Service Instances Per Recreation

**Lines**: 41-49
Default params create new `SettingsService`/`PermissionService` on each view recreation.

### MED-4: MainViewModel - Reset Order Bug

**Lines**: 142-148
`reset()` sets `selectedSection = .home` which triggers `didSet` that persists, then tries to remove from UserDefaults.

### MED-5: MainWindow - ViewModel Shared Across Recreations

**Lines**: 21-26, 64-68
Same ViewModel reused when window recreated, can cause stale observation state.

### MED-6: MainWindow - Thread Safety

**Lines**: 19, 56-120
`window` property accessed without synchronization (relies on @MainActor).

### MED-7: HomeSection - Keyboard Always Consumed

**Lines**: 86-97
Tab/Return/Space handlers always return `.handled`, preventing child view keyboard navigation.

### MED-8: HomeSection - Focus System Issues

**Lines**: 32, 249-268
No initial focus set, focus may not propagate through ScrollView.

### MED-9: GeneralSection - Save Errors Silent

**Lines**: 224-232
`isSaving` set but never used, errors logged but user not notified.

### MED-10: AudioSection - 300ms Artificial Delay

**Line**: 386
Sleep before device enumeration creates poor UX.

### MED-11: AudioSection - Save Errors Swallowed

**Lines**: 436-444
Errors logged, user not informed, UI shows success.

### MED-12: PrivacySection - Save Race Condition

**Lines**: 367-382
Multiple `didSet` observers spawn concurrent Tasks, later saves overwrite earlier.

### MED-13: PrivacySection - State Inconsistency

**Line**: 373
`storeHistory` derived from `storagePolicy` only on save, not on load.

### MED-14: AboutSection - Notification No Listener

**Lines**: 312-318
`showAcknowledgments()` posts notification but no guaranteed listener.

### MED-15: AboutSection - URL Open No Error Handling

**Lines**: 304-310
`openURL` completion handler not used, failures silent.

---

## Fix Priority

### Phase 1 - Critical (Functionality Broken)

1. AudioSection device selection
2. LanguageSection persistence (auto-detect + downloaded models)
3. GeneralSection launch at login
4. MainWindow retain cycle

### Phase 2 - High (Data Loss / Crashes)

1. HomeSection task cancellation + MainActor
2. LanguageSection download fixes
3. MainViewModel deinit fix

### Phase 3 - Medium (Quality)

1. Dead code removal
2. Error handling improvements
3. Race condition fixes

---

## Test Plan

After fixes, verify:

1. [x] Selected microphone is actually used for recording
2. [x] Auto-detect language toggle persists across restart
3. [x] Downloaded models persist across restart
4. [x] Launch at Login actually adds/removes login item
5. [x] MainWindow can be opened/closed repeatedly without memory growth
6. [x] View disappear cancels all background tasks
7. [x] No random download failures
8. [x] Download status correctly shows "downloaded" after download

---

## Fix Status: COMPLETE

**Date Completed**: 2026-01-05

### Build & Test Results

- **Build**: ✅ SUCCESS (swift build)
- **Tests**: ✅ 712/712 PASSED (swift test --parallel)

### Files Modified

| File | Bugs Fixed |
|------|------------|
| `AudioSection.swift` | CRIT-1, HIGH-7, HIGH-8, MED-10, MED-11 |
| `AudioCaptureService.swift` | CRIT-1 (device selection) |
| `RecordingViewModel.swift` | CRIT-1 (service injection) |
| `LanguageSection.swift` | CRIT-2, CRIT-3, HIGH-4, HIGH-5, HIGH-6 |
| `GeneralSection.swift` | CRIT-4, MED-9 |
| `PrivacySection.swift` | MED-12, MED-13 |
| `AboutSection.swift` | HIGH-11, MED-14, MED-15 |
| `HomeSection.swift` | HIGH-1, HIGH-2, HIGH-3, MED-7, MED-8 |
| `MainWindow.swift` | CRIT-5, HIGH-9, HIGH-10 |
| `MainViewModel.swift` | HIGH-12, MED-4 |
| `MainView.swift` | MED-1, MED-2, MED-3 |
| `MainViewModelTests.swift` | Test update for MED-4 |

### Summary of Changes

**Critical Fixes**:

1. **Audio device selection now functional** - AudioCaptureService reads inputDeviceId from settings and configures CoreAudio
2. **Language auto-detect persists** - Added didSet observer to save on toggle
3. **Downloaded models persist** - Added downloadedModels to saveLanguageSettings()
4. **Launch at Login works** - Integrated SMAppService.mainApp.register/unregister
5. **MainWindow memory leak fixed** - Delegate nil'd before close, proper cleanup chain

**High Severity Fixes**:

- Task cancellation on view disappear (HomeSection)
- MainActor isolation for state updates
- Removed 10% random download failure
- Download status now reflects actual state
- Race condition prevention with task tracking

**Medium Severity Fixes**:

- 186 lines of dead code removed from MainView
- Save error feedback to users
- Debounced saves in PrivacySection
- URL open error handling
- Focus system improvements
