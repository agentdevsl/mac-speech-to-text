# Research: Permission and Code Signing for Local Development

**Feature**: 002-permission-signing
**Date**: 2026-01-03
**Status**: Complete

This document captures research findings for implementing persistent code signing
for local macOS development, resolving all "NEEDS CLARIFICATION" items from the
plan.

---

## Research Topics

### 1. macOS TCC (Transparency, Consent, and Control) Behavior

**Question**: How does TCC determine application identity for permission persistence?

**Findings**:

1. **Code Signing Identity**: TCC uses the code signing identity (code directory
   hash) to identify applications. When an app is signed with the same identity
   across builds, TCC recognizes it as the same application.

2. **Ad-hoc Signing Behavior**: Ad-hoc signing (`codesign --sign -`) generates a
   unique identifier per build based on the code content. Each rebuild creates a
   new identity, causing TCC to treat it as a new application.

3. **Self-Signed Certificate Persistence**: A self-signed certificate stored in
   the macOS Keychain provides a consistent signing identity. When the same
   certificate signs multiple builds, TCC preserves permissions.

4. **Bundle Identifier Impact**: The `CFBundleIdentifier` in Info.plist also
   factors into TCC identity. It must remain consistent across builds.

**Decision**: Use self-signed development certificates stored in the login
keychain for consistent code signing identity.

**Rationale**: This provides the simplest path to persistent permissions without
requiring Apple Developer Program enrollment.

**Alternatives Considered**:

- Apple Developer ID: Requires paid enrollment, overkill for local development
- Hardened Runtime without signing: Not possible, macOS requires valid signature
- Xcode automatic signing: Works but ties development to Xcode workflow

---

### 2. Self-Signed Certificate Creation Methods

**Question**: What is the best method to create self-signed code signing
certificates on macOS?

**Findings**:

1. **Keychain Access GUI**:
   - Path: Keychain Access > Certificate Assistant > Create a Certificate
   - Pros: Visual, no command-line required
   - Cons: Manual process, not scriptable, requires multiple clicks

2. **OpenSSL + security CLI**:
   - Uses OpenSSL to generate cert, `security` to import to keychain
   - Pros: Fully scriptable, no Xcode required
   - Cons: Complex command sequence, PKCS12 conversion required

3. **security CLI only**:
   - `security create-keychain` and related commands
   - Pros: Native macOS tools
   - Cons: Cannot create certificates directly, only manage keychains

**Decision**: Use OpenSSL + security CLI approach in `setup-signing.sh`.

**Rationale**: Scriptable automation enables consistent team experience and can
be documented in CI/CD. Already implemented in existing `setup-signing.sh`.

**Alternatives Considered**:

- Keychain Access GUI: Documented as fallback for script failures
- Third-party tools: Unnecessary complexity

---

### 3. Entitlements for TCC Permissions

**Question**: What entitlements are required for microphone, accessibility, and
input monitoring permissions?

**Findings**:

The following entitlements are required (already present in
`SpeechToText.entitlements`):

| Entitlement | Purpose | TCC |
|-------------|---------|-----|
| `device.microphone` | Audio capture | Mic |
| `automation.apple-events` | Text insertion | Auto |
| `accessibility` | AX API access | AX |
| `files.user-selected` | File dialogs | Files |
| `network.client` | Model download | Net |

**Important Note**: `com.apple.security.app-sandbox` is set to `false`. This is
intentional because:

- Full accessibility API access requires non-sandboxed execution
- Global hotkeys via Carbon require non-sandboxed execution
- FluidAudio SDK may need non-sandboxed paths for models

**Decision**: Keep current entitlements. No changes required.

**Rationale**: Current entitlements already cover all required TCC categories.

---

### 4. Xcode Automatic Signing Workflow

**Question**: How does Xcode handle code signing, and can it be used as an
alternative workflow?

**Findings**:

1. **Xcode Automatic Signing**:
   - Xcode automatically creates a development certificate on first build
   - Certificate persists in keychain across builds
   - No manual setup required

2. **SPM Integration**:
   - Open `Package.swift` in Xcode to generate Xcode project
   - Xcode manages signing automatically
   - Entitlements must be added to Xcode project settings

3. **Limitations**:
   - Xcode-generated signing doesn't apply to `swift build` CLI builds
   - Developers using both workflows need separate signing strategies

**Decision**: Document Xcode workflow as a first-class alternative with its own
advantages (automatic signing, debugger integration).

**Rationale**: Xcode provides superior debugging experience and eliminates
manual signing setup.

---

### 5. Certificate Expiration and Renewal

**Question**: How should expired certificates be handled?

**Findings**:

1. **Default Validity**: The `setup-signing.sh` creates certificates valid for
   10 years (3650 days), making expiration rare.

2. **Detection**: `security find-identity -v -p codesigning` shows validity.
   Expired certs still appear but fail signing operations.

3. **Renewal Process**:
   - Delete old certificate from Keychain Access
   - Run `setup-signing.sh` to create new certificate
   - Permissions will need re-granting for new identity

**Decision**: Use 10-year validity to minimize renewal frequency. Document
renewal process for edge cases.

**Rationale**: 10 years exceeds typical project lifespan. Renewal is
straightforward.

---

### 6. System Integrity Protection (SIP) Considerations

**Question**: Does SIP affect code signing or permission granting?

**Findings**:

1. **SIP and Code Signing**: SIP does not affect user-generated self-signed
   certificates or codesigning operations on user applications.

2. **SIP and TCC**: SIP protects the TCC database. Direct manipulation is not
   possible.

3. **Automation TCC**: Some automation permissions (AppleEvents to system apps)
   may require explicit user approval even with entitlements.

**Decision**: Document SIP as informational. No workarounds needed for standard
development workflow.

**Rationale**: SIP does not block the intended functionality.

---

### 7. Build Script Integration Points

**Question**: How should the build script detect and use signing identities?

**Findings**:

Current `build-app.sh` already implements:

1. **Identity File**: Checks for `.signing-identity` file in project root
2. **CLI Override**: `--sign NAME` flag overrides file-based identity
3. **Fallback**: Defaults to ad-hoc signing with warning
4. **Entitlements**: Applies entitlements when using a real identity

**Gaps Identified**:

- No validation that the identity exists in keychain before build
- No clear error message when identity file is malformed
- Warning about ad-hoc signing could be more prominent

**Decision**: Enhance build script with identity validation and clearer
warnings.

**Rationale**: Better developer experience with actionable error messages.

---

## Summary of Decisions

| Topic | Decision |
|-------|----------|
| Code signing approach | Self-signed certificate via `setup-signing.sh` |
| Certificate creation | OpenSSL + security CLI (existing script) |
| Entitlements | No changes needed (current file is complete) |
| Xcode workflow | Document as first-class alternative |
| Certificate validity | 10 years (3650 days) |
| SIP handling | Informational documentation only |
| Build integration | Enhance validation and warnings |

---

## Open Questions Resolved

All "NEEDS CLARIFICATION" items have been resolved:

1. **How does TCC track identity?** - Via code signing identity + bundle ID
2. **What signing method to use?** - Self-signed certificate in login keychain
3. **What entitlements are needed?** - Already complete in current file
4. **How to handle Xcode users?** - Document as parallel workflow
5. **Certificate expiration?** - 10-year validity, document renewal

---

## References

- Apple Developer Documentation: Code Signing Guide
- Apple TCC: Technical Note TN3127
- Existing project files: `scripts/setup-signing.sh`, `scripts/build-app.sh`
- Existing entitlements: `SpeechToText.entitlements`
