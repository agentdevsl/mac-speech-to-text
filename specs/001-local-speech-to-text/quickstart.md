# Developer Quickstart Guide

**Feature**: 001-local-speech-to-text - macOS Local Speech-to-Text Application
**Date**: 2026-01-02
**Updated**: 2026-01-02 (FluidAudio SDK)
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
- 3GB free disk space (development tools + FluidAudio models)

### Software
- macOS 12.0 (Monterey) or later
- Xcode 14.0+ (for Swift compiler and macOS SDK)
- Command Line Tools for Xcode

### Permissions (for testing)
- Microphone access
- Accessibility permission
- Input monitoring (macOS 10.15+)

---

## Development Environment Setup

### Step 1: Install System Dependencies

```bash
# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Rust toolchain (for Tauri)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env

# Install Bun (for frontend development)
curl -fsSL https://bun.sh/install | bash

# Install Swift (comes with Xcode Command Line Tools)
xcode-select --install
```

### Step 2: Install Tauri CLI

```bash
# Install Tauri 2.0 CLI
cargo install tauri-cli --version "^2.0.0"

# Verify installation
cargo tauri --version
# Should output: tauri-cli 2.x.x
```

### Step 3: Clone Repository and Install Dependencies

```bash
# Clone repository
git clone <repository-url>
cd mac-speech-to-text

# Install frontend dependencies
cd src
bun install

# Verify Bun installation
bun --version

# Return to root
cd ..
```

### Step 4: Build Swift Package with FluidAudio

```bash
# Navigate to Swift package
cd src-tauri/swift

# Resolve Swift Package Manager dependencies (includes FluidAudio)
swift package resolve

# Build Swift package
swift build -c release

# Verify FluidAudio SDK is available
swift package show-dependencies
# Should show: FluidAudio v0.9.0 or later

# Return to root
cd ../..
```

### Step 5: Grant Development Permissions

```bash
# Run permission setup script
./scripts/setup-dev.sh

# This script will guide you through granting:
# 1. Microphone access (for audio capture)
# 2. Accessibility permission (for text insertion)
# 3. Input monitoring permission (for global hotkeys)
```

**Note**: FluidAudio will automatically download language models on first use. The English model (~500MB) will be cached locally in `~/Library/Application Support/FluidAudio/`.

---

## Project Structure

```
mac-speech-to-text/
├── src/                         # React + TypeScript frontend
│   ├── components/
│   │   ├── RecordingModal/      # Main recording UI
│   │   ├── Onboarding/          # First-time setup
│   │   ├── Settings/            # Configuration screens
│   │   └── Waveform/            # Audio visualization
│   ├── services/
│   │   ├── audio.service.ts     # Audio state management
│   │   ├── settings.service.ts  # User preferences
│   │   └── ipc.service.ts       # Tauri command wrappers
│   ├── hooks/                   # React custom hooks
│   ├── types/                   # TypeScript definitions
│   └── App.tsx                  # Main React app
│
├── src-tauri/                   # Rust backend (Tauri core)
│   ├── src/
│   │   ├── main.rs              # Tauri app entry point
│   │   ├── commands.rs          # IPC command handlers
│   │   ├── swift_bridge.rs      # Swift FFI interop
│   │   └── lib/                 # Shared utilities
│   ├── swift/                   # Swift native + FluidAudio
│   │   ├── Package.swift        # SPM configuration
│   │   ├── Sources/
│   │   │   ├── GlobalHotkey/    # Carbon API hotkeys
│   │   │   ├── FluidAudioService/ # FluidAudio wrapper
│   │   │   ├── TextInsertion/   # Accessibility API
│   │   │   └── bridge.swift     # C ABI exports
│   │   └── Tests/
│   ├── Cargo.toml
│   └── build.rs                 # Swift compilation integration
│
├── tests/                       # Integration tests
│   ├── e2e/                     # End-to-end tests
│   └── integration/             # Cross-layer tests
│
└── scripts/                     # Build and dev tools
    ├── setup-dev.sh             # Dev environment setup
    └── build-swift.sh           # Swift module compilation
```

---

## Building the Application

### Development Build

```bash
# Full development build (frontend + Tauri + Swift)
cargo tauri dev

# This will:
# 1. Build Swift package (including FluidAudio)
# 2. Compile Rust Tauri core
# 3. Start Vite dev server for React frontend
# 4. Launch the app with hot-reload enabled
```

### Production Build

```bash
# Create optimized production build
cargo tauri build

# Output locations:
# - macOS App Bundle: src-tauri/target/release/bundle/macos/
# - DMG Installer: src-tauri/target/release/bundle/dmg/
```

### Swift-Only Build (for testing)

```bash
cd src-tauri/swift

# Build Swift package independently
swift build -c release

# Run Swift tests
swift test

cd ../..
```

---

## Running Tests

### Frontend Tests (Vitest)

```bash
cd src

# Run all tests
bun test

# Watch mode
bun test --watch

# Coverage report
bun test --coverage

cd ..
```

### Rust Tests (Cargo)

```bash
cd src-tauri

# Unit tests
cargo test

# Integration tests (requires permissions)
cargo test --ignored

# With output
cargo test -- --nocapture

cd ..
```

### Swift Tests (XCTest)

```bash
cd src-tauri/swift

# Run all Swift tests
swift test

# Run specific test
swift test --filter FluidAudioServiceTests

# Verbose output
swift test --verbose

cd ../..
```

### Run All Tests

```bash
# Run complete test suite
bun test && \
  cd src-tauri && cargo test && cd .. && \
  cd src-tauri/swift && swift test && cd ../..
```

---

## Development Workflow

### 1. Start Development Server

```bash
# Terminal 1: Start Tauri dev server (includes hot-reload)
cargo tauri dev
```

### 2. Make Changes

- **Frontend**: Edit files in `src/` - Vite hot-reload applies changes instantly
- **Rust**: Edit files in `src-tauri/src/` - Requires rebuild (automatic on save)
- **Swift**: Edit files in `src-tauri/swift/Sources/` - Requires rebuild

### 3. Test Changes

```bash
# Frontend changes
cd src && bun test

# Rust changes
cd src-tauri && cargo test

# Swift changes
cd src-tauri/swift && swift test
```

### 4. Common Tasks

| Task | Command |
|------|---------|
| Start dev server | `cargo tauri dev` |
| Build for production | `cargo tauri build` |
| Run frontend tests | `cd src && bun test` |
| Run Rust tests | `cd src-tauri && cargo test` |
| Run Swift tests | `cd src-tauri/swift && swift test` |
| Format code | `cd src && bun run format` |
| Lint code | `cd src && bun run lint` |
| Type check | `cd src && bun run typecheck` |

---

## Troubleshooting

### Issue: FluidAudio models not downloading

**Symptom**: App fails to transcribe with "model not found" error

**Solution**:
```bash
# Check internet connection
curl -I https://huggingface.co

# Verify FluidAudio can access model registry
swift run fluidaudio transcribe --help

# Check local cache
ls ~/Library/Application\ Support/FluidAudio/models/

# Clear cache and retry
rm -rf ~/Library/Application\ Support/FluidAudio/models/
# Restart app - FluidAudio will re-download
```

### Issue: Swift build fails with "cannot find module FluidAudio"

**Symptom**: Build error during `cargo tauri dev`

**Solution**:
```bash
cd src-tauri/swift

# Reset Swift Package Manager cache
swift package reset

# Re-resolve dependencies
swift package resolve

# Verify FluidAudio is listed
swift package show-dependencies | grep FluidAudio

# Should output: FluidAudio (from: https://github.com/FluidInference/FluidAudio.git)
```

### Issue: Global hotkey not working

**Symptom**: Pressing ⌘⌃Space doesn't trigger recording

**Solution**:
```bash
# Check Input Monitoring permission
# System Settings > Privacy & Security > Input Monitoring
# Ensure your app is listed and enabled

# Verify hotkey registration in logs
cargo tauri dev --verbose

# Look for: "Hotkey registered: keyCode=49, modifiers=..."
```

### Issue: Text insertion fails

**Symptom**: Transcription completes but text doesn't appear

**Solution**:
```bash
# Check Accessibility permission
# System Settings > Privacy & Security > Accessibility
# Ensure your app is listed and enabled

# Test with TextEdit
open -a TextEdit
# Focus on TextEdit window, then try dictation

# Check logs for accessibility errors
cargo tauri dev --verbose
```

### Issue: Microphone access denied

**Symptom**: Recording fails immediately

**Solution**:
```bash
# Grant microphone permission
# System Settings > Privacy & Security > Microphone
# Enable your app

# Verify permission status
cargo tauri dev --verbose
# Look for: "Microphone permission: granted"
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
cd src-tauri/swift
swift package show-dependencies | grep FluidAudio
# Should be v0.9.0 or later (Swift 6 compatible)
```

---

## Next Steps

1. **Explore Contracts**: See [contracts/swift-fluidaudio.md](./contracts/swift-fluidaudio.md) for FluidAudio integration details
2. **Explore Contracts**: See [contracts/tauri-ipc.md](./contracts/tauri-ipc.md) for frontend-backend API
3. **Review Architecture**: See [plan.md](./plan.md) for system design
4. **Check Data Models**: See [data-model.md](./data-model.md) for entity definitions

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

---

**Environment Ready!** 🎉

You can now start developing the macOS local speech-to-text application with FluidAudio SDK.
