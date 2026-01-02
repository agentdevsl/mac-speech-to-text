# Research Report: macOS Local Speech-to-Text Application

**Feature**: 001-local-speech-to-text
**Date**: 2026-01-02
**Updated**: 2026-01-02 (FluidAudio SDK Integration)
**Purpose**: Document technical decisions and integration patterns

---

## Executive Summary

This document records the key technical decisions for implementing a privacy-first macOS speech-to-text application using **FluidAudio Swift SDK v0.9.0** for local ML inference on Apple Silicon.

**Key Decision**: Use FluidAudio SDK instead of custom Python MLX integration

**Rationale**: FluidAudio provides production-ready ASR with Parakeet TDT v3, automatic model management, built-in VAD, and Apple Neural Engine optimization - eliminating the complexity of custom Python subprocess integration.

---

## Research Areas Addressed

1. ML Inference Strategy (FluidAudio vs Custom MLX)
2. Swift Package Manager Integration
3. Swift-to-Rust FFI Bridge
4. Audio Processing and VAD
5. Model Management and Caching
6. Performance Benchmarking Strategy
7. Testing Approach for System Permissions
8. Tauri + React Integration Patterns

---

## 1. ML Inference Strategy: FluidAudio SDK

### Decision: Use FluidAudio Swift SDK v0.9.0

**Context**: Two approaches were considered for local speech-to-text inference:

| Approach | Pros | Cons |
|----------|------|------|
| **Custom Python MLX** | Full control, flexibility | Subprocess complexity, IPC overhead, Python dependency |
| **FluidAudio Swift SDK** ✅ | Production-ready, auto model mgmt, built-in VAD, ANE optimized | Less control, SDK dependency |

**Why FluidAudio**:
1. **Production-Ready**: Battle-tested library with 1.2k GitHub stars
2. **Parakeet TDT v3**: Same model (0.6b), optimized for ANE
3. **Auto Model Management**: Downloads from HuggingFace, handles caching
4. **Built-in VAD**: Silero models for voice activity detection
5. **Performance**: 190x real-time factor on M4 Pro
6. **Simpler Architecture**: No Python subprocess, no JSON-RPC IPC

**Implementation Pattern**:

```swift
import FluidAudio

// Initialize FluidAudio ASR Manager
let models = try await AsrModels.downloadAndLoad(version: .v3)
let asrManager = AsrManager(config: .default)
try await asrManager.initialize(models: models)

// Transcribe audio
let samples: [Float] = [...] // 16kHz mono audio
let result = try await asrManager.transcribe(samples)
print(result.text) // Transcribed text
```

**Rejected Alternative**: Custom Python MLX integration would require:
- Python 3.11+ virtual environment
- JSON-RPC subprocess protocol
- Custom model download scripts
- Manual VAD implementation
- Cross-process IPC complexity

---

## 2. Swift Package Manager Integration

### Decision: SPM for FluidAudio dependency management

**Package.swift Configuration**:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SpeechToTextNative",
    platforms: [.macOS(.v12)],
    products: [
        .library(
            name: "SpeechToTextNative",
            type: .dynamic,
            targets: ["SpeechToTextNative"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/FluidInference/FluidAudio.git",
            from: "0.9.0"
        )
    ],
    targets: [
        .target(
            name: "SpeechToTextNative",
            dependencies: [
                .product(name: "FluidAudio", package: "FluidAudio")
            ]
        )
    ]
)
```

**Build Integration** (Cargo build.rs):

```rust
fn main() {
    println!("cargo:rerun-if-changed=swift/");

    // Build Swift package with SPM
    std::process::Command::new("swift")
        .args(&["build", "-c", "release"])
        .current_dir("swift/")
        .status()
        .expect("Failed to build Swift package");

    // Link dynamic library
    println!("cargo:rustc-link-search=swift/.build/release");
    println!("cargo:rustc-link-lib=dylib=SpeechToTextNative");
}
```

**Why SPM over CocoaPods/Carthage**:
- Native Swift tooling (no Ruby dependency)
- Better Xcode integration
- Semantic versioning support
- FluidAudio is distributed via SPM

---

## 3. Swift-to-Rust FFI Bridge

### Decision: C ABI with manual memory management

**Architecture**:
```
Rust Tauri Core
    ↓ (extern "C" FFI)
Swift Dynamic Library (.dylib)
    ↓ (Swift Package Manager)
FluidAudio SDK
    ↓ (Apple Neural Engine)
Parakeet TDT v3 Model
```

**C ABI Interface** (Swift side):

```swift
@_cdecl("fluidaudio_create")
public func fluidAudioCreate() -> UnsafeMutableRawPointer? {
    let service = FluidAudioService()
    return Unmanaged.passRetained(service).toOpaque()
}

@_cdecl("fluidaudio_transcribe")
public func fluidAudioTranscribe(
    handle: UnsafeMutableRawPointer?,
    audioData: UnsafePointer<Int16>?,
    sampleCount: Int32,
    callback: @escaping @convention(c) (UnsafePointer<CChar>?, Float, Int32) -> Void
) -> Int32 {
    // Implementation...
}
```

**Rust FFI Wrapper**:

```rust
extern "C" {
    fn fluidaudio_create() -> *mut c_void;
    fn fluidaudio_transcribe(
        handle: *mut c_void,
        audio_data: *const i16,
        sample_count: c_int,
        callback: extern "C" fn(*const c_char, c_float, c_int),
    ) -> c_int;
}
```

**Why C ABI over Swift/Rust Interop**:
- Stable ABI across Swift versions
- No Swift runtime in Rust
- Clear ownership boundaries
- Compatible with Tauri build system

---

## 4. Audio Processing and VAD

### Decision: FluidAudio handles all audio preprocessing

**FluidAudio Capabilities**:
- 16kHz mono audio conversion (automatic)
- Voice Activity Detection (Silero models)
- Audio normalization and preprocessing
- Silence detection (configurable threshold)

**Integration**:

```swift
// FluidAudio handles VAD automatically
let samples = capturedAudio.map { Float($0) / 32768.0 }
let result = try await asrManager.transcribe(samples)
// FluidAudio has already applied VAD, preprocessing
```

**Rejected Alternative**: Custom VAD would require:
- Manual energy-based detection
- Separate VAD model loading
- Custom silence threshold tuning
- Additional processing pipeline

---

## 5. Model Management and Caching

### Decision: FluidAudio auto-downloads and caches models

**Model Storage Location**:
```
~/Library/Application Support/FluidAudio/
└── models/
    └── parakeet-tdt-v3/
        ├── config.json
        ├── weights.mlmodel (CoreML)
        └── tokenizer.json
```

**Download Behavior**:
- First call to `AsrModels.downloadAndLoad()` triggers download
- Subsequent calls use cached models
- Downloads from HuggingFace (HTTPS)
- Automatic checksum verification

**User Control**:
```swift
// Check if model exists locally
let modelExists = AsrModels.isModelCached(version: .v3)

// Force re-download (if corrupted)
try await AsrModels.downloadAndLoad(version: .v3, forceDownload: true)
```

**Why FluidAudio Model Management**:
- Automatic caching (no custom implementation)
- Integrity verification built-in
- Progress tracking support
- Handles network failures with retry

---

## 6. Performance Benchmarking Strategy

### Decision: Multi-tier benchmarking with XCTest + Criterion

**Tier 1: Unit Benchmarks**

```swift
// Swift XCTest Measure Blocks
func testTranscriptionPerformance() throws {
    let service = FluidAudioService()
    let samples = generateTestAudio(duration: 5) // 5 seconds

    measure {
        _ = try? service.transcribe(samples: samples)
    }
    // XCTest reports average time, std deviation
}
```

**Tier 2: Integration Benchmarks**

```rust
// Rust Criterion.rs
use criterion::{black_box, criterion_group, criterion_main, Criterion};

fn bench_hotkey_to_modal(c: &mut Criterion) {
    c.bench_function("hotkey_response", |b| {
        b.iter(|| {
            // Measure hotkey press → modal display
            trigger_hotkey();
            wait_for_modal();
        });
    });
}
```

**Success Criteria** (from spec.md):
| Metric | Target | Measurement |
|--------|--------|-------------|
| Hotkey response | <50ms | XCTest timing |
| Transcription latency | <100ms | FluidAudio result.durationMs |
| Waveform FPS | ≥30fps | requestAnimationFrame tracking |
| Idle RAM | <200MB | Instruments.app monitoring |
| Active RAM | <500MB | Instruments.app during transcription |

**CI Integration**:
```yaml
# .github/workflows/benchmark.yml
- name: Run Swift benchmarks
  run: |
    cd src-tauri/swift
    swift test --enable-test-discovery
    # XCTest outputs to console

- name: Compare against baseline
  run: |
    python scripts/compare-benchmarks.py \
      --current results.json \
      --baseline main \
      --threshold 10%  # Fail if >10% regression
```

---

## 7. Testing Strategy for System Permissions

### Decision: Mocked unit tests + pre-authorized integration environment

**Challenge**: macOS permissions cannot be granted programmatically in CI/CD

**Approach**:

**Level 1: Mocked Unit Tests** (runs in CI):

```swift
protocol PermissionChecker {
    func checkMicrophonePermission() -> Bool
}

class MockPermissionChecker: PermissionChecker {
    var microphoneGranted = true
    func checkMicrophonePermission() -> Bool {
        return microphoneGranted
    }
}

// Test with mock
func testRecordingWithoutPermission() {
    let mockChecker = MockPermissionChecker()
    mockChecker.microphoneGranted = false

    let service = AudioService(permissionChecker: mockChecker)

    XCTAssertThrowsError(try service.startRecording()) { error in
        XCTAssertEqual(error as? AudioError, .permissionDenied)
    }
}
```

**Level 2: Integration Tests** (developer machine with pre-granted permissions):

```rust
#[test]
#[ignore] // Only run with `cargo test -- --ignored`
fn test_actual_hotkey_registration() {
    let bridge = SwiftBridge::load().unwrap();

    // Requires Input Monitoring permission already granted
    let result = bridge.register_hotkey(49, CMD_KEY | CONTROL_KEY);

    assert!(result.is_ok());
}
```

**Level 3: Manual E2E** (fresh macOS VM):
- Test onboarding flow
- Grant permissions via UI
- Verify all acceptance scenarios

**CI Strategy**:
```yaml
jobs:
  unit-tests:
    runs-on: macos-14
    steps:
      - name: Run unit tests (mocked)
        run: swift test

  integration-tests:
    runs-on: self-hosted # Developer machine with permissions
    if: github.ref == 'refs/heads/main'
    steps:
      - name: Run integration tests
        run: cargo test -- --ignored
```

---

## 8. Tauri + React Integration Patterns

### Decision: Typed IPC commands with React Context

**Tauri Command** (Rust):

```rust
#[tauri::command]
async fn start_recording(
    state: State<'_, AppState>,
) -> Result<(), String> {
    let mut swift_bridge = state.swift_bridge.lock().await;
    swift_bridge.start_recording()
        .map_err(|e| e.to_string())
}
```

**TypeScript Service**:

```typescript
// src/services/ipc.service.ts
import { invoke } from '@tauri-apps/api/core';

export class IPCService {
    async startRecording(): Promise<void> {
        await invoke('start_recording');
    }

    async stopRecording(): Promise<TranscriptionResult> {
        return await invoke<TranscriptionResult>('stop_recording');
    }
}
```

**React Context**:

```typescript
// src/contexts/RecordingContext.tsx
export const RecordingProvider: React.FC = ({ children }) => {
    const [isRecording, setIsRecording] = useState(false);

    const startRecording = useCallback(async () => {
        setIsRecording(true);
        await ipcService.startRecording();
    }, []);

    return (
        <RecordingContext.Provider value={{ isRecording, startRecording }}>
            {children}
        </RecordingContext.Provider>
    );
};
```

**Why This Pattern**:
- Type-safe IPC (TypeScript interfaces match Rust structs)
- React Context avoids prop drilling
- Service layer abstracts Tauri API
- Easy to mock for testing

---

## Technology Stack Summary

| Layer | Technology | Rationale |
|-------|-----------|-----------|
| **Frontend** | React 18 + TypeScript 5.7 | Modern UI, type safety |
| **State** | React Context + Zustand | Lightweight, predictable |
| **Styling** | TailwindCSS + Framer Motion | Rapid dev, smooth animations |
| **Testing (Frontend)** | Vitest + React Testing Library | Fast, Vite-compatible |
| **App Framework** | Tauri 2.0 (Rust) | Small bundle, native APIs |
| **IPC** | Tauri Commands | Type-safe, async/await |
| **Testing (Rust)** | Cargo test + mockall | Standard Rust testing |
| **Native Layer** | Swift 5.9+ | macOS APIs, FluidAudio |
| **ML Inference** | FluidAudio SDK | Production-ready ASR |
| **Model** | Parakeet TDT v3 (0.6b) | 25 languages, ANE optimized |
| **Testing (Swift)** | XCTest | Standard Swift testing |
| **Package Manager (Frontend)** | Bun | Fast, native ESM |
| **Package Manager (Swift)** | SPM | Native Swift tooling |
| **Build Tool** | Cargo (Rust) | Coordinates all layers |

---

## Architecture Decision Records

### ADR-001: Use FluidAudio SDK over Custom MLX

**Status**: Accepted

**Context**: Need local speech-to-text on Apple Silicon

**Decision**: Use FluidAudio Swift SDK v0.9.0

**Consequences**:
- ✅ Simpler architecture (no Python)
- ✅ Production-ready ML inference
- ✅ Auto model management
- ✅ Built-in VAD
- ❌ Less control over ML pipeline
- ❌ Dependency on external SDK

---

### ADR-002: Swift Dynamic Library via FFI

**Status**: Accepted

**Context**: Rust Tauri needs to call Swift code

**Decision**: Build Swift as dynamic library with C ABI exports

**Consequences**:
- ✅ Stable ABI across Swift versions
- ✅ Clear ownership boundaries
- ✅ No Swift runtime in Rust
- ❌ Manual memory management required
- ❌ C ABI limitations (no Swift generics)

---

### ADR-003: React Context for State Management

**Status**: Accepted

**Context**: Need global state for recording/transcription

**Decision**: Use React Context + hooks (not Redux/Zustand for global state)

**Consequences**:
- ✅ No external dependencies
- ✅ Simple for small state surface
- ✅ Type-safe with TypeScript
- ❌ Re-renders can be inefficient
- ❌ May need Zustand if state grows

---

## Performance Targets

### FluidAudio Benchmarks (from docs)

- **Real-time factor**: 190x on M4 Pro
  - 5 second audio → ~25ms transcription
- **Model loading**: <2 seconds (first time), <500ms (cached)
- **Memory**: ~300MB during active transcription
- **Languages**: 25 European languages (multilingual model)

### Application Targets

| Metric | Target | Verification |
|--------|--------|--------------|
| Hotkey → Modal | <50ms | XCTest + Criterion |
| Transcription | <100ms | FluidAudio result |
| Waveform FPS | ≥30fps | requestAnimationFrame |
| Idle RAM | <200MB | Instruments.app |
| Active RAM | <500MB | Instruments.app |
| App Bundle | <50MB | Exclude models |
| Accuracy (WER) | >95% | English test set |

---

## Next Steps

**Phase 1: Design & Contracts** ✅
- [x] data-model.md - Entity definitions
- [x] contracts/tauri-ipc.md - React ↔ Rust API
- [x] contracts/swift-fluidaudio.md - Swift FluidAudio wrapper
- [x] quickstart.md - Developer setup guide

**Phase 2: Implementation** (Next)
- [ ] `/speckit.tasks` - Generate dependency-ordered tasks
- [ ] `/speckit.implement` - TDD implementation
- [ ] Milestone 1: Core Infrastructure (hotkey → transcribe → insert)
- [ ] Milestone 2: UI/UX Polish (modal, waveform, settings)
- [ ] Milestone 3: Multi-Language Support (25 languages)

---

**Research Complete**: All architectural decisions documented. Ready for implementation with FluidAudio SDK.
