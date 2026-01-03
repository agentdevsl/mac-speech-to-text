# E2E Validation Checklist

**Feature**: Permission and Code Signing for Local Development
**Date**: 2026-01-03
**Purpose**: Validate complete end-to-end workflow after implementation

---

## Pre-Validation Setup

Before running validation, ensure you have:

- [ ] macOS 14+ (Sonoma or later)
- [ ] Xcode Command Line Tools installed
- [ ] Fresh clone of repository (or clean working directory)
- [ ] No existing SpeechToText entries in Privacy & Security settings

---

## Phase 1: Code Signing Setup Validation

### T035-A: First-Time Setup

- [ ] Run `./scripts/setup-signing.sh`
- [ ] Verify no errors during execution
- [ ] Verify `.signing-identity` file created
- [ ] Verify certificate appears in Keychain Access
- [ ] Run `./scripts/setup-signing.sh --verify` to validate

**Expected Results:**

- Script completes successfully
- `.signing-identity` contains certificate name
- `security find-identity -v -p codesigning` shows the certificate

### T035-B: Verification Flag

- [ ] Run `./scripts/setup-signing.sh --verify`
- [ ] Verify identity is found in keychain
- [ ] Verify expiration date is shown (or noted as valid)

**Expected Results:**

- "Identity found in keychain" message
- Certificate validity period displayed

### T035-C: Force Recreate

- [ ] Run `./scripts/setup-signing.sh --force`
- [ ] Verify certificate is recreated
- [ ] Verify new certificate works for signing

**Expected Results:**

- New certificate created (may have same name)
- Subsequent builds use new certificate

---

## Phase 2: Build Validation

### T035-D: Build with Signing Identity

- [ ] Run `./scripts/build-app.sh`
- [ ] Verify no ad-hoc warning (if identity configured)
- [ ] Verify "Signed with: (identity)" message appears
- [ ] Verify app bundle created at `build/SpeechToText.app`

**Expected Results:**

- Build completes successfully
- App is signed with configured identity
- No ad-hoc signing warnings

### T035-E: Check Signing Flag

- [ ] Run `./scripts/build-app.sh --check-signing`
- [ ] Verify signing configuration is validated
- [ ] Verify entitlements are checked

**Expected Results:**

- "Signing configuration is valid" message
- All entitlements present

### T035-F: Ad-Hoc Warning (if no identity)

- [ ] Temporarily move `.signing-identity` file
- [ ] Run `./scripts/build-app.sh`
- [ ] Verify prominent ad-hoc warning is displayed
- [ ] Restore `.signing-identity` file

**Expected Results:**

- Yellow warning box about ad-hoc signing
- Recommendation to run setup-signing.sh

---

## Phase 3: Permission Granting Validation

### T035-G: First Launch Permissions

- [ ] Open app: `open build/SpeechToText.app`
- [ ] Verify microphone permission dialog appears
- [ ] Grant microphone permission
- [ ] Verify accessibility prompt (or manual enable required)
- [ ] Enable in System Settings > Privacy & Security > Accessibility
- [ ] Verify app appears in menu bar

**Expected Results:**

- App launches successfully
- Both permissions granted
- App functional in menu bar

### T035-H: Permission Persistence (Critical)

- [ ] Rebuild app: `./scripts/build-app.sh --clean`
- [ ] Open app again: `open build/SpeechToText.app`
- [ ] Verify NO new permission prompts
- [ ] Verify app still has microphone access
- [ ] Verify app still has accessibility access

**Expected Results:**

- No permission dialogs on subsequent launches
- App retains all previously granted permissions

### T035-I: Multiple Rebuild Test

Repeat the following 3 times:

- [ ] Run `./scripts/build-app.sh --clean`
- [ ] Open app: `open build/SpeechToText.app`
- [ ] Verify no permission prompts
- [ ] Close app

**Expected Results:**

- Permissions persist across all 3+ rebuilds
- No permission dialogs appear

---

## Phase 4: E2E Recording Workflow (T036)

### T036-A: Recording Initiation

- [ ] Open app (ensure running in menu bar)
- [ ] Press global hotkey (Cmd+Ctrl+Space)
- [ ] Verify recording modal appears
- [ ] Verify waveform visualization shows audio input

**Expected Results:**

- Hotkey triggers recording modal
- Audio level meter responds to voice

### T036-B: Transcription

- [ ] Speak a test phrase (e.g., "Hello world, this is a test")
- [ ] Stop recording (click button or release hotkey)
- [ ] Verify transcription appears in modal
- [ ] Verify transcription is reasonably accurate

**Expected Results:**

- Speech is transcribed
- Text appears in modal
- Accuracy is acceptable (80%+ for clear speech)

### T036-C: Text Insertion

- [ ] Open a text application (TextEdit, Notes, etc.)
- [ ] Place cursor in text field
- [ ] Trigger recording (Cmd+Ctrl+Space)
- [ ] Speak test phrase
- [ ] Stop recording
- [ ] Verify transcribed text is inserted into target app

**Expected Results:**

- Text is pasted into target application
- No accessibility errors
- Insertion is at cursor position

### T036-D: Complete Workflow Verification

Perform complete E2E test:

1. [ ] Start with app running in menu bar
2. [ ] Open target application (TextEdit)
3. [ ] Trigger hotkey
4. [ ] Speak: "This is a complete end-to-end test"
5. [ ] Stop recording
6. [ ] Verify text appears in TextEdit

**Expected Results:**

- Full workflow completes without errors
- Text successfully inserted
- No permission prompts during workflow

---

## Phase 5: Smoke Test Validation

### T036-E: Basic Smoke Test

- [ ] Run `./scripts/smoke-test.sh --build`
- [ ] Verify app builds successfully
- [ ] Verify app launches without crash
- [ ] Verify test completes with "PASSED"

**Expected Results:**

- No crashes detected
- Exit code 0

### T036-F: Permission Check

- [ ] Run `./scripts/smoke-test.sh --check-permissions`
- [ ] Verify signing identity check
- [ ] Verify microphone permission check
- [ ] Verify accessibility permission check
- [ ] Verify status summary

**Expected Results:**

- All checks pass (if permissions granted)
- Clear status report displayed

---

## Phase 6: Documentation Validation

### T036-G: LOCAL_DEVELOPMENT.md

- [ ] Read docs/LOCAL_DEVELOPMENT.md
- [ ] Verify Quick Start section is accurate
- [ ] Verify Troubleshooting section covers common issues
- [ ] Verify commands work as documented

### T036-H: XCODE_WORKFLOW.md

- [ ] Read docs/XCODE_WORKFLOW.md
- [ ] If using Xcode: Follow documented steps
- [ ] Verify Xcode workflow produces working build
- [ ] Verify permissions persist in Xcode workflow

---

## Validation Summary

### Pass Criteria

All critical items must pass:

- [ ] **C1**: Signing identity created and persists
- [ ] **C2**: Builds use configured signing identity
- [ ] **C3**: Permissions persist across 3+ rebuilds
- [ ] **C4**: E2E recording workflow completes successfully
- [ ] **C5**: Smoke test passes without crashes

### Sign-Off

| Validator | Date | Result |
|-----------|------|--------|
| ___________ | ______ | PASS / FAIL |

### Notes

_Record any issues, observations, or deviations here:_

---

## Quick Validation Script

For rapid re-validation, run:

```bash
# 1. Setup
./scripts/setup-signing.sh --verify

# 2. Build
./scripts/build-app.sh --clean

# 3. Check permissions
./scripts/smoke-test.sh --check-permissions

# 4. Full smoke test
./scripts/smoke-test.sh

# 5. Rebuild and verify persistence
./scripts/build-app.sh --clean
./scripts/smoke-test.sh
```

If all steps pass, the implementation is validated.
