# Developer Quickstart Guide

**Feature**: 001-local-speech-to-text - macOS Local Speech-to-Text Application
**Date**: 2026-01-02
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
- Apple Silicon Mac (M1, M2, M3, or M4)
- Minimum 8GB RAM (16GB recommended)
- 5GB free disk space (for development tools + ML models)

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

# Install Rust toolchain
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env

# Install Bun (for frontend)
curl -fsSL https://bun.sh/install | bash

# Install Python 3.11+
brew install python@3.11

# Install Swift (comes with Xcode Command Line Tools)
xcode-select --install
```

### Step 2: Install Tauri CLI

```bash
cargo install tauri-cli --version "^2.0.0"
```

### Step 3: Install Python Dependencies

```bash
# Create virtual environment
python3.11 -m venv .venv
source .venv/bin/activate

# Install MLX and dependencies
pip install mlx==0.21.0
pip install numpy==1.26.0
pip install soundfile==0.12.1
pip install pytest==7.4.0
pip install pytest-benchmark==4.0.0
```

### Step 4: Clone Repository and Install Dependencies

```bash
# Clone repository
git clone <repository-url>
cd speech-to-text

# Install frontend dependencies
cd src
bun install

# Install Rust dependencies
cd ../src-tauri
cargo fetch

# Return to root
cd ..
```

### Step 5: Download Default Language Model

```bash
# Activate Python virtual environment
source .venv/bin/activate

# Download English model (~500MB)
python -m ml_backend.download_model --language en --models-dir ml-backend/models

# Verify download
ls -lh ml-backend/models/parakeet-tdt-0.6b-en/
# Should show: config.json, weights.safetensors, tokenizer.json
```

### Step 6: Grant Development Permissions

```bash
# Run permission setup script
./scripts/setup-dev.sh

# Follow prompts to grant:
# 1. Microphone access
# 2. Accessibility permission
# 3. Input monitoring permission
```

---

## Project Structure

```text
speech-to-text/
├── src/                          # React + TypeScript frontend
│   ├── components/               # React components
│   ├── services/                 # Business logic
│   ├── hooks/                    # Custom React hooks
│   ├── types/                    # TypeScript type definitions
│   └── App.tsx                   # Main React app
│
├── src-tauri/                    # Rust Tauri backend
│   ├── src/
│   │   ├── main.rs              # Tauri app entry point
│   │   ├── commands.rs          # IPC command handlers
│   │   ├── swift_bridge.rs      # Swift FFI wrapper
│   │   ├── python_bridge.rs     # Python subprocess manager
│   │   └── models/              # Rust data types
│   ├── swift/                   # Swift native modules
│   │   ├── GlobalHotkey/
│   │   ├── AudioCapture/
│   │   ├── TextInsertion/
│   │   └── MenuBar/
│   ├── Cargo.toml
│   └── build.rs                 # Swift build integration
│
├── ml-backend/                  # Python ML inference service
│   ├── src/
│   │   ├── server.py           # JSON-RPC server
│   │   ├── transcriber.py      # MLX model wrapper
│   │   ├── model_manager.py    # Model loading
│   │   └── vad.py              # Voice activity detection
│   ├── models/                 # Downloaded ML models
│   └── tests/                  # Python tests
│
├── tests/                      # Integration and E2E tests
│   ├── e2e/
│   └── integration/
│
├── scripts/                    # Build and development scripts
│   ├── setup-dev.sh
│   ├── build-swift.sh
│   └── download-models.sh
│
└── specs/                      # Feature specifications
    └── 001-local-speech-to-text/
```

---

## Building the Application

### Development Build

```bash
# Build and run in development mode (hot reload enabled)
cargo tauri dev

# This will:
# 1. Compile Rust backend
# 2. Compile Swift native modules
# 3. Start frontend dev server (Vite)
# 4. Spawn Python ML backend
# 5. Open application window
```

**Expected output**:
```
   Compiling tauri v2.0.0
   Compiling speech-to-text v0.1.0
    Finished dev [unoptimized + debuginfo] target(s) in 12.34s
     Running `target/debug/speech-to-text`

VITE v5.0.0  ready in 456 ms
  ➜  Local:   http://localhost:1420/
  ➜  Network: use --host to expose

[Tauri] App started successfully
```

### Production Build

```bash
# Build optimized production binary
cargo tauri build

# Output: src-tauri/target/release/bundle/dmg/Speech-to-Text_0.1.0_aarch64.dmg
```

**Build options**:
```bash
# Build for specific architecture
cargo tauri build --target aarch64-apple-darwin

# Build without bundling (for testing)
cargo tauri build --no-bundle

# Debug build with optimizations
cargo tauri build --debug
```

---

## Running Tests

### Frontend Tests (Vitest)

```bash
cd src

# Run all tests
bun run test

# Watch mode
bun run test:watch

# Coverage report
bun run test:coverage
```

### Rust Tests

```bash
cd src-tauri

# Run unit tests
cargo test

# Run with output
cargo test -- --nocapture

# Run specific test
cargo test test_swift_bridge

# Run integration tests (requires permissions)
cargo test --test integration -- --ignored
```

### Python Tests (pytest)

```bash
source .venv/bin/activate
cd ml-backend

# Run all tests
pytest tests/

# Run with coverage
pytest tests/ --cov=src --cov-report=html

# Run benchmarks
pytest tests/ --benchmark-only

# Run specific test
pytest tests/test_transcriber.py::test_transcribe_english
```

### End-to-End Tests

```bash
# Build test application
cargo tauri build --debug

# Run E2E tests (requires permissions)
cd tests/e2e
cargo test -- --ignored

# Run with Tauri WebDriver
cargo tauri test
```

---

## Development Workflow

### 1. Start Development Server

```bash
# Terminal 1: Start Tauri dev server
cargo tauri dev
```

### 2. Make Changes

**Frontend (React/TypeScript)**:
- Edit files in `src/`
- Hot reload automatically updates UI
- Check browser console for errors

**Rust Backend**:
- Edit files in `src-tauri/src/`
- Save triggers rebuild (5-10 seconds)
- Check terminal for compilation errors

**Swift Native**:
- Edit files in `src-tauri/swift/`
- Rebuild required: `./scripts/build-swift.sh`
- Restart `cargo tauri dev`

**Python ML Backend**:
- Edit files in `ml-backend/src/`
- Restart required (kill and restart `cargo tauri dev`)

### 3. Run Tests

```bash
# Before committing, run all tests
bun run test          # Frontend
cargo test            # Rust
pytest tests/         # Python
```

### 4. Lint and Format

```bash
# Frontend
cd src
bun run lint
bun run format

# Rust
cd src-tauri
cargo clippy -- -D warnings
cargo fmt --check

# Python
cd ml-backend
black src/ tests/
mypy src/
```

### 5. Commit Changes

```bash
# Stage changes
git add .

# Commit with descriptive message
git commit -m "feat: add real-time waveform visualization"

# Push to feature branch
git push origin 001-local-speech-to-text
```

---

## Common Development Tasks

### Adding a New Tauri Command

1. **Define command in Rust** (`src-tauri/src/commands.rs`):
```rust
#[tauri::command]
pub async fn my_new_command(
    state: State<'_, AppState>,
    param: String,
) -> Result<MyResult, String> {
    // Implementation
    Ok(MyResult { data: param })
}
```

2. **Register command** (`src-tauri/src/main.rs`):
```rust
fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![
            // ... existing commands
            my_new_command,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
```

3. **Call from frontend** (`src/services/ipc.service.ts`):
```typescript
export async function callMyNewCommand(param: string): Promise<MyResult> {
  return await invoke<MyResult>('my_new_command', { param });
}
```

4. **Write tests**:
```rust
// src-tauri/src/commands.rs
#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_my_new_command() {
        let state = create_test_state();
        let result = my_new_command(state, "test".to_string()).await;
        assert!(result.is_ok());
    }
}
```

---

### Adding a New Language Model

```bash
# 1. Download model
source .venv/bin/activate
python -m ml_backend.download_model --language es

# 2. Verify model files
ls ml-backend/models/parakeet-tdt-0.6b-es/

# 3. Test transcription
python -c "
from ml_backend.transcriber import Transcriber
from ml_backend.model_manager import ModelManager

manager = ModelManager('ml-backend/models')
transcriber = Transcriber(manager)

# Test with sample audio
import numpy as np
audio = np.random.randn(16000).astype(np.float32)
result = transcriber.transcribe(audio, language='es')
print(result)
"

# 4. Update frontend language list
# Edit: src/constants/languages.ts
```

---

### Debugging Tips

**Frontend debugging**:
```bash
# Open DevTools in Tauri window
cargo tauri dev
# Press Cmd+Option+I in the app window
```

**Rust debugging**:
```bash
# Run with debug logging
RUST_LOG=debug cargo tauri dev

# Use rust-lldb for breakpoints
rust-lldb target/debug/speech-to-text
```

**Python debugging**:
```python
# Add breakpoint in ml-backend/src/server.py
import pdb; pdb.set_trace()

# Run Tauri dev to hit breakpoint
cargo tauri dev
```

**Swift debugging**:
```bash
# Compile Swift with debug symbols
./scripts/build-swift.sh --debug

# Use lldb for debugging
lldb target/debug/speech-to-text
```

---

## Troubleshooting

### Issue: `cargo tauri dev` fails with "Swift compilation error"

**Solution**:
```bash
# Manually compile Swift library
./scripts/build-swift.sh

# Check for Swift compiler errors
swiftc -v src-tauri/swift/**/*.swift -o test.dylib 2>&1 | grep error

# Verify Xcode Command Line Tools
xcode-select -p
# Should output: /Library/Developer/CommandLineTools
```

---

### Issue: Python ML backend fails to start

**Solution**:
```bash
# Check Python environment
source .venv/bin/activate
which python
# Should be: /path/to/project/.venv/bin/python

# Verify MLX installation
python -c "import mlx; print(mlx.__version__)"
# Should output: 0.21.0

# Test ML backend manually
python -m ml_backend.server
# Type: {"jsonrpc":"2.0","id":1,"method":"ping","params":{}}
# Should respond with: {"jsonrpc":"2.0","id":1,"result":{"status":"ok"}}
```

---

### Issue: Microphone permission not granted

**Solution**:
```bash
# Reset permissions (requires restart)
tccutil reset Microphone com.example.speech-to-text

# Manually grant in System Settings
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
```

---

### Issue: Accessibility API fails to insert text

**Solution**:
```bash
# Check accessibility permission
python -c "
import Quartz
options = {Quartz.kAXTrustedCheckOptionPrompt: False}
trusted = Quartz.AXIsProcessTrustedWithOptions(options)
print(f'Accessibility trusted: {trusted}')
"

# If false, grant in System Settings:
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

# Add the app to the list and enable checkbox
```

---

### Issue: Global hotkey not registering

**Solution**:
```bash
# Check Input Monitoring permission (macOS 10.15+)
open "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"

# Test hotkey registration manually
# In Swift REPL:
swift
import Carbon

let hotKeyID = EventHotKeyID(signature: 0x484B, id: 1)
var hotKeyRef: EventHotKeyRef?
let status = RegisterEventHotKey(49, UInt32(cmdKey | controlKey), hotKeyID, GetEventDispatcherTarget(), 0, &hotKeyRef)
print("Status: \(status)")  // Should be 0 (noErr)
```

---

### Issue: Frontend build errors

**Solution**:
```bash
# Clear Bun cache
cd src
rm -rf node_modules
bun install

# Check for TypeScript errors
bun run typecheck

# Verify Vite config
cat vite.config.ts
```

---

### Issue: Tests fail with "Permission denied"

**Solution**:
```bash
# Integration tests require permissions
# Follow setup guide:
./scripts/setup-test-env.sh

# Run only unit tests (no permissions needed)
cargo test --lib
pytest tests/ -m "not integration"
```

---

## Performance Benchmarking

```bash
# Run all benchmarks
cd src-tauri
cargo bench

cd ../ml-backend
pytest tests/ --benchmark-only --benchmark-autosave

# View benchmark results
open target/criterion/index.html  # Rust benchmarks
open .benchmarks/*/index.html     # Python benchmarks
```

---

## Useful Commands Reference

| Task | Command |
|------|---------|
| Start dev server | `cargo tauri dev` |
| Build production | `cargo tauri build` |
| Run all tests | `bun test && cargo test && pytest tests/` |
| Format code | `bun run format && cargo fmt && black ml-backend/` |
| Lint code | `bun run lint && cargo clippy && mypy ml-backend/` |
| Download model | `python -m ml_backend.download_model --language <lang>` |
| Clean build | `cargo clean && rm -rf src/node_modules` |
| Generate types | `cargo tauri dev --export-types` |
| View logs | `tail -f ~/Library/Logs/com.example.speech-to-text/app.log` |

---

## Next Steps

1. Read the [data-model.md](./data-model.md) for entity definitions
2. Review [contracts/tauri-ipc.md](./contracts/tauri-ipc.md) for API documentation
3. Explore [contracts/python-jsonrpc.md](./contracts/python-jsonrpc.md) for ML backend protocol
4. Check [research.md](./research.md) for technical decisions and patterns

---

## Getting Help

- **Issues**: Open a GitHub issue with reproduction steps
- **Discussions**: Use GitHub Discussions for questions
- **Docs**: See `/specs/001-local-speech-to-text/` for detailed specifications

---

**Quickstart Guide Complete**: Developers can now set up the environment and start contributing.
