# Local Development Guide

**Project**: SpeechToText macOS Application
**Updated**: 2026-01-03

This guide covers setting up your local development environment for the
SpeechToText macOS application, with a focus on code signing and permission
management.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start](#quick-start)
3. [Understanding Code Signing](#understanding-code-signing)
4. [Setting Up Persistent Permissions](#setting-up-persistent-permissions)
5. [Building the Application](#building-the-application)
6. [Granting Permissions](#granting-permissions)
7. [Troubleshooting](#troubleshooting)
8. [TCC and Code Signing Explained](#tcc-and-code-signing-explained)

---

## Prerequisites

Before you begin, ensure you have:

- **macOS 14 (Sonoma) or later**
- **Xcode Command Line Tools** (install with `xcode-select --install`)
- **Swift 5.9 or later** (included with Xcode 15+)

### Verify Prerequisites

```bash
# Check macOS version
sw_vers

# Check Swift version
swift --version

# Verify Xcode tools
xcode-select -p
```

---

## Quick Start

For the fastest setup, follow these steps:

```bash
# 1. Clone the repository
git clone <repository-url>
cd SpeechToText

# 2. Set up code signing (one-time)
./scripts/setup-signing.sh

# 3. Build and run
./scripts/build-app.sh --open
```

After first launch:

1. Grant **Microphone** permission when prompted
2. Grant **Accessibility** permission in System Settings
3. Rebuild anytime - permissions persist!

For detailed instructions, continue reading below.

---

## Understanding Code Signing

### Why Code Signing Matters

macOS uses **code signing** to verify app identity. The system's **TCC**
(Transparency, Consent, and Control) framework tracks which apps have been
granted sensitive permissions like microphone access.

**The Problem with Ad-Hoc Signing:**

When you build without a configured signing identity, the app uses "ad-hoc"
signing. Each build generates a **new identity**, causing macOS to treat it
as a completely different application. This means:

- You must re-grant permissions after every rebuild
- The app appears as multiple entries in Privacy & Security
- Development becomes tedious and frustrating

**The Solution:**

A **persistent code signing identity** ensures every build is recognized as
the same application, preserving your granted permissions across rebuilds.

### Signing Identity vs. Developer ID

| Type | Use Case | Requirements |
|------|----------|--------------|
| Self-Signed | Local development | Free, created locally |
| Apple Development | Xcode builds | Free Apple ID |
| Developer ID | Distribution | $99/year Apple Developer Program |

For local development, a **self-signed certificate** is sufficient and free.

---

## Setting Up Persistent Permissions

### Option A: Script-Based Setup (Recommended)

The project includes a setup script that creates and configures a self-signed
code signing certificate:

```bash
./scripts/setup-signing.sh
```

This script:

1. Creates a self-signed certificate named "SpeechToText-Dev"
2. Imports it into your login keychain
3. Saves the identity name to `.signing-identity`
4. Configures builds to use this identity automatically

### Option B: Xcode Workflow

If you prefer Xcode, it manages signing automatically. See the
[XCODE_WORKFLOW.md](./XCODE_WORKFLOW.md) guide for details.

### Verifying Your Setup

After setup, verify with:

```bash
# Check certificate exists
security find-identity -v -p codesigning | grep SpeechToText

# Verify .signing-identity file
cat .signing-identity

# Run validation
./scripts/setup-signing.sh --verify
```

---

## Building the Application

### Basic Build

```bash
# Debug build (faster)
./scripts/build-app.sh

# Release build (optimized)
./scripts/build-app.sh --release
```

### Build Options

| Option | Description |
|--------|-------------|
| `--release` | Build with optimizations |
| `--clean` | Clean before building |
| `--dmg` | Create DMG installer |
| `--open` | Open app after building |
| `--check-signing` | Validate signing without building |

### Examples

```bash
# Full release build with DMG
./scripts/build-app.sh --release --dmg

# Clean build and open
./scripts/build-app.sh --clean --open

# Check signing configuration
./scripts/build-app.sh --check-signing
```

---

## Granting Permissions

### Required Permissions

The app requires three permissions to function:

1. **Microphone** - For audio capture
2. **Accessibility** - For text insertion
3. **Input Monitoring** - For global hotkey (optional)

### First Launch

On first launch, macOS will prompt for permissions:

1. **Microphone**: Click "Allow" when prompted
2. **Accessibility**: You must manually enable in System Settings:
   - Open **System Settings > Privacy & Security > Accessibility**
   - Find "SpeechToText" in the list
   - Toggle it **ON**

### Verifying Permissions

```bash
# Check if app can access microphone (requires running app)
# The smoke test validates permissions:
./scripts/smoke-test.sh --build
```

### Resetting Permissions (for testing)

If you need to reset permissions:

```bash
# Reset microphone permission
tccutil reset Microphone com.speechtotext.app

# Note: Accessibility cannot be reset via CLI
# Remove and re-add in System Settings > Privacy & Security > Accessibility
```

---

## Troubleshooting

### Certificate Creation Failed

**Symptom**: `setup-signing.sh` fails with keychain errors

**Solution**: Create certificate manually:

1. Open **Keychain Access**
2. Menu: **Keychain Access > Certificate Assistant > Create a Certificate**
3. Fill in:
   - Name: `SpeechToText-Dev`
   - Identity Type: Self Signed Root
   - Certificate Type: Code Signing
4. Create the identity file:

   ```bash
   echo "SpeechToText-Dev" > .signing-identity
   ```

### Permissions Not Persisting

**Symptom**: Must re-grant permissions after every build

**Diagnosis**:

```bash
# Check current signing identity
./scripts/build-app.sh --check-signing

# Compare app signature
codesign -dv build/SpeechToText.app 2>&1 | grep Authority
```

**Solutions**:

1. Ensure `.signing-identity` file exists and contains correct name
2. Verify certificate exists: `security find-identity -v -p codesigning`
3. Recreate certificate: `./scripts/setup-signing.sh --force`

### Signing Identity Not Found

**Symptom**: Build fails with "identity not found in keychain"

**Solution**:

```bash
# List available identities
security find-identity -v -p codesigning

# If empty, create new certificate
./scripts/setup-signing.sh --force
```

### Keychain Access Denied

**Symptom**: Keychain prompts for password repeatedly

**Solution**:

```bash
# Unlock keychain
security unlock-keychain ~/Library/Keychains/login.keychain-db

# If persistent, open Keychain Access and check lock settings
open -a "Keychain Access"
```

### Accessibility Permission Not Granting

**Symptom**: Toggle stays off or app doesn't appear

**Solutions**:

1. Remove existing entry in Accessibility, rebuild app, re-add
2. Ensure app bundle exists at the path shown in System Settings
3. Try building with `--clean` flag

### App Crashes on Launch

**Symptom**: App crashes immediately after permission setup

**Diagnosis**:

```bash
# Run smoke test
./scripts/smoke-test.sh --build

# Check crash logs
ls -la ~/Library/Logs/DiagnosticReports/SpeechToText*.ips
```

---

## TCC and Code Signing Explained

### What is TCC?

**TCC (Transparency, Consent, and Control)** is macOS's permission system.
It manages access to sensitive resources like:

- Microphone and Camera
- Accessibility APIs
- Files and Folders
- Contacts, Calendars, etc.

### How TCC Identifies Apps

TCC identifies applications using a combination of:

1. **Code Signing Identity** (the certificate used to sign)
2. **Bundle Identifier** (e.g., `com.speechtotext.app`)
3. **Code Directory Hash** (hash of the executable)

When you grant permission to an app, TCC stores this grant keyed by the
signing identity. If the identity changes (as with ad-hoc signing), TCC
treats the new build as a completely different application.

### The Relationship

```text
+-----------------------+     +-------------------+
|   Code Signing        |     |   TCC Database    |
|   (Certificate)       |---->|   (Permissions)   |
+-----------------------+     +-------------------+
         |                            |
         v                            v
+------------------+        +------------------+
| App Bundle       |        | Granted Rights   |
| (SpeechToText)   |        | - Microphone     |
|                  |        | - Accessibility  |
+------------------+        +------------------+
```

### Self-Signed Certificates

A self-signed certificate:

- Is created and stored locally in your macOS keychain
- Provides a stable identity across builds
- Does not require Apple Developer Program membership
- Is only valid for local development (not distribution)

The certificate includes:

- **Common Name (CN)**: Identifies the certificate (e.g., "SpeechToText-Dev")
- **Key Usage**: Marked for code signing
- **Validity Period**: Set to 10 years by default

### Entitlements

**Entitlements** are capabilities your app requests, declared in
`SpeechToText.entitlements`:

```xml
<key>com.apple.security.device.microphone</key>
<true/>
<key>com.apple.security.personal-information.accessibility</key>
<true/>
```

These must be:

1. Declared in the entitlements file
2. Applied during code signing
3. Granted by the user at runtime

Without proper signing, entitlements cannot be applied, and permissions
cannot be reliably granted.

---

## Additional Resources

- [Apple: Code Signing Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/)
- [Apple: TCC Database](https://developer.apple.com/documentation/security/protecting-the-user-s-privacy)
- [Project: XCODE_WORKFLOW.md](./XCODE_WORKFLOW.md) - Xcode-specific workflow
- [Project: CONCURRENCY_PATTERNS.md](./CONCURRENCY_PATTERNS.md) - Swift concurrency

---

## Quick Reference

| Task | Command |
|------|---------|
| Set up signing | `./scripts/setup-signing.sh` |
| Verify signing | `./scripts/setup-signing.sh --verify` |
| Force recreate cert | `./scripts/setup-signing.sh --force` |
| Debug build | `./scripts/build-app.sh` |
| Release build | `./scripts/build-app.sh --release` |
| Build + DMG | `./scripts/build-app.sh --release --dmg` |
| Check signing | `./scripts/build-app.sh --check-signing` |
| Run smoke test | `./scripts/smoke-test.sh --build` |
| List certificates | `security find-identity -v -p codesigning` |
| Reset microphone | `tccutil reset Microphone com.speechtotext.app` |
