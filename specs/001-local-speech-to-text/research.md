# Research Report: macOS Local Speech-to-Text Application

**Feature**: 001-local-speech-to-text
**Date**: 2026-01-02
**Purpose**: Resolve technical unknowns and establish implementation patterns

---

## Research Areas

This document addresses the following unknowns from Technical Context:

1. Audio preprocessing requirements (noise reduction, VAD)
2. IPC protocol between Tauri/React and Python ML backend
3. Swift bridge mechanism (FFI, XPC, or subprocess)
4. Performance benchmarking strategy for ML inference
5. Testing approach for accessibility permissions and global hotkeys
6. Best practices for Tauri 2.0 + React integration
7. MLX parakeet-tdt model integration patterns
8. macOS permission flows (Accessibility, Microphone)

---

## 1. Audio Preprocessing & Voice Activity Detection

### Decision: Hybrid VAD with MLX-accelerated silence detection

**Rationale**:
- Real-time VAD needed to auto-stop recording after silence
- parakeet-tdt models expect clean 16kHz mono audio
- Background noise common in home/office environments
- Apple Silicon provides hardware-accelerated audio processing

**Implementation Pattern**:

**Frontend (Real-time visualization)**:
- Web Audio API for live waveform display
- Basic energy-based VAD for UI feedback
- 30fps canvas rendering with requestAnimationFrame

**Swift (Audio capture & preprocessing)**:
- AVAudioEngine for microphone input (48kHz native)
- AVAudioConverter for 16kHz mono downsampling
- Core Audio DSP for noise gate (remove background hum)
- Circular buffer pattern for streaming to Python

**Python (Advanced VAD & ML inference)**:
- MLX-accelerated energy threshold detection
- Configurable silence duration (default 1.5s)
- Optional: WebRTC VAD for improved accuracy
- Audio chunks: 100ms windows for low latency

**Alternatives Considered**:
- Client-side only VAD: Insufficient for noisy environments
- Server-based denoising: Violates privacy requirement
- PyTorch VAD: Slower than MLX on Apple Silicon

**Code Pattern** (Swift audio capture):
```swift
// AVAudioEngine setup for 16kHz mono capture
let audioEngine = AVAudioEngine()
let inputNode = audioEngine.inputNode
let recordingFormat = AVAudioFormat(
    commonFormat: .pcmFormatInt16,
    sampleRate: 16000,
    channels: 1,
    interleaved: false
)

inputNode.installTap(onBus: 0, bufferSize: 1600, format: recordingFormat) { buffer, time in
    // Send to Python ML backend via IPC
    self.sendAudioChunk(buffer)
}
```

---

## 2. IPC Architecture: Tauri ↔ Python ML Backend

### Decision: Subprocess with stdin/stdout JSON-RPC protocol

**Rationale**:
- Python process isolation prevents blocking Rust/UI threads
- JSON-RPC provides structured request/response pattern
- stdin/stdout enables streaming audio chunks
- Process lifecycle manageable by Tauri (spawn on start, kill on exit)
- No network overhead (Unix pipes faster than HTTP/gRPC)

**Architecture**:

```
React/TS Frontend
    ↕ (Tauri IPC commands)
Rust Tauri Core
    ↕ (JSON-RPC via subprocess stdin/stdout)
Python ML Backend (long-running subprocess)
    ↕ (MLX inference)
parakeet-tdt model
```

**Protocol Specification**:

**Request** (Rust → Python):
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "transcribe",
  "params": {
    "audio_base64": "...",
    "language": "en",
    "sample_rate": 16000
  }
}
```

**Response** (Python → Rust):
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "text": "transcribed text",
    "confidence": 0.95,
    "duration_ms": 87
  }
}
```

**Streaming Progress**:
```json
{
  "jsonrpc": "2.0",
  "method": "progress",
  "params": {
    "percent": 45,
    "stage": "decoding"
  }
}
```

**Alternatives Considered**:
- HTTP localhost server: Unnecessary network overhead, port conflicts
- gRPC: Overkill for single-machine IPC, protobuf complexity
- Shared memory: Platform-specific, complex error handling
- FFI (PyO3): Cannot isolate Python GIL from Rust threads

**Implementation** (Rust subprocess manager):
```rust
// src-tauri/src/python_bridge.rs
use std::process::{Command, Stdio, ChildStdin, ChildStdout};
use serde::{Serialize, Deserialize};

pub struct MLBackend {
    process: Child,
    stdin: ChildStdin,
    stdout: BufReader<ChildStdout>,
    request_id: AtomicU64,
}

impl MLBackend {
    pub fn spawn() -> Result<Self> {
        let mut child = Command::new("python3")
            .arg("-m")
            .arg("ml_backend.server")
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::inherit())
            .spawn()?;

        let stdin = child.stdin.take().unwrap();
        let stdout = BufReader::new(child.stdout.take().unwrap());

        Ok(Self {
            process: child,
            stdin,
            stdout,
            request_id: AtomicU64::new(1),
        })
    }

    pub async fn transcribe(&mut self, audio: Vec<i16>, language: &str) -> Result<String> {
        let id = self.request_id.fetch_add(1, Ordering::SeqCst);
        let request = json!({
            "jsonrpc": "2.0",
            "id": id,
            "method": "transcribe",
            "params": {
                "audio_base64": base64::encode(&audio),
                "language": language,
                "sample_rate": 16000
            }
        });

        serde_json::to_writer(&mut self.stdin, &request)?;
        self.stdin.write_all(b"\n")?;
        self.stdin.flush()?;

        let mut line = String::new();
        self.stdout.read_line(&mut line)?;
        let response: JsonRpcResponse = serde_json::from_str(&line)?;

        Ok(response.result.text)
    }
}
```

---

## 3. Swift Bridge Architecture

### Decision: Swift dynamic library (dylib) loaded via FFI with C ABI

**Rationale**:
- Tauri (Rust) can load dynamic libraries via `libloading` crate
- Swift can expose C-compatible APIs via `@_cdecl`
- No XPC overhead for synchronous calls (hotkey, text insertion)
- Single dylib bundles all Swift modules
- Build-time compilation ensures ABI compatibility

**Architecture**:

```
Rust Tauri Core
    ↓ (FFI via libloading)
libswift_native.dylib (C ABI)
    ↓ (Swift bridging header)
Swift modules (GlobalHotkey, AudioCapture, TextInsertion, MenuBar)
    ↓ (Foundation/AppKit)
macOS system frameworks
```

**C ABI Interface** (Swift side):
```swift
// src-tauri/swift/bridge.swift
import Carbon
import ApplicationServices

@_cdecl("register_global_hotkey")
public func registerGlobalHotkey(
    keyCode: UInt32,
    modifiers: UInt32,
    callback: @escaping @convention(c) () -> Void
) -> Bool {
    let hotKeyID = EventHotKeyID(signature: 0x484B4559, id: 1)
    var eventHotKey: EventHotKeyRef?

    let status = RegisterEventHotKey(
        keyCode,
        modifiers,
        hotKeyID,
        GetEventDispatcherTarget(),
        0,
        &eventHotKey
    )

    if status == noErr {
        // Store callback and register event handler
        HotkeyManager.shared.setCallback(callback)
        return true
    }
    return false
}

@_cdecl("insert_text")
public func insertText(text: UnsafePointer<CChar>) -> Bool {
    let swiftText = String(cString: text)

    // Use Accessibility API
    let systemWideElement = AXUIElementCreateSystemWide()
    var focusedElement: CFTypeRef?

    AXUIElementCopyAttributeValue(
        systemWideElement,
        kAXFocusedUIElementAttribute as CFString,
        &focusedElement
    )

    if let focused = focusedElement {
        let element = focused as! AXUIElement
        AXUIElementSetAttributeValue(
            element,
            kAXValueAttribute as CFString,
            swiftText as CFTypeRef
        )
        return true
    }
    return false
}
```

**Rust FFI Wrapper**:
```rust
// src-tauri/src/swift_bridge.rs
use libloading::{Library, Symbol};
use std::ffi::CString;

pub struct SwiftBridge {
    lib: Library,
}

impl SwiftBridge {
    pub fn load() -> Result<Self> {
        let lib_path = get_swift_lib_path()?; // Bundle path resolution
        let lib = unsafe { Library::new(lib_path)? };
        Ok(Self { lib })
    }

    pub fn register_hotkey(&self, key_code: u32, modifiers: u32) -> Result<()> {
        unsafe {
            let func: Symbol<extern "C" fn(u32, u32, extern "C" fn()) -> bool> =
                self.lib.get(b"register_global_hotkey")?;

            extern "C" fn hotkey_callback() {
                // Notify Rust/Tauri that hotkey was pressed
                // Use event emitter to trigger frontend
            }

            if func(key_code, modifiers, hotkey_callback) {
                Ok(())
            } else {
                Err(anyhow!("Failed to register hotkey"))
            }
        }
    }

    pub fn insert_text(&self, text: &str) -> Result<()> {
        let c_text = CString::new(text)?;
        unsafe {
            let func: Symbol<extern "C" fn(*const i8) -> bool> =
                self.lib.get(b"insert_text")?;

            if func(c_text.as_ptr()) {
                Ok(())
            } else {
                Err(anyhow!("Failed to insert text"))
            }
        }
    }
}
```

**Build Integration** (Cargo build.rs):
```rust
// src-tauri/build.rs
fn main() {
    // Compile Swift module into dynamic library
    let swift_files = &[
        "swift/bridge.swift",
        "swift/GlobalHotkey/hotkey.swift",
        "swift/TextInsertion/accessibility.swift",
        "swift/AudioCapture/audio.swift",
        "swift/MenuBar/menu.swift",
    ];

    println!("cargo:rerun-if-changed=swift/");

    std::process::Command::new("swiftc")
        .args(swift_files)
        .arg("-emit-library")
        .arg("-o")
        .arg("libswift_native.dylib")
        .arg("-import-objc-header")
        .arg("swift/bridge.h")
        .status()
        .expect("Failed to compile Swift library");
}
```

**Alternatives Considered**:
- XPC service: Async overhead for synchronous operations (hotkey latency)
- Swift Package Manager framework: Tauri cannot link against SPM frameworks
- Subprocess with pipes: Excessive overhead for simple text insertion
- AppleScript bridge: Unreliable, deprecated, security restrictions

---

## 4. Performance Benchmarking Strategy

### Decision: Multi-tier benchmarking with automated regression detection

**Benchmarking Tiers**:

**Tier 1: Unit Benchmarks** (Per-component performance)
- Python: pytest-benchmark for MLX model inference
- Rust: criterion.rs for IPC overhead
- Swift: XCTest measure blocks for native API calls
- TypeScript: Vitest bench for UI rendering

**Tier 2: Integration Benchmarks** (Cross-boundary)
- End-to-end latency: Hotkey press → Modal display
- Transcription pipeline: Audio capture → Text insertion
- Model loading: Cold start vs warm start
- Memory usage: Idle, recording, transcribing

**Tier 3: Real-World Scenarios** (User-facing metrics)
- 5-second dictation: Total time to insertion
- 60-second recording: Memory stability, UI responsiveness
- Language switching: Model load + first transcription
- Cold app start: Launch to ready state

**Success Criteria** (from spec.md):
- Hotkey response: <50ms
- Transcription latency: <100ms (silence detection → insertion)
- Waveform FPS: ≥30fps
- Idle RAM: <200MB
- Active RAM: <500MB
- UI responsiveness: 60fps during transcription

**Implementation**:

**Python MLX Benchmark** (pytest-benchmark):
```python
# ml-backend/tests/test_transcriber_perf.py
import pytest
import mlx.core as mx
from ml_backend.transcriber import Transcriber

@pytest.fixture
def transcriber():
    return Transcriber(model_path="models/parakeet-tdt-0.6b-en")

def test_inference_latency(benchmark, transcriber):
    # 5-second audio sample at 16kHz
    audio = mx.random.normal((80000,))

    result = benchmark(transcriber.transcribe, audio)

    assert result.duration_ms < 100, f"Inference took {result.duration_ms}ms (target: <100ms)"

def test_model_cold_start(benchmark):
    def load_model():
        return Transcriber(model_path="models/parakeet-tdt-0.6b-en")

    transcriber = benchmark(load_model)
    assert benchmark.stats.mean < 2.0, "Cold start exceeded 2 seconds"

@pytest.mark.parametrize("audio_length", [1, 5, 10, 30, 60])
def test_memory_scaling(audio_length):
    transcriber = Transcriber(model_path="models/parakeet-tdt-0.6b-en")
    audio = mx.random.normal((16000 * audio_length,))

    import tracemalloc
    tracemalloc.start()

    transcriber.transcribe(audio)

    current, peak = tracemalloc.get_traced_memory()
    tracemalloc.stop()

    assert peak < 500 * 1024 * 1024, f"Memory peaked at {peak / 1024 / 1024}MB (target: <500MB)"
```

**E2E Latency Benchmark** (Rust + Tauri):
```rust
// tests/e2e/test_latency.rs
use std::time::Instant;
use tauri::test::MockRuntime;

#[tauri::test]
async fn test_hotkey_to_modal_latency() {
    let app = create_test_app().await;

    let start = Instant::now();

    // Simulate hotkey press
    app.trigger_hotkey().await;

    // Wait for modal to appear in DOM
    app.wait_for_selector(".recording-modal").await;

    let latency = start.elapsed();

    assert!(
        latency.as_millis() < 50,
        "Hotkey → modal latency: {}ms (target: <50ms)",
        latency.as_millis()
    );
}

#[tauri::test]
async fn test_end_to_end_transcription() {
    let app = create_test_app().await;

    let start = Instant::now();

    // 1. Trigger hotkey
    app.trigger_hotkey().await;

    // 2. Send test audio (5 seconds of "Hello world")
    let audio = load_test_audio("fixtures/hello_world_5s.wav");
    app.send_audio_chunks(audio).await;

    // 3. Wait for silence detection
    tokio::time::sleep(Duration::from_millis(1500)).await;

    // 4. Wait for text insertion
    let inserted_text = app.wait_for_text_insertion().await;

    let total_latency = start.elapsed();

    assert_eq!(inserted_text.trim(), "Hello world");
    assert!(
        total_latency.as_millis() < 7000,
        "Total flow: {}ms (5s audio + 1.5s silence + <0.5s processing)",
        total_latency.as_millis()
    );
}
```

**Continuous Monitoring**:
- GitHub Actions CI runs benchmarks on every PR
- Store results in JSON artifacts
- Compare against baseline (main branch)
- Fail PR if regression >10% on critical metrics
- Weekly scheduled run for long-term trend analysis

**Visualization**:
```bash
# scripts/benchmark-report.sh
bun run test:bench --reporter=json > bench-results.json
python scripts/visualize-benchmarks.py bench-results.json --output=report.html
```

---

## 5. Testing Strategy for Permissions & System APIs

### Decision: Mocked unit tests + manual E2E with pre-authorized test environment

**Challenge**: macOS permissions cannot be granted programmatically in CI/CD. Accessibility API and global hotkeys require user interaction in System Settings.

**Approach**:

**Unit Tests** (Mocked system APIs):
- Mock Carbon hotkey registration (verify correct key codes sent)
- Mock Accessibility API responses (simulate granted/denied states)
- Mock AVAudioEngine (test audio buffer handling without hardware)
- 100% coverage of business logic, 0% dependency on real system permissions

**Integration Tests** (Pre-authorized local environment):
- Developer machine with permissions already granted
- Test harness verifies actual hotkey registration
- Test accessibility insertion into TextEdit/Notes
- Automated via `make test-integration` (requires one-time setup)

**E2E Tests** (Manual QA checklist):
- Fresh macOS VM (Parallels/VMware)
- Follow onboarding flow
- Grant permissions when prompted
- Verify all user stories from spec.md
- Regression testing before each release

**Implementation**:

**Swift Mock** (XCTest):
```swift
// src-tauri/swift/Tests/GlobalHotkeyTests.swift
import XCTest
@testable import GlobalHotkey

class MockHotkeyRegistrar: HotkeyRegistrarProtocol {
    var registeredKeyCodes: [(UInt32, UInt32)] = []
    var shouldSucceed = true

    func registerHotkey(keyCode: UInt32, modifiers: UInt32) -> Bool {
        registeredKeyCodes.append((keyCode, modifiers))
        return shouldSucceed
    }
}

class GlobalHotkeyTests: XCTestCase {
    func testRegisterCommandControlSpace() {
        let mock = MockHotkeyRegistrar()
        let manager = HotkeyManager(registrar: mock)

        let success = manager.registerDefault() // ⌘⌃Space

        XCTAssertTrue(success)
        XCTAssertEqual(mock.registeredKeyCodes.count, 1)
        XCTAssertEqual(mock.registeredKeyCodes[0].0, 49) // Space keycode
        XCTAssertEqual(mock.registeredKeyCodes[0].1, cmdKey | controlKey)
    }

    func testHandleRegistrationFailure() {
        let mock = MockHotkeyRegistrar()
        mock.shouldSucceed = false

        let manager = HotkeyManager(registrar: mock)
        let success = manager.registerDefault()

        XCTAssertFalse(success)
        // Verify error callback was triggered
    }
}
```

**Accessibility API Mock** (Rust):
```rust
// src-tauri/src/swift_bridge.rs
#[cfg(test)]
mod tests {
    use super::*;

    struct MockSwiftBridge {
        accessibility_enabled: bool,
    }

    impl MockSwiftBridge {
        fn insert_text(&self, text: &str) -> Result<()> {
            if !self.accessibility_enabled {
                return Err(anyhow!("Accessibility permission denied"));
            }
            // Simulate successful insertion
            Ok(())
        }
    }

    #[test]
    fn test_insert_text_with_permission() {
        let bridge = MockSwiftBridge { accessibility_enabled: true };
        let result = bridge.insert_text("Hello world");
        assert!(result.is_ok());
    }

    #[test]
    fn test_insert_text_without_permission() {
        let bridge = MockSwiftBridge { accessibility_enabled: false };
        let result = bridge.insert_text("Hello world");
        assert!(result.is_err());
        assert_eq!(result.unwrap_err().to_string(), "Accessibility permission denied");
    }
}
```

**Integration Test Setup** (one-time developer machine):
```bash
# scripts/setup-test-env.sh
#!/bin/bash

echo "Setting up integration test environment..."
echo "This script will guide you through granting permissions for testing."

# Build test app
cargo build --manifest-path=src-tauri/Cargo.toml

# Open System Settings pages
echo "Opening System Settings > Privacy & Security > Accessibility"
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

echo ""
echo "Manual steps required:"
echo "1. Click the lock icon and authenticate"
echo "2. Click '+' and add: target/debug/speech-to-text-test"
echo "3. Enable the checkbox for speech-to-text-test"
echo ""
read -p "Press Enter when permissions are granted..."

echo "Opening System Settings > Privacy & Security > Microphone"
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"

echo ""
echo "4. Enable the checkbox for speech-to-text-test"
echo ""
read -p "Press Enter when microphone permission is granted..."

echo ""
echo "✅ Test environment ready. Run: make test-integration"
```

**E2E Test** (requires pre-authorized environment):
```rust
// tests/integration/test_swift_bridge.rs
#[test]
#[ignore] // Only run with `cargo test -- --ignored` on authorized machines
fn test_actual_hotkey_registration() {
    let bridge = SwiftBridge::load().unwrap();

    // Register ⌘⌃Space
    let result = bridge.register_hotkey(49, CMD_KEY | CONTROL_KEY);

    assert!(result.is_ok(), "Failed to register hotkey - check permissions");
}

#[test]
#[ignore]
fn test_actual_text_insertion() {
    let bridge = SwiftBridge::load().unwrap();

    // Launch TextEdit programmatically
    std::process::Command::new("open")
        .arg("-a")
        .arg("TextEdit")
        .spawn()
        .unwrap();

    std::thread::sleep(Duration::from_secs(1));

    // Insert text
    let result = bridge.insert_text("Integration test text");

    assert!(result.is_ok(), "Failed to insert text - check Accessibility permissions");

    // Verify via Accessibility API query
    // (Read back the text from focused element)
}
```

**CI/CD Strategy**:
```yaml
# .github/workflows/ci.yml
name: CI

on: [push, pull_request]

jobs:
  unit-tests:
    runs-on: macos-14 # Apple Silicon runner
    steps:
      - uses: actions/checkout@v4
      - name: Run unit tests (mocked)
        run: |
          cargo test
          cd ml-backend && pytest tests/
          cd src && bun run test

  benchmarks:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Run performance benchmarks
        run: |
          cargo bench
          cd ml-backend && pytest tests/ --benchmark-only
      - name: Upload benchmark results
        uses: actions/upload-artifact@v4
        with:
          name: benchmarks
          path: target/criterion/

  integration-tests:
    runs-on: self-hosted # Developer machine with permissions
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      - name: Run integration tests
        run: cargo test -- --ignored
```

---

## 6. Tauri 2.0 + React Best Practices

### Decision: Tauri IPC commands with typed TypeScript bindings + React Context for state

**Key Patterns**:

**1. Tauri Command Definition** (Rust):
```rust
// src-tauri/src/commands.rs
use tauri::State;
use serde::{Serialize, Deserialize};

#[derive(Serialize, Deserialize)]
pub struct TranscriptionResult {
    pub text: String,
    pub confidence: f32,
    pub duration_ms: u64,
}

#[tauri::command]
pub async fn start_recording(
    state: State<'_, AppState>,
) -> Result<(), String> {
    let mut audio_service = state.audio_service.lock().await;
    audio_service.start_capture()
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn stop_recording_and_transcribe(
    state: State<'_, AppState>,
    language: String,
) -> Result<TranscriptionResult, String> {
    let mut audio_service = state.audio_service.lock().await;
    let audio_data = audio_service.stop_capture()
        .map_err(|e| e.to_string())?;

    let mut ml_backend = state.ml_backend.lock().await;
    ml_backend.transcribe(audio_data, &language)
        .await
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn insert_text(
    state: State<'_, AppState>,
    text: String,
) -> Result<(), String> {
    let swift_bridge = state.swift_bridge.lock().await;
    swift_bridge.insert_text(&text)
        .map_err(|e| e.to_string())
}
```

**2. TypeScript IPC Service** (Auto-generated types):
```typescript
// src/services/ipc.service.ts
import { invoke } from '@tauri-apps/api/core';

export interface TranscriptionResult {
  text: string;
  confidence: number;
  duration_ms: number;
}

export class IPCService {
  async startRecording(): Promise<void> {
    await invoke('start_recording');
  }

  async stopRecordingAndTranscribe(language: string): Promise<TranscriptionResult> {
    return await invoke<TranscriptionResult>('stop_recording_and_transcribe', {
      language,
    });
  }

  async insertText(text: string): Promise<void> {
    await invoke('insert_text', { text });
  }

  async registerHotkey(keyCode: number, modifiers: number): Promise<void> {
    await invoke('register_hotkey', { keyCode, modifiers });
  }
}

export const ipcService = new IPCService();
```

**3. React Context for Global State**:
```typescript
// src/contexts/RecordingContext.tsx
import React, { createContext, useContext, useState, useCallback } from 'react';
import { ipcService, TranscriptionResult } from '../services/ipc.service';

interface RecordingState {
  isRecording: boolean;
  isTranscribing: boolean;
  error: string | null;
  lastResult: TranscriptionResult | null;
}

interface RecordingContextValue extends RecordingState {
  startRecording: () => Promise<void>;
  stopRecording: () => Promise<void>;
  clearError: () => void;
}

const RecordingContext = createContext<RecordingContextValue | null>(null);

export const RecordingProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [state, setState] = useState<RecordingState>({
    isRecording: false,
    isTranscribing: false,
    error: null,
    lastResult: null,
  });

  const startRecording = useCallback(async () => {
    try {
      setState((prev) => ({ ...prev, isRecording: true, error: null }));
      await ipcService.startRecording();
    } catch (error) {
      setState((prev) => ({
        ...prev,
        isRecording: false,
        error: error instanceof Error ? error.message : 'Unknown error'
      }));
    }
  }, []);

  const stopRecording = useCallback(async () => {
    try {
      setState((prev) => ({ ...prev, isRecording: false, isTranscribing: true }));

      const result = await ipcService.stopRecordingAndTranscribe('en');

      await ipcService.insertText(result.text);

      setState((prev) => ({
        ...prev,
        isTranscribing: false,
        lastResult: result
      }));
    } catch (error) {
      setState((prev) => ({
        ...prev,
        isTranscribing: false,
        error: error instanceof Error ? error.message : 'Unknown error'
      }));
    }
  }, []);

  const clearError = useCallback(() => {
    setState((prev) => ({ ...prev, error: null }));
  }, []);

  return (
    <RecordingContext.Provider value={{ ...state, startRecording, stopRecording, clearError }}>
      {children}
    </RecordingContext.Provider>
  );
};

export const useRecording = () => {
  const context = useContext(RecordingContext);
  if (!context) {
    throw new Error('useRecording must be used within RecordingProvider');
  }
  return context;
};
```

**4. React Component Usage**:
```typescript
// src/components/RecordingModal/RecordingModal.tsx
import React, { useEffect } from 'react';
import { useRecording } from '../../contexts/RecordingContext';
import { Waveform } from '../Waveform/Waveform';

export const RecordingModal: React.FC = () => {
  const { isRecording, isTranscribing, error, startRecording, stopRecording } = useRecording();

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        stopRecording();
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [stopRecording]);

  useEffect(() => {
    // Auto-start recording when modal opens
    startRecording();
  }, []);

  return (
    <div className="recording-modal">
      {isRecording && (
        <>
          <Waveform />
          <p>Listening...</p>
        </>
      )}

      {isTranscribing && <p>Transcribing...</p>}

      {error && (
        <div className="error">
          <p>{error}</p>
          <button onClick={stopRecording}>Close</button>
        </div>
      )}
    </div>
  );
};
```

**5. Event Emission (Rust → Frontend)**:
```rust
// src-tauri/src/events.rs
use tauri::{AppHandle, Emitter};

pub fn emit_audio_level(app: &AppHandle, level: f32) -> Result<()> {
    app.emit("audio-level", level)?;
    Ok(())
}

pub fn emit_transcription_progress(app: &AppHandle, percent: u32) -> Result<()> {
    app.emit("transcription-progress", percent)?;
    Ok(())
}
```

**Frontend Event Listener**:
```typescript
// src/hooks/useAudioLevel.ts
import { useEffect, useState } from 'react';
import { listen } from '@tauri-apps/api/event';

export const useAudioLevel = () => {
  const [level, setLevel] = useState(0);

  useEffect(() => {
    const unlisten = listen<number>('audio-level', (event) => {
      setLevel(event.payload);
    });

    return () => {
      unlisten.then((fn) => fn());
    };
  }, []);

  return level;
};
```

---

## 7. MLX + Parakeet-TDT Integration

### Decision: MLX model loaded once at startup, inference via Metal GPU acceleration

**Model Details**:
- parakeet-tdt-0.6b-v3: 600M parameter transformer-based ASR model
- Optimized for Apple Silicon via MLX framework
- Supports 25+ languages with language-specific fine-tuning
- Model size: ~500MB per language (quantized)

**Implementation Pattern**:

**Model Manager** (Python):
```python
# ml-backend/src/model_manager.py
import mlx.core as mx
import mlx.nn as nn
from pathlib import Path
from typing import Dict, Optional

class ModelManager:
    """Manages parakeet-tdt model loading and caching."""

    def __init__(self, models_dir: Path):
        self.models_dir = models_dir
        self.loaded_models: Dict[str, nn.Module] = {}
        self.current_language: Optional[str] = None

    def load_model(self, language: str) -> nn.Module:
        """Load model for specified language, cache if not already loaded."""
        if language in self.loaded_models:
            return self.loaded_models[language]

        model_path = self.models_dir / f"parakeet-tdt-0.6b-{language}"

        if not model_path.exists():
            raise FileNotFoundError(
                f"Model for language '{language}' not found at {model_path}. "
                f"Run: python -m ml_backend.download_model --language {language}"
            )

        # Load model weights with MLX
        model = self._load_parakeet_model(model_path)

        # Move to Metal GPU
        mx.eval(model)

        self.loaded_models[language] = model
        self.current_language = language

        return model

    def _load_parakeet_model(self, model_path: Path) -> nn.Module:
        """Load parakeet-tdt model architecture and weights."""
        import json

        config_path = model_path / "config.json"
        weights_path = model_path / "weights.safetensors"

        with open(config_path) as f:
            config = json.load(f)

        # Initialize model architecture
        model = ParakeetTDTModel(
            vocab_size=config["vocab_size"],
            d_model=config["d_model"],
            num_layers=config["num_layers"],
            num_heads=config["num_heads"],
        )

        # Load weights from safetensors
        weights = mx.load(str(weights_path))
        model.load_weights(weights)

        return model

    def unload_model(self, language: str):
        """Unload model to free memory."""
        if language in self.loaded_models:
            del self.loaded_models[language]
            mx.metal.clear_cache()  # Free GPU memory
```

**Transcriber** (Python):
```python
# ml-backend/src/transcriber.py
import mlx.core as mx
import numpy as np
from typing import Optional
from .model_manager import ModelManager
from .audio_processor import AudioProcessor

class Transcriber:
    """Handles audio transcription using parakeet-tdt models."""

    def __init__(self, model_manager: ModelManager):
        self.model_manager = model_manager
        self.audio_processor = AudioProcessor()

    def transcribe(
        self,
        audio: np.ndarray,
        language: str = "en",
        sample_rate: int = 16000,
    ) -> dict:
        """
        Transcribe audio to text.

        Args:
            audio: Raw audio samples (int16 or float32)
            language: Language code (e.g., 'en', 'es', 'fr')
            sample_rate: Audio sample rate (must be 16000 for parakeet)

        Returns:
            {
                'text': str,
                'confidence': float,
                'duration_ms': int,
                'segments': List[dict]  # Word-level timestamps
            }
        """
        import time
        start_time = time.time()

        # Validate sample rate
        if sample_rate != 16000:
            raise ValueError(f"Sample rate must be 16000 Hz, got {sample_rate}")

        # Preprocess audio
        audio_features = self.audio_processor.extract_features(audio)

        # Convert to MLX array
        features_mx = mx.array(audio_features)

        # Load model for language
        model = self.model_manager.load_model(language)

        # Run inference
        with mx.stream(mx.gpu):
            logits = model(features_mx)
            predictions = mx.argmax(logits, axis=-1)

        # Decode predictions to text
        text = self._decode_predictions(predictions, language)

        # Calculate confidence
        confidence = self._calculate_confidence(logits, predictions)

        duration_ms = int((time.time() - start_time) * 1000)

        return {
            'text': text,
            'confidence': float(confidence),
            'duration_ms': duration_ms,
            'segments': self._extract_segments(logits, predictions),
        }

    def _decode_predictions(self, predictions: mx.array, language: str) -> str:
        """Decode model predictions to text using tokenizer."""
        tokenizer = self._get_tokenizer(language)
        token_ids = predictions.tolist()
        text = tokenizer.decode(token_ids)
        return text.strip()

    def _calculate_confidence(self, logits: mx.array, predictions: mx.array) -> float:
        """Calculate average confidence score."""
        probs = mx.softmax(logits, axis=-1)
        selected_probs = mx.take_along_axis(probs, predictions[:, :, None], axis=-1)
        return mx.mean(selected_probs).item()

    def _extract_segments(self, logits: mx.array, predictions: mx.array) -> list:
        """Extract word-level timestamps and confidence."""
        # Simplified - actual implementation would align tokens to words
        return []
```

**Audio Preprocessing** (Python):
```python
# ml-backend/src/audio_processor.py
import mlx.core as mx
import numpy as np

class AudioProcessor:
    """Preprocesses audio for parakeet-tdt model."""

    def extract_features(self, audio: np.ndarray) -> np.ndarray:
        """
        Extract mel-spectrogram features.

        Parakeet-TDT expects:
        - 80 mel filterbanks
        - 25ms window, 10ms hop
        - Normalized to [-1, 1]
        """
        # Normalize audio
        audio = audio.astype(np.float32)
        if audio.max() > 1.0:
            audio = audio / 32768.0  # int16 to float32

        # Compute mel spectrogram using MLX
        mel_spec = self._compute_mel_spectrogram(audio)

        # Normalize
        mel_spec = (mel_spec - mel_spec.mean()) / (mel_spec.std() + 1e-8)

        return mel_spec

    def _compute_mel_spectrogram(self, audio: np.ndarray) -> np.ndarray:
        """Compute 80-bin mel spectrogram."""
        # Use MLX for GPU-accelerated FFT
        audio_mx = mx.array(audio)

        # STFT parameters
        n_fft = 400  # 25ms at 16kHz
        hop_length = 160  # 10ms

        # Compute STFT
        stft = mx.fft.stft(audio_mx, n_fft=n_fft, hop_length=hop_length)
        magnitude = mx.abs(stft)

        # Apply mel filterbank
        mel_filters = self._create_mel_filterbank(n_fft // 2 + 1, n_mels=80)
        mel_spec = mx.matmul(mel_filters, magnitude)

        # Log scale
        mel_spec = mx.log(mel_spec + 1e-8)

        return np.array(mel_spec)

    def _create_mel_filterbank(self, n_freqs: int, n_mels: int) -> mx.array:
        """Create mel filterbank matrix."""
        # Simplified - actual implementation would use librosa-style mel filters
        return mx.random.uniform(shape=(n_mels, n_freqs))
```

**Model Download Script**:
```python
# ml-backend/src/download_model.py
import argparse
from pathlib import Path
import requests
from tqdm import tqdm

AVAILABLE_LANGUAGES = [
    "en", "es", "fr", "de", "it", "pt", "ru", "zh", "ja", "ko",
    "ar", "hi", "tr", "pl", "nl", "sv", "da", "no", "fi",
    "cs", "ro", "uk", "el", "he", "th", "vi"
]

MODEL_BASE_URL = "https://huggingface.co/nvidia/parakeet-tdt-0.6b/resolve/main"

def download_model(language: str, models_dir: Path):
    """Download parakeet-tdt model for specified language."""
    if language not in AVAILABLE_LANGUAGES:
        raise ValueError(f"Language '{language}' not supported. Available: {AVAILABLE_LANGUAGES}")

    model_dir = models_dir / f"parakeet-tdt-0.6b-{language}"
    model_dir.mkdir(parents=True, exist_ok=True)

    files_to_download = [
        "config.json",
        "weights.safetensors",
        "tokenizer.json",
    ]

    for filename in files_to_download:
        url = f"{MODEL_BASE_URL}/{language}/{filename}"
        output_path = model_dir / filename

        if output_path.exists():
            print(f"✓ {filename} already exists")
            continue

        print(f"Downloading {filename}...")

        response = requests.get(url, stream=True)
        response.raise_for_status()

        total_size = int(response.headers.get('content-length', 0))

        with open(output_path, 'wb') as f, tqdm(
            total=total_size, unit='B', unit_scale=True
        ) as pbar:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
                pbar.update(len(chunk))

        print(f"✓ Downloaded {filename}")

    print(f"\n✅ Model '{language}' ready at {model_dir}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--language", required=True, choices=AVAILABLE_LANGUAGES)
    parser.add_argument("--models-dir", default="models")
    args = parser.parse_args()

    download_model(args.language, Path(args.models_dir))
```

**Testing**:
```python
# ml-backend/tests/test_transcriber.py
import pytest
import numpy as np
from ml_backend.transcriber import Transcriber
from ml_backend.model_manager import ModelManager
from pathlib import Path

@pytest.fixture
def transcriber():
    models_dir = Path("models")
    model_manager = ModelManager(models_dir)
    return Transcriber(model_manager)

def test_transcribe_english(transcriber):
    # Load test audio: "Hello world" (5 seconds at 16kHz)
    audio = np.random.randn(80000).astype(np.float32)  # Mock audio

    result = transcriber.transcribe(audio, language="en")

    assert "text" in result
    assert "confidence" in result
    assert "duration_ms" in result
    assert 0.0 <= result["confidence"] <= 1.0

def test_invalid_sample_rate(transcriber):
    audio = np.random.randn(44100).astype(np.float32)

    with pytest.raises(ValueError, match="Sample rate must be 16000"):
        transcriber.transcribe(audio, language="en", sample_rate=44100)
```

---

## 8. macOS Permission Flows

### Decision: Incremental permission requests with clear explanations and fallback handling

**Permission Requirements**:
1. **Microphone Access**: Required for audio capture (AVFoundation)
2. **Accessibility**: Required for text insertion into other apps
3. **Input Monitoring** (optional): For global hotkey registration on macOS 10.15+

**Implementation**:

**Permission Manager** (Swift):
```swift
// src-tauri/swift/Permissions/PermissionManager.swift
import AVFoundation
import ApplicationServices

public class PermissionManager {
    public enum Permission {
        case microphone
        case accessibility
        case inputMonitoring
    }

    public enum PermissionStatus {
        case granted
        case denied
        case notDetermined
    }

    public static func checkStatus(for permission: Permission) -> PermissionStatus {
        switch permission {
        case .microphone:
            return checkMicrophoneStatus()
        case .accessibility:
            return checkAccessibilityStatus()
        case .inputMonitoring:
            return checkInputMonitoringStatus()
        }
    }

    public static func requestPermission(
        for permission: Permission,
        completion: @escaping (Bool) -> Void
    ) {
        switch permission {
        case .microphone:
            requestMicrophonePermission(completion: completion)
        case .accessibility:
            requestAccessibilityPermission(completion: completion)
        case .inputMonitoring:
            requestInputMonitoringPermission(completion: completion)
        }
    }

    // MARK: - Microphone

    private static func checkMicrophoneStatus() -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .granted
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }

    private static func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    // MARK: - Accessibility

    private static func checkAccessibilityStatus() -> PermissionStatus {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        return trusted ? .granted : .denied
    }

    private static func requestAccessibilityPermission(completion: @escaping (Bool) -> Void) {
        // Accessibility permission requires user to manually enable in System Settings
        // Open System Settings to the appropriate pane
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)

        // Poll for permission grant (since there's no callback)
        var pollCount = 0
        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            pollCount += 1

            if checkAccessibilityStatus() == .granted {
                timer.invalidate()
                completion(true)
            } else if pollCount > 60 { // 30 seconds timeout
                timer.invalidate()
                completion(false)
            }
        }
    }

    // MARK: - Input Monitoring

    private static func checkInputMonitoringStatus() -> PermissionStatus {
        // Input Monitoring is required for global hotkeys on macOS 10.15+
        if #available(macOS 10.15, *) {
            // Try to register a test hotkey
            // If it fails, permission is likely denied
            return .notDetermined // Simplified check
        } else {
            return .granted // Not required on older macOS
        }
    }

    private static func requestInputMonitoringPermission(completion: @escaping (Bool) -> Void) {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
        NSWorkspace.shared.open(url)

        // Similar polling as accessibility
        completion(false) // Simplified
    }
}
```

**Onboarding Flow** (React):
```typescript
// src/components/Onboarding/PermissionStep.tsx
import React, { useState, useEffect } from 'react';
import { ipcService } from '../../services/ipc.service';

interface PermissionStepProps {
  permission: 'microphone' | 'accessibility' | 'inputMonitoring';
  onGranted: () => void;
  onSkipped: () => void;
}

export const PermissionStep: React.FC<PermissionStepProps> = ({
  permission,
  onGranted,
  onSkipped,
}) => {
  const [status, setStatus] = useState<'checking' | 'granted' | 'denied' | 'requesting'>('checking');

  useEffect(() => {
    checkPermission();
  }, []);

  const checkPermission = async () => {
    const result = await ipcService.checkPermission(permission);
    setStatus(result ? 'granted' : 'denied');

    if (result) {
      setTimeout(onGranted, 500); // Auto-advance if already granted
    }
  };

  const requestPermission = async () => {
    setStatus('requesting');
    const granted = await ipcService.requestPermission(permission);

    if (granted) {
      setStatus('granted');
      setTimeout(onGranted, 1000);
    } else {
      setStatus('denied');
    }
  };

  const permissionInfo = {
    microphone: {
      title: 'Microphone Access',
      description: 'Speech-to-Text needs access to your microphone to capture audio.',
      whyNeeded: 'All audio is processed locally on your device. No recordings are stored or transmitted.',
      icon: '🎤',
    },
    accessibility: {
      title: 'Accessibility Permission',
      description: 'This allows the app to insert transcribed text into other applications.',
      whyNeeded: 'Accessibility permission is required to automatically type the transcribed text where your cursor is.',
      icon: '⌨️',
    },
    inputMonitoring: {
      title: 'Input Monitoring (Optional)',
      description: 'Required for global hotkey support on macOS Catalina and later.',
      whyNeeded: 'This allows the app to listen for the ⌘⌃Space hotkey even when other apps are active.',
      icon: '🔑',
    },
  };

  const info = permissionInfo[permission];

  return (
    <div className="permission-step">
      <div className="icon">{info.icon}</div>
      <h2>{info.title}</h2>
      <p className="description">{info.description}</p>
      <div className="why-needed">
        <strong>Why we need this:</strong>
        <p>{info.whyNeeded}</p>
      </div>

      {status === 'granted' && (
        <div className="status-granted">
          ✅ Permission granted
        </div>
      )}

      {status === 'denied' && (
        <>
          <button onClick={requestPermission} className="primary">
            Grant Permission
          </button>
          <button onClick={onSkipped} className="secondary">
            Skip for now
          </button>
          <p className="note">
            Some features won't work without this permission. You can grant it later in Settings.
          </p>
        </>
      )}

      {status === 'requesting' && (
        <div className="requesting">
          <p>Opening System Settings...</p>
          <p className="instructions">
            {permission === 'accessibility' && (
              <>
                1. Click the lock icon and authenticate<br />
                2. Find "Speech-to-Text" in the list<br />
                3. Enable the checkbox<br />
                4. Return to this app
              </>
            )}
            {permission === 'microphone' && (
              <>
                A system dialog should appear.<br />
                Click "OK" to allow microphone access.
              </>
            )}
          </p>
        </div>
      )}
    </div>
  );
};
```

**Info.plist Configuration** (Required for permissions):
```xml
<!-- src-tauri/Info.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSMicrophoneUsageDescription</key>
    <string>Speech-to-Text needs microphone access to transcribe your speech into text. All processing is done locally on your device.</string>

    <key>NSAppleEventsUsageDescription</key>
    <string>Speech-to-Text needs permission to control other applications to insert transcribed text.</string>
</dict>
</plist>
```

---

## Summary of Decisions

| Research Area | Decision | Key Technology |
|--------------|----------|----------------|
| Audio preprocessing & VAD | Hybrid: Web Audio (UI) + Swift (capture) + Python MLX (advanced VAD) | AVAudioEngine, MLX, energy threshold |
| Tauri ↔ Python IPC | Subprocess with JSON-RPC over stdin/stdout | Long-running Python process, structured protocol |
| Swift bridge | Dynamic library (dylib) via FFI with C ABI | `@_cdecl`, libloading, build.rs integration |
| Performance benchmarking | Multi-tier: pytest-benchmark + criterion + E2E latency tests | Automated regression detection in CI |
| Permission testing | Mocked unit tests + pre-authorized integration tests + manual E2E | MockHotkeyRegistrar, accessibility mocks |
| Tauri + React patterns | Typed IPC commands + React Context for state | Auto-generated TypeScript bindings |
| MLX integration | Model loaded at startup, Metal GPU inference | parakeet-tdt-0.6b, 80-mel features |
| macOS permissions | Incremental onboarding with explanations + fallback handling | AVFoundation, AXIsProcessTrusted |

---

## Next Steps: Phase 1 - Design & Contracts

With all clarifications resolved, proceed to Phase 1:

1. **data-model.md**: Define entities (RecordingSession, UserSettings, LanguageModel, etc.)
2. **contracts/**: Generate IPC API contracts (Tauri commands, JSON-RPC schema)
3. **quickstart.md**: Developer setup guide with all toolchain requirements
4. **Update agent context**: Add Tauri/Swift/MLX to .github/copilot-instructions.md

---

**Research Complete**: All "NEEDS CLARIFICATION" items resolved. Ready for Phase 1 design.
