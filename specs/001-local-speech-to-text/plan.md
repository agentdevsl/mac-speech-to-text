# Implementation Plan: macOS Local Speech-to-Text Application

**Branch**: `001-local-speech-to-text` | **Date**: 2026-01-02 | **Updated**: 2026-01-02 (Pure Swift + SwiftUI) | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-local-speech-to-text/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. Updated to Pure Swift + SwiftUI architecture with FluidAudio SDK v0.9.0.

## Summary

Build a privacy-first macOS speech-to-text application that runs 100% locally on Apple Silicon. The app uses a global hotkey to trigger an elegant recording modal, captures audio, transcribes locally using FluidAudio SDK with Parakeet TDT v3 on Apple Neural Engine, and automatically inserts text into the active application. Technical stack: Pure Swift + SwiftUI for native macOS application with FluidAudio SDK for ML inference and audio processing.

## Technical Context

**Language/Version**:
- Swift 5.9+ (single language for entire application)
- SwiftUI for declarative UI
- FluidAudio SDK v0.9.0+ (ASR, VAD, audio processing)

**Primary Dependencies**:
- SwiftUI (native macOS UI framework)
- FluidAudio Swift SDK v0.9.0+ (local ASR with Parakeet TDT v3, VAD, audio processing)
- Swift: Carbon/Cocoa (global hotkeys), Accessibility APIs (text insertion), Core Audio (audio capture)
- Swift Package Manager for dependency management

**Storage**:
- User settings: UserDefaults or local JSON
- ML models: Managed by FluidAudio SDK (auto-downloads from HuggingFace)
- Usage statistics: Local SQLite database or UserDefaults
- No cloud storage or network calls

**Testing**:
- XCTest for all Swift code (UI, services, FluidAudio integration)
- SwiftUI Previews for rapid UI development
- XCUITest for end-to-end application testing
- Performance: XCTest measure blocks for benchmarking

**Target Platform**:
- macOS 12.0 (Monterey) or later
- Apple Silicon only (M1/M2/M3/M4)
- Universal binary distribution via DMG

**Project Type**: Native macOS desktop application (Pure Swift)

**Performance Goals**:
- Hotkey response: <50ms from keypress to modal display
- Transcription latency: <100ms from silence detection to text insertion
- Waveform visualization: 30+ fps during recording
- Idle memory: <200MB RAM
- Active transcription: <500MB RAM
- UI responsiveness: 60fps (120fps on ProMotion displays)

**Constraints**:
- 100% local processing (zero network calls post-setup)
- Bundle size: <50MB (excluding ML models)
- Model downloads: background with progress, applied on restart
- Accessibility permission required for text insertion
- Single app instance (singleton enforcement)
- Real-time audio processing without blocking UI

**Scale/Scope**:
- Single-user desktop application
- 25 supported languages (via FluidAudio)
- ~8 SwiftUI views (onboarding, settings, recording modal, menu bar)
- ML models: ~500MB per language, up to 12.5GB if all downloaded
- Expected usage: 20-50 transcription sessions per day per user

## Constitution Check

_GATE: Must pass before Phase 0 research. Re-check after Phase 1 design._

### Constitution Compliance Analysis

This project diverges from the web-centric TypeScript/Node.js constitution, but the differences are justified by the native macOS desktop application nature:

**COMPLIANT (Adapted for Swift)**:
- Strict type safety (Swift's type system equivalent to TypeScript strict mode)
- XCTest for all testing (equivalent to Vitest)
- SwiftLint for code quality (equivalent to ESLint + Prettier)
- Environment variables / configuration patterns
- TDD methodology (RED-GREEN-REFACTOR)
- Service-repository pattern for state management
- Explicit error handling with typed errors (Swift Error protocol)
- Modern async/await patterns (Swift Concurrency)

**JUSTIFIED DEVIATIONS** (Native macOS Application):

| Constitution Rule | Deviation | Justification |
|------------------|-----------|---------------|
| "TypeScript with strict mode" | Swift 5.9+ with strict concurrency checking | Native macOS app requires Swift for system integration, SwiftUI, Accessibility APIs, and FluidAudio SDK. Swift provides equivalent type safety and better performance. |
| "Node.js 24+ runtime" | macOS native (Swift runtime) | Desktop app requires native performance and system integration. Swift provides direct access to macOS frameworks, Apple Neural Engine, and system APIs that Node.js cannot access. |
| "Vitest for testing" | XCTest for testing | XCTest is the native Swift testing framework with first-class Xcode integration, SwiftUI test support, and performance testing capabilities. |
| "Web application structure" | Native app structure | macOS desktop app with native UI requirements (global hotkeys, menu bar, system permissions). Web architecture inappropriate for system-level integrations. |

**NO VIOLATIONS**:
- Security-first development: Input validation, no credential storage, secure keychain usage
- Test-driven development: TDD for all layers (XCTest for Swift, XCUITest for UI)
- Code quality: SwiftLint for style, SwiftFormat for formatting
- Architecture patterns: Service layer for business logic, repository pattern for data access
- Single language: Pure Swift eliminates multi-language complexity

**GATE STATUS**: ✅ PASS - Pure Swift architecture is simpler and more aligned with macOS best practices. Single-language stack reduces complexity significantly. Constitution's principles (TDD, type safety, code quality) apply to Swift layer.

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

**Structure Decision**: Pure Swift application using SwiftUI for UI and FluidAudio SDK for ML inference. All code in a single language with clear separation of concerns using Swift's native patterns.

```text
SpeechToText.xcodeproj   # Xcode project
Package.swift             # Swift Package Manager config

Sources/
├── SpeechToTextApp/
│   ├── SpeechToTextApp.swift    # @main entry point
│   ├── AppDelegate.swift         # App lifecycle, menu bar
│   └── AppState.swift            # Observable app state
│
├── Views/                        # SwiftUI views
│   ├── RecordingModal.swift     # Main recording UI with waveform
│   ├── OnboardingView.swift     # First-time setup flow
│   ├── SettingsView.swift       # Configuration screens
│   ├── MenuBarView.swift        # Menu dropdown content
│   └── Components/
│       ├── WaveformView.swift   # Audio visualization
│       ├── PermissionCard.swift # Permission request UI
│       └── LanguagePicker.swift # Language selection
│
├── Services/                     # Business logic
│   ├── FluidAudioService.swift  # FluidAudio SDK wrapper
│   ├── HotkeyService.swift      # Global hotkey (Carbon API)
│   ├── AudioCaptureService.swift # Core Audio integration
│   ├── TextInsertionService.swift # Accessibility API
│   ├── SettingsService.swift    # UserDefaults wrapper
│   ├── StatisticsService.swift  # Usage tracking
│   └── PermissionService.swift  # System permission checks
│
├── Models/                       # Data types
│   ├── RecordingSession.swift   # Recording state machine
│   ├── UserSettings.swift       # Configuration model
│   ├── LanguageModel.swift      # Language metadata
│   ├── UsageStatistics.swift    # Stats aggregation
│   └── AudioBuffer.swift        # Audio data handling
│
└── Utilities/                    # Shared helpers
    ├── Extensions/
    │   ├── Color+Theme.swift    # Warm Minimalism palette
    │   └── View+Modifiers.swift # Custom SwiftUI modifiers
    └── Constants.swift          # App-wide constants

Tests/
├── SpeechToTextTests/           # Unit tests (XCTest)
│   ├── Services/
│   │   ├── FluidAudioServiceTests.swift
│   │   ├── HotkeyServiceTests.swift
│   │   └── TextInsertionServiceTests.swift
│   └── Models/
│       └── RecordingSessionTests.swift
│
└── SpeechToTextUITests/         # UI tests (XCUITest)
    ├── OnboardingFlowTests.swift
    ├── RecordingFlowTests.swift
    └── SettingsTests.swift

Resources/
├── Assets.xcassets/             # Images, icons, colors
├── Sounds/                      # Audio feedback
└── Localizations/               # i18n (25 languages)
```

## Complexity Tracking

| Deviation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|--------------------------------------|
| FluidAudio SDK dependency | FluidAudio provides production-ready ASR with Parakeet TDT v3 on Apple Neural Engine. Built-in VAD, model management, and 25-language support | Custom MLX integration: Would require Python subprocess and complex IPC. Apple Speech Framework: Requires network, violates privacy requirement. WASM ML: Insufficient performance, no ANE acceleration. |
| Carbon API for global hotkeys | Modern Swift lacks native global hotkey API. Carbon provides the only reliable cross-app hotkey registration on macOS | Accessibility API hotkeys: Unreliable, permission issues. Polling: High CPU usage, poor latency. CGEventTap: Requires accessibility permission anyway. |
| Accessibility API for text insertion | Only API that can insert text programmatically into arbitrary applications | Clipboard paste simulation: Unreliable, replaces clipboard. AppleScript: Slow, application-specific. Pasteboard: Doesn't trigger insertion. |

---

## Phase 0: Research & Discovery

**Status**: ✅ COMPLETE (Pure Swift + SwiftUI Architecture)

All technical unknowns resolved. Architecture significantly simplified with Pure Swift approach.

**Key Decisions**:
1. **Pure Swift**: Single language for entire application (eliminates Tauri/Rust/TypeScript)
2. **SwiftUI**: Declarative UI framework with native macOS integration
3. **FluidAudio SDK**: Production-ready ASR with Parakeet TDT v3 on Apple Neural Engine
4. **Swift Concurrency**: async/await for all asynchronous operations
5. **XCTest**: Native testing framework with SwiftUI test support
6. **Swift Package Manager**: Dependency management for FluidAudio
7. **Xcode**: Primary development environment with Previews for rapid iteration

**Architecture Simplification**:
- **Eliminated**: Tauri, Rust, React, TypeScript, Python, JSON-RPC, IPC boundaries
- **Unified**: All code in Swift with native APIs
- **Reduced complexity**: 1 language (Swift) instead of 3-4 languages

---

## Phase 1: Design & Contracts

**Status**: ✅ COMPLETE

### Artifacts Generated

1. **data-model.md**: Complete entity definitions
   - RecordingSession (lifecycle and state machine)
   - UserSettings (configuration with defaults)
   - LanguageModel (25 supported languages)
   - UsageStatistics (privacy-preserving aggregations)
   - AudioBuffer (in-memory audio handling)

2. **contracts/swift-fluidaudio.md**: Swift FluidAudio integration contract
   - FluidAudio SDK wrapper interface
   - AsrManager configuration and usage
   - Model loading and language switching
   - Error codes and Swift implementation patterns

3. **quickstart.md**: Developer onboarding guide
   - System requirements and dependencies
   - Swift Package Manager setup for FluidAudio
   - Xcode workspace configuration
   - Development workflow and common tasks
   - Troubleshooting guide

---

## Phase 2: Architecture Summary

### System Architecture

```
┌─────────────────────────────────────────┐
│         SwiftUI Application             │
│  ┌───────────────────────────────────┐  │
│  │  Views                            │  │
│  │  - RecordingModal (waveform)     │  │
│  │  - OnboardingView                │  │
│  │  - SettingsView                  │  │
│  │  - MenuBarView                   │  │
│  └─────────────┬─────────────────────┘  │
│                │                         │
│  ┌─────────────▼─────────────────────┐  │
│  │  Services (Swift)                 │  │
│  │  - FluidAudioService              │  │
│  │  - HotkeyService (Carbon)         │  │
│  │  - AudioCaptureService            │  │
│  │  - TextInsertionService (AX)     │  │
│  │  - SettingsService                │  │
│  │  - StatisticsService              │  │
│  │  - PermissionService              │  │
│  └─────────────┬─────────────────────┘  │
│                │                         │
│                ▼                         │
│         FluidAudio SDK                   │
│         Apple Neural Engine              │
└─────────────────────────────────────────┘
```

### Data Flow: User Dictation

```
1. User presses ⌘⌃Space
   ↓
2. HotkeyService detects via Carbon API
   ↓
3. AppState updates → RecordingModal appears (SwiftUI)
   ↓
4. User speaks → AudioCaptureService captures audio
   ↓
5. AudioCaptureService → audio levels to WaveformView (30fps)
   ↓
6. FluidAudioService detects silence via VAD (1.5s)
   ↓
7. FluidAudioService.transcribe() → Apple Neural Engine
   ↓
8. Parakeet TDT v3 inference → text + confidence
   ↓
9. TextInsertionService inserts via Accessibility API
   ↓
10. Modal closes → StatisticsService updates
```

### Technology Integration Points

| Integration | Mechanism | Purpose |
|-------------|-----------|---------|
| SwiftUI → Services | @StateObject, @EnvironmentObject | Reactive UI updates, dependency injection |
| Services → FluidAudio | Swift Package Manager | ASR transcription, VAD, model management |
| Services → Carbon | C API bridge | Global hotkey registration |
| Services → Accessibility | macOS framework | Text insertion into active app |
| FluidAudio → ANE | Apple Neural Engine | Parakeet TDT v3 inference (on-device) |

### Security & Privacy Architecture

**Privacy Guarantees**:
- 100% local processing via Apple Neural Engine (zero network calls post-setup)
- No audio data persisted to disk
- No transcribed text stored (only aggregated statistics)
- User settings stored in UserDefaults (encrypted by macOS)
- Models auto-downloaded by FluidAudio from HuggingFace (HTTPS only)

**Permission Boundaries**:
- Microphone: Required for audio capture
- Accessibility: Required for text insertion
- Input Monitoring: Required for global hotkeys (macOS 10.15+)
- No network permission needed (except model downloads)
- App Sandbox compatible (with entitlements)

**Sandboxing**:
- All code runs in single process (no IPC boundaries)
- Clear service boundaries via Swift protocols
- FluidAudio SDK runs in-process for maximum performance
- Accessibility API accessed via official macOS frameworks

---

## Phase 3: Testing Strategy (TDD Implementation)

### Test Pyramid

```
        ┌─────────────────┐
        │   E2E Tests     │  XCUITest on fresh macOS
        │   (XCUITest)    │  Permission flows, full user stories
        └─────────────────┘
              ▲
              │
        ┌─────────────────┐
        │  Integration    │  Pre-authorized environment
        │  Tests (XCTest) │  FluidAudio, Accessibility API
        └─────────────────┘
              ▲
              │
    ┌───────────────────────┐
    │   Unit Tests          │  Mocked system APIs
    │   (XCTest)            │  100% business logic coverage
    │                       │  No permission dependencies
    └───────────────────────┘
```

### Test Coverage Requirements

| Layer | Tool | Minimum Coverage | Notes |
|-------|------|------------------|-------|
| Services | XCTest + mocks | 80% | FluidAudioService, HotkeyService, etc. |
| Models | XCTest | 90% | RecordingSession, UserSettings, etc. |
| Views | SwiftUI Previews + XCUITest | 60% | Visual regression via Previews |
| Integration | XCTest --ignored | Key flows | Hotkey → modal → transcribe → insert |
| E2E | XCUITest | User stories | All acceptance criteria from spec.md |

### TDD Workflow

**RED Phase** (Write failing test):
```swift
// Tests/SpeechToTextTests/Services/FluidAudioServiceTests.swift
import XCTest
@testable import SpeechToText

class FluidAudioServiceTests: XCTestCase {
    func testTranscribeReturnsTextForValidAudio() async throws {
        let service = FluidAudioService()
        try await service.initialize(language: "en")

        let mockSamples = generateSilence(duration: 2.0) // 2 seconds of silence

        let result = try await service.transcribe(samples: mockSamples)

        XCTAssertFalse(result.text.isEmpty)
        XCTAssertGreaterThan(result.confidence, 0.0)
    }
}
```

**GREEN Phase** (Minimal implementation):
```swift
// Sources/Services/FluidAudioService.swift
import FluidAudio

class FluidAudioService {
    private var asrManager: AsrManager?

    func initialize(language: String) async throws {
        let models = try await AsrModels.downloadAndLoad(version: .v3)
        self.asrManager = AsrManager(config: .default)
        try await asrManager?.initialize(models: models)
    }

    func transcribe(samples: [Int16]) async throws -> TranscriptionResult {
        let floatSamples = samples.map { Float($0) / 32768.0 }
        let result = try await asrManager!.transcribe(floatSamples)
        return TranscriptionResult(text: result.text, confidence: result.confidence ?? 0.95)
    }
}
```

**REFACTOR Phase** (Improve with error handling):
```swift
class FluidAudioService {
    func transcribe(samples: [Int16]) async throws -> TranscriptionResult {
        guard let asrManager = asrManager else {
            throw FluidAudioError.notInitialized
        }

        guard !samples.isEmpty else {
            throw FluidAudioError.invalidInput("Audio samples cannot be empty")
        }

        let floatSamples = samples.map { Float($0) / 32768.0 }

        do {
            let result = try await asrManager.transcribe(floatSamples)
            return TranscriptionResult(text: result.text, confidence: result.confidence ?? 0.95)
        } catch {
            throw FluidAudioError.transcriptionFailed(error.localizedDescription)
        }
    }
}
```

### Performance Benchmarking

Automated benchmarks run on every PR to detect regressions:

**Success Criteria** (from spec.md):
- Hotkey response: <50ms
- Transcription latency: <100ms
- Waveform FPS: ≥30fps
- Idle RAM: <200MB
- Active RAM: <500MB
- UI responsiveness: 60fps (120fps on ProMotion)

**XCTest Measure Blocks**:
```swift
class PerformanceTests: XCTestCase {
    func testHotkeyResponseLatency() {
        let service = HotkeyService()

        measure {
            service.simulateHotkeyPress()
            // Measure time until modal appears
        }
        // XCTest will report average time, std deviation
    }

    func testTranscriptionLatency() async throws {
        let service = FluidAudioService()
        try await service.initialize(language: "en")
        let samples = generateTestAudio(duration: 5.0)

        measure {
            _ = try? await service.transcribe(samples: samples)
        }
    }
}
```

---

## Implementation Roadmap

### Milestone 1: Core Infrastructure (P1 - User Story 1 & 2)
- [ ] Xcode project setup with Swift Package Manager
- [ ] FluidAudio SDK integration via SPM
- [ ] SwiftUI app scaffold with menu bar integration
- [ ] HotkeyService (Carbon API for global hotkeys)
- [ ] AudioCaptureService (Core Audio)
- [ ] FluidAudioService wrapper (English only initially)
- [ ] TextInsertionService (Accessibility API)
- [ ] Basic RecordingModal SwiftUI view
- [ ] OnboardingView with permission requests
- **Deliverable**: User can press hotkey, speak, and see text inserted

### Milestone 2: UI/UX Polish (P2 - User Story 3)
- [ ] RecordingModal with frosted glass design (.ultraThinMaterial)
- [ ] Real-time WaveformView (Core Audio visualization)
- [ ] SettingsView (hotkey, language, audio sensitivity)
- [ ] MenuBarView with stats display
- [ ] Error handling and user feedback
- [ ] "Warm Minimalism" design system (colors, typography, animations)
- **Deliverable**: Production-quality UI matching design spec

### Milestone 3: Multi-Language Support (P3 - User Story 4 & 5)
- [ ] Language selection UI in SettingsView
- [ ] FluidAudio model management (auto-download with progress)
- [ ] Language switching in FluidAudioService
- [ ] Model download progress UI
- [ ] 25 European language support
- **Deliverable**: All languages supported via FluidAudio

### Milestone 4: Testing & Quality (All Priorities)
- [ ] Unit tests for all services (80% coverage)
- [ ] XCUITest for E2E flows
- [ ] Performance benchmarks (XCTest measure blocks)
- [ ] SwiftUI Previews for all views
- [ ] Accessibility testing (VoiceOver, keyboard navigation)
- **Deliverable**: Production-ready quality

### Milestone 5: Distribution (Release)
- [ ] DMG installer with code signing
- [ ] App notarization (Apple)
- [ ] Sparkle framework for auto-updates
- [ ] Crash reporting (privacy-preserving)
- [ ] Optional analytics (opt-in, anonymous)
- **Deliverable**: Shippable macOS app

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Accessibility API reliability | High | Fallback to clipboard copy, extensive testing across apps |
| FluidAudio model download failures | Low | FluidAudio handles downloads with built-in retry logic |
| Global hotkey conflicts | Medium | Conflict detection, alternative hotkey suggestions |
| Memory leaks in FluidAudio | Low | FluidAudio manages memory internally, monitor via Instruments |
| FluidAudio SDK breaking changes | Medium | Pin to specific version (0.9.0), test upgrades in isolation |
| Permission denial by users | Medium | Clear explanations, graceful degradation, settings link |
| Carbon API deprecation | Low | Monitor Apple announcements, prepare CGEventTap fallback |

---

## Success Metrics (from spec.md)

### Performance Metrics
- ✅ SC-001: Text insertion <100ms from silence detection
- ✅ SC-002: App bundle <50MB (excluding models)
- ✅ SC-003: Transcription accuracy >95% (WER benchmark)
- ✅ SC-004: Zero network calls during operation
- ✅ SC-005: Onboarding complete <2 minutes
- ✅ SC-006: Modal appears <50ms from hotkey
- ✅ SC-007: RAM usage <200MB idle, <500MB active
- ✅ SC-008: Waveform 30fps minimum
- ✅ SC-009: 90% permission grant success
- ✅ SC-010: Language switch <2 seconds
- ✅ SC-011: UI 60fps during transcription
- ✅ SC-012: 95% transcription success rate

### User Acceptance
- All 5 user stories from spec.md pass acceptance scenarios
- All edge cases handled gracefully
- Onboarding flow completes without confusion
- Settings are discoverable and intuitive

---

## Next Steps

**Phase 2 Planning Complete** ✅

**Ready for Phase 3**: Task generation

Run `/speckit.tasks` command to generate `tasks.md` with dependency-ordered implementation tasks for Pure Swift + SwiftUI architecture.

**Note**: This plan stops at Phase 2 as per the `/speckit.plan` workflow. Implementation occurs in Phase 3 via the `/speckit.implement` command.
