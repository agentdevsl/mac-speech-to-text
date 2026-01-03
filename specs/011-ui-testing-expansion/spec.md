# UI Testing Expansion Specification

**Issue**: [#11 - Expand XCUITest coverage and integrate into pre-push hooks](https://github.com/agentdevsl/mac-speech-to-text/issues/11)
**Created**: 2026-01-03
**Status**: Planning

## Overview

This specification details the expansion of XCUITest coverage for the Speech-to-Text macOS application. The goal is to achieve comprehensive E2E test coverage and integrate UI tests into the pre-push hook workflow.

## Current Test Coverage

### Existing UI Tests (`UITests/SpeechToTextUITests.swift`)

| Test | Description | Status |
|------|-------------|--------|
| `testOnboardingAppearsOnFirstLaunch` | Verifies onboarding window appears | ✅ Implemented |
| `testOnboardingNavigation` | Tests step navigation through onboarding | ✅ Implemented |
| `testOnboardingCompletion` | Full onboarding flow completion | ✅ Implemented |
| `testMenuBarIconAppears` | Menu bar presence verification | ✅ Implemented |
| `testRecordingModalOpens` | Recording modal trigger test | ✅ Implemented |
| `testSettingsWindowOpens` | Settings access test | ✅ Implemented |

## Proposed Test Categories

### 1. Recording Flow Tests

See: [test-plans/recording-flow.md](./test-plans/recording-flow.md)

### 2. Language Selection Tests

See: [test-plans/language-selection.md](./test-plans/language-selection.md)

### 3. Settings Tests

See: [test-plans/settings.md](./test-plans/settings.md)

### 4. Error State Tests

See: [test-plans/error-states.md](./test-plans/error-states.md)

### 5. Accessibility Tests

See: [test-plans/accessibility.md](./test-plans/accessibility.md)

## Pre-Push Hook Integration

### Current Hook Behavior

- Runs `swift test --parallel` on remote Mac via SSH
- Does **not** include UI tests

### Proposed Changes

```bash
# scripts/remote-test.sh additions

run_ui_tests() {
    echo "Running UI tests..."
    xcodebuild test \
        -scheme SpeechToText \
        -destination 'platform=macOS' \
        -only-testing:SpeechToTextUITests \
        -parallel-testing-enabled YES \
        -resultBundlePath ./test-results/ui-tests.xcresult
}

# Add flags
# --skip-ui-tests    Skip UI tests for quick iterations
# --ui-tests-only    Run only UI tests
```

## Test Infrastructure Requirements

### Launch Arguments

| Argument | Purpose |
|----------|---------|
| `--uitesting` | Enable UI test mode (disable animations, mock slow services) |
| `--reset-onboarding` | Clear UserDefaults for clean onboarding state |
| `--skip-permission-checks` | Mock permission services for permission-agnostic tests |
| `--mock-audio` | Provide mock audio input for recording tests |

### Screenshot Capture

- Capture screenshot on test failure
- Store in `./test-results/screenshots/`
- Include timestamp and test name in filename

## File Structure

```
specs/011-ui-testing-expansion/
├── spec.md                           # This file
└── test-plans/
    ├── recording-flow.md             # Recording modal test plans
    ├── language-selection.md         # Language picker test plans
    ├── settings.md                   # Settings view test plans
    ├── error-states.md               # Error handling test plans
    └── accessibility.md              # VoiceOver and keyboard tests
```

## Implementation Priority

1. **High Priority**: Recording flow tests (core functionality)
2. **High Priority**: Error state tests (user experience)
3. **Medium Priority**: Settings tests (configuration)
4. **Medium Priority**: Language selection tests (internationalization)
5. **Lower Priority**: Accessibility tests (compliance)

## Success Criteria

- [ ] All new UI tests pass locally and on CI
- [ ] Pre-push hook runs both unit and UI tests
- [ ] `--skip-ui-tests` flag works for quick iterations
- [ ] Test failure screenshots are captured
- [ ] Documentation updated in CLAUDE.md
- [ ] Test coverage report generated
