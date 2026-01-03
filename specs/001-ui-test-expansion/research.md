# Research: UI Test Expansion

**Feature**: Expand XCUITest Coverage and Pre-Push Hook Integration
**Date**: 2026-01-03
**Status**: Complete

## Research Tasks

### 1. XCUITest Best Practices for macOS Menu Bar Apps

**Question**: How to effectively test menu bar applications with XCUITest, particularly for global hotkey triggering and floating window modals?

**Decision**: Use a hybrid testing approach combining XCUITest with launch arguments for state control.

**Rationale**:

- XCUITest cannot directly trigger global hotkeys (Carbon API) or access menu bar extras reliably
- The app already supports `--uitesting`, `--reset-onboarding`, and `--skip-permission-checks` launch arguments
- Tests should use notification-based triggering where possible (e.g., `NotificationCenter.default.post(name: .showRecordingModal)`)
- For global hotkey tests, use AppleScript bridges via `NSAppleScript` or accept limitations

**Alternatives Considered**:

- **Pure AppleScript automation**: Rejected - fragile, slower, and less integrated with XCTest assertions
- **Accessibility API direct access**: Rejected - requires elevated permissions not suitable for CI
- **UI Automation frameworks (like Appium)**: Rejected - overkill for native macOS app, adds complexity

**Implementation Notes**:

- Add `--trigger-recording` launch argument to programmatically trigger recording modal for tests
- Use `XCUIApplication.activate()` and `app.windows` queries for window state verification
- Screenshot capture via `XCUIScreen.main.screenshot()` for failure diagnostics

### 2. Pre-Push Hook Integration Patterns

**Question**: How to integrate UI tests into the existing pre-push hook without significantly impacting developer workflow?

**Decision**: Extend the existing pre-push hook with conditional UI test execution controlled by flags.

**Rationale**:

- Current pre-push hook (`scripts/remote-test.sh`) runs unit tests on remote Mac via SSH
- UI tests require macOS display and can take 3-5 minutes
- Developers need escape hatches for quick iterations
- Configurable timeout prevents CI hangs

**Alternatives Considered**:

- **Separate pre-push hooks**: Rejected - harder to maintain, confusing for developers
- **CI-only UI tests**: Rejected - misses the "catch before push" benefit
- **Parallel test execution**: Investigated but deferred - xcodebuild parallelization is limited for UI tests

**Implementation Notes**:

- Add flags: `--skip-ui-tests`, `--ui-tests-only`, `--timeout=<seconds>`
- Default timeout: 600 seconds (10 minutes) via `UI_TEST_TIMEOUT` environment variable
- Exit code propagation: any test failure blocks push
- Verbose mode shows xcodebuild output in real-time

### 3. Screenshot Capture on Failure

**Question**: How to implement reliable screenshot capture for XCUITest failures on macOS?

**Decision**: Use XCTest's native `XCTAttachment` API with automatic teardown capture.

**Rationale**:

- XCTest provides built-in screenshot capture via `XCUIScreen.main.screenshot()`
- `XCTAttachment` automatically saves to test results bundle
- Accessible via Xcode Test Reports and `xcresult` bundle

**Alternatives Considered**:

- **Manual screencapture command**: Rejected - requires subprocess, file management complexity
- **Custom screenshot directory**: Implemented as complement - saves to `test-screenshots/` for easy access

**Implementation Notes**:

```swift
override func tearDown() {
    if testRun?.failureCount ?? 0 > 0 {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Failure-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    super.tearDown()
}
```

### 4. Permission Dialog Handling in Tests

**Question**: How to handle macOS permission dialogs (microphone, accessibility) that cannot be automated?

**Decision**: Use launch arguments to bypass permission checks in test mode with clear documentation of limitations.

**Rationale**:

- macOS TCC (Transparency, Consent, and Control) dialogs cannot be automated by design
- `tccutil` can reset permissions but cannot grant them programmatically
- Test infrastructure must work without manual intervention
- Real permission flows should be tested manually or via MDM-provisioned test machines

**Alternatives Considered**:

- **MDM profiles for test machines**: Valid for CI environments, out of scope for developer machines
- **Mock permission service**: Already exists (`MockPermissionService`), used for unit tests
- **Full Automation Hub (like Sauce Labs)**: Rejected - cost and complexity for this project scale

**Implementation Notes**:

- `--skip-permission-checks` launch argument bypasses `PermissionService` checks
- App detects this flag and uses mock/stub implementations
- Document that full permission flow tests require manual intervention or MDM setup
- Add test for error UI when permissions are denied (using mock state)

### 5. Test Helper Utilities Pattern

**Question**: What utilities should `UITestHelpers.swift` provide for consistent test implementation?

**Decision**: Create a focused helper module with waiting, element interaction, and assertion utilities.

**Rationale**:

- Reduces boilerplate in individual test files
- Encapsulates XCUITest's async patterns
- Provides consistent timeout and retry behavior
- Makes tests more readable and maintainable

**Alternatives Considered**:

- **Third-party libraries (Quick/Nimble for UI)**: Rejected - XCTest is sufficient, reduces dependencies
- **Page Object Model full implementation**: Deferred - current scope doesn't require that complexity

**Implementation Notes**:

```swift
enum UITestHelpers {
    static func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool
    static func tapButton(_ button: XCUIElement, app: XCUIApplication)
    static func typeText(_ text: String, in element: XCUIElement)
    static func verifyText(_ text: String, exists: Bool, in app: XCUIApplication)
    static func captureScreenshot(named: String, attachment: Bool = true) -> XCUIScreenshot
}
```

### 6. Test Organization and Naming

**Question**: How should the expanded UI test suite be organized for maintainability?

**Decision**: Organize by feature with clear naming conventions and test plan support.

**Rationale**:

- Feature-based organization maps to user stories in spec
- Test plans allow selective execution (recording, onboarding, settings)
- Naming convention: `test_<feature>_<scenario>` for consistency

**Alternatives Considered**:

- **Single file with regions**: Rejected - grows unwieldy, harder to navigate
- **One file per test case**: Rejected - too granular, increases overhead

**Implementation Notes**:

```
UITests/
├── SpeechToTextUITests.swift      # Base class and shared utilities
├── RecordingFlowTests.swift       # Recording modal tests (P1)
├── OnboardingFlowTests.swift      # Onboarding tests (P2)
├── SettingsTests.swift            # Settings tests (P2)
├── ErrorStateTests.swift          # Error handling tests (P2)
├── AccessibilityTests.swift       # VoiceOver/keyboard tests (P3)
├── LanguageSelectionTests.swift   # Language picker tests (P3)
└── TestPlans/
    ├── AllUITests.xctestplan
    ├── QuickUITests.xctestplan    # P1 tests only
    └── AccessibilityTests.xctestplan
```

### 7. Existing Infrastructure Analysis

**Question**: What existing test infrastructure can be leveraged or extended?

**Decision**: Extend existing infrastructure rather than replace.

**Findings**:

- **Existing UITests**: `SpeechToTextUITests.swift` has basic onboarding and recording tests
- **Launch arguments**: `--uitesting`, `--reset-onboarding`, `--skip-permission-checks`, `--skip-onboarding` already implemented
- **Pre-push hook**: `scripts/remote-test.sh` runs unit tests via SSH
- **UI test script**: `scripts/run-ui-tests.sh` exists but needs enhancement
- **Permission handler**: `addUIInterruptionMonitor` pattern already in use
- **Test helpers**: `Tests/SpeechToTextTests/Utilities/ScreenshotTestHelper.swift` exists for unit tests

**Implementation Notes**:

- Refactor existing `SpeechToTextUITests.swift` into base class
- Add new test files following organization pattern
- Enhance `run-ui-tests.sh` with configurable options
- Modify `pre-push` hook to call UI tests with appropriate flags

### 8. CI/CD Integration

**Question**: How will the expanded UI tests integrate with GitHub Actions CI?

**Decision**: Leverage existing remote Mac infrastructure with optional UI test stage.

**Rationale**:

- GitHub-hosted macOS runners support XCUITest
- Existing `remote-test.sh` infrastructure handles SSH to dedicated Mac
- UI tests should run in CI but not block quick PR validation

**Alternatives Considered**:

- **GitHub-hosted macOS runners only**: May not have proper permissions setup
- **Self-hosted runner with display**: Ideal but requires hardware investment
- **Headless UI tests**: Not supported by XCUITest

**Implementation Notes**:

- Add `ui-tests` job to GitHub Actions workflow
- Use `continue-on-error: true` initially while stabilizing tests
- Configure `UI_TEST_TIMEOUT` environment variable in CI
- Archive `xcresult` bundles as artifacts for failure diagnosis

## Summary

All technical unknowns have been resolved. The implementation will:

1. **Extend existing UITests** with feature-based organization
2. **Enhance pre-push hook** with `--skip-ui-tests` and `--ui-tests-only` flags
3. **Use launch arguments** for test mode control and permission bypassing
4. **Implement UITestHelpers** for consistent test patterns
5. **Add screenshot capture** via XCTest native APIs
6. **Integrate with CI** through existing remote Mac infrastructure

No constitution violations identified. The approach follows:

- Swift 5.9+ with XCTest (native framework)
- TDD-aligned testing patterns
- Local-first execution (no cloud services required)
- Minimal new dependencies
