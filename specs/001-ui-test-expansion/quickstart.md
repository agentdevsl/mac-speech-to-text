# Quickstart: UI Test Expansion

**Feature**: Expand XCUITest Coverage and Pre-Push Hook Integration
**Date**: 2026-01-03

## Overview

This guide helps you get started with the expanded UI test suite and pre-push hook integration.

## Prerequisites

- macOS 14+ (Sonoma or newer)
- Xcode 15+ with Command Line Tools
- Git with pre-commit hooks configured
- SSH access to remote Mac for testing (if using remote-test.sh)

## Quick Setup

### 1. Install Pre-Push Hook

The pre-push hook should already be installed. Verify with:

```bash
ls -la .git/hooks/pre-push
```

If missing, install it:

```bash
cp scripts/pre-push .git/hooks/pre-push
chmod +x .git/hooks/pre-push
```

### 2. Verify UI Test Infrastructure

Run a quick check to ensure UI tests can execute:

```bash
# Build the app first
swift build

# Run UI tests locally (requires macOS with display)
./scripts/run-ui-tests.sh --verbose
```

### 3. Test the Pre-Push Hook

```bash
# Dry run (doesn't actually push)
./scripts/pre-push-test.sh

# Or trigger a real push to a test branch
git checkout -b test-ui-tests
git commit --allow-empty -m "Test UI tests"
git push origin test-ui-tests
```

## Running UI Tests

### All Tests

```bash
./scripts/run-ui-tests.sh
```

### P1 Tests Only (Quick Validation)

```bash
./scripts/run-ui-tests.sh --test-plan P1OnlyTests
```

### Specific Test File

```bash
xcodebuild test \
  -scheme SpeechToText \
  -destination 'platform=macOS' \
  -only-testing:SpeechToTextUITests/RecordingFlowTests
```

### With Verbose Output

```bash
./scripts/run-ui-tests.sh --verbose
```

## Pre-Push Hook Flags

### Skip UI Tests (Quick Iteration)

```bash
SKIP_UI_TESTS=1 git push
```

### Run Only UI Tests

```bash
UI_TESTS_ONLY=1 git push
```

### Set Custom Timeout

```bash
UI_TEST_TIMEOUT=300 git push  # 5 minutes
```

### Bypass Hook Entirely (Not Recommended)

```bash
git push --no-verify
```

## Writing New UI Tests

### 1. Create Test File

```swift
// UITests/P2/MyFeatureTests.swift
import XCTest

final class MyFeatureTests: UITestBase {
    func test_myFeature_scenario() throws {
        // Launch with appropriate arguments
        launchApp(arguments: [
            LaunchArguments.uitesting,
            LaunchArguments.skipOnboarding,
            LaunchArguments.skipPermissionChecks
        ])

        // Find and interact with elements
        let myButton = app.buttons["My Button"]
        XCTAssertTrue(UITestHelpers.waitForElement(myButton))

        try UITestHelpers.tapButton(myButton)

        // Verify result
        let resultText = app.staticTexts["Expected Result"]
        XCTAssertTrue(resultText.waitForExistence(timeout: 5))
    }
}
```

### 2. Follow Naming Convention

```
test_<feature>_<scenario>

Examples:
- test_recording_modalAppears
- test_settings_languageChanges
- test_error_microphoneDenied
```

### 3. Use UITestHelpers

```swift
// Wait for element
let exists = UITestHelpers.waitForElement(element, timeout: 10)

// Safe tap (throws if not hittable)
try UITestHelpers.tapButton(button)

// Type text
UITestHelpers.typeText("Hello", in: textField)

// Capture screenshot
UITestHelpers.captureScreenshot(named: "my-test-state", attachTo: self)
```

### 4. Add to Test Plan

Edit `UITests/TestPlans/AllUITests.xctestplan` to include your new test class.

## Launch Arguments Reference

| Argument | Purpose |
|----------|---------|
| `--uitesting` | Enable UI test mode |
| `--reset-onboarding` | Reset to first-launch state |
| `--skip-onboarding` | Skip onboarding flow |
| `--skip-permission-checks` | Use mock permissions |
| `--trigger-recording` | Show recording modal on launch |
| `--mock-permissions=granted` | Mock all permissions as granted |
| `--mock-permissions=denied` | Mock all permissions as denied |
| `--initial-language=es-ES` | Set initial language |
| `--simulate-error=transcription` | Simulate transcription error |

## Debugging Failed Tests

### 1. Check Screenshots

Screenshots are captured automatically on failure:

```bash
# View xcresult bundle
open DerivedData/SpeechToText/Logs/Test/*.xcresult

# Or find in test-screenshots/ directory
ls test-screenshots/
```

### 2. Run Single Test with Logging

```bash
xcodebuild test \
  -scheme SpeechToText \
  -destination 'platform=macOS' \
  -only-testing:SpeechToTextUITests/RecordingFlowTests/test_recording_modalAppears \
  2>&1 | tee test-output.log
```

### 3. Use Verbose Mode

```bash
./scripts/run-ui-tests.sh --verbose
```

### 4. Check Element Hierarchy

Add to your test:

```swift
print(app.debugDescription)
```

## Common Issues

### "Element not found"

1. Check launch arguments are correct
2. Verify element identifier matches
3. Increase timeout
4. Check if onboarding is blocking

### "Not hittable"

1. Element may be covered by another view
2. Animation may not have completed
3. Window may not be key/front

### "Permission dialog appeared"

1. Add `--skip-permission-checks` to launch arguments
2. Ensure `addUIInterruptionMonitor` is configured
3. Pre-configure permissions on test machine

### UI Tests Timeout

1. Check `UI_TEST_TIMEOUT` environment variable
2. Look for hanging animations or dialogs
3. Use `--verbose` to see where it stops

## CI Integration

### GitHub Actions

UI tests run as part of the CI pipeline:

```yaml
jobs:
  ui-tests:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Run UI Tests
        run: ./scripts/run-ui-tests.sh
        timeout-minutes: 10
      - uses: actions/upload-artifact@v4
        if: failure()
        with:
          name: test-results
          path: test-screenshots/
```

### Remote Mac Testing

```bash
# Run on remote Mac via SSH
./scripts/remote-test.sh --include-ui-tests
```

## Success Criteria

Your changes are ready when:

- [ ] All P1 tests pass
- [ ] Pre-push hook runs without errors
- [ ] No regressions in existing tests
- [ ] Screenshots captured on test failures
- [ ] Documentation updated in CLAUDE.md

## Next Steps

1. Review the [Test Scenarios Contract](contracts/test-scenarios.md) for full test list
2. Check [Research](research.md) for technical decisions
3. Implement tests following the [Data Model](data-model.md) entities
