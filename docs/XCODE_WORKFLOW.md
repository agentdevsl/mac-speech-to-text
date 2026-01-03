# Xcode Development Workflow

**Project**: SpeechToText macOS Application
**Updated**: 2026-01-03

This guide covers using Xcode as your primary development environment for
the SpeechToText application. Xcode provides automatic code signing,
integrated debugging, and a streamlined development experience.

---

## Table of Contents

1. [Overview](#overview)
2. [Getting Started](#getting-started)
3. [Automatic Signing Behavior](#automatic-signing-behavior)
4. [Debugging with LLDB](#debugging-with-lldb)
5. [Permission Persistence](#permission-persistence)
6. [When to Use Xcode vs CLI](#when-to-use-xcode-vs-cli)
7. [Troubleshooting](#troubleshooting)

---

## Overview

### Why Use Xcode?

Xcode offers several advantages for macOS development:

| Feature | Xcode | CLI (swift build) |
|---------|-------|-------------------|
| Automatic code signing | Yes | Requires setup |
| LLDB integration | Full GUI | Command-line only |
| Breakpoints | Visual | Manual lldb |
| Console output | Integrated | Terminal |
| Memory debugging | Instruments | Manual |
| Build caching | Optimized | Basic |

### Xcode vs CLI Comparison

Choose **Xcode** when you need:

- Visual debugging with breakpoints
- Memory/performance profiling
- Automatic code signing without setup
- Integrated console and build output

Choose **CLI** when you need:

- Automated builds (CI/CD)
- Scripted workflows
- Faster iteration for small changes
- Remote development (SSH)

---

## Getting Started

### Step 1: Open the Project

Open the Swift Package in Xcode:

```bash
# Option A: From command line
open Package.swift

# Option B: From Finder
# Double-click Package.swift

# Option C: From Xcode
# File > Open > Select Package.swift
```

Xcode will generate an Xcode project from the Package.swift manifest.

### Step 2: Select Scheme and Destination

1. In the toolbar, select the **SpeechToText** scheme
2. Select **My Mac** as the destination

```text
[ SpeechToText ]  [ My Mac ]  [ Build ]
      ^                ^
   Scheme          Destination
```

### Step 3: Configure Signing

#### First-Time Setup (Automatic)

On first build, Xcode may prompt to configure signing:

1. Click the project in the Navigator (left sidebar)
2. Select the **SpeechToText** target
3. Go to **Signing & Capabilities** tab
4. Check "Automatically manage signing"
5. Select your **Team** (or "Personal Team" for free accounts)

#### What Xcode Creates

Xcode automatically:

- Creates an "Apple Development" certificate if needed
- Provisions the app for local development
- Signs builds with a consistent identity

### Step 4: Build and Run

Press **Cmd+R** or click the Play button to build and run.

The app will launch and appear in the menu bar.

---

## Automatic Signing Behavior

### How Xcode Signing Works

When "Automatically manage signing" is enabled, Xcode:

1. **Creates certificates** if none exist (Apple Development certificate)
2. **Provisions the app** with appropriate entitlements
3. **Signs builds** consistently across rebuilds
4. **Manages the identity** in your login keychain

### Certificate Types

| Certificate | Created By | Use Case |
|-------------|-----------|----------|
| Apple Development | Xcode (free Apple ID) | Local development |
| Mac Developer | Xcode (paid account) | Local development |
| Developer ID | Apple Developer Portal | Distribution |

### Entitlements in Xcode

Xcode reads entitlements from `SpeechToText.entitlements`:

```xml
<key>com.apple.security.device.microphone</key>
<true/>
<key>com.apple.security.personal-information.accessibility</key>
<true/>
```

To modify entitlements in Xcode:

1. Select the project in Navigator
2. Select target > **Signing & Capabilities**
3. Use **+ Capability** to add/modify

---

## Debugging with LLDB

### Setting Breakpoints

#### Click in gutter

- Click the line number gutter to set a breakpoint
- Blue arrow indicates active breakpoint

#### Keyboard shortcut

- Place cursor on line, press **Cmd+\\**

#### By symbol

1. Debug > Breakpoints > Create Symbolic Breakpoint
2. Enter function name (e.g., `RecordingViewModel.startRecording`)

### Using the Debugger

When paused at a breakpoint:

| Action | Keyboard | Description |
|--------|----------|-------------|
| Continue | Cmd+Ctrl+Y | Resume execution |
| Step Over | F6 | Execute current line |
| Step Into | F7 | Enter function |
| Step Out | F8 | Exit current function |

### Viewing Variables

- **Variables View**: Shows local and instance variables
- **Console**: Type `po variableName` to print objects
- **Quick Look**: Click eye icon on variable for preview

### Console Output

View `print()` and `os_log()` output in the Debug Console:

- **View > Debug Area > Activate Console**
- Or press **Cmd+Shift+C**

### Debug Navigator

Open with **Cmd+7** to view:

- CPU usage
- Memory allocation
- Network activity
- Thread states

### Common Debug Commands

```lldb
# Print object description
po viewModel

# Print variable value
p audioLevel

# Print expression
expr viewModel.state

# Set watchpoint (break when value changes)
watchpoint set variable audioLevel

# Thread backtrace
bt

# Continue to next breakpoint
c
```

---

## Permission Persistence

### How Xcode Maintains Permissions

Xcode's automatic signing ensures:

1. **Consistent identity**: Same certificate used for every build
2. **Stable bundle ID**: Matches `com.speechtotext.app`
3. **TCC recognition**: macOS remembers granted permissions

### Verifying Persistence

After granting permissions once:

1. **Rebuild** the app (Cmd+B)
2. **Run** again (Cmd+R)
3. **Verify** no permission prompts appear

### Checking Xcode Signing

To verify Xcode's signing configuration:

1. Build the app (Cmd+B)
2. Find the built app:
   - Product > Show Build Folder in Finder
   - Navigate to `Build/Products/Debug/SpeechToText.app`
3. Check signature:

   ```bash
   codesign -dv SpeechToText.app 2>&1 | grep Authority
   ```

Expected output:

```text
Authority=Apple Development: your@email.com (XXXXXXXXXX)
```

### Switching Between Xcode and CLI

**Important**: Xcode and CLI builds use **different** signing identities
by default. This means:

- Permissions granted to CLI builds won't apply to Xcode builds
- Permissions granted to Xcode builds won't apply to CLI builds

To avoid confusion:

- Stick to one workflow during active development
- Grant permissions separately for each workflow
- Or configure CLI to use the same certificate as Xcode

---

## When to Use Xcode vs CLI

### Use Xcode For

#### Active Development

- Writing and testing new features
- Fixing bugs with debugging
- UI development and iteration

#### Debugging Issues

- Setting breakpoints in specific code paths
- Inspecting variable values at runtime
- Profiling with Instruments

#### First-Time Setup

- Xcode handles signing automatically
- No certificate creation required
- Just need a free Apple ID

### Use CLI For

#### Automated Builds

```bash
# CI/CD pipeline
./scripts/build-app.sh --release --dmg
```

#### Quick Iterations

```bash
# Faster for simple changes (builds proper app bundle)
./scripts/build-app.sh --open

# Or for raw executable only (no app bundle, limited functionality)
swift build && .build/debug/SpeechToText
```

#### Remote Development

```bash
# SSH to Mac
ssh mac-mini
cd SpeechToText
./scripts/build-app.sh
```

#### Distribution Builds

```bash
# Create signed DMG for sharing
./scripts/build-app.sh --release --dmg
```

### Hybrid Workflow

Many developers use both:

1. **Develop in Xcode** for debugging features
2. **Test with CLI** for release builds
3. **Deploy with scripts** for automation

---

## Troubleshooting

### Signing Certificate Not Found

**Symptom**: Xcode shows "No signing certificate" error

**Solutions**:

1. Ensure Apple ID is added: Xcode > Settings > Accounts
2. Click "Manage Certificates" and create new certificate
3. Select "Automatically manage signing" and choose team

### "Code Signature Invalid" Error

**Symptom**: App won't launch, shows signature error

**Solutions**:

1. Clean build: Product > Clean Build Folder (Cmd+Shift+K)
2. Delete derived data:

   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```

3. Rebuild: Cmd+B

### Permissions Not Working

**Symptom**: App can't access microphone despite granting permission

**Diagnosis**:

1. Check entitlements are present in Signing & Capabilities
2. Verify bundle ID matches System Settings entry
3. Check Console.app for TCC denial messages

**Solutions**:

1. Remove old entries from System Settings > Privacy & Security
2. Clean build and reinstall
3. Verify entitlements file is correct

### Xcode Won't Open Package.swift

**Symptom**: Xcode shows error when opening package

**Solutions**:

1. Update Xcode to latest version
2. Reset package cache:

   ```bash
   swift package reset
   swift package resolve
   ```

3. Check Package.swift syntax is valid

### Breakpoints Not Hitting

**Symptom**: Breakpoints appear but never trigger

**Causes**:

- Code not executed (check flow)
- Optimizations removed code (use Debug build)
- Wrong scheme selected

**Solutions**:

1. Verify Debug configuration is selected
2. Add `print()` to verify code path
3. Clean and rebuild

### Memory Issues with Instruments

**Symptom**: App crashes or uses excessive memory

**Diagnosis with Instruments**:

1. Product > Profile (Cmd+I)
2. Select "Leaks" or "Allocations" template
3. Record and analyze

### Build Takes Too Long

**Solutions**:

1. Use incremental builds (don't clean unnecessarily)
2. Close unused projects
3. Increase derived data storage
4. Consider Debug builds for testing

---

## Quick Reference

### Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Build | Cmd+B |
| Run | Cmd+R |
| Stop | Cmd+. |
| Clean Build | Cmd+Shift+K |
| Show Console | Cmd+Shift+C |
| Navigator | Cmd+0 to Cmd+9 |
| Breakpoint | Cmd+\\ |
| Step Over | F6 |
| Step Into | F7 |
| Step Out | F8 |
| Continue | Cmd+Ctrl+Y |

### Common Tasks

| Task | Steps |
|------|-------|
| Open package | `open Package.swift` |
| Change scheme | Toolbar > Scheme dropdown |
| View signing | Project > Target > Signing |
| Add capability | Signing > + Capability |
| Find built app | Product > Show Build Folder |
| Profile app | Product > Profile (Cmd+I) |

---

## Additional Resources

- [Apple: Debugging with Xcode](https://developer.apple.com/documentation/xcode/debugging)
- [Apple: Code Signing Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/)
- [Project: LOCAL_DEVELOPMENT.md](./LOCAL_DEVELOPMENT.md) - CLI workflow guide
- [Project: CONCURRENCY_PATTERNS.md](./CONCURRENCY_PATTERNS.md) - Swift patterns
