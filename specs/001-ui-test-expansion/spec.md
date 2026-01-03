# Feature Specification: Expand XCUITest Coverage and Pre-Push Hook Integration

**Feature Branch**: `001-ui-test-expansion`
**Created**: 2026-01-03
**Status**: Draft
**Input**: User description: "Expand the existing XCUITest suite to provide comprehensive E2E coverage and integrate UI tests into the pre-push hook workflow alongside unit tests."

## User Scenarios & Testing _(mandatory)_

### User Story 1 - Recording Flow Validation (Priority: P1)

As a developer, I want comprehensive UI tests for the recording workflow so that I can catch regressions in the core speech-to-text capture functionality before they reach production.

**Why this priority**: The recording flow is the primary user interaction with the application. Any regression here directly impacts the core value proposition. This must be tested thoroughly.

**Independent Test**: Can be fully tested by triggering the recording modal and verifying UI state transitions. Delivers confidence that the main user journey works correctly.

**Acceptance Scenarios**:

1. **Given** the app is launched with onboarding completed and permissions granted, **When** the global hotkey (Cmd+Ctrl+Space) is pressed, **Then** the recording modal appears with the waveform visualization visible
2. **Given** the recording modal is open, **When** audio input is detected, **Then** the waveform visualization updates to reflect audio levels
3. **Given** the recording modal is open and recording, **When** the user clicks "Stop Recording", **Then** the modal transitions to "Transcribing" state with progress indicator
4. **Given** the recording modal is open, **When** the user clicks "Cancel" or presses Escape, **Then** the modal dismisses without inserting any text
5. **Given** the recording modal is recording, **When** 1.5 seconds of silence is detected, **Then** recording stops automatically and transcription begins

---

### User Story 2 - Pre-Push Hook Integration (Priority: P1)

As a developer, I want the pre-push hook to run both unit tests and UI tests so that I have comprehensive validation before code is pushed to the repository.

**Why this priority**: This is critical infrastructure that gates code quality. Without proper test integration, regressions can slip through to the main branch.

**Independent Test**: Can be tested by running the pre-push hook script manually and verifying both test types execute. Delivers confidence that the CI/CD pipeline catches issues.

**Acceptance Scenarios**:

1. **Given** a developer attempts to push code, **When** the pre-push hook executes, **Then** both unit tests (swift test) and UI tests (xcodebuild test) run sequentially
2. **Given** a developer needs quick iteration, **When** they run the script with `--skip-ui-tests` flag, **Then** only unit tests execute
3. **Given** a developer is focused on UI work, **When** they run the script with `--ui-tests-only` flag, **Then** only UI tests execute
4. **Given** any test fails, **When** the pre-push hook completes, **Then** the push is blocked with clear error output identifying which tests failed

---

### User Story 3 - Onboarding Test Coverage (Priority: P2)

As a developer, I want complete UI test coverage for the onboarding flow so that first-time user experience is validated end-to-end.

**Why this priority**: Onboarding is the first impression for new users. While not as frequently used as recording, broken onboarding leads to user abandonment.

**Independent Test**: Can be tested by launching with `--reset-onboarding` flag and navigating through all steps. Delivers confidence that new users can complete setup.

**Acceptance Scenarios**:

1. **Given** the app launches for the first time (or with reset flag), **When** the onboarding window appears, **Then** the welcome step is visible with all expected elements
2. **Given** the user is on the welcome step, **When** they click "Continue", **Then** they advance to the microphone permission step
3. **Given** the user navigates through all permission steps, **When** they complete the final step, **Then** the onboarding window closes and the app is ready for use
4. **Given** the user is on a permission step, **When** they click "Skip", **Then** a warning appears and they can proceed without granting that permission

---

### User Story 4 - Settings Validation Tests (Priority: P2)

As a developer, I want UI tests for the settings interface so that user preferences are correctly displayed and persisted.

**Why this priority**: Settings control user customization. Bugs here lead to frustration but don't block core functionality.

**Independent Test**: Can be tested by opening settings and modifying values, then verifying persistence. Delivers confidence that user preferences are respected.

**Acceptance Scenarios**:

1. **Given** the app is running, **When** the user opens Settings (Cmd+,), **Then** the settings window appears with all tabs visible
2. **Given** the settings window is open, **When** the user selects the Language tab, **Then** the language picker displays with searchable language list
3. **Given** the user changes a setting, **When** the settings window is closed and reopened, **Then** the changed value persists
4. **Given** the user clicks "Reset to Defaults", **When** the action completes, **Then** all settings return to their default values

---

### User Story 5 - Error State Testing (Priority: P2)

As a developer, I want UI tests that verify error handling so that users see appropriate feedback when things go wrong.

**Why this priority**: Error handling is critical for user trust but requires special test infrastructure to simulate failure conditions.

**Independent Test**: Can be tested by launching with permission-denied mock state. Delivers confidence that error UI is informative.

**Acceptance Scenarios**:

1. **Given** microphone permission is denied, **When** the user tries to start recording, **Then** an error message appears explaining how to grant permission
2. **Given** accessibility permission is denied, **When** transcription completes, **Then** an error message appears explaining text cannot be inserted
3. **Given** the app encounters a transcription error, **When** the error occurs, **Then** the recording modal displays the error with user-friendly message

---

### User Story 6 - Language Selection Tests (Priority: P3)

As a developer, I want UI tests for language selection so that multi-language support is validated.

**Why this priority**: Language selection is used infrequently but supports internationalization goals.

**Independent Test**: Can be tested by opening language picker and selecting different languages. Delivers confidence in localization support.

**Acceptance Scenarios**:

1. **Given** the language picker is open, **When** the user types in the search field, **Then** the language list filters to matching results
2. **Given** the user selects a different language, **When** they return to recording, **Then** the recording modal shows the selected language indicator
3. **Given** the user selects a language, **When** the app is restarted, **Then** the language selection persists

---

### User Story 7 - Accessibility Compliance Tests (Priority: P3)

As a developer, I want UI tests that verify VoiceOver and keyboard navigation so that the app is accessible to all users.

**Why this priority**: Accessibility is important for inclusivity but requires specialized testing setup.

**Independent Test**: Can be tested by enabling VoiceOver mode and verifying element labels. Delivers confidence in accessibility compliance.

**Acceptance Scenarios**:

1. **Given** VoiceOver is enabled, **When** navigating the onboarding view, **Then** all interactive elements have appropriate accessibility labels
2. **Given** the settings window is open, **When** using only keyboard navigation (Tab/Shift+Tab), **Then** all interactive elements are reachable
3. **Given** the recording modal is open, **When** VoiceOver reads the waveform, **Then** it announces the current audio level percentage

---

### User Story 8 - Test Infrastructure Improvements (Priority: P1)

As a developer, I want improved test infrastructure with screenshot capture and helper utilities so that test failures are easier to diagnose.

**Why this priority**: Without proper infrastructure, debugging test failures is time-consuming and reduces developer productivity.

**Independent Test**: Can be tested by intentionally failing a test and verifying screenshot capture. Delivers improved debugging capability.

**Acceptance Scenarios**:

1. **Given** a UI test fails, **When** the test completes, **Then** a screenshot of the failure state is captured and saved
2. **Given** tests are running, **When** using UITestHelpers utilities, **Then** common operations (wait for element, tap button) are simplified
3. **Given** tests need clean state, **When** launching with `--reset-onboarding`, **Then** UserDefaults are cleared for that test run

---

### Edge Cases

- What happens when the recording modal is opened while another modal is already open?
- How does the app behave when permissions are revoked mid-session?
- What happens when the user rapidly toggles recording start/stop?
- How do tests handle system dialogs that cannot be automated (e.g., Accessibility settings)?
- What happens when the remote Mac for testing is unreachable?

## Requirements _(mandatory)_

### Functional Requirements

#### Recording Flow Tests

- **FR-001**: Test suite MUST verify that the recording modal appears when the global hotkey is triggered
- **FR-002**: Test suite MUST verify that the waveform visualization is visible during recording
- **FR-003**: Test suite MUST verify that the audio level indicator reflects input levels
- **FR-004**: Test suite MUST verify that the "Cancel" button dismisses the modal
- **FR-005**: Test suite MUST verify that "Stop Recording" transitions to transcription state
- **FR-026**: Test suite MUST verify auto-stop after 1.5 seconds of silence (US1 scenario 5)

#### Language Selection Tests

- **FR-006**: Test suite MUST verify that the language picker opens from settings
- **FR-007**: Test suite MUST verify that language selection updates the UI
- **FR-008**: Test suite MUST verify that language selection persists across app launches

#### Settings Tests

- **FR-009**: _(OUT OF SCOPE)_ Test suite MUST verify that hotkey customization UI is accessible - _deferred: hotkey customization UI not yet implemented_
- **FR-010**: _(OUT OF SCOPE)_ Test suite MUST verify that "Launch at login" toggle works - _deferred: launch at login UI not yet implemented_
- **FR-011**: _(OUT OF SCOPE)_ Test suite MUST verify that language model download status is displayed - _deferred: download status UI not yet implemented_

#### Error State Tests

- **FR-012**: Test suite MUST verify error UI when microphone permission is denied
- **FR-013**: Test suite MUST verify error UI when accessibility permission is denied
- **FR-014**: Test suite MUST verify graceful handling of transcription errors

#### Accessibility Tests

- **FR-015**: Test suite MUST verify VoiceOver compatibility for all views
- **FR-016**: Test suite MUST verify full keyboard navigation support

#### Pre-Push Hook Integration

- **FR-017**: Pre-push hook MUST run both unit tests and UI tests by default
- **FR-018**: Pre-push hook MUST support `--skip-ui-tests` flag for quick iterations
- **FR-019**: Pre-push hook MUST support `--ui-tests-only` flag for UI-focused development
- **FR-020**: Pre-push hook MUST support configurable timeout via environment variable

#### Test Infrastructure

- **FR-021**: App MUST handle `--uitesting` launch argument for test mode
- **FR-022**: App MUST handle `--reset-onboarding` launch argument to clear UserDefaults
- **FR-023**: App MUST handle `--skip-permission-checks` for permission-agnostic tests
- **FR-024**: Test infrastructure MUST capture screenshots on test failure
- **FR-025**: Test infrastructure MUST provide `UITestHelpers.swift` with common utilities

### Key Entities

- **UITestCase**: A test case class extending XCTestCase with setup for app launch and teardown
- **UITestHelpers**: Utility functions for common UI test operations (wait, tap, verify text)
- **LaunchArguments**: Enum or constants defining all supported test launch arguments
- **TestScreenshots**: Directory structure for storing failure screenshots organized by test name

## Success Criteria _(mandatory)_

### Measurable Outcomes

- **SC-001**: UI test suite covers at least 15 distinct user flows (recording, onboarding, settings, error states, language selection)
- **SC-002**: Pre-push hook completes (unit + UI tests) in under 10 minutes on standard Mac hardware
- **SC-003**: Screenshot capture works for 100% of test failures, with screenshots saved in accessible location
- **SC-004**: All UI tests pass on clean install with proper permission handling (via launch arguments)
- **SC-005**: Developer can skip UI tests via `--skip-ui-tests` flag, reducing pre-push time by at least 50%
- **SC-006**: Documentation in CLAUDE.md reflects new test commands and flags
- **SC-007**: At least 80% of interactive UI elements have accessibility labels verified by tests
- **SC-008**: No existing unit tests are broken by the changes

### Assumptions

- Tests will run on macOS 14+ with Xcode 15+
- Remote Mac for testing has SSH access configured (existing infrastructure)
- Permission dialogs will be handled via launch arguments rather than automation
- XCUITest can access menu bar extras for some but not all interactions (limitation documented)
- UI test execution time is expected to be 3-5 minutes for the full suite
