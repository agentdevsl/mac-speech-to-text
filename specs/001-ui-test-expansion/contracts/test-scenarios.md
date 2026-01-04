# Test Scenario Contracts

**Feature**: UI Test Expansion
**Version**: 1.0.0
**Date**: 2026-01-03

This document defines the contract for test scenarios that map acceptance criteria from the specification to XCUITest implementations.

## Priority 1 (P1) Scenarios - Must Pass for Push

### Recording Flow Tests

| ID | Scenario | Test Method | Launch Args | Acceptance Criteria |
|----|----------|-------------|-------------|---------------------|
| RF-001 | Recording modal appears on hotkey | `test_recording_modalAppearsOnTrigger` | `--uitesting`, `--skip-onboarding`, `--skip-permission-checks`, `--trigger-recording` | US1-AC1: Modal visible with waveform |
| RF-002 | Waveform visible during recording | `test_recording_waveformIsVisible` | Same as RF-001 | US1-AC2: Waveform element exists |
| RF-003 | Cancel dismisses modal | `test_recording_cancelDismissesModal` | Same as RF-001 | US1-AC4: Modal not present after cancel |
| RF-004 | Stop button initiates transcription | `test_recording_stopInitiatesTranscription` | Same as RF-001 | US1-AC3: "Transcribing" state shown |
| RF-005 | Escape key dismisses modal | `test_recording_escapeKeyDismisses` | Same as RF-001 | US1-AC4: Modal dismissed on Escape |

### Pre-Push Hook Tests

| ID | Scenario | Test Method | Environment | Acceptance Criteria |
|----|----------|-------------|-------------|---------------------|
| PH-001 | Hook runs both test types | Manual verification | Default env | US2-AC1: Unit + UI tests execute |
| PH-002 | Skip UI tests flag works | Manual verification | `SKIP_UI_TESTS=1` | US2-AC2: Only unit tests run |
| PH-003 | UI tests only flag works | Manual verification | `UI_TESTS_ONLY=1` | US2-AC3: Only UI tests run |
| PH-004 | Failure blocks push | Manual verification | Failing test | US2-AC4: Exit code 1, clear error |

### Test Infrastructure

| ID | Scenario | Test Method | Verification | Acceptance Criteria |
|----|----------|-------------|--------------|---------------------|
| TI-001 | Screenshot on failure | `test_infrastructure_screenshotCaptured` | Check xcresult | US8-AC1: Screenshot in results |
| TI-002 | UITestHelpers work | `test_infrastructure_helpersFunction` | Assertions pass | US8-AC2: Helpers simplify tests |
| TI-003 | Reset onboarding works | `test_infrastructure_resetOnboarding` | Fresh onboarding | US8-AC3: Clean state for test |

## Priority 2 (P2) Scenarios - Should Pass

### Onboarding Flow Tests

| ID | Scenario | Test Method | Launch Args | Acceptance Criteria |
|----|----------|-------------|-------------|---------------------|
| ON-001 | Welcome step visible | `test_onboarding_welcomeStepVisible` | `--uitesting`, `--reset-onboarding` | US3-AC1: Welcome elements present |
| ON-002 | Continue advances step | `test_onboarding_continueAdvances` | Same as ON-001 | US3-AC2: Next step shown |
| ON-003 | Complete onboarding | `test_onboarding_completion` | `--uitesting`, `--reset-onboarding`, `--skip-permission-checks` | US3-AC3: Onboarding window closes |
| ON-004 | Skip shows warning | `test_onboarding_skipShowsWarning` | Same as ON-001 | US3-AC4: Warning alert appears |

### Settings Tests

| ID | Scenario | Test Method | Launch Args | Acceptance Criteria |
|----|----------|-------------|-------------|---------------------|
| ST-001 | Settings window opens | `test_settings_windowOpens` | `--uitesting`, `--skip-onboarding` | US4-AC1: Settings window visible |
| ST-002 | Language tab visible | `test_settings_languageTabWorks` | Same as ST-001 | US4-AC2: Language picker shown |
| ST-003 | Settings persist | `test_settings_changesPersist` | Same as ST-001 | US4-AC3: Value persists after relaunch |
| ST-004 | Reset to defaults | `test_settings_resetToDefaults` | Same as ST-001 | US4-AC4: Settings return to defaults |

### Error State Tests

| ID | Scenario | Test Method | Launch Args | Acceptance Criteria |
|----|----------|-------------|-------------|---------------------|
| ER-001 | Mic denied error UI | `test_error_microphoneDeniedMessage` | `--uitesting`, `--skip-onboarding`, `--mock-permissions=denied`, `--trigger-recording` | US5-AC1: Error message visible |
| ER-002 | Accessibility denied | `test_error_accessibilityDeniedMessage` | Same with accessibility mock | US5-AC2: Error with instructions |
| ER-003 | Transcription error | `test_error_transcriptionFailure` | `--simulate-error=transcription` | US5-AC3: User-friendly error |

## Priority 3 (P3) Scenarios - Nice to Have

### Language Selection Tests

| ID | Scenario | Test Method | Launch Args | Acceptance Criteria |
|----|----------|-------------|-------------|---------------------|
| LS-001 | Language search filters | `test_language_searchFilters` | `--uitesting`, `--skip-onboarding` | US6-AC1: List filters on type |
| LS-002 | Language indicator shows | `test_language_indicatorInModal` | `--uitesting`, `--skip-onboarding`, `--initial-language=es-ES`, `--trigger-recording` | US6-AC2: Flag visible in modal |
| LS-003 | Language persists | `test_language_selectionPersists` | Same as LS-001 | US6-AC3: Selection survives restart |

### Accessibility Tests

| ID | Scenario | Test Method | Launch Args | Acceptance Criteria |
|----|----------|-------------|-------------|---------------------|
| AC-001 | VoiceOver labels present | `test_accessibility_voiceOverLabels` | `--uitesting`, `--skip-onboarding`, `--accessibility-testing` | US7-AC1: All elements have labels |
| AC-002 | Keyboard navigation | `test_accessibility_keyboardNav` | Same as AC-001 | US7-AC2: All elements reachable |
| AC-003 | Waveform announces level | `test_accessibility_waveformAnnounces` | `--uitesting`, `--skip-onboarding`, `--trigger-recording`, `--accessibility-testing` | US7-AC3: Level percentage announced |

## Test File Organization Contract

```
UITests/
├── Base/
│   ├── UITestBase.swift           # Base class with common setup/teardown
│   └── UITestHelpers.swift        # Helper functions
│
├── P1/
│   ├── RecordingFlowTests.swift   # RF-001 through RF-005
│   └── TestInfrastructureTests.swift # TI-001 through TI-003
│
├── P2/
│   ├── OnboardingFlowTests.swift  # ON-001 through ON-004
│   ├── SettingsTests.swift        # ST-001 through ST-004
│   └── ErrorStateTests.swift      # ER-001 through ER-003
│
├── P3/
│   ├── LanguageSelectionTests.swift # LS-001 through LS-003
│   └── AccessibilityTests.swift   # AC-001 through AC-003
│
└── TestPlans/
    ├── AllUITests.xctestplan      # All tests
    ├── P1OnlyTests.xctestplan     # P1 tests only (for quick validation)
    └── AccessibilityTests.xctestplan # AC-* tests only
```

## Test Naming Convention Contract

```
test_<feature>_<scenario>

Examples:
- test_recording_modalAppearsOnTrigger
- test_onboarding_welcomeStepVisible
- test_settings_languageTabWorks
- test_error_microphoneDeniedMessage
- test_accessibility_voiceOverLabels
```

## Required Assertions Per Test

Each test MUST include:

1. At least one `XCTAssert*` call
2. Element existence verification before interaction
3. Timeout specification for async operations
4. Screenshot capture on failure (via base class)

## Test Independence Contract

Each test MUST:

1. Launch app fresh (not depend on prior test state)
2. Use launch arguments to set initial state
3. Clean up any created state in tearDown
4. Not depend on execution order

## Timeout Contracts

| Operation | Default Timeout | Max Timeout |
|-----------|-----------------|-------------|
| Element wait | 5 seconds | 10 seconds |
| Window appear | 5 seconds | 10 seconds |
| Animation complete | 1 second | 3 seconds |
| Full test execution | 30 seconds | 60 seconds |
