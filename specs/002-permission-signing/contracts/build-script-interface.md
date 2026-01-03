# Contract: Build Script Interface

**Feature**: 002-permission-signing
**Date**: 2026-01-03
**Status**: Complete

This document defines the interface contract for the build scripts related to
code signing.

---

## Script: setup-signing.sh

### setup-signing Purpose

Creates and configures a self-signed code signing certificate for consistent
local development builds.

### setup-signing Interface

```bash
./scripts/setup-signing.sh [options]
```

### setup-signing Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--name NAME` | String | `SpeechToText-Dev` | Certificate Common Name |
| `--days DAYS` | Integer | `3650` | Validity period in days |
| `--verify` | Flag | N/A | Verify existing identity only |
| `--force` | Flag | N/A | Recreate certificate even if exists |
| `--help` | Flag | N/A | Show help message |

### setup-signing Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success - certificate created or already exists |
| 1 | Error - certificate creation failed |

### setup-signing Outputs

**On Success**:

1. Certificate created in login keychain (if not exists)
2. `.signing-identity` file created in project root
3. `.signing-identity` added to `.gitignore` (if not present)

**On Failure**:

1. Error message to stderr
2. Fallback instructions for manual creation via Keychain Access

### setup-signing Preconditions

1. Running on macOS
2. OpenSSL installed (included with macOS)
3. `security` CLI available (included with macOS)
4. Write access to project root
5. Write access to login keychain

### setup-signing Side Effects

1. Creates/modifies files:
   - `${PROJECT_ROOT}/.signing-identity`
   - `${PROJECT_ROOT}/.gitignore` (appends line)
2. Creates keychain entries:
   - Certificate in `login.keychain-db`
   - Private key in `login.keychain-db`

### setup-signing Example Usage

```bash
# Default setup
./scripts/setup-signing.sh

# Custom certificate name
./scripts/setup-signing.sh --name "MyApp-Dev"

# Custom validity period
./scripts/setup-signing.sh --days 365
```

---

## Script: build-app.sh

### build-app Purpose

Builds the application and creates a signed .app bundle.

### build-app Interface

```bash
./scripts/build-app.sh [options]
```

### build-app Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--release` | Flag | debug | Build in release mode |
| `--dmg` | Flag | false | Also create DMG installer |
| `--open` | Flag | false | Open app after building |
| `--clean` | Flag | false | Clean build directory first |
| `--sign NAME` | String | (from file) | Override signing identity |
| `--sync` | Flag | false | Pull latest from git first |
| `--help` | Flag | N/A | Show help message |

### build-app Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success - app bundle created |
| 1 | Error - build or signing failed |

### Signing Behavior

```text
Priority Order:
1. --sign NAME argument (highest priority)
2. .signing-identity file content
3. Ad-hoc signing with warning (lowest priority)
```

### build-app Outputs

**On Success**:

1. App bundle at `build/SpeechToText.app`
2. DMG at `build/SpeechToText.dmg` (if `--dmg` specified)
3. Build log at `build/build.log`

**On Signing with Identity**:

```text
Signing with identity: SpeechToText-Dev
Signed with: SpeechToText-Dev
```

**On Ad-hoc Signing**:

```text
Ad-hoc signing for local testing...
Ad-hoc signed - permissions may not persist across builds
```

### build-app Preconditions

1. Running on macOS
2. Swift 5.9+ installed
3. Xcode Command Line Tools installed
4. Project dependencies resolved

### build-app Side Effects

1. Creates/modifies directories:
   - `${PROJECT_ROOT}/build/`
   - `${PROJECT_ROOT}/.build/`
2. Creates files:
   - `${PROJECT_ROOT}/build/SpeechToText.app`
   - `${PROJECT_ROOT}/build/build.log`
   - `${PROJECT_ROOT}/build/SpeechToText.dmg` (optional)

### build-app Example Usage

```bash
# Development build with signing
./scripts/setup-signing.sh  # One-time setup
./scripts/build-app.sh

# Release build with DMG
./scripts/build-app.sh --release --dmg

# Clean release build, open when done
./scripts/build-app.sh --release --clean --open

# Override signing identity
./scripts/build-app.sh --sign "Different-Cert"

# Ad-hoc signing (explicit)
./scripts/build-app.sh --sign "ad-hoc"
```

---

## Contract: Signing Identity File

### File: .signing-identity

### Format

```text
CERTIFICATE_COMMON_NAME
```

- Plain text
- Single line
- No trailing newline preferred
- No leading/trailing whitespace

### Validation

The build script validates:

1. File exists: Use identity from file
2. File not exists: Fall back to ad-hoc
3. Identity in file: Must exist in keychain (verified by codesign)

### Example Content

```text
SpeechToText-Dev
```

---

## Contract: Entitlements Application

### When Applied

Entitlements are applied when:

1. `--sign NAME` is provided AND NAME != "ad-hoc"
2. `.signing-identity` file exists with valid identity

### Codesign Command

```bash
codesign --force --deep --sign "${SIGN_IDENTITY}" \
    --entitlements "${ENTITLEMENTS_FILE}" \
    --options runtime \
    "${APP_BUNDLE}"
```

### Flags Explanation

| Flag | Purpose |
|------|---------|
| `--force` | Replace existing signature |
| `--deep` | Sign nested bundles/frameworks |
| `--sign` | Signing identity to use |
| `--entitlements` | Path to entitlements plist |
| `--options runtime` | Enable hardened runtime |

---

## Error Messages Contract

### Identity Not Found

```text
Code signing failed. Check that the identity exists:
  security find-identity -v -p codesigning
```

### Build Failed

```text
Build failed. Check build/build.log
```

### Not macOS

```text
This script must be run on macOS
```

### Swift Not Found

```text
Swift not found. Install Xcode Command Line Tools:
  xcode-select --install
```
