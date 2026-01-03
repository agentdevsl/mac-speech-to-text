# Feature Specification: Permission and Code Signing for Local Development

**Feature Branch**: `002-permission-signing`
**Created**: 2026-01-03
**Status**: Draft
**Input**: User description: "Fix permission and code signing issues"

## User Scenarios & Testing _(mandatory)_

### User Story 1 - Persistent Code Signing Identity (Priority: P1)

As a developer building the application locally, I want my code signing
identity to persist across rebuilds so that macOS TCC (Transparency, Consent,
and Control) recognizes the application as the same entity and preserves my
granted permissions (microphone, accessibility, input monitoring).

**Why this priority**: Without consistent code signing, every rebuild creates
a new identity. macOS TCC treats each build as a brand new application,
requiring developers to re-grant all permissions manually. This is the root
cause blocking effective local development.

**Independent Test**: Can be fully tested by building the application twice
consecutively, granting permissions after the first build, then verifying
permissions remain granted after the second build without re-authorization.

**Acceptance Scenarios**:

1. **Given** a developer has built the app and granted microphone permission,
   **When** they rebuild the app using the same signing configuration,
   **Then** the microphone permission remains granted without prompting again.

2. **Given** a developer has granted accessibility permission to the app,
   **When** they rebuild the app,
   **Then** the app appears under the same entry in System Settings >
   Privacy & Security > Accessibility.

3. **Given** a developer runs the build script without any signing identity,
   **When** the build completes,
   **Then** the script displays a clear message explaining that ad-hoc signing
   will not preserve permissions across rebuilds.

---

### User Story 2 - Signing Setup Workflow (Priority: P2)

As a developer setting up the project for the first time, I want a simple
workflow to configure code signing so that I can quickly get started with
local development without understanding the complexities of macOS code signing.

**Why this priority**: A streamlined setup process reduces friction for new
developers and ensures consistent signing configuration across the team, but
existing developers can work around this manually.

**Independent Test**: Can be fully tested by running the setup script on a
fresh clone of the repository and verifying that subsequent builds maintain
permission persistence.

**Acceptance Scenarios**:

1. **Given** a developer has cloned the repository and has valid Apple tools,
   **When** they run the signing setup workflow,
   **Then** a self-signed certificate is created and configured for builds.

2. **Given** a developer runs the signing setup workflow,
   **When** the setup completes successfully,
   **Then** subsequent builds automatically use the configured signing identity.

3. **Given** a developer runs the signing setup workflow but lacks tools,
   **When** the setup encounters an error,
   **Then** clear error messages guide the developer on how to resolve.

---

### User Story 3 - Xcode Development Workflow (Priority: P3)

As a developer who prefers using Xcode, I want clear documentation on how to
use Xcode for development so that I can take advantage of Xcode's built-in
code signing management and debugging tools.

**Why this priority**: Xcode handles code signing automatically and provides
superior debugging capabilities, but the project is primarily configured for
Swift Package Manager command-line builds.

**Independent Test**: Can be fully tested by opening the project in Xcode,
building, and verifying that permissions persist across Xcode rebuilds.

**Acceptance Scenarios**:

1. **Given** a developer opens the package in Xcode,
   **When** they build and run the application,
   **Then** Xcode automatically handles code signing with consistent identity.

2. **Given** a developer has granted permissions via Xcode-built app,
   **When** they rebuild in Xcode,
   **Then** permissions persist without requiring re-authorization.

3. **Given** a developer wants to debug the recording flow,
   **When** they run the app through Xcode,
   **Then** they can use LLDB breakpoints and console logging effectively.

---

### User Story 4 - End-to-End Recording Validation (Priority: P4)

As a developer, I want to verify the complete recording workflow (audio
capture, transcription, text insertion) so that I can confirm all components
work correctly after fixing permission issues.

**Why this priority**: This validates that the permission fixes actually
enable the full application functionality, but it depends on having
persistent permissions first.

**Independent Test**: Can be fully tested by recording speech, observing
transcription, and verifying text is inserted into a target application.

**Acceptance Scenarios**:

1. **Given** the app has microphone permission and FluidAudio models loaded,
   **When** the user records speech,
   **Then** the audio is captured without errors.

2. **Given** audio has been captured successfully,
   **When** transcription completes,
   **Then** the transcribed text appears in the recording modal.

3. **Given** the app has accessibility permission and text is transcribed,
   **When** the text insertion occurs,
   **Then** the transcribed text is pasted into the frontmost application.

---

### Edge Cases

- What happens when a developer's self-signed certificate expires?
  - The system should detect expired certificates and prompt for renewal

- What happens when Keychain access is denied during signing?
  - Build script should provide clear error messages guiding users to grant
    Keychain access

- What happens when multiple signing identities are available?
  - Setup workflow should allow selection or default to most recent valid cert

- What happens when System Integrity Protection (SIP) blocks operations?
  - Documentation should explain SIP limitations and workarounds

- What happens when microphone permission is revoked while recording?
  - The app should gracefully handle permission revocation with clear errors

## Requirements _(mandatory)_

### Functional Requirements

- **FR-001**: Build system MUST support configuring a persistent code signing
  identity that survives across rebuilds
- **FR-002**: Build system MUST use the configured signing identity
  automatically when building the application
- **FR-003**: Build system MUST display clear warnings when using ad-hoc
  signing about permission persistence limitations
- **FR-004**: Project MUST provide a setup script to create and configure a
  self-signed development certificate
- **FR-005**: Setup script MUST store the signing identity configuration in a
  location that is not committed to version control
- **FR-006**: Setup script MUST validate that required tools (security,
  codesign, Keychain) are available
- **FR-007**: Documentation MUST explain how to use Xcode as an alternative
  development workflow
- **FR-008**: Documentation MUST explain the relationship between code
  signing and macOS TCC permissions
- **FR-009**: Build script MUST apply entitlements when signing with a valid
  identity
- **FR-010**: Project MUST provide a verification mechanism to test that the
  complete recording workflow functions correctly

### Key Entities

- **Signing Identity**: A code signing certificate stored in the developer's
  Keychain, identified by its Common Name (e.g., "SpeechToText Development").
  Used to consistently sign builds so TCC recognizes them as the same app.

- **Signing Configuration**: A project-local file (e.g., `.signing-identity`)
  containing the name of the signing identity to use. Excluded from version
  control to allow per-developer customization.

- **Entitlements**: A plist file (`SpeechToText.entitlements`) declaring the
  application's required capabilities (microphone, accessibility, automation).
  Applied during code signing to enable TCC permission requests.

## Success Criteria _(mandatory)_

### Measurable Outcomes

- **SC-001**: Developers can grant permissions once and retain them across at
  least 10 consecutive rebuilds without re-authorization
- **SC-002**: New developers can complete the signing setup workflow in under
  5 minutes
- **SC-003**: The complete recording workflow (record, transcribe, insert)
  succeeds on first attempt after proper setup
- **SC-004**: Build script provides actionable error messages that allow
  developers to resolve signing issues without external documentation in 90%
  of common failure cases
- **SC-005**: Documentation enables developers unfamiliar with macOS code
  signing to understand the permission model and configure their environment
