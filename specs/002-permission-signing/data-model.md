# Data Model: Permission and Code Signing

**Feature**: 002-permission-signing
**Date**: 2026-01-03
**Status**: Complete

This document defines the data entities, configurations, and relationships for
the permission and code signing feature.

---

## Entities

### 1. SigningIdentity

Represents a code signing certificate stored in the macOS Keychain.

```text
Entity: SigningIdentity
Purpose: Identifies the certificate used to sign application builds
Storage: macOS Keychain (login.keychain-db)

Fields:
  - commonName: String [required]
    Description: Certificate Common Name (e.g., "SpeechToText-Dev")
    Validation: Non-empty, alphanumeric with hyphens allowed
    Example: "SpeechToText-Dev"

  - validFrom: Date [readonly]
    Description: Certificate validity start date
    Source: Generated at creation time

  - validUntil: Date [readonly]
    Description: Certificate expiration date
    Default: 10 years from creation

  - keyUsage: String [readonly]
    Description: Certificate key usage (always "codeSigning")
    Value: "critical, codeSigning"

  - isValid: Boolean [computed]
    Description: Whether certificate is within validity period
    Computation: current_date >= validFrom AND current_date <= validUntil
```

### 2. SigningConfiguration

Project-level configuration that references a signing identity.

```text
Entity: SigningConfiguration
Purpose: Stores the signing identity to use for builds
Storage: File system (.signing-identity in project root)

Fields:
  - identityName: String [required]
    Description: Common Name of the certificate to use
    Validation: Must match an existing SigningIdentity in keychain
    Example: "SpeechToText-Dev"

File Format: Plain text, single line, no trailing whitespace
Location: ${PROJECT_ROOT}/.signing-identity
Git Status: Excluded via .gitignore (per-developer configuration)
```

### 3. Entitlements

Application capability declarations for TCC permission requests.

```text
Entity: Entitlements
Purpose: Declares required system permissions for the application
Storage: File system (SpeechToText.entitlements)
Format: XML Property List (plist)

Fields:
  - microphone: Boolean [required]
    Key: com.apple.security.device.microphone
    Purpose: Audio capture for speech recognition
    Default: true

  - automation: Boolean [required]
    Key: com.apple.security.automation.apple-events
    Purpose: Send AppleEvents to other applications
    Default: true

  - accessibility: Boolean [required]
    Key: com.apple.security.personal-information.accessibility
    Purpose: Use Accessibility APIs for text insertion
    Default: true

  - userSelectedFiles: Boolean [required]
    Key: com.apple.security.files.user-selected.read-write
    Purpose: Access files via open/save dialogs
    Default: true

  - networkClient: Boolean [required]
    Key: com.apple.security.network.client
    Purpose: Outgoing network connections (model download)
    Default: true

  - appSandbox: Boolean [required]
    Key: com.apple.security.app-sandbox
    Purpose: Enable App Sandbox (disabled for full API access)
    Default: false

Location: ${PROJECT_ROOT}/SpeechToText.entitlements
Git Status: Tracked (shared across all developers)
```

### 4. PermissionsGranted

Runtime state of granted TCC permissions (existing entity in codebase).

```text
Entity: PermissionsGranted
Purpose: Tracks which TCC permissions are currently granted
Storage: In-memory (runtime state)
Source: Sources/SpeechToTextApp/AppState.swift

Fields:
  - microphone: Boolean
    Description: Microphone permission granted
    Check: AVCaptureDevice.authorizationStatus(for: .audio) == .authorized

  - accessibility: Boolean
    Description: Accessibility permission granted
    Check: AXIsProcessTrustedWithOptions([prompt: false])

  - inputMonitoring: Boolean
    Description: Input monitoring permission granted
    Check: IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted

Relationships:
  - Used by: PermissionService (to check current status)
  - Used by: OnboardingViewModel (to guide user through setup)
  - Used by: AppState (to track overall readiness)
```

---

## Relationships

```text
SigningConfiguration ----references----> SigningIdentity
       |                                       |
       | (stored in)                           | (stored in)
       v                                       v
  .signing-identity                     macOS Keychain
       |
       | (read by)
       v
  build-app.sh ----(applies)----> Entitlements
       |                                |
       | (creates)                      | (enables)
       v                                v
  SpeechToText.app            TCC Permission Requests
                                        |
                                        | (grants)
                                        v
                               PermissionsGranted
```

---

## State Transitions

### Signing Identity Lifecycle

```text
[Not Exists] ---(setup-signing.sh)---> [Created]
     ^                                      |
     |                                      | (10 years)
     |                                      v
     +-------(renewal)----------- [Expired]
```

### Permission Grant Lifecycle

```text
[Not Requested] ---(first launch)---> [Prompted]
                                           |
                     +---------------------+---------------------+
                     |                                           |
                     v                                           v
              [Granted]                                   [Denied]
                  |                                           |
                  | (rebuild with new identity)               |
                  v                                           v
           [Re-prompted]*                              [Still Denied]

* Only if code signing identity changes
```

---

## Validation Rules

### SigningIdentity

1. `commonName` must be 1-64 characters
2. `commonName` must match pattern: `^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]$`
3. Certificate must have codeSigning extended key usage
4. Certificate must be in login keychain (not system keychain)

### SigningConfiguration

1. File must contain exactly one line
2. Line must not be empty
3. Line must not contain leading/trailing whitespace
4. Value must match an existing SigningIdentity.commonName in keychain

### Entitlements

1. File must be valid XML plist
2. All required keys must be present
3. `app-sandbox` must be `false` for non-sandboxed operation
4. Boolean values only (no string representations)

---

## Storage Locations

| Entity | Location | Version Control |
|--------|----------|-----------------|
| SigningIdentity | `~/Library/Keychains/login.keychain-db` | No (system) |
| SigningConfiguration | `${PROJECT_ROOT}/.signing-identity` | No (.gitignore) |
| Entitlements | `${PROJECT_ROOT}/SpeechToText.entitlements` | Yes |
| PermissionsGranted | Memory (runtime) | N/A |

---

## Security Considerations

1. **Private Keys**: SigningIdentity private keys are stored in the macOS
   Keychain with access control. They should not be exported.

2. **Configuration File**: `.signing-identity` contains only the certificate
   name, not the certificate itself or private key.

3. **Entitlements Scope**: Entitlements request minimum required permissions.
   App Sandbox is disabled only because it's required for full functionality.

4. **TCC Database**: The TCC database is protected by SIP. Permissions can only
   be granted through legitimate user consent flows.
