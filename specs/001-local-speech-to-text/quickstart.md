# Developer Quickstart Guide

**Feature**: 001-local-speech-to-text - macOS Local Speech-to-Text Application
**Date**: 2026-01-02
**Updated**: 2026-01-02 (Pure Swift + SwiftUI Architecture)
**Prerequisites**: macOS 12.0+, Apple Silicon (M1/M2/M3/M4)

---

## Table of Contents

1. [System Requirements](#system-requirements)
2. [Development Environment Setup](#development-environment-setup)
3. [Project Structure](#project-structure)
4. [Building the Application](#building-the-application)
5. [Running Tests](#running-tests)
6. [Development Workflow](#development-workflow)
7. [Troubleshooting](#troubleshooting)

---

## System Requirements

### Hardware
- **Apple Silicon Mac** (M1, M2, M3, or M4) - Required for Apple Neural Engine
- Minimum 8GB RAM (16GB recommended)
- 3GB free disk space (Xcode + FluidAudio models)

### Software
- macOS 12.0 (Monterey) or later
- Xcode 15.0+ (for Swift 5.9+ and SwiftUI)
- Command Line Tools for Xcode

### Permissions (for testing)
- Microphone access
- Accessibility permission
- Input monitoring (macOS 10.15+)

---

## Development Environment Setup

### Step 1: Install Xcode and Command Line Tools

```bash
# Install Xcode from Mac App Store
# Or download from https://developer.apple.com/xcode/

# Install Command Line Tools
xcode-select --install

# Verify Xcode installation
xcodebuild -version
# Should output: Xcode 15.0 or later

# Verify Swift version
swift --version
# Should output: Swift 5.9 or later
```

### Step 2: Clone Repository

```bash
# Clone repository
git clone <repository-url>
cd mac-speech-to-text

# Verify project structure
ls -la
# Should see: SpeechToText.xcodeproj, Package.swift, Sources/, Tests/
```

### Step 3: Resolve Swift Package Dependencies

```bash
# Resolve dependencies (includes FluidAudio SDK)
swift package resolve

# Verify FluidAudio SDK is available
swift package show-dependencies
# Should show: FluidAudio v0.9.0 or later

# Build Swift packages
swift build
```

### Step 4: Open Project in Xcode

```bash
# Open Xcode project
open SpeechToText.xcodeproj

# Or use Xcode's File > Open menu
```

In Xcode:
1. Wait for Swift Package Manager to resolve dependencies (progress in status bar)
2. Select target: **SpeechToText** (macOS)
3. Select scheme: **SpeechToText** or **SpeechToText (Debug)**
4. Verify build settings:
   - Deployment Target: macOS 12.0 or later
   - Architecture: Apple Silicon (arm64)

### Step 5: Grant Development Permissions

```bash
# Run permission setup script
./scripts/setup-dev.sh

# This script will guide you through granting:
# 1. Microphone access (for audio capture)
# 2. Accessibility permission (for text insertion)
# 3. Input monitoring permission (for global hotkeys)
```

**Manual Permission Setup** (if script fails):
1. **System Settings** > **Privacy & Security** > **Microphone**
   - Enable **Xcode** or **SpeechToText.app**
2. **System Settings** > **Privacy & Security** > **Accessibility**
   - Enable **Xcode** or **SpeechToText.app**
3. **System Settings** > **Privacy & Security** > **Input Monitoring**
   - Enable **Xcode** or **SpeechToText.app**

**Note**: FluidAudio will automatically download language models on first use. The English model (~500MB) will be cached locally in `~/Library/Application Support/FluidAudio/`.

---

## Project Structure

```
mac-speech-to-text/
├── SpeechToText.xcodeproj    # Xcode project
├── Package.swift              # Swift Package Manager config
│
├── Sources/
│   ├── SpeechToTextApp/       # App entry point
│   │   ├── SpeechToTextApp.swift   # @main entry
│   │   ├── AppDelegate.swift       # Lifecycle, menu bar
│   │   └── AppState.swift          # Observable state
│   │
│   ├── Views/                 # SwiftUI views
│   │   ├── RecordingModal.swift    # Main recording UI
│   │   ├── OnboardingView.swift    # First-time setup
│   │   ├── SettingsView.swift      # Configuration
│   │   ├── MenuBarView.swift       # Menu dropdown
│   │   └── Components/
│   │       ├── WaveformView.swift  # Audio visualization
│   │       ├── PermissionCard.swift
│   │       └── LanguagePicker.swift
│   │
│   ├── Services/              # Business logic
│   │   ├── FluidAudioService.swift      # FluidAudio wrapper
│   │   ├── HotkeyService.swift          # Global hotkeys
│   │   ├── AudioCaptureService.swift    # Core Audio
│   │   ├── TextInsertionService.swift   # Accessibility API
│   │   ├── SettingsService.swift        # UserDefaults
│   │   ├── StatisticsService.swift      # Usage tracking
│   │   └── PermissionService.swift      # Permission checks
│   │
│   ├── Models/                # Data types
│   │   ├── RecordingSession.swift
│   │   ├── UserSettings.swift
│   │   ├── LanguageModel.swift
│   │   ├── UsageStatistics.swift
│   │   └── AudioBuffer.swift
│   │
│   └── Utilities/             # Shared helpers
│       ├── Extensions/
│       │   ├── Color+Theme.swift
│       │   └── View+Modifiers.swift
│       └── Constants.swift
│
├── Tests/
│   ├── SpeechToTextTests/     # Unit tests (XCTest)
│   │   ├── Services/
│   │   │   ├── FluidAudioServiceTests.swift
│   │   │   ├── HotkeyServiceTests.swift
│   │   │   └── TextInsertionServiceTests.swift
│   │   └── Models/
│   │       └── RecordingSessionTests.swift
│   │
│   └── SpeechToTextUITests/   # UI tests (XCUITest)
│       ├── OnboardingFlowTests.swift
│       ├── RecordingFlowTests.swift
│       └── SettingsTests.swift
│
├── Resources/
│   ├── Assets.xcassets/       # Images, icons, colors
│   ├── Sounds/                # Audio feedback
│   └── Localizations/         # i18n (25 languages)
│
└── scripts/                   # Build and dev tools
    ├── setup-dev.sh           # Dev environment setup
    └── export-dmg.sh          # DMG creation
```

---

## Building the Application

### Development Build in Xcode

1. **Open Project**: `open SpeechToText.xcodeproj`
2. **Select Scheme**: SpeechToText (Debug)
3. **Select Target Device**: My Mac (Apple Silicon)
4. **Build and Run**: `Cmd + R` or Product > Run

**SwiftUI Previews** (for rapid UI iteration):
- Open any SwiftUI view file (e.g., `RecordingModal.swift`)
- Click "Resume" in the preview pane (right side of Xcode)
- Edit view code and see live updates

### Command-Line Build

```bash
# Build for development (with debug symbols)
xcodebuild -project SpeechToText.xcodeproj \
  -scheme SpeechToText \
  -configuration Debug \
  build

# Build for release (optimized)
xcodebuild -project SpeechToText.xcodeproj \
  -scheme SpeechToText \
  -configuration Release \
  build

# Output location
ls -lh build/Release/SpeechToText.app
```

### Swift Package Manager Build (for testing)

```bash
# Build Swift packages independently
swift build -c debug

# Build for release
swift build -c release

# Clean build artifacts
swift package clean
```

### Production Build (DMG Distribution)

```bash
# Create signed and notarized DMG
./scripts/export-dmg.sh

# This will:
# 1. Build release configuration
# 2. Code sign the app bundle
# 3. Create DMG installer
# 4. Submit for Apple notarization
# 5. Staple notarization ticket

# Output location
ls -lh build/Release/SpeechToText.dmg
```

---

## Running Tests

### Unit Tests (XCTest)

**In Xcode**:
1. **Test Navigator**: `Cmd + 6`
2. **Run All Tests**: `Cmd + U`
3. **Run Single Test**: Click ◇ next to test method name

**Command Line**:
```bash
# Run all tests
xcodebuild test \
  -project SpeechToText.xcodeproj \
  -scheme SpeechToText \
  -destination 'platform=macOS,arch=arm64'

# Run specific test suite
xcodebuild test \
  -project SpeechToText.xcodeproj \
  -scheme SpeechToText \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:SpeechToTextTests/FluidAudioServiceTests

# Run with coverage
xcodebuild test \
  -project SpeechToText.xcodeproj \
  -scheme SpeechToText \
  -destination 'platform=macOS,arch=arm64' \
  -enableCodeCoverage YES
```

### Swift Package Manager Tests

```bash
# Run all Swift package tests
swift test

# Run with verbose output
swift test --verbose

# Run specific test
swift test --filter FluidAudioServiceTests

# Run with parallel execution
swift test --parallel
```

### UI Tests (XCUITest)

**In Xcode**:
1. **Test Navigator**: `Cmd + 6`
2. Expand **SpeechToTextUITests**
3. Click ◇ next to test method name

**Command Line**:
```bash
# Run UI tests (requires permissions)
xcodebuild test \
  -project SpeechToText.xcodeproj \
  -scheme SpeechToText \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:SpeechToTextUITests

# Run specific UI test
xcodebuild test \
  -project SpeechToText.xcodeproj \
  -scheme SpeechToText \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:SpeechToTextUITests/RecordingFlowTests/testRecordingFlow
```

### Performance Tests

```bash
# Run performance benchmarks
xcodebuild test \
  -project SpeechToText.xcodeproj \
  -scheme SpeechToText \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:SpeechToTextTests/PerformanceTests

# View performance metrics in Xcode Test Report
# Test Navigator > Select test > Performance tab
```

### Code Coverage

**In Xcode**:
1. **Product** > **Test** (with coverage enabled)
2. **Report Navigator**: `Cmd + 9`
3. Select latest test report
4. Click **Coverage** tab

**Command Line**:
```bash
# Generate coverage report
xcodebuild test \
  -project SpeechToText.xcodeproj \
  -scheme SpeechToText \
  -destination 'platform=macOS,arch=arm64' \
  -enableCodeCoverage YES \
  -resultBundlePath TestResults.xcresult

# View coverage (requires xcov or xcresultparser)
xcrun xccov view --report TestResults.xcresult
```

---

## Development Workflow

### 1. Start Development

```bash
# Open project in Xcode
open SpeechToText.xcodeproj

# Or use command line
xcodebuild -project SpeechToText.xcodeproj \
  -scheme SpeechToText \
  -configuration Debug \
  build
```

### 2. SwiftUI Preview Workflow (Recommended)

1. Open any SwiftUI view file (e.g., `RecordingModal.swift`)
2. Click **Resume** in preview pane (right side)
3. Edit code and see live updates
4. Test interactions directly in preview
5. Use preview variants for different states

**Example Preview**:
```swift
#Preview("Recording") {
    RecordingModal(isRecording: true)
        .environmentObject(AppState())
}

#Preview("Idle") {
    RecordingModal(isRecording: false)
        .environmentObject(AppState())
}
```

### 3. Make Changes

- **Views**: Edit SwiftUI files in `Sources/Views/` - use Previews for instant feedback
- **Services**: Edit business logic in `Sources/Services/` - write tests first (TDD)
- **Models**: Edit data types in `Sources/Models/` - update tests
- **Tests**: Follow RED-GREEN-REFACTOR cycle

### 4. Test Changes

```bash
# Quick test (during development)
swift test

# Full test suite (before commit)
xcodebuild test \
  -project SpeechToText.xcodeproj \
  -scheme SpeechToText \
  -destination 'platform=macOS,arch=arm64'
```

### 5. Common Tasks

| Task | Xcode | Command Line |
|------|-------|--------------|
| Build | `Cmd + B` | `xcodebuild build` |
| Run | `Cmd + R` | `xcodebuild build && open build/...` |
| Test | `Cmd + U` | `xcodebuild test` |
| Clean | `Cmd + Shift + K` | `xcodebuild clean` |
| Preview | `Cmd + Option + P` | N/A (Xcode only) |
| Format | Xcode auto-format | `swiftformat .` |
| Lint | Xcode warnings | `swiftlint` |

### 6. Git Workflow

```bash
# Create feature branch
git checkout -b feature/your-feature-name

# Make changes and test
swift test

# Stage changes
git add .

# Commit (pre-commit hooks will run)
git commit -m "feat: add your feature"

# Push to remote
git push origin feature/your-feature-name
```

---

## Troubleshooting

### Issue: FluidAudio models not downloading

**Symptom**: App fails to transcribe with "model not found" error

**Solution**:
```bash
# Check internet connection
curl -I https://huggingface.co

# Verify FluidAudio SDK version
swift package show-dependencies | grep FluidAudio
# Should show: FluidAudio v0.9.0 or later

# Check local cache
ls ~/Library/Application\ Support/FluidAudio/models/

# Clear cache and retry
rm -rf ~/Library/Application\ Support/FluidAudio/models/
# Restart app - FluidAudio will re-download

# Check Xcode console for download errors
# Look for: "FluidAudio: Downloading model..."
```

### Issue: Swift build fails with "cannot find module FluidAudio"

**Symptom**: Build error in Xcode or command line

**Solution**:
```bash
# Reset Swift Package Manager cache
swift package reset

# Re-resolve dependencies
swift package resolve

# Verify FluidAudio is listed
swift package show-dependencies | grep FluidAudio
# Should output: FluidAudio (from: https://github.com/FluidInference/FluidAudio.git)

# Clean build in Xcode
# Product > Clean Build Folder (Cmd + Shift + K)

# Rebuild
xcodebuild -project SpeechToText.xcodeproj \
  -scheme SpeechToText \
  build
```

### Issue: Xcode cannot find Swift Package dependencies

**Symptom**: "No such module 'FluidAudio'" error

**Solution**:
```bash
# In Xcode:
# File > Packages > Reset Package Caches
# File > Packages > Resolve Package Versions

# Or command line:
rm -rf ~/Library/Caches/org.swift.swiftpm/
rm -rf .build/

# Re-resolve
swift package resolve

# Restart Xcode
```

### Issue: Global hotkey not working

**Symptom**: Pressing ⌘⌃Space doesn't trigger recording

**Solution**:
```bash
# Check Input Monitoring permission
# System Settings > Privacy & Security > Input Monitoring
# Ensure "Xcode" or "SpeechToText" is listed and enabled

# Verify hotkey registration in Xcode console
# Look for: "Hotkey registered: keyCode=49, modifiers=..."

# Test with different hotkey (in SettingsView)

# Check for conflicting system shortcuts
# System Settings > Keyboard > Keyboard Shortcuts
# Ensure ⌘⌃Space is not assigned to another function
```

### Issue: Text insertion fails

**Symptom**: Transcription completes but text doesn't appear

**Solution**:
```bash
# Check Accessibility permission
# System Settings > Privacy & Security > Accessibility
# Ensure "Xcode" or "SpeechToText" is listed and enabled

# Test with TextEdit
open -a TextEdit
# Focus on TextEdit window, then try dictation

# Check Xcode console for accessibility errors
# Look for: "AXError: permission denied"

# Verify TextInsertionService is initialized
# Add breakpoint in TextInsertionService.swift

# Try alternative text insertion method (clipboard fallback)
```

### Issue: Microphone access denied

**Symptom**: Recording fails immediately

**Solution**:
```bash
# Grant microphone permission
# System Settings > Privacy & Security > Microphone
# Enable "Xcode" or "SpeechToText"

# Restart app after granting permission

# Verify permission status in Xcode console
# Look for: "Microphone permission: granted"

# Test microphone in System Settings > Sound > Input
```

### Issue: Apple Neural Engine not being used

**Symptom**: High CPU usage during transcription

**Solution**:
FluidAudio automatically uses Apple Neural Engine on Apple Silicon. Verify:

```bash
# Check Activity Monitor during transcription:
# - Look for "ANE" process activity
# - CPU usage should be LOW during inference

# Verify Apple Silicon
system_profiler SPHardwareDataType | grep "Chip"
# Should show: M1/M2/M3/M4

# Check FluidAudio version
swift package show-dependencies | grep FluidAudio
# Should be v0.9.0 or later (Swift 6 compatible)

# Verify Release build (Debug builds may not use ANE)
xcodebuild -project SpeechToText.xcodeproj \
  -scheme SpeechToText \
  -configuration Release \
  build
```

### Issue: SwiftUI Previews not working

**Symptom**: "Preview crashed" or "Cannot preview in this file"

**Solution**:
```bash
# Clean build folder
# Product > Clean Build Folder (Cmd + Shift + K)

# Restart Xcode Preview process
# Editor > Canvas > Restart Canvas

# Check for syntax errors in view file

# Verify preview provider is correct
#Preview {
    YourView()
        .environmentObject(AppState())
}

# Restart Xcode if previews are still broken
```

### Issue: Code signing errors during build

**Symptom**: "Code signing failed" or "No certificate found"

**Solution**:
```bash
# In Xcode:
# Project Settings > Signing & Capabilities
# Team: Select your Apple Developer team
# Signing Certificate: Automatic (recommended)

# For development builds, use:
# Signing: Automatically manage signing
# Team: Your personal team

# For production builds, use:
# Signing: Manually manage signing
# Provisioning Profile: SpeechToText Distribution
```

### Issue: Tests failing with permission errors

**Symptom**: XCUITests fail with "Permission denied"

**Solution**:
```bash
# UI tests require permissions to be granted beforehand
# Run app manually first to grant permissions:
xcodebuild -project SpeechToText.xcodeproj \
  -scheme SpeechToText \
  build

# Open app and grant all permissions
open build/Debug/SpeechToText.app

# Then run UI tests
xcodebuild test \
  -project SpeechToText.xcodeproj \
  -scheme SpeechToText \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:SpeechToTextUITests
```

---

## Next Steps

1. **Explore Contracts**: See [contracts/swift-fluidaudio.md](./contracts/swift-fluidaudio.md) for FluidAudio integration details
2. **Review Architecture**: See [plan.md](./plan.md) for system design
3. **Check Data Models**: See [data-model.md](./data-model.md) for entity definitions
4. **Read Spec**: See [spec.md](./spec.md) for feature requirements and user stories

---

## Performance Notes

### FluidAudio Characteristics

- **Real-time factor**: ~190x on M4 Pro (5s audio transcribed in ~25ms)
- **First transcription**: 1-2 seconds (model loading)
- **Subsequent transcriptions**: <100ms
- **Memory usage**: ~300MB during active transcription
- **Model cache**: ~500MB per language (stored locally)

### Optimization Tips

1. **Pre-warm models**: Initialize FluidAudio on app startup
2. **Language switching**: Parakeet TDT v3 is multilingual (no model reload needed)
3. **Memory**: Monitor with Instruments.app for leaks
4. **Performance**: Use Release builds for accurate benchmarking
5. **SwiftUI**: Use `.task` and `.onChange` modifiers for reactive updates
6. **Async/Await**: Use Swift Concurrency for all asynchronous operations

### Xcode Instruments Profiling

```bash
# Profile app in Xcode
# Product > Profile (Cmd + I)

# Useful instruments:
# - Time Profiler: CPU usage and call stacks
# - Allocations: Memory usage and leaks
# - Leaks: Memory leak detection
# - System Trace: System-level performance

# Or command line:
instruments -t "Time Profiler" build/Release/SpeechToText.app
```

---

**Environment Ready!**

You can now start developing the macOS local speech-to-text application with Pure Swift + SwiftUI architecture and FluidAudio SDK.
