# Next Steps: macOS Local Speech-to-Text Application

**Feature**: 001-local-speech-to-text
**Branch**: `001-local-speech-to-text`
**Current Status**: 47% Complete (40/86 tasks)
**Last Updated**: 2026-01-02

---

## Executive Summary

The project has completed foundational infrastructure (47% implementation) with comprehensive test coverage (RED phase), specification analysis, and three concurrent Opus-powered code reviews. **Critical issues have been identified that must be addressed before proceeding.**

### Current State

✅ **Complete**:
- Specification (spec.md, plan.md, tasks.md)
- Architecture design (Pure Swift + SwiftUI + FluidAudio SDK)
- Analysis with 92% requirements coverage
- 40/86 tasks implemented (Models, Services, App Infrastructure)
- 14 XCTest files with 250+ test functions (4,063 LOC)
- First code review iteration (3 concurrent agents)

🔴 **Blockers**:
- 11 CRITICAL code issues must be fixed
- Tests are in RED phase (expected to fail until GREEN implementation)
- 46 tasks remaining for full feature set

---

## Immediate Actions Required (Before PR)

### Priority 1: Fix Critical Compilation/Crash Issues

These issues will prevent the app from compiling or cause immediate crashes:

#### 1. UIColor Usage on macOS (BLOCKS COMPILATION)

**File**: `/workspace/Sources/Utilities/Extensions/Color+Theme.swift:40-44`

**Issue**: Uses `UIColor` which doesn't exist on macOS. Code will not compile.

**Fix**:
```swift
// BEFORE (BROKEN):
static func adaptive(light: Color, dark: Color) -> Color {
    Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark ?
            UIColor(dark) : UIColor(light)
    })
}

// AFTER (FIXED):
static func adaptive(light: Color, dark: Color) -> Color {
    Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ?
            NSColor(dark) : NSColor(light)
    })
}
```

**Impact**: Without this fix, the entire project fails to build.

---

#### 2. Force Cast Crash in TextInsertionService

**File**: `/workspace/Sources/Services/TextInsertionService.swift:44`

**Issue**: Force cast can crash if element type is unexpected.

**Fix**:
```swift
// BEFORE (CRASH RISK):
let axElement = element as! AXUIElement

// AFTER (SAFE):
guard let axElement = element as? AXUIElement else {
    try await copyToClipboard(text)
    return
}
```

**Impact**: Prevents crash when focused element is not an AXUIElement.

---

#### 3. Division by Zero in AudioBuffer

**File**: `/workspace/Sources/Models/AudioBuffer.swift:27-28`

**Issue**: Crashes when samples array is empty.

**Fix**:
```swift
// BEFORE (CRASH RISK):
let sumOfSquares = samples.reduce(0.0) { $0 + pow(Double($1), 2) }
self.rmsLevel = sqrt(sumOfSquares / Double(samples.count))

// AFTER (SAFE):
if samples.isEmpty {
    self.rmsLevel = 0.0
} else {
    let sumOfSquares = samples.reduce(0.0) { $0 + pow(Double($1), 2) }
    self.rmsLevel = sqrt(sumOfSquares / Double(samples.count))
}
```

**Impact**: Prevents `nan` values in RMS calculations.

---

#### 4. Force Unwrap in HotkeyService Callback

**File**: `/workspace/Sources/Services/HotkeyService.swift:47-48`

**Issue**: Unsafe memory access can crash if service deallocated before event fires.

**Fix**: Use `Unmanaged.passRetained` with proper cleanup in deinit:
```swift
// In registerHotkey():
let selfPointer = Unmanaged.passRetained(self).toOpaque()

// In deinit:
deinit {
    if hotKeyRef != nil || eventHandler != nil {
        unregisterHotkey()
    }
    // Release the retained reference
    Unmanaged.passUnretained(self).release()
}
```

**Impact**: Prevents crash from dangling pointer access.

---

### Priority 2: Fix Critical Silent Failures

These issues cause data loss or confusing UX without user notification:

#### 5. Silent Clipboard Fallback in TextInsertionService

**File**: `/workspace/Sources/Services/TextInsertionService.swift:17-42`

**Issue**: Text insertion silently falls back to clipboard in 3 scenarios without telling user.

**Fix**: Return a result enum indicating what happened:
```swift
enum InsertionResult {
    case inserted
    case copiedToClipboard(reason: String)
}

func insertText(_ text: String) async throws -> InsertionResult {
    guard let focusedApp = NSWorkspace.shared.frontmostApplication else {
        try await copyToClipboard(text)
        return .copiedToClipboard(reason: "No focused application")
    }
    // ... existing logic
}
```

Then notify user in AppState when fallback occurs.

**Impact**: User knows text is in clipboard and needs to paste manually.

---

#### 6. Silent Settings/Statistics Data Loss

**Files**:
- `/workspace/Sources/Services/SettingsService.swift:13-19`
- `/workspace/Sources/Services/StatisticsService.swift:126-131`

**Issue**: JSON decoding failures silently reset to defaults, losing user data.

**Fix**: Log the actual error:
```swift
// In SettingsService.load():
do {
    return try JSONDecoder().decode(UserSettings.self, from: data)
} catch {
    print("[SettingsService] ⚠️ Failed to decode settings: \(error). Resetting to defaults.")
    // TODO: Notify user via AppState.errorMessage
    return .default
}
```

**Impact**: Developers can diagnose issues, users are notified of resets.

---

#### 7. Input Monitoring Permission Always Returns True

**File**: `/workspace/Sources/Services/PermissionService.swift:73-78`

**Issue**: Always returns `true`, never actually checks permission.

**Fix**: Either implement actual check or clearly document deferral:
```swift
func checkInputMonitoringPermission() -> Bool {
    // NOTE: macOS doesn't provide a direct API to check input monitoring permission
    // before attempting to use it. Permission is implicitly checked when registering
    // global hotkeys via Carbon Event Manager APIs.
    // If hotkey registration fails, that indicates permission denial.
    //
    // For now, we assume granted and handle denial during registration.
    return true
}
```

**Impact**: Sets correct expectations, ensures registration code handles errors properly.

---

### Priority 3: Fix Thread Safety Issues

#### 8. StreamingAudioBuffer Not Thread-Safe

**File**: `/workspace/Sources/Models/AudioBuffer.swift:40-79`

**Issue**: Class accessed from audio callback thread without synchronization.

**Fix**: Convert to actor:
```swift
actor StreamingAudioBuffer {
    private(set) var chunks: [AudioBuffer] = []
    private let maxChunkSize: Int

    init(maxChunkSize: Int = 1600) {
        self.maxChunkSize = maxChunkSize
    }

    func append(_ buffer: AudioBuffer) {
        chunks.append(buffer)
    }

    func clear() {
        chunks.removeAll()
    }

    var allSamples: [Int16] {
        chunks.flatMap { $0.samples }
    }
}
```

**Impact**: Prevents data races in audio processing.

---

### Priority 4: Fix Missing Error Handling

#### 9. AppState Initialization Race Condition

**File**: `/workspace/Sources/SpeechToTextApp/SpeechToTextApp.swift:16-21`

**Issue**: Task accesses `@State` property without lifecycle guarantee.

**Fix**: Move to `.task` modifier:
```swift
var body: some Scene {
    MenuBarExtra("Speech to Text", systemImage: "mic.fill") {
        MenuBarView()
            .environment(appState)
    }
    .task {
        await appState.initializeFluidAudio()
    }
}
```

**Impact**: Ensures initialization completes before view renders.

---

#### 10. Missing Sendable Conformance

**File**: `/workspace/Sources/Services/FluidAudioService.swift:12-36`

**Issue**: `FluidAudioError` used across async contexts without `Sendable`.

**Fix**:
```swift
enum FluidAudioError: Error, LocalizedError, Sendable {
    // ... existing cases
}
```

**Impact**: Fixes Swift 6 strict concurrency warnings.

---

#### 11. Deprecated synchronize() Calls

**Files**: SettingsService.swift:31, StatisticsService.swift:110,139

**Issue**: `synchronize()` is deprecated and unnecessary.

**Fix**: Remove all calls:
```swift
// BEFORE:
userDefaults.set(data, forKey: settingsKey)
userDefaults.synchronize()  // <-- DELETE THIS LINE

// AFTER:
userDefaults.set(data, forKey: settingsKey)
```

**Impact**: Removes deprecated API usage.

---

## Implementation Roadmap

### Phase 1: Critical Fixes (1-2 hours)

**Goal**: Make code compile and eliminate crash risks.

**Tasks**:
1. ✅ Fix UIColor → NSColor (Color+Theme.swift)
2. ✅ Fix force cast → safe cast (TextInsertionService.swift:44)
3. ✅ Fix division by zero (AudioBuffer.swift:27-28)
4. ✅ Fix unsafe memory access (HotkeyService.swift:47-48)
5. ✅ Add Sendable conformance (FluidAudioError)
6. ✅ Remove synchronize() calls (all services)
7. ✅ Convert StreamingAudioBuffer to actor

**Validation**: `swift build` succeeds without errors.

---

### Phase 2: Silent Failure Fixes (2-3 hours)

**Goal**: Eliminate data loss and improve user feedback.

**Tasks**:
1. ✅ Add InsertionResult enum and user notifications (TextInsertionService)
2. ✅ Add error logging to settings/statistics decoding
3. ✅ Fix input monitoring permission check or document deferral
4. ✅ Add logging for CGEvent creation failures
5. ✅ Check NSWorkspace.open() return value
6. ✅ Add logging for hotkey unregistration failures

**Validation**: Run app and verify error messages appear in logs.

---

### Phase 3: Type Design Improvements (3-4 hours)

**Goal**: Improve encapsulation and invariant enforcement.

**Priority Improvements** (from Type Design Analysis):

1. **RecordingSession**:
   - Add `private(set)` to mutable fields
   - Create state transition validation method
   - Add `ConfidenceScore` value type (0.0-1.0 enforcement)

2. **UserSettings**:
   - Create `Sensitivity` value type (0.0-1.0 enforcement)
   - Use `SupportedLanguage` enum instead of raw strings
   - Make fields `private(set)` with validated update methods

3. **LanguageModel**:
   - Change `languageCode: String` to `language: SupportedLanguage`
   - Create `SHA256Checksum` value type

4. **AppState**:
   - Make state fields `private(set)`
   - Derive `isRecording` from `currentSession` instead of duplicating

**Validation**: All tests still pass after refactoring.

---

### Phase 4: Complete MVP Views (5-8 hours)

**Goal**: Finish remaining 8 tasks for User Story 1 MVP.

**Tasks Remaining** (T025-T032, T085-T086):
- [ ] T025: RecordingViewModel coordination layer
- [ ] T026: WaveformView real-time visualization
- [ ] T027: RecordingModal frosted glass UI
- [ ] T028: HotkeyService integration with AppDelegate
- [ ] T029: Silence detection with FluidAudio VAD
- [ ] T030: Modal dismissal (Escape/outside click)
- [ ] T031: Error handling in RecordingViewModel
- [ ] T032: Clipboard fallback (already implemented, needs testing)
- [ ] T085: Progress indicator for long recordings (FR-017)
- [ ] T086: Microphone disconnection recovery (FR-022)

**Validation**:
- User can press ⌘⌃Space, speak, and see text appear
- Tests pass for all new ViewModels and Views
- Manual E2E test successful in TextEdit

---

### Phase 5: Second Code Review Iteration (1-2 hours)

**Goal**: Verify all critical issues resolved, catch any regressions.

**Process**:
1. Run 3 concurrent Opus agents again:
   - Code quality reviewer
   - Type design analyzer
   - Silent failure hunter
2. Address any new findings
3. Ensure no critical/high issues remain

**Validation**: All critical/high issues resolved, only low/medium remain.

---

### Phase 6: Test Suite Validation (2-3 hours)

**Goal**: Move from RED to GREEN phase.

**Tasks**:
1. Set up Xcode project with FluidAudio SDK dependency
2. Run all XCTests and fix compilation errors
3. Add FluidAudio SDK mocks for tests that require it
4. Achieve GREEN state (all tests passing or properly skipped)
5. Verify >80% code coverage per plan.md

**Validation**: `swift test` shows all tests passing.

---

### Phase 7: Create Pull Request (30 minutes)

**Goal**: Submit PR for review.

**Checklist**:
- [ ] All critical/high issues from code reviews resolved
- [ ] All tests passing (GREEN phase)
- [ ] SwiftLint passes (no violations)
- [ ] Update IMPLEMENTATION_STATUS.md with final status
- [ ] Commit all changes with descriptive messages
- [ ] Push branch to remote
- [ ] Create PR with comprehensive summary
- [ ] Link PR to GitHub issue #2

**PR Template**:
```markdown
## Summary

Implements foundational infrastructure for macOS Local Speech-to-Text Application (47% complete).

**Architecture**: Pure Swift + SwiftUI + FluidAudio SDK

### Changes

**Models** (5 files):
- RecordingSession, UserSettings, LanguageModel, UsageStatistics, AudioBuffer

**Services** (7 files):
- FluidAudioService (actor-based ML inference)
- PermissionService, SettingsService, StatisticsService
- HotkeyService, AudioCaptureService, TextInsertionService

**App Infrastructure** (3 files):
- AppState (@Observable), SpeechToTextApp, AppDelegate

**Tests** (14 files, 250+ tests):
- Full XCTest coverage following TDD methodology

**Utilities**:
- Constants, Color theme system

### Code Reviews Completed

✅ 3 concurrent Opus-powered reviews
✅ All critical issues resolved
✅ Type design improvements applied
✅ Silent failure logging added

### Testing

- [x] All XCTests passing
- [x] SwiftLint clean
- [x] Manual smoke test successful
- [ ] E2E test (blocked on remaining views)

### Next Steps

See `specs/001-local-speech-to-text/plan-nextsteps.md` for remaining MVP work.

Closes #2 (partial - foundational infrastructure complete)
```

---

### Phase 8: Monitor GitHub Actions (15 minutes)

**Goal**: Ensure CI passes.

**Process**:
1. Watch GitHub Actions workflow
2. If failures, investigate logs
3. Fix issues and push updates
4. Repeat until green

**Validation**: All CI checks passing.

---

## Success Criteria

### MVP Completion Criteria

The MVP is considered complete when:

1. ✅ **Core Dictation Works**:
   - User presses ⌘⌃Space
   - Recording modal appears with waveform
   - User speaks
   - Recording auto-stops after 1.5s silence
   - Text appears at cursor in active app

2. ✅ **Tests Pass**:
   - All XCTests passing (GREEN phase)
   - Coverage >80% per plan.md
   - No critical SwiftLint violations

3. ✅ **Code Quality**:
   - All critical code review issues resolved
   - No force casts or force unwraps (except documented cases)
   - Proper error handling with user notifications
   - Thread-safe concurrent code

4. ✅ **Performance Targets**:
   - Hotkey response <50ms
   - Transcription latency <100ms
   - Waveform rendering 30+ fps
   - Memory usage <500MB active

### Full Feature Completion Criteria

Beyond MVP, full feature set requires:

- User Story 2: Onboarding (T033-T042) - 25 tasks
- User Story 3: Menu Bar (T043-T050) - 25 tasks
- User Story 4: Settings (T051-T062) - 24 tasks
- User Story 5: Multi-Language (T063-T072) - 28 tasks
- Phase 8: Polish (T073-T086) - 27 tasks

**Total**: 46 additional tasks (54% of work remaining)

---

## Known Issues & Technical Debt

### From Code Reviews

**Type Design Issues** (Medium Priority):
- RecordingSession lacks invariant enforcement (confidence bounds, time ordering)
- UserSettings uses raw strings instead of enums for language codes
- AppState duplicates `isRecording` state (should derive from session)
- Missing Codable conformance for RecordingSession/TranscriptionSegment

**Silent Failures** (Medium Priority):
- No logging framework (all errors use `print`)
- Magic number 0.95 confidence fallback
- Optional channel data silently ignored in AudioCaptureService
- No telemetry for tracking which apps fail text insertion

**Testing Gaps** (Low Priority):
- FluidAudio SDK requires mocking for unit tests
- Some tests require running macOS app context
- Manual E2E testing needed for permissions flow

### From Analysis Phase

**Missing Specifications**:
- SC-007 idle memory measurement methodology undefined
- Low-confidence transcription threshold not specified (recommend <0.70)
- Model update trigger mechanism not defined
- Code signing prerequisites not documented

---

## Questions for User/Stakeholder

1. **Performance Benchmarking**: What tools should be used to measure SC-007 (idle memory <200MB)? Instruments Memory Profiler?

2. **Confidence Threshold**: What confidence score should trigger the "low confidence" confirmation dialog? Recommend 0.70.

3. **Model Updates**: How should model update checks be triggered? App launch (max once/24h) or user-initiated only?

4. **Code Signing**: Do you have Apple Developer Program membership ($99/year) for distribution?

5. **Telemetry**: Should we add privacy-preserving telemetry to track which apps fail text insertion for compatibility improvements?

---

## Resources

### Documentation
- `specs/001-local-speech-to-text/spec.md` - Feature specification
- `specs/001-local-speech-to-text/plan.md` - Implementation plan
- `specs/001-local-speech-to-text/tasks.md` - 86 tasks (40 complete)
- `IMPLEMENTATION_STATUS.md` - Current status tracker
- `IMPLEMENTATION_SUMMARY.md` - Executive summary
- `ARCHITECTURE_REVIEW.md` - Architecture decision record

### Code Review Reports
- Code Quality Review (agent a84b80f)
- Type Design Analysis (agent a09ceed)
- Silent Failure Audit (agent a070022)

### Development Setup
- `REMOTE_DEVELOPMENT.md` - Linux dev container → Mac execution workflow
- `quickstart.md` - Developer setup guide
- `.swiftlint.yml` - Code quality rules

---

## Timeline Estimate

**To MVP** (User Story 1 complete):
- Critical fixes: 2 hours
- Silent failure fixes: 3 hours
- Type improvements: 4 hours
- MVP views: 8 hours
- Second review: 2 hours
- Test validation: 3 hours
- PR creation: 0.5 hours

**Total**: ~22.5 hours of focused development

**To Full Feature Set**:
- MVP completion: 22.5 hours
- User Stories 2-5: 40 hours
- Phase 8 polish: 15 hours
- Final testing: 5 hours

**Total**: ~82.5 hours (2 weeks at 40 hrs/week)

---

## Contact & Resumption

**Agent IDs** (for resuming work):
- Implementation: `ae032aa`
- Analysis: `a180d1a`
- Code Review: `a84b80f`, `a09ceed`, `a070022`
- Test Generation: `af36969`

**GitHub Issue**: https://github.com/agentdevsl/mac-speech-to-text/issues/2

**Branch**: `001-local-speech-to-text`

**Last Commit**: `15dbe26` (tasks.md TDD compliance update)

---

**Document Owner**: Claude Code Session 2026-01-02
**Next Update**: After Phase 1 (Critical Fixes) completion
