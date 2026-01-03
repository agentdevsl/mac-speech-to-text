# Research Report: macOS Local Speech-to-Text Application

**Feature**: 001-local-speech-to-text
**Date**: 2026-01-02
**Updated**: 2026-01-02 (Pure Swift + SwiftUI Architecture)
**Purpose**: Document technical decisions and integration patterns

---

## Executive Summary

This document records the key technical decisions for implementing a privacy-first macOS speech-to-text application using **Pure Swift + SwiftUI** with **FluidAudio Swift SDK v0.9.0** for local ML inference on Apple Silicon.

**Key Architectural Decisions**:
1. **Pure Swift + SwiftUI** - Native macOS application (no Tauri/Rust/React)
2. **FluidAudio SDK** - Production-ready ASR instead of custom Python MLX integration

**Rationale**: FluidAudio provides production-ready ASR with Parakeet TDT v3, automatic model management, built-in VAD, and Apple Neural Engine optimization. Pure Swift architecture eliminates IPC complexity, reduces bundle size (10-20MB vs 50-80MB), improves performance (<10ms hotkey latency), and provides native macOS integration with frosted glass effects and hardware-accelerated animations.

---

## Research Areas Addressed

1. ML Inference Strategy (FluidAudio SDK)
2. Swift Package Manager Integration
3. Audio Processing and VAD
4. Model Management and Caching
5. Performance Benchmarking Strategy
6. Testing Approach for System Permissions
7. SwiftUI State Management Patterns
8. SwiftUI Integration with FluidAudio

---

## 1. ML Inference Strategy: FluidAudio SDK with Pure Swift

### Decision: Use FluidAudio Swift SDK v0.9.0 with Direct Swift Integration

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
6. **Native Swift Integration**: No FFI overhead, direct Swift API

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

**Rejected Alternatives**:
- **Custom Python MLX**: Would require Python subprocess, JSON-RPC IPC, custom VAD
- **Tauri + Rust FFI Bridge**: Unnecessary complexity for macOS-only app

---

## 2. Swift Package Manager Integration

### Decision: SPM for FluidAudio dependency management

**Package.swift Configuration**:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SpeechToTextApp",
    platforms: [.macOS(.v13)],
    products: [
        .executable(
            name: "SpeechToTextApp",
            targets: ["SpeechToTextApp"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/FluidInference/FluidAudio.git",
            from: "0.9.0"
        )
    ],
    targets: [
        .executableTarget(
            name: "SpeechToTextApp",
            dependencies: [
                .product(name: "FluidAudio", package: "FluidAudio")
            ]
        ),
        .testTarget(
            name: "SpeechToTextAppTests",
            dependencies: ["SpeechToTextApp"]
        )
    ]
)
```

**Xcode Project Integration**:
- File → Add Package Dependencies → https://github.com/FluidInference/FluidAudio.git
- FluidAudio automatically resolves dependencies (CoreML, Accelerate)
- No manual framework linking required

**Why SPM over CocoaPods/Carthage**:
- Native Swift tooling (no Ruby dependency)
- Better Xcode integration
- Semantic versioning support
- FluidAudio is distributed via SPM
- Official Apple package manager

---

## 3. Audio Processing and VAD

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

**Audio Capture** (AVAudioEngine):

```swift
import AVFoundation

class AudioCaptureService {
    private let audioEngine = AVAudioEngine()
    private let inputNode: AVAudioInputNode

    func startCapture() async throws {
        let recordingFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )!

        inputNode.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: recordingFormat
        ) { buffer, time in
            // Process audio buffer
            self.processAudioBuffer(buffer)
        }

        try audioEngine.start()
    }
}
```

**Rejected Alternative**: Custom VAD would require:
- Manual energy-based detection
- Separate VAD model loading
- Custom silence threshold tuning
- Additional processing pipeline

---

## 4. Model Management and Caching

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

**SwiftUI Integration for Download Progress**:

```swift
struct ModelDownloadView: View {
    @State private var downloadProgress: Double = 0
    @State private var isDownloading = false

    var body: some View {
        VStack(spacing: 16) {
            if isDownloading {
                ProgressView(value: downloadProgress, total: 1.0)
                    .progressViewStyle(.linear)
                Text("\(Int(downloadProgress * 100))% downloaded")
                    .font(.caption)
            }
        }
        .task {
            await downloadModels()
        }
    }

    func downloadModels() async {
        isDownloading = true
        do {
            let models = try await AsrModels.downloadAndLoad(
                version: .v3,
                progressHandler: { progress in
                    downloadProgress = progress
                }
            )
            isDownloading = false
        } catch {
            // Handle error
        }
    }
}
```

**Why FluidAudio Model Management**:
- Automatic caching (no custom implementation)
- Integrity verification built-in
- Progress tracking support
- Handles network failures with retry

---

## 5. Performance Benchmarking Strategy

### Decision: XCTest Measure Blocks + Instruments.app

**Tier 1: Unit Benchmarks**

```swift
// Swift XCTest Measure Blocks
import XCTest

class FluidAudioPerformanceTests: XCTestCase {
    func testTranscriptionPerformance() async throws {
        let service = FluidAudioService()
        let samples = generateTestAudio(duration: 5) // 5 seconds

        measure {
            Task {
                _ = try? await service.transcribe(samples: samples)
            }
        }
        // XCTest reports average time, std deviation
    }

    func testHotkeyResponseTime() throws {
        let hotkeyService = HotkeyService()

        measure {
            hotkeyService.simulateHotkeyPress()
            // Measure time until modal appears
        }
    }
}
```

**Tier 2: Integration Benchmarks with Instruments**

```bash
# Profile with Instruments (Time Profiler)
xcodebuild test \
    -scheme SpeechToTextApp \
    -destination 'platform=macOS' \
    -enableCodeCoverage YES \
    | xcpretty

# Memory profiling
instruments -t "Leaks" -D trace.trace SpeechToTextApp.app
```

**Success Criteria** (from spec.md):
| Metric | Target | Measurement |
|--------|--------|-------------|
| Hotkey response | <50ms | XCTest timing |
| Transcription latency | <100ms | FluidAudio result.durationMs |
| Waveform FPS | ≥30fps | CADisplayLink tracking |
| Idle RAM | <200MB | Instruments.app monitoring |
| Active RAM | <500MB | Instruments.app during transcription |
| App Bundle | <20MB | Xcode archive size (excluding models) |

**CI Integration**:
```yaml
# .github/workflows/benchmark.yml
- name: Run Swift benchmarks
  run: |
    xcodebuild test \
      -scheme SpeechToTextApp \
      -destination 'platform=macOS' \
      -only-testing:SpeechToTextAppTests/PerformanceTests

- name: Compare against baseline
  run: |
    swift run BenchmarkCompare \
      --current results.json \
      --baseline main \
      --threshold 10%  # Fail if >10% regression
```

---

## 6. Testing Strategy for System Permissions

### Decision: Protocol-based dependency injection with mocks

**Challenge**: macOS permissions cannot be granted programmatically in CI/CD

**Approach**:

**Level 1: Mocked Unit Tests** (runs in CI):

```swift
protocol PermissionChecker {
    func checkMicrophonePermission() async -> Bool
    func requestMicrophonePermission() async throws
}

class RealPermissionChecker: PermissionChecker {
    func checkMicrophonePermission() async -> Bool {
        return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    func requestMicrophonePermission() async throws {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        if !granted {
            throw PermissionError.microphoneDenied
        }
    }
}

class MockPermissionChecker: PermissionChecker {
    var microphoneGranted = true

    func checkMicrophonePermission() async -> Bool {
        return microphoneGranted
    }

    func requestMicrophonePermission() async throws {
        if !microphoneGranted {
            throw PermissionError.microphoneDenied
        }
    }
}

// Test with mock
class AudioServiceTests: XCTestCase {
    func testRecordingWithoutPermission() async throws {
        let mockChecker = MockPermissionChecker()
        mockChecker.microphoneGranted = false

        let service = AudioService(permissionChecker: mockChecker)

        do {
            try await service.startRecording()
            XCTFail("Should have thrown permission error")
        } catch {
            XCTAssertEqual(error as? PermissionError, .microphoneDenied)
        }
    }
}
```

**Level 2: Integration Tests** (developer machine with pre-granted permissions):

```swift
class IntegrationTests: XCTestCase {
    func testActualHotkeyRegistration() async throws {
        // Requires Input Monitoring permission already granted
        let hotkeyService = HotkeyService()

        let success = try await hotkeyService.registerHotkey(
            keyCode: 49, // Space
            modifiers: [.command, .control]
        )

        XCTAssertTrue(success)
    }
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
        run: |
          xcodebuild test \
            -scheme SpeechToTextApp \
            -destination 'platform=macOS'
```

---

## 7. SwiftUI State Management Patterns

### Decision: SwiftUI @Observable + @State for reactive UI

**Architecture**:

```swift
// Modern Swift Observation Framework (macOS 14+)
import Observation

@Observable
class RecordingViewModel {
    var isRecording: Bool = false
    var transcribedText: String = ""
    var audioLevel: Float = 0.0
    var errorMessage: String?

    private let audioService: AudioCaptureService
    private let transcriptionService: FluidAudioService

    init(
        audioService: AudioCaptureService = AudioCaptureService(),
        transcriptionService: FluidAudioService = FluidAudioService()
    ) {
        self.audioService = audioService
        self.transcriptionService = transcriptionService
    }

    func startRecording() async throws {
        isRecording = true
        errorMessage = nil

        do {
            try await audioService.startCapture { audioData in
                Task { @MainActor in
                    self.audioLevel = self.calculateLevel(audioData)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            isRecording = false
            throw error
        }
    }

    func stopRecordingAndTranscribe() async throws {
        isRecording = false
        let audioData = try await audioService.stopCapture()

        let result = try await transcriptionService.transcribe(samples: audioData)
        transcribedText = result.text
    }
}

// SwiftUI View
struct RecordingModalView: View {
    @State private var viewModel = RecordingViewModel()

    var body: some View {
        VStack(spacing: 24) {
            Text(viewModel.isRecording ? "Recording..." : "Ready")
                .font(.title)
                .foregroundStyle(.amber)

            // Waveform visualization
            WaveformView(audioLevel: viewModel.audioLevel)
                .frame(height: 80)

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Button(viewModel.isRecording ? "Stop" : "Start") {
                Task {
                    if viewModel.isRecording {
                        try? await viewModel.stopRecordingAndTranscribe()
                    } else {
                        try? await viewModel.startRecording()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
```

**Environment Objects for App-Wide State**:

```swift
@Observable
class AppState {
    var settings: AppSettings
    var statistics: UsageStatistics

    init() {
        self.settings = AppSettings.load()
        self.statistics = UsageStatistics.load()
    }
}

@main
struct SpeechToTextApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("Speech to Text", systemImage: "mic.fill") {
            MenuBarView()
        }
        .environment(appState)
    }
}

// Access in child views
struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Toggle("Show visual feedback", isOn: Bindable(appState).settings.showVisualFeedback)
    }
}
```

**Why @Observable over @StateObject/@ObservableObject**:
- Modern Swift Observation (simpler syntax)
- Better performance (granular updates)
- Type-safe keypaths
- No need for `@Published` wrappers

**For older macOS targets (pre-14), fallback to @StateObject**:

```swift
// Legacy approach (macOS 12+)
class RecordingViewModel: ObservableObject {
    @Published var isRecording: Bool = false
    @Published var transcribedText: String = ""
    // ... same implementation
}

struct RecordingModalView: View {
    @StateObject private var viewModel = RecordingViewModel()
    // ... same view body
}
```

---

## 8. SwiftUI Integration with FluidAudio

### Decision: Service layer with async/await pattern

**Service Architecture**:

```swift
import FluidAudio

actor FluidAudioService {
    private var asrManager: AsrManager?
    private var isInitialized = false

    func initialize() async throws {
        guard !isInitialized else { return }

        let models = try await AsrModels.downloadAndLoad(version: .v3)
        let config = AsrConfig.default

        asrManager = AsrManager(config: config)
        try await asrManager?.initialize(models: models)

        isInitialized = true
    }

    func transcribe(samples: [Float]) async throws -> TranscriptionResult {
        guard let asrManager = asrManager else {
            throw FluidAudioError.notInitialized
        }

        let result = try await asrManager.transcribe(samples)

        return TranscriptionResult(
            text: result.text,
            confidence: result.confidence,
            duration: result.durationMs
        )
    }

    func shutdown() async {
        asrManager = nil
        isInitialized = false
    }
}

struct TranscriptionResult {
    let text: String
    let confidence: Float
    let duration: TimeInterval
}
```

**SwiftUI View Integration**:

```swift
struct RecordingWorkflow: View {
    @State private var fluidAudioService = FluidAudioService()
    @State private var isInitialized = false
    @State private var initializationError: String?

    var body: some View {
        Group {
            if !isInitialized {
                ProgressView("Loading ML models...")
                    .task {
                        do {
                            try await fluidAudioService.initialize()
                            isInitialized = true
                        } catch {
                            initializationError = error.localizedDescription
                        }
                    }
            } else {
                RecordingModalView(transcriptionService: fluidAudioService)
            }
        }
    }
}
```

**Why Actor for FluidAudioService**:
- Thread-safe access to ASR manager
- Prevents data races in async context
- Clean async/await API
- No manual locking required

**Alternative Pattern (if not using actor)**:

```swift
@MainActor
class FluidAudioService {
    // All properties and methods run on main thread
    // Simpler but may block UI for expensive operations
}
```

---

## Technology Stack Summary

| Layer | Technology | Rationale |
|-------|-----------|-----------|
| **UI Framework** | SwiftUI | Native macOS, declarative, modern |
| **Language** | Swift 5.9+ | Single language, native performance |
| **State Management** | @Observable + @State | Modern Swift Observation, reactive |
| **Testing** | XCTest | Standard Swift testing framework |
| **ML Inference** | FluidAudio SDK | Production-ready ASR, ANE optimized |
| **Model** | Parakeet TDT v3 (0.6b) | 25 languages, ANE optimized |
| **Package Manager** | Swift Package Manager | Native Swift tooling, Xcode integration |
| **Build Tool** | Xcode | Official Apple IDE, integrated debugging |
| **Audio** | AVAudioEngine | Native audio capture, low latency |
| **Hotkeys** | Carbon Event Manager | Global hotkey support |
| **Accessibility** | AXUIElement APIs | Text insertion, native macOS |

**Key Benefits**:
- **1 Language**: Pure Swift (no TypeScript, Rust, Python)
- **0 IPC Boundaries**: No FFI overhead
- **10-20MB Bundle**: Native app (vs 50-80MB Tauri)
- **<10ms Hotkey Latency**: Native Carbon API
- **Native UI**: SwiftUI with frosted glass effects
- **Simple Architecture**: Single codebase, single build system

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
- ✅ Direct Swift integration
- ❌ Less control over ML pipeline
- ❌ Dependency on external SDK

---

### ADR-002: Pure Swift Application (No Rust/Tauri)

**Status**: Accepted

**Context**: Originally planned Tauri (React + Rust) with Swift FFI for FluidAudio. After eliminating Python, questioned if Rust/Tauri is still justified for macOS-only app.

**Decision**: Use Pure Swift + SwiftUI instead of Tauri + React + Swift

**Rationale**:
- Tauri's value is **cross-platform** - we're macOS-only
- With Python gone, Rust is just an **IPC bridge** - unnecessary complexity
- SwiftUI provides **better macOS integration** than web technologies
- **Simpler architecture**: 1 language vs 3, 0 IPC boundaries vs 2
- **Better performance**: <10ms hotkey latency vs ~30ms, native rendering vs web
- **Smaller bundle**: 10-20MB vs 50-80MB

**Consequences**:
- ✅ Single language (Swift only)
- ✅ No FFI overhead (direct FluidAudio integration)
- ✅ Native macOS integration (frosted glass, native animations)
- ✅ Smallest bundle size (10-20MB)
- ✅ Best performance (<10ms hotkey latency)
- ✅ Simpler build system (Xcode only)
- ❌ No React ecosystem (TailwindCSS, Framer Motion)
- ❌ SwiftUI learning curve (if unfamiliar)
- ❌ Less mature UI component ecosystem than React

**Rejected Alternative**: Tauri + React would require:
- 3 languages (TypeScript, Rust, Swift)
- 2 IPC boundaries (React ↔ Rust ↔ Swift)
- Larger bundle size (50-80MB)
- Higher hotkey latency (~30ms)
- More complex build pipeline

---

### ADR-003: SwiftUI @Observable for State Management

**Status**: Accepted

**Context**: Need reactive state management for recording/transcription UI

**Decision**: Use SwiftUI @Observable (macOS 14+) with fallback to @StateObject for older targets

**Rationale**:
- Modern Swift Observation framework (simpler than Combine)
- Granular UI updates (better performance)
- Type-safe keypaths
- No `@Published` boilerplate
- Native to SwiftUI

**Consequences**:
- ✅ Modern Swift best practices
- ✅ Better performance (granular updates)
- ✅ Simpler syntax (no `@Published`)
- ✅ Type-safe
- ❌ Requires macOS 14+ (can fallback to @StateObject)
- ❌ Less familiar than React Context

**Alternative Considered**:
- **React Context**: Rejected due to Pure Swift decision
- **Combine + @StateObject**: More verbose, older pattern
- **@StateObject only**: Still valid for older macOS targets

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
| Hotkey → Modal | <50ms | XCTest timing |
| Transcription | <100ms | FluidAudio result |
| Waveform FPS | ≥30fps | CADisplayLink |
| Idle RAM | <200MB | Instruments.app |
| Active RAM | <500MB | Instruments.app |
| App Bundle | <20MB | Xcode archive (excluding models) |
| Accuracy (WER) | >95% | English test set |

**Pure Swift Benefits**:
- Native hotkey latency: <10ms (vs ~30ms Tauri)
- Smaller bundle: 10-20MB (vs 50-80MB Tauri)
- Lower idle RAM: <50MB (vs ~200MB Tauri)

---

## Next Steps

**Phase 1: Design & Contracts** ✅
- [x] data-model.md - Entity definitions
- [x] contracts/swiftui-views.md - View component specifications
- [x] contracts/swift-services.md - Service layer API contracts
- [x] quickstart.md - Developer setup guide

**Phase 2: Implementation** (Next)
- [ ] `/speckit.tasks` - Generate dependency-ordered tasks
- [ ] `/speckit.implement` - TDD implementation
- [ ] Milestone 1: Core Infrastructure (hotkey → transcribe → insert)
- [ ] Milestone 2: UI/UX Polish (modal, waveform, settings)
- [ ] Milestone 3: Multi-Language Support (25 languages)

---

**Research Complete**: All architectural decisions documented. Pure Swift + SwiftUI architecture validated. Ready for implementation with FluidAudio SDK.
