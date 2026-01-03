# Tasks: Expand XCUITest Coverage and Pre-Push Hook Integration

**Input**: Design documents from `/specs/001-ui-test-expansion/`
**Prerequisites**: plan.md (complete), spec.md (complete), research.md (complete), data-model.md (complete), contracts/ (complete)

**Tests**: This feature IS a test expansion feature. The "tests" ARE the implementation. No separate test phase needed - the implementation delivers test coverage.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

Based on plan.md structure:
- **Source code**: `Sources/` at repository root
- **Unit tests**: `Tests/SpeechToTextTests/`
- **UI tests**: `UITests/`
- **Scripts**: `scripts/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create base test infrastructure that all UI tests depend on

- [ ] T001 Create UITests/Base/ directory structure for shared test utilities
- [ ] T002 [P] Implement UITestBase.swift base class with setup/teardown in UITests/Base/UITestBase.swift
- [ ] T003 [P] Implement UITestHelpers.swift helper functions in UITests/Base/UITestHelpers.swift
- [ ] T004 [P] Create UITestError enum in UITests/Base/UITestHelpers.swift for consistent error handling
- [ ] T005 [P] Add XCUIElement+SafeTap extension in UITests/Base/UITestHelpers.swift
- [ ] T006 [P] Add XCTestCase+Screenshot extension in UITests/Base/UITestHelpers.swift

**Acceptance**:
- UITestBase provides consistent app launch with configurable arguments
- UITestHelpers provides waitForElement, tapButton, typeText, captureScreenshot
- Screenshot capture works on test failure
- All base utilities compile and can be imported

**Checkpoint**: Base infrastructure ready - test implementation can now begin

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Launch argument handling in production code that MUST be complete before ANY test can run

**CRITICAL**: No user story work can begin until this phase is complete

- [ ] T007 Create LaunchArguments enum constants in Sources/Utilities/LaunchArguments.swift
- [ ] T008 Create UITestConfiguration struct in Sources/Models/UITestConfiguration.swift
- [ ] T009 Create LaunchArgumentParser in Sources/Utilities/LaunchArgumentParser.swift
- [ ] T010 Add MockPermissionState and SimulatedErrorType enums in Sources/Models/UITestConfiguration.swift
- [ ] T011 Modify AppDelegate.swift to parse and apply UITestConfiguration on launch
- [ ] T012 Add --trigger-recording support to show recording modal on launch in Sources/SpeechToTextApp/AppDelegate.swift
- [ ] T013 Add --mock-permissions support to PermissionService in Sources/Services/PermissionService.swift
- [ ] T014 Add --simulate-error support to FluidAudioService in Sources/Services/FluidAudioService.swift
- [ ] T015 Verify existing --uitesting, --reset-onboarding, --skip-permission-checks, --skip-onboarding arguments still work

**Acceptance**:
- All launch arguments from data-model.md are functional
- App launches correctly with test arguments
- Mock permission states can be forced via arguments
- Recording modal can be triggered via arguments
- Error states can be simulated via arguments

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 8 - Test Infrastructure Improvements (Priority: P1)

**Goal**: Improved test infrastructure with screenshot capture and helper utilities for easier failure diagnosis

**Independent Test**: Run a test that intentionally fails and verify screenshot is captured in xcresult bundle

### Implementation for User Story 8

- [ ] T016 [P] [US8] Create UITests/P1/ directory for P1 priority tests
- [ ] T017 [P] [US8] Create TestInfrastructureTests.swift in UITests/P1/TestInfrastructureTests.swift
- [ ] T018 [US8] Implement test_infrastructure_screenshotCaptured in UITests/P1/TestInfrastructureTests.swift
- [ ] T019 [US8] Implement test_infrastructure_helpersFunction in UITests/P1/TestInfrastructureTests.swift
- [ ] T020 [US8] Implement test_infrastructure_resetOnboarding in UITests/P1/TestInfrastructureTests.swift
- [ ] T021 [US8] Add test-screenshots/ directory creation and management in UITestBase.swift

**Acceptance**:
- TI-001: Screenshot captured on failure (verify in xcresult)
- TI-002: UITestHelpers simplify common operations
- TI-003: --reset-onboarding clears state for fresh test runs
- All 3 infrastructure tests pass

**Checkpoint**: Test infrastructure verified - recording flow tests can proceed

---

## Phase 4: User Story 1 - Recording Flow Validation (Priority: P1)

**Goal**: Comprehensive UI tests for the core recording workflow - the primary user interaction

**Independent Test**: Launch app with --trigger-recording and verify modal appears, waveform visible, cancel dismisses

### Implementation for User Story 1

- [ ] T022 [US1] Create RecordingFlowTests.swift in UITests/P1/RecordingFlowTests.swift
- [ ] T023 [US1] Implement test_recording_modalAppearsOnTrigger (RF-001) in UITests/P1/RecordingFlowTests.swift
- [ ] T024 [US1] Implement test_recording_waveformIsVisible (RF-002) in UITests/P1/RecordingFlowTests.swift
- [ ] T025 [US1] Implement test_recording_cancelDismissesModal (RF-003) in UITests/P1/RecordingFlowTests.swift
- [ ] T026 [US1] Implement test_recording_stopInitiatesTranscription (RF-004) in UITests/P1/RecordingFlowTests.swift
- [ ] T027 [US1] Implement test_recording_escapeKeyDismisses (RF-005) in UITests/P1/RecordingFlowTests.swift
- [ ] T027b [US1] Implement test_recording_silenceAutoStop (FR-026) in UITests/P1/RecordingFlowTests.swift - verify auto-stop after 1.5s silence
- [ ] T028 [US1] Add accessibility identifiers to RecordingModal.swift for test element queries

**Acceptance**:
- RF-001: Recording modal appears when launched with --trigger-recording
- RF-002: Waveform visualization element exists and visible
- RF-003: Cancel button dismisses modal
- RF-004: Stop button transitions to "Transcribing" state
- RF-005: Escape key dismisses modal
- RF-006: Auto-stop triggers after 1.5 seconds of silence (FR-026)
- All 6 recording flow tests pass

**Checkpoint**: Core recording flow tested - User Story 1 complete

---

## Phase 5: User Story 2 - Pre-Push Hook Integration (Priority: P1)

**Goal**: Integrate UI tests into git workflow via remote Mac (macdev) with configurable flags

**Independent Test**: Run pre-push hook manually and verify both unit and UI tests execute on macdev

### Implementation for User Story 2

- [ ] T029 [US2] Modify scripts/run-ui-tests.sh to support --test-plan flag for selective test execution
- [ ] T030 [US2] Add --verbose flag to scripts/run-ui-tests.sh for detailed output
- [ ] T031 [US2] Add timeout handling to scripts/run-ui-tests.sh using UI_TEST_TIMEOUT env var
- [ ] T032 [US2] Modify scripts/remote-test.sh to include --include-ui-tests flag
- [ ] T033 [US2] Create pre-push hook script at scripts/pre-push with unit + UI test integration
- [ ] T034 [US2] Add SKIP_UI_TESTS environment variable support to scripts/pre-push
- [ ] T035 [US2] Add UI_TESTS_ONLY environment variable support to scripts/pre-push
- [ ] T036 [US2] Add result parsing and clear error output format to scripts/pre-push
- [ ] T037 [US2] Add installation instructions for pre-push hook to scripts/pre-push header
- [ ] T038 [US2] Create scripts/install-hooks.sh to install pre-push hook to .git/hooks/

**Acceptance**:
- PH-001: Default git push runs both unit tests and UI tests on macdev
- PH-002: SKIP_UI_TESTS=1 git push runs only unit tests
- PH-003: UI_TESTS_ONLY=1 git push runs only UI tests
- PH-004: Test failures block push with clear error messages
- Timeout after 10 minutes by default (configurable via UI_TEST_TIMEOUT)
- All tests execute on macdev remote Mac via SSH

**Checkpoint**: Pre-push integration complete - User Story 2 complete

---

## Phase 6: User Story 3 - Onboarding Test Coverage (Priority: P2)

**Goal**: Complete UI test coverage for the first-time user onboarding flow

**Independent Test**: Launch with --reset-onboarding and navigate through all onboarding steps

### Implementation for User Story 3

- [ ] T039 [P] [US3] Create UITests/P2/ directory for P2 priority tests
- [ ] T040 [US3] Create OnboardingFlowTests.swift in UITests/P2/OnboardingFlowTests.swift
- [ ] T041 [US3] Implement test_onboarding_welcomeStepVisible (ON-001) in UITests/P2/OnboardingFlowTests.swift
- [ ] T042 [US3] Implement test_onboarding_continueAdvances (ON-002) in UITests/P2/OnboardingFlowTests.swift
- [ ] T043 [US3] Implement test_onboarding_completion (ON-003) in UITests/P2/OnboardingFlowTests.swift
- [ ] T044 [US3] Implement test_onboarding_skipShowsWarning (ON-004) in UITests/P2/OnboardingFlowTests.swift
- [ ] T045 [US3] Add accessibility identifiers to OnboardingView.swift for test element queries
- [ ] T046 [US3] Refactor existing SpeechToTextUITests.swift onboarding tests to use new base class

**Acceptance**:
- ON-001: Welcome step visible with all expected elements
- ON-002: Continue button advances to next step
- ON-003: Completing all steps closes onboarding window
- ON-004: Skip button shows warning dialog
- All 4 onboarding tests pass with --reset-onboarding

**Checkpoint**: Onboarding flow tested - User Story 3 complete

---

## Phase 7: User Story 4 - Settings Validation Tests (Priority: P2)

**Goal**: UI tests for settings interface to verify user preferences are correctly displayed and persisted

**Independent Test**: Open settings, modify a value, relaunch app, verify value persisted

### Implementation for User Story 4

- [ ] T047 [US4] Create SettingsTests.swift in UITests/P2/SettingsTests.swift
- [ ] T048 [US4] Implement test_settings_windowOpens (ST-001) in UITests/P2/SettingsTests.swift
- [ ] T049 [US4] Implement test_settings_languageTabWorks (ST-002) in UITests/P2/SettingsTests.swift
- [ ] T050 [US4] Implement test_settings_changesPersist (ST-003) in UITests/P2/SettingsTests.swift
- [ ] T051 [US4] Implement test_settings_resetToDefaults (ST-004) in UITests/P2/SettingsTests.swift
- [ ] T052 [US4] Add accessibility identifiers to Settings views for test element queries

**Acceptance**:
- ST-001: Settings window opens with Cmd+, shortcut
- ST-002: Language tab displays with searchable language picker
- ST-003: Changed settings persist after relaunch
- ST-004: Reset to Defaults restores all default values
- All 4 settings tests pass

**Checkpoint**: Settings tested - User Story 4 complete

---

## Phase 8: User Story 5 - Error State Testing (Priority: P2)

**Goal**: UI tests that verify error handling shows appropriate feedback when things go wrong

**Independent Test**: Launch with --mock-permissions=denied and verify error UI appears

### Implementation for User Story 5

- [ ] T053 [US5] Create ErrorStateTests.swift in UITests/P2/ErrorStateTests.swift
- [ ] T054 [US5] Implement test_error_microphoneDeniedMessage (ER-001) in UITests/P2/ErrorStateTests.swift
- [ ] T055 [US5] Implement test_error_accessibilityDeniedMessage (ER-002) in UITests/P2/ErrorStateTests.swift
- [ ] T056 [US5] Implement test_error_transcriptionFailure (ER-003) in UITests/P2/ErrorStateTests.swift
- [ ] T057 [US5] Add error message accessibility identifiers to RecordingModal.swift
- [ ] T058 [US5] Add error simulation support to RecordingViewModel for --simulate-error argument

**Acceptance**:
- ER-001: Microphone denied shows permission error with instructions
- ER-002: Accessibility denied shows error with settings link
- ER-003: Transcription error shows user-friendly message
- All 3 error state tests pass

**Checkpoint**: Error handling tested - User Story 5 complete

---

## Phase 9: User Story 6 - Language Selection Tests (Priority: P3)

**Goal**: UI tests for language selection to validate multi-language support

**Independent Test**: Open language picker, search for a language, select it, verify indicator

### Implementation for User Story 6

- [ ] T059 [P] [US6] Create UITests/P3/ directory for P3 priority tests
- [ ] T060 [US6] Create LanguageSelectionTests.swift in UITests/P3/LanguageSelectionTests.swift
- [ ] T061 [US6] Implement test_language_searchFilters (LS-001) in UITests/P3/LanguageSelectionTests.swift
- [ ] T062 [US6] Implement test_language_indicatorInModal (LS-002) in UITests/P3/LanguageSelectionTests.swift
- [ ] T063 [US6] Implement test_language_selectionPersists (LS-003) in UITests/P3/LanguageSelectionTests.swift
- [ ] T064 [US6] Add accessibility identifiers to language picker components

**Acceptance**:
- LS-001: Language search filters list as user types
- LS-002: Selected language indicator visible in recording modal
- LS-003: Language selection persists after app restart
- All 3 language tests pass

**Checkpoint**: Language selection tested - User Story 6 complete

---

## Phase 10: User Story 7 - Accessibility Compliance Tests (Priority: P3)

**Goal**: UI tests that verify VoiceOver and keyboard navigation for accessibility compliance

**Independent Test**: Enable accessibility testing mode and verify all interactive elements have labels

### Implementation for User Story 7

- [ ] T065 [US7] Create AccessibilityTests.swift in UITests/P3/AccessibilityTests.swift
- [ ] T066 [US7] Implement test_accessibility_voiceOverLabels (AC-001) in UITests/P3/AccessibilityTests.swift
- [ ] T067 [US7] Implement test_accessibility_keyboardNav (AC-002) in UITests/P3/AccessibilityTests.swift
- [ ] T068 [US7] Implement test_accessibility_waveformAnnounces (AC-003) in UITests/P3/AccessibilityTests.swift
- [ ] T069 [US7] Add accessibility labels to all interactive elements in Views/
- [ ] T070 [US7] Add accessibilityValue for waveform audio level in Views/Components/WaveformView.swift

**Acceptance**:
- AC-001: All interactive elements in onboarding have VoiceOver labels
- AC-002: All settings elements reachable via Tab/Shift+Tab
- AC-003: Waveform announces current audio level percentage
- At least 80% of interactive elements have accessibility labels (SC-007)
- All 3 accessibility tests pass

**Checkpoint**: Accessibility compliance tested - User Story 7 complete

---

## Phase 11: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, test plans, and cleanup that affect multiple user stories

- [ ] T071 [P] Create UITests/TestPlans/AllUITests.xctestplan for all UI tests
- [ ] T072 [P] Create UITests/TestPlans/P1OnlyTests.xctestplan for P1 tests only (quick validation)
- [ ] T073 [P] Create UITests/TestPlans/AccessibilityTests.xctestplan for accessibility tests only
- [ ] T074 Update CLAUDE.md with new UI test commands and flags
- [ ] T075 Update AGENTS.md with UI testing patterns and best practices
- [ ] T076 Refactor SpeechToTextUITests.swift to import new base class and remove duplicated code
- [ ] T077 [P] Verify all SC-001 through SC-008 success criteria are met
- [ ] T078 Run full test suite and verify no unit test regressions (SC-008)
- [ ] T079 Time pre-push hook execution and verify <10 minutes (SC-002)
- [ ] T080 Test SKIP_UI_TESTS reduces time by at least 50% (SC-005)

**Acceptance**:
- Test plans enable selective execution
- Documentation reflects new capabilities
- No regressions in existing tests
- All success criteria verified

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phases 3-10)**: All depend on Foundational phase completion
  - User stories can proceed in priority order (P1 -> P2 -> P3)
  - Stories within same priority can run in parallel if staffed
- **Polish (Phase 11)**: Depends on all user stories being complete

### User Story Dependencies

| Story | Priority | Depends On | Notes |
|-------|----------|------------|-------|
| US8 (Infrastructure) | P1 | Foundational | Must be first - other tests need helpers |
| US1 (Recording) | P1 | US8 | Uses infrastructure from US8 |
| US2 (Pre-Push) | P1 | US1 | Needs tests to exist to validate hook |
| US3 (Onboarding) | P2 | Foundational | Can start after P1 complete |
| US4 (Settings) | P2 | Foundational | Can run parallel with US3 |
| US5 (Errors) | P2 | Foundational | Can run parallel with US3, US4 |
| US6 (Language) | P3 | US4 | Uses settings infrastructure |
| US7 (Accessibility) | P3 | US3, US4 | Needs UI elements to exist |

### Within Each User Story

- Models/enums before services (T007-T010 before T011-T014)
- Base classes before test files (T002-T006 before T017-T020)
- Source code changes before test verification
- Complete story before moving to next priority

### Parallel Opportunities

Within Phase 2 (Foundational):
```
T007, T008, T009, T010 can run in parallel (separate files)
```

Within Phase 3 (US8):
```
T016, T017 can run in parallel (directory and file creation)
```

Within Phase 6-8 (P2 stories):
```
US3, US4, US5 can run in parallel if team has capacity
```

Within Phase 11 (Polish):
```
T071, T072, T073 can run in parallel (separate test plan files)
```

---

## Implementation Strategy

### MVP First (P1 Stories Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 8 (Infrastructure)
4. Complete Phase 4: User Story 1 (Recording)
5. Complete Phase 5: User Story 2 (Pre-Push)
6. **STOP and VALIDATE**: All P1 criteria met, pre-push hook functional
7. Deploy/demo if ready - 8 tests covering core functionality

### Incremental Delivery

1. Complete Phases 1-5 -> P1 complete (MVP!)
2. Add Phases 6-8 (US3, US4, US5) -> P2 complete (11 more tests)
3. Add Phases 9-10 (US6, US7) -> P3 complete (6 more tests)
4. Complete Phase 11 -> Full feature complete

### Team Strategy

With multiple developers after Foundational:
- Developer A: US8 -> US1 -> US2 (P1 path)
- Developer B: US3 -> US6 (Onboarding/Language path)
- Developer C: US4 -> US5 -> US7 (Settings/Error/A11y path)

---

## Task Summary

| Phase | Description | Task Count | Priority |
|-------|-------------|------------|----------|
| 1 | Setup | 6 | - |
| 2 | Foundational | 9 | - |
| 3 | US8 Infrastructure | 6 | P1 |
| 4 | US1 Recording | 7 | P1 |
| 5 | US2 Pre-Push | 10 | P1 |
| 6 | US3 Onboarding | 8 | P2 |
| 7 | US4 Settings | 6 | P2 |
| 8 | US5 Errors | 6 | P2 |
| 9 | US6 Language | 6 | P3 |
| 10 | US7 Accessibility | 6 | P3 |
| 11 | Polish | 10 | - |
| **Total** | | **80** | |

### Test Count by User Story

| User Story | Test Methods | Scenarios |
|------------|--------------|-----------|
| US8 (Infrastructure) | 3 | TI-001, TI-002, TI-003 |
| US1 (Recording) | 5 | RF-001 through RF-005 |
| US3 (Onboarding) | 4 | ON-001 through ON-004 |
| US4 (Settings) | 4 | ST-001 through ST-004 |
| US5 (Errors) | 3 | ER-001 through ER-003 |
| US6 (Language) | 3 | LS-001 through LS-003 |
| US7 (Accessibility) | 3 | AC-001 through AC-003 |
| **Total** | **25** | (Exceeds SC-001: 15+ flows) |

### Parallel Opportunities

- Phase 1: 5 tasks can run in parallel
- Phase 2: 4 tasks can run in parallel initially
- Phases 3-5 (P1): Sequential within, but isolated from P2/P3
- Phases 6-8 (P2): 3 user stories can run in parallel
- Phases 9-10 (P3): 2 user stories can run in parallel
- Phase 11: 4 tasks can run in parallel

---

## Notes

- All tests run on `macdev` remote Mac via SSH (not GitHub Actions)
- macOS hardware is required for UI tests
- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
