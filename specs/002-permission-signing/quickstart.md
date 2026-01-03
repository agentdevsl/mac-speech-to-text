# Quickstart: Permission and Code Signing Setup

**Feature**: 002-permission-signing
**Date**: 2026-01-03
**Estimated Time**: 5 minutes

This guide helps developers quickly set up code signing for persistent macOS
permissions during local development.

---

## Prerequisites

- macOS 14 or later
- Xcode Command Line Tools (`xcode-select --install`)
- Swift 5.9 or later

---

## Option A: Script-Based Setup (Recommended)

### Step 1: Create Signing Certificate

Run the setup script to create a self-signed development certificate:

```bash
./scripts/setup-signing.sh
```

This creates:

- A code signing certificate named "SpeechToText-Dev" in your login keychain
- A `.signing-identity` file in the project root
- Updates `.gitignore` to exclude the identity file

### Step 2: Build the Application

```bash
./scripts/build-app.sh
```

The script automatically:

- Detects the signing identity from `.signing-identity`
- Signs the app bundle with entitlements
- Creates `build/SpeechToText.app`

### Step 3: Grant Permissions (First Run Only)

1. Open the app: `open build/SpeechToText.app`
2. Grant Microphone permission when prompted
3. Grant Accessibility permission in System Settings
4. Grant Input Monitoring permission if prompted

### Step 4: Verify Persistence

Rebuild the app:

```bash
./scripts/build-app.sh --clean
```

Open again - permissions should remain granted without re-prompting.

---

## Option B: Xcode Workflow

Xcode provides automatic code signing with its own managed certificates.

### Step 1: Open in Xcode

```bash
open Package.swift
```

Or: File > Open > Select `Package.swift`

### Step 2: Configure Signing

1. Select "SpeechToText" scheme
2. Product > Destination > My Mac
3. Xcode auto-configures signing (creates "Apple Development" cert if needed)

### Step 3: Build and Run

Press Cmd+R or Product > Run

### Step 4: Grant Permissions

Same as Option A, Step 3.

### Xcode Advantages

- Automatic signing management
- LLDB debugger integration
- Console log viewing
- Breakpoint support

---

## Verification Checklist

After setup, verify the following:

### Check 1: Signing Identity Exists

```bash
security find-identity -v -p codesigning | grep SpeechToText
```

Expected output:

```text
1) XXXXXXXX "SpeechToText-Dev"
```

### Check 2: App is Properly Signed

```bash
codesign -dv build/SpeechToText.app 2>&1 | grep Authority
```

Expected output (with signing):

```text
Authority=SpeechToText-Dev
```

### Check 3: Entitlements Applied

```bash
codesign -d --entitlements - build/SpeechToText.app 2>/dev/null | head -20
```

Should show microphone, accessibility, and other entitlements.

### Check 4: Permissions Persist Across Rebuilds

1. Grant all permissions
2. Run `./scripts/build-app.sh --clean`
3. Open app - no permission prompts should appear

---

## Troubleshooting

### Certificate Creation Failed

If `setup-signing.sh` fails, create manually:

1. Open Keychain Access
2. Keychain Access > Certificate Assistant > Create a Certificate
3. Name: `SpeechToText-Dev`
4. Identity Type: Self Signed Root
5. Certificate Type: Code Signing
6. Create file: `echo "SpeechToText-Dev" > .signing-identity`

### Permission Still Prompted After Rebuild

This indicates signing identity changed. Check:

```bash
# Compare identities
codesign -dv build/SpeechToText.app 2>&1 | grep Authority
```

If different from expected, ensure `.signing-identity` contains correct name.

### Accessibility Permission Not Working

1. Open System Settings > Privacy & Security > Accessibility
2. Find and remove old "SpeechToText" entries
3. Rebuild and re-grant

### Microphone Access Denied

Reset TCC database for testing (use with caution):

```bash
tccutil reset Microphone com.speechtotext.app
```

---

## Quick Reference

| Task | Command |
|------|---------|
| Setup signing (one-time) | `./scripts/setup-signing.sh` |
| Build app | `./scripts/build-app.sh` |
| Release build | `./scripts/build-app.sh --release` |
| Build and open | `./scripts/build-app.sh --open` |
| Clean build | `./scripts/build-app.sh --clean` |
| Create DMG | `./scripts/build-app.sh --release --dmg` |
| Check signing | `codesign -dv build/SpeechToText.app` |
| List certificates | `security find-identity -v -p codesigning` |

---

## Next Steps

After successful setup:

1. Test the recording workflow (hotkey, transcription, text insertion)
2. Review `docs/CONCURRENCY_PATTERNS.md` for Swift development patterns
3. Run tests: `swift test --parallel`
