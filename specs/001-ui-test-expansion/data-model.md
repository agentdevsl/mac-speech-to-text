# Data Model: UI Test Expansion

**Feature**: Expand XCUITest Coverage and Pre-Push Hook Integration
**Date**: 2026-01-03
**Status**: Complete

## Entity Overview

This feature primarily involves test infrastructure and scripting. The "data model" consists of:

1. Launch argument configuration
2. Test helper types
3. Script configuration

## Entities

### 1. LaunchArguments

**Purpose**: Defines all supported launch arguments for test mode control.

```swift
/// Launch arguments for XCUITest and smoke testing
enum LaunchArguments {
    // MARK: - Existing Arguments (already implemented)

    /// Enable UI testing mode - disables certain animations and timeouts
    static let uitesting = "--uitesting"

    /// Reset onboarding state - clears UserDefaults for onboarding completion
    static let resetOnboarding = "--reset-onboarding"

    /// Skip permission checks - uses mock permission service
    static let skipPermissionChecks = "--skip-permission-checks"

    /// Skip onboarding entirely - for tests that don't need onboarding flow
    static let skipOnboarding = "--skip-onboarding"

    // MARK: - New Arguments (to be implemented)

    /// Trigger recording modal on launch - for recording flow tests
    static let triggerRecording = "--trigger-recording"

    /// Set mock permission state: granted or denied
    /// Usage: --mock-permissions=granted or --mock-permissions=denied
    static let mockPermissions = "--mock-permissions"

    /// Set initial language for testing
    /// Usage: --initial-language=en-US
    static let initialLanguage = "--initial-language"

    /// Enable accessibility testing mode - verbose accessibility labels
    static let accessibilityTesting = "--accessibility-testing"
}
```

**Fields**:

| Field | Type | Description | Constraints |
|-------|------|-------------|-------------|
| argument | String | Command-line argument string | Starts with `--` |

### 2. UITestConfiguration

**Purpose**: Configuration state for UI test execution.

```swift
/// Configuration for UI test runs
struct UITestConfiguration {
    /// Whether the app is running in UI test mode
    let isUITesting: Bool

    /// Whether onboarding should be reset
    let resetOnboarding: Bool

    /// Whether to skip permission checks
    let skipPermissionChecks: Bool

    /// Whether to skip onboarding flow
    let skipOnboarding: Bool

    /// Whether to trigger recording modal on launch
    let triggerRecordingOnLaunch: Bool

    /// Mock permission state (nil = real permissions)
    let mockPermissionState: MockPermissionState?

    /// Initial language code for testing
    let initialLanguage: String?

    /// Whether accessibility testing mode is enabled
    let accessibilityTestingEnabled: Bool

    /// Parse configuration from ProcessInfo arguments
    static func fromProcessInfo() -> UITestConfiguration
}

/// Mock permission state for testing
enum MockPermissionState: String {
    case granted
    case denied
}
```

**Fields**:

| Field | Type | Description | Default |
|-------|------|-------------|---------|
| isUITesting | Bool | UI test mode flag | false |
| resetOnboarding | Bool | Reset onboarding state | false |
| skipPermissionChecks | Bool | Use mock permissions | false |
| skipOnboarding | Bool | Skip onboarding flow | false |
| triggerRecordingOnLaunch | Bool | Show recording modal immediately | false |
| mockPermissionState | MockPermissionState? | Forced permission state | nil |
| initialLanguage | String? | Override language setting | nil |
| accessibilityTestingEnabled | Bool | Enable verbose a11y | false |

### 3. UITestResult

**Purpose**: Represents the result of a UI test execution for reporting.

```swift
/// Result of a single UI test execution
struct UITestResult {
    /// Test identifier (class.method)
    let testIdentifier: String

    /// Whether the test passed
    let passed: Bool

    /// Duration in seconds
    let duration: TimeInterval

    /// Failure message if test failed
    let failureMessage: String?

    /// Path to failure screenshot if captured
    let screenshotPath: URL?

    /// Accessibility audit results if applicable
    let accessibilityAuditResults: [AccessibilityAuditResult]?
}

/// Result of an accessibility audit
struct AccessibilityAuditResult {
    /// Element identifier
    let elementIdentifier: String

    /// Audit issue type
    let issueType: AccessibilityIssueType

    /// Description of the issue
    let issueDescription: String
}

/// Types of accessibility issues
enum AccessibilityIssueType {
    case missingLabel
    case insufficientContrast
    case touchTargetTooSmall
    case dynamicTypeUnsupported
}
```

**Fields**:

| Field | Type | Description | Constraints |
|-------|------|-------------|-------------|
| testIdentifier | String | Full test method name | Non-empty |
| passed | Bool | Test pass/fail status | Required |
| duration | TimeInterval | Execution time | >= 0 |
| failureMessage | String? | Error description | nil if passed |
| screenshotPath | URL? | Failure screenshot | nil if passed |

### 4. PrePushHookConfig

**Purpose**: Configuration for the pre-push hook script behavior.

```swift
/// Pre-push hook configuration (read from environment and flags)
struct PrePushHookConfig {
    /// Whether to skip UI tests entirely
    let skipUITests: Bool

    /// Whether to run only UI tests (skip unit tests)
    let uiTestsOnly: Bool

    /// Timeout for UI test execution in seconds
    let uiTestTimeout: TimeInterval

    /// Whether to run tests in verbose mode
    let verbose: Bool

    /// Sync mode for remote testing (rsync or scp)
    let syncMode: SyncMode

    /// Default configuration
    static let `default` = PrePushHookConfig(
        skipUITests: false,
        uiTestsOnly: false,
        uiTestTimeout: 600, // 10 minutes
        verbose: false,
        syncMode: .scp
    )
}

/// Sync mode for remote testing
enum SyncMode: String {
    case rsync
    case scp
}
```

**Environment Variables**:

| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| UI_TEST_TIMEOUT | Int | Timeout in seconds | 600 |
| UI_TEST_VERBOSE | Bool | Verbose output | false |
| SKIP_UI_TESTS | Bool | Skip UI tests | false |

### 5. TestScenario

**Purpose**: Defines test scenarios for documentation and traceability.

```swift
/// A test scenario mapping to acceptance criteria
struct TestScenario {
    /// User story reference (e.g., "US1", "US2")
    let userStory: String

    /// Priority level
    let priority: TestPriority

    /// Scenario description
    let description: String

    /// XCTest method name implementing this scenario
    let testMethodName: String

    /// Required launch arguments
    let requiredLaunchArguments: [String]

    /// Whether this scenario requires manual intervention
    let requiresManualIntervention: Bool
}

/// Test priority levels
enum TestPriority: String, Comparable {
    case p1 = "P1"
    case p2 = "P2"
    case p3 = "P3"

    static func < (lhs: TestPriority, rhs: TestPriority) -> Bool {
        let order: [TestPriority] = [.p1, .p2, .p3]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}
```

## Relationships

```
UITestConfiguration --uses--> LaunchArguments
    Parse launch arguments to create configuration

PrePushHookConfig --controls--> UITestExecution
    Determines which tests run and how

TestScenario --maps-to--> XCTestCase methods
    Traceability from spec to implementation

UITestResult --references--> TestScenario
    Results link back to scenarios for reporting
```

## State Transitions

### Test Execution State

```
[Not Started] -> [Setup] -> [Running] -> [Teardown] -> [Complete]
                    |           |            |
                    v           v            v
              [Setup Failed] [Test Failed] [Teardown Failed]
                    |           |            |
                    +-----------+------------+
                                |
                                v
                         [Screenshot Captured]
```

### Pre-Push Hook State

```
[Hook Triggered]
      |
      v
[Parse Arguments] --> [Skip All Tests] --> [Exit 0]
      |
      v
[Run Unit Tests] -----> [Unit Tests Failed] --> [Exit 1]
      |
      v (if not --ui-tests-only)
[Run UI Tests] -------> [UI Tests Failed] ----> [Exit 1]
      |
      v
[All Tests Passed] --> [Exit 0]
```

## Validation Rules

1. **LaunchArguments**: Must start with `--` prefix
2. **UITestConfiguration**: `mockPermissionState` only valid when `skipPermissionChecks` is true
3. **UITestResult**: `screenshotPath` must be valid URL if provided
4. **PrePushHookConfig**: `uiTestTimeout` must be positive, max 600 seconds
5. **TestScenario**: `testMethodName` must match pattern `test_<feature>_<scenario>`

## Notes

- These entities are primarily used at test-time, not runtime
- `LaunchArguments` are string constants, not persisted
- `UITestResult` is transient, used for reporting only
- `PrePushHookConfig` is parsed from environment/flags, not stored
