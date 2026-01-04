# UI Testing Guide

This document explains how to run UI tests (XCUITest) for the macOS Speech-to-Text application.

## Prerequisites

- macOS 14+ with Xcode 16+ installed
- The application must be code-signed (even with ad-hoc signing)
- Microphone and Accessibility permissions may be required

## Quick Start

### Run All UI Tests

```bash
./scripts/run-ui-tests.sh
```

### Run with Verbose Output

```bash
./scripts/run-ui-tests.sh --verbose
```

### Run Specific Test Plan

```bash
./scripts/run-ui-tests.sh --plan P1-RecordingFlow
```

Available test plans:
- `P1-RecordingFlow` - Core recording workflow tests
- `P2-SettingsTests` - Settings window tests
- `P3-Accessibility` - Accessibility compliance tests
- `AllUITests` - All UI tests (default)

## Running from Xcode

1. Open the project in Xcode:
   ```bash
   open Package.swift
   ```

2. Select the `SpeechToText` scheme

3. Choose your Mac as the destination

4. Press `Cmd+U` to run all tests, or use the Test Navigator (`Cmd+6`) to run individual tests

## Test Structure

```
UITests/
├── Base/
│   ├── UITestBase.swift      # Base class with common setup
│   └── UITestHelpers.swift   # Utility functions
├── P1/                       # Priority 1 (Critical)
│   ├── RecordingFlowTests.swift
│   ├── OnboardingFlowTests.swift
│   └── TestInfrastructureTests.swift
├── P2/                       # Priority 2 (Important)
│   ├── SettingsTests.swift
│   ├── ErrorStateTests.swift
│   └── LanguageTests.swift
├── P3/                       # Priority 3 (Nice-to-have)
│   └── AccessibilityTests.swift
└── TestPlans/
    ├── AllUITests.xctestplan
    ├── P1-RecordingFlow.xctestplan
    ├── P2-SettingsTests.xctestplan
    └── P3-Accessibility.xctestplan
```

## Launch Arguments for Testing

The app supports these launch arguments for UI testing:

| Argument | Description |
|----------|-------------|
| `--uitesting` | Enable UI testing mode |
| `--skip-onboarding` | Skip the onboarding flow |
| `--reset-onboarding` | Reset onboarding to show fresh |
| `--trigger-recording` | Open recording modal on launch |
| `--skip-permission-checks` | Skip permission validation |
| `--mock-permission-state=granted` | Mock permission as granted |
| `--mock-permission-state=denied` | Mock permission as denied |
| `--accessibility-testing` | Enable accessibility testing mode |
| `--initial-language=en` | Set initial language code |
| `--simulate-error=transcription` | Simulate transcription error |

### Example Usage in Tests

```swift
func testRecordingModal() throws {
    let app = XCUIApplication()
    app.launchArguments = [
        "--uitesting",
        "--skip-onboarding",
        "--skip-permission-checks",
        "--trigger-recording"
    ]
    app.launch()

    // Test recording modal appears
    XCTAssertTrue(app.staticTexts["Recording"].waitForExistence(timeout: 5))
}
```

## Pre-Push Hook Integration

The pre-push hook runs UI tests on `macdev` (remote Mac) before allowing pushes.

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SKIP_UI_TESTS` | `0` | Set to `1` to skip UI tests |
| `UI_TESTS_ONLY` | `0` | Set to `1` to run only UI tests |
| `SKIP_ALL_TESTS` | `0` | Set to `1` to skip all tests |
| `UI_TEST_TIMEOUT` | `600` | Timeout in seconds |
| `REMOTE_TEST_HOST` | `macdev` | SSH host for remote testing |

### Examples

```bash
# Normal push (runs unit + UI tests on macdev)
git push

# Skip UI tests for quick iteration
SKIP_UI_TESTS=1 git push

# Run only UI tests
UI_TESTS_ONLY=1 git push

# Skip all tests (not recommended)
git push --no-verify
```

## Remote Testing on macdev

### SSH Setup

```bash
# One-time setup
./scripts/setup-ssh-for-mac.sh
```

### Manual Remote Testing

```bash
# Sync code and run tests
./scripts/remote-test.sh

# Run only UI tests
./scripts/remote-test.sh --ui-only

# Run with verbose output
./scripts/remote-test.sh --verbose
```

## Writing New Tests

### Base Class

All UI tests should extend `UITestBase`:

```swift
import XCTest

final class MyNewTests: UITestBase {
    func test_myFeature_works() throws {
        // Launch with recording modal
        launchAppWithRecordingModal()

        // Wait for element
        let element = app.buttons["My Button"]
        guard element.waitForExistence(timeout: 5) else {
            captureScreenshot(named: "MyTest-Element-Not-Found")
            XCTFail("Button not found")
            return
        }

        // Interact
        element.tap()

        // Verify
        XCTAssertTrue(app.staticTexts["Success"].exists)
        captureScreenshot(named: "MyTest-Success")
    }
}
```

### Helper Methods

```swift
// Launch variants
launchAppSkippingOnboarding()
launchAppWithFreshOnboarding()
launchAppWithRecordingModal()
launchApp(arguments: ["--custom-arg"])

// Wait utilities
waitForDisappearance(element, timeout: 5)

// Screenshots (saved to test results)
captureScreenshot(named: "descriptive-name")
```

### Keyboard Helpers

```swift
// Press Escape key
UITestHelpers.pressEscape(in: app)

// Open Settings (Cmd+,)
UITestHelpers.openSettings(in: app)
```

## Troubleshooting

### Tests Can't Find Elements

1. Check accessibility identifiers are set in the SwiftUI views
2. Use `--accessibility-testing` launch argument
3. Capture screenshots to see actual UI state
4. Try increasing timeout values

### Permission Dialogs Block Tests

Use `--skip-permission-checks` and `--mock-permission-state=granted` to bypass real permission checks.

### Tests Pass Locally but Fail on macdev

1. Ensure macdev has same Xcode version
2. Check SSH connection: `ssh macdev echo connected`
3. Verify code is synced: `./scripts/build-app.sh --sync`
4. Check for timing differences (increase timeouts)

### Recording Modal Doesn't Appear

1. Verify `--trigger-recording` is in launch arguments
2. Check for errors in console output
3. Ensure app is properly code-signed

## CI Integration

UI tests run on macdev via SSH because GitHub Actions doesn't provide macOS hardware with UI capabilities.

The workflow is:
1. Pre-push hook syncs code to macdev
2. Runs `swift test --parallel` for unit tests
3. Runs `./scripts/run-ui-tests.sh` for UI tests
4. Blocks push if any tests fail

To bypass for emergency fixes:
```bash
git push --no-verify
```

**Note**: Always fix failing tests before merging to main.
