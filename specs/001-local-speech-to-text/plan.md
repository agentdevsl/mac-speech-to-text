# Implementation Plan: macOS Local Speech-to-Text Application

**Branch**: `001-local-speech-to-text` | **Date**: 2026-01-02 | **Updated**: 2026-01-02 (FluidAudio) | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-local-speech-to-text/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. Updated to use FluidAudio Swift SDK v0.9.0.

## Summary

Build a privacy-first macOS speech-to-text application that runs 100% locally on Apple Silicon. The app uses a global hotkey to trigger an elegant recording modal, captures audio, transcribes locally using FluidAudio SDK with Parakeet TDT v3 on Apple Neural Engine, and automatically inserts text into the active application. Technical stack: Tauri 2.0 + React + TypeScript frontend, FluidAudio Swift SDK for ML inference and audio processing, Swift for native macOS APIs (hotkeys, text insertion).

## Technical Context

**Language/Version**:
- Frontend: TypeScript 5.7+ (strict mode), React 18+
- Native/ML: Swift 5.9+ with FluidAudio SDK v0.9.0+
- Build: Rust 1.75+ (Tauri framework)

**Primary Dependencies**:
- Tauri 2.0 (cross-platform app framework with Rust core)
- React 18+ with TypeScript (UI layer)
- FluidAudio Swift SDK v0.9.0+ (local ASR with Parakeet TDT v3, VAD, audio processing)
- Swift: Carbon/Cocoa (global hotkeys), Accessibility APIs (text insertion)
- Swift Package Manager for FluidAudio integration

**Storage**:
- User settings: Local JSON/SQLite via Tauri Store plugin
- ML models: Managed by FluidAudio SDK (auto-downloads from HuggingFace)
- Usage statistics: Local SQLite database
- No cloud storage or network calls

**Testing**:
- Frontend: Vitest + React Testing Library
- Swift/FluidAudio: XCTest for native API integrations and ASR pipeline
- E2E: Tauri WebDriver for full application flow
- Performance: Automated benchmarks for transcription latency and memory usage

**Target Platform**:
- macOS 12.0 (Monterey) or later
- Apple Silicon only (M1/M2/M3/M4)
- Universal binary distribution via DMG

**Project Type**: Desktop application (hybrid: web frontend + native backend + ML inference)

**Performance Goals**:
- Hotkey response: <50ms from keypress to modal display
- Transcription latency: <100ms from silence detection to text insertion
- Waveform visualization: 30+ fps during recording
- Idle memory: <200MB RAM
- Active transcription: <500MB RAM
- UI responsiveness: 60fps (no jank during transcription)

**Constraints**:
- 100% local processing (zero network calls post-setup)
- Bundle size: <50MB (excluding ML models)
- Model downloads: background with progress, applied on restart
- Accessibility permission required for text insertion
- Single app instance (singleton enforcement)
- Real-time audio processing without blocking UI

**Scale/Scope**:
- Single-user desktop application
- 25 supported languages
- ~12 UI screens (onboarding, settings, recording modal, menu bar)
- ML models: ~500MB per language, up to 12.5GB if all downloaded
- Expected usage: 20-50 transcription sessions per day per user

## Constitution Check

_GATE: Must pass before Phase 0 research. Re-check after Phase 1 design._

### Constitution Compliance Analysis

This project diverges from the web-centric TypeScript/Node.js constitution but the differences are justified by the desktop/ML nature:

**COMPLIANT**:
- TypeScript with strict mode for frontend React code
- Vitest for frontend testing
- ESLint + Prettier for code quality
- Environment variables for configuration
- TDD methodology (RED-GREEN-REFACTOR)
- Service-repository pattern for frontend state management
- Explicit error handling with typed errors
- Modern async/await patterns

**JUSTIFIED DEVIATIONS** (Desktop + ML Application):

| Constitution Rule | Deviation | Justification |
|------------------|-----------|---------------|
| "Node.js 24+ runtime" | Uses Tauri (Rust) + Swift runtime | Desktop apps require native performance and system integration. Tauri provides secure native APIs, Swift provides macOS system access and ML via FluidAudio. Node.js cannot access macOS Accessibility APIs or Apple Neural Engine. |
| "Web application structure" | Desktop application structure | macOS desktop app with native UI requirements (global hotkeys, menu bar, system permissions). Web architecture inappropriate for system-level integrations. |
| "All code in TypeScript" | Swift for native APIs + ML | macOS APIs (Accessibility, hotkeys) and FluidAudio SDK require Swift. TypeScript cannot access Apple Neural Engine or system frameworks. FluidAudio eliminates need for Python. |
| "Single language stack" | Multi-language (TS/Rust/Swift) | Each language serves essential purpose: TS for UI, Rust for security/IPC, Swift for macOS APIs and on-device ML. Significantly simpler than previous Python approach. |

**NO VIOLATIONS**:
- Security-first development: All secrets in env vars, input validation, no credential storage
- Test-driven development: TDD for all layers (frontend Vitest, Swift XCTest)
- Code quality: ESLint + Prettier for TS, SwiftLint for Swift
- Architecture patterns: Service layer for business logic, repository pattern for data access

**GATE STATUS**: ✅ PASS - Deviations are necessary and well-justified for desktop ML application. FluidAudio SDK significantly simplifies architecture by eliminating Python layer. The constitution's TypeScript/web principles apply to frontend layer.

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

**Structure Decision**: Tauri desktop application with Swift-first architecture. Frontend (React/TS) communicates with Rust core via Tauri IPC. Rust core orchestrates Swift native layer which includes FluidAudio SDK for ML inference. This structure eliminates Python complexity while maintaining clear separation of concerns.

```text
src-tauri/                    # Rust backend (Tauri core)
├── src/
│   ├── main.rs              # Tauri app entry point
│   ├── commands.rs          # IPC command handlers
│   ├── swift_bridge.rs      # Swift interop via FFI
│   ├── models/              # Rust data types
│   └── lib/                 # Shared utilities
├── swift/                   # Swift native modules + FluidAudio
│   ├── Package.swift        # Swift Package Manager config
│   ├── GlobalHotkey/        # Hotkey registration (Carbon API)
│   ├── FluidAudioService/   # FluidAudio SDK wrapper for ASR
│   ├── TextInsertion/       # Accessibility API bridge
│   ├── MenuBar/             # NSStatusItem integration
│   └── bridge.swift         # C ABI exports to Rust
├── Cargo.toml
└── build.rs                 # Swift compilation integration

src/                         # React + TypeScript frontend
├── components/
│   ├── RecordingModal/      # Main recording UI
│   ├── Onboarding/          # First-time setup flow
│   ├── Settings/            # Configuration screens
│   ├── Waveform/            # Audio visualization
│   └── MenuBar/             # Menu dropdown
├── services/
│   ├── audio.service.ts     # Audio state management
│   ├── settings.service.ts  # User preferences
│   ├── stats.service.ts     # Usage tracking
│   └── ipc.service.ts       # Tauri command wrappers
├── hooks/                   # React custom hooks
├── types/                   # TypeScript definitions
├── styles/                  # Warm Minimalism design system
└── App.tsx                  # Main React app

tests/                      # Cross-layer integration tests
├── e2e/
│   ├── test_hotkey_flow.rs  # Full recording flow
│   ├── test_onboarding.rs   # Permission grants
│   └── test_settings.rs     # Configuration changes
└── integration/
    └── test_swift_bridge.rs # Native API + FluidAudio integration

scripts/                    # Build and development tools
├── setup-dev.sh           # Development environment setup
└── build-swift.sh         # Swift module compilation with SPM
```

## Complexity Tracking

| Deviation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|--------------------------------------|
| Multi-language stack (TS/Rust/Swift) | Each language provides irreplaceable capabilities: TS for modern UI, Rust for secure system integration, Swift for macOS native APIs + FluidAudio ML | Electron: Cannot access Accessibility APIs or global hotkeys. Pure Swift: Poor web UI tooling, no Tauri benefits. TypeScript-only: Cannot access Apple Neural Engine or system frameworks. |
| Swift FluidAudio SDK | FluidAudio provides production-ready ASR with Parakeet TDT v3 on Apple Neural Engine. Eliminates need for Python/MLX custom integration | Custom MLX integration: Requires Python subprocess, JSON-RPC IPC, custom model loading. WASM ML: Insufficient performance, no ANE acceleration. Server-based: Violates privacy requirement. |
| Swift native bridge | macOS Accessibility API, global hotkey registration (Carbon), menu bar integration require Objective-C/Swift runtime | Rust only: Cannot access Accessibility framework or Carbon API. JavaScript bridge: Performance penalty, security risk for system APIs. |

---

## Phase 0: Research & Discovery

**Status**: ✅ COMPLETE (Updated for FluidAudio SDK)

All technical unknowns resolved. Architecture significantly simplified with FluidAudio SDK.

**Key Decisions**:
1. ML inference: FluidAudio Swift SDK with Parakeet TDT v3 on Apple Neural Engine
2. Audio processing: FluidAudio handles VAD, preprocessing, and model management
3. Swift bridge: Dynamic library via FFI with C ABI
4. Performance benchmarking: Multi-tier with automated regression detection
5. Permission testing: Mocked unit tests + pre-authorized integration tests
6. Tauri + React: Typed IPC commands + React Context for state
7. Model management: FluidAudio auto-downloads from HuggingFace
8. macOS permissions: Incremental onboarding with explanations

**Architecture Simplification**:
- **Eliminated**: Python subprocess, JSON-RPC protocol, custom MLX integration
- **Unified**: All Swift code in single layer (native APIs + ML via FluidAudio)
- **Reduced complexity**: 3 languages instead of 4, simpler IPC surface

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

2. **contracts/tauri-ipc.md**: Tauri IPC API specification
   - Command definitions with request/response schemas
   - Event emissions for real-time updates
   - Error handling patterns and codes
   - TypeScript type generation strategy

3. **contracts/swift-fluidae.md**: Swift FluidAudio integration contract
   - FluidAudio SDK wrapper interface
   - AsrManager configuration and usage
   - Model loading and language switching
   - Error codes and Swift implementation patterns

4. **quickstart.md**: Developer onboarding guide
   - System requirements and dependencies
   - Swift Package Manager setup for FluidAudio
   - Development workflow and common tasks
   - Troubleshooting guide

---

## Phase 2: Architecture Summary

### System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     React Frontend (TS)                      │
│  • Recording modal with waveform visualization              │
│  • Onboarding flow with permission requests                 │
│  • Settings UI with hotkey customization                    │
│  • Menu bar integration                                     │
└──────────────────┬──────────────────────────────────────────┘
                   │ Tauri IPC (async invoke)
┌──────────────────▼──────────────────────────────────────────┐
│                   Rust Tauri Core                           │
│  • IPC command handlers (commands.rs)                       │
│  • Application state management                             │
│  • Swift bridge orchestration (FFI)                         │
└──────────────────┬──────────────────────────────────────────┘
                   │ Swift FFI (C ABI)
┌──────────────────▼──────────────────────────────────────────┐
│              Swift Native Layer + FluidAudio                 │
│  • GlobalHotkey (Carbon API)                                │
│  • FluidAudio SDK:                                          │
│    - AsrManager (Parakeet TDT v3)                           │
│    - Voice Activity Detection (Silero)                      │
│    - Audio preprocessing (16kHz conversion)                 │
│    - Model management (auto-download)                       │
│  • TextInsertion (Accessibility API)                        │
│  • MenuBar (NSStatusItem)                                   │
│  • Apple Neural Engine (ANE) for inference                  │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow: User Dictation

```
1. User presses ⌘⌃Space
   ↓
2. Swift GlobalHotkey detects → emits event to Rust
   ↓
3. Rust emits 'hotkey-pressed' → React shows modal
   ↓
4. React calls invoke('start_recording')
   ↓
5. Rust calls Swift FluidAudioService → starts recording
   ↓
6. FluidAudio captures audio (16kHz) + VAD detection
   ↓
7. Audio levels → Rust → React (30fps) for waveform
   ↓
8. Silence detected by FluidAudio VAD (1.5s) → auto-stop
   ↓
9. Swift calls FluidAudio AsrManager.transcribe()
   ↓
10. Apple Neural Engine inference (Parakeet TDT v3)
    ↓
11. FluidAudio returns text + confidence → Swift → Rust
    ↓
12. Rust calls Swift TextInsertion → Accessibility API
    ↓
13. Text inserted at cursor → modal closes
    ↓
14. Statistics updated → SQLite
```

### Technology Integration Points

| Integration | Mechanism | Purpose |
|-------------|-----------|---------|
| React ↔ Rust | Tauri IPC commands | UI state management, trigger actions |
| Rust ↔ Swift | FFI with C ABI (dylib) | Native macOS APIs + FluidAudio ML |
| Swift → FluidAudio | Swift Package Manager | ASR transcription, VAD, model management |
| Swift → Hardware | Carbon, Accessibility | System hotkeys, text insertion |
| FluidAudio → ANE | Apple Neural Engine | Parakeet TDT v3 inference (on-device) |

### Security & Privacy Architecture

**Privacy Guarantees**:
- 100% local processing via Apple Neural Engine (zero network calls post-setup)
- No audio data persisted to disk
- No transcribed text stored (only aggregated statistics)
- User settings encrypted at rest (Tauri Store)
- Models auto-downloaded by FluidAudio from HuggingFace (HTTPS only)

**Permission Boundaries**:
- Microphone: Required for audio capture via FluidAudio
- Accessibility: Required for text insertion
- Input Monitoring: Required for global hotkeys (macOS 10.15+)
- No network permission needed (except model downloads)
- No file system access beyond app sandbox

**Sandboxing**:
- Swift native code runs in same process (FFI) with clearly defined C ABI boundary
- Frontend (React) has no direct access to native APIs
- All cross-boundary communication validated
- FluidAudio SDK runs in-process for maximum performance

---

## Phase 3: Testing Strategy (TDD Implementation)

### Test Pyramid

```
        ┌─────────────────┐
        │   E2E Tests     │  Manual QA on fresh macOS
        │   (Manual)      │  Permission flows, full user stories
        └─────────────────┘
              ▲
              │
        ┌─────────────────┐
        │  Integration    │  Pre-authorized environment
        │  Tests (Cargo)  │  Swift bridge, Python bridge
        └─────────────────┘
              ▲
              │
    ┌───────────────────────┐
    │   Unit Tests          │  Mocked system APIs
    │   (Vitest + pytest +  │  100% business logic coverage
    │    Cargo + XCTest)    │  No permission dependencies
    └───────────────────────┘
```

### Test Coverage Requirements

| Layer | Tool | Minimum Coverage | Notes |
|-------|------|------------------|-------|
| Frontend (React/TS) | Vitest + React Testing Library | 80% | Components, hooks, services |
| Rust (Tauri core) | cargo test + mockall | 80% | Commands, Swift bridge, state |
| Swift (Native + FluidAudio) | XCTest + mocks | 75% | Hotkey, FluidAudio wrapper, text insertion |
| Integration | cargo test --ignored | Key flows | Hotkey → modal → transcribe → insert |
| E2E | Manual QA | User stories | All acceptance criteria from spec.md |

### TDD Workflow

**RED Phase** (Write failing test):
```typescript
// src/services/audio.service.test.ts
describe('AudioService', () => {
  it('should start recording when microphone permission granted', async () => {
    const mockIPC = createMockIPCService({ micPermission: true });
    const audioService = new AudioService(mockIPC);

    await audioService.startRecording();

    expect(mockIPC.startRecording).toHaveBeenCalled();
    expect(audioService.isRecording).toBe(true);
  });
});
```

**GREEN Phase** (Minimal implementation):
```typescript
// src/services/audio.service.ts
export class AudioService {
  private _isRecording = false;

  constructor(private ipc: IPCService) {}

  async startRecording(): Promise<void> {
    await this.ipc.startRecording();
    this._isRecording = true;
  }

  get isRecording(): boolean {
    return this._isRecording;
  }
}
```

**REFACTOR Phase** (Improve with error handling):
```typescript
export class AudioService {
  async startRecording(): Promise<void> {
    if (this._isRecording) {
      throw new Error('Recording already in progress');
    }

    try {
      await this.ipc.startRecording();
      this._isRecording = true;
    } catch (error) {
      if (error.code === 'PERMISSION_DENIED') {
        throw new PermissionError('Microphone permission not granted');
      }
      throw error;
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
- UI responsiveness: 60fps during transcription

**CI Pipeline**:
```yaml
# .github/workflows/ci.yml
- name: Run performance benchmarks
  run: |
    cargo bench --bench hotkey_latency
    cargo bench --bench transcription_e2e
    pytest ml-backend/tests/ --benchmark-only

- name: Compare against baseline
  run: |
    python scripts/compare-benchmarks.py \
      --current target/criterion/ \
      --baseline main \
      --threshold 10%  # Fail if >10% regression
```

---

## Implementation Roadmap

### Milestone 1: Core Infrastructure (P1 - User Story 1 & 2)
- [ ] Tauri app scaffold with React frontend
- [ ] Swift dylib build integration with Swift Package Manager
- [ ] FluidAudio SDK integration via SPM
- [ ] Basic IPC commands (start_recording, stop_recording, transcribe)
- [ ] Swift global hotkey registration (Carbon API)
- [ ] FluidAudio AsrManager wrapper (English only initially)
- [ ] Swift text insertion (Accessibility API)
- [ ] Onboarding flow with permission requests
- **Deliverable**: User can press hotkey, speak, and see text inserted

### Milestone 2: UI/UX Polish (P2 - User Story 3)
- [ ] Recording modal with frosted glass design
- [ ] Real-time waveform visualization (Web Audio API)
- [ ] Settings UI (hotkey, language, audio sensitivity)
- [ ] Menu bar integration with stats
- [ ] Error handling and user feedback
- **Deliverable**: Production-quality UI matching design spec

### Milestone 3: Multi-Language Support (P3 - User Story 4 & 5)
- [ ] Language selection UI
- [ ] FluidAudio model management (auto-download from HuggingFace)
- [ ] Language switching (AsrManager language parameter)
- [ ] Model download progress UI
- **Deliverable**: 25 European languages supported via FluidAudio

### Milestone 4: Testing & Quality (All Priorities)
- [ ] Unit tests for all layers (80% coverage)
- [ ] Integration tests (Swift bridge + FluidAudio)
- [ ] Performance benchmarks (automated CI)
- [ ] E2E test scenarios (manual QA checklist)
- [ ] Accessibility testing (VoiceOver, keyboard navigation)
- **Deliverable**: Production-ready quality

### Milestone 5: Distribution (Release)
- [ ] DMG installer with code signing
- [ ] App notarization (Apple)
- [ ] Auto-update mechanism (Tauri updater)
- [ ] Crash reporting (privacy-preserving)
- [ ] Analytics (opt-in, anonymous)
- **Deliverable**: Shippable macOS app

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Accessibility API reliability | High | Fallback to clipboard copy, extensive testing |
| FluidAudio model download failures | Low | FluidAudio handles downloads with built-in retry logic |
| Global hotkey conflicts | Medium | Conflict detection, alternative hotkey suggestions |
| Memory leaks in FluidAudio | Low | FluidAudio manages memory internally, monitor via instruments |
| FluidAudio SDK updates breaking changes | Medium | Pin to specific version, test upgrades in isolation |
| Permission denial by users | Medium | Clear explanations, graceful degradation, settings link |
| Swift/Rust FFI ABI mismatch | High | Strict C ABI only, comprehensive integration tests |

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

Run `/speckit.tasks` command to generate `tasks.md` with dependency-ordered implementation tasks.

**Note**: This plan stops at Phase 2 as per the `/speckit.plan` workflow. Implementation occurs in Phase 3 via the `/speckit.implement` command.
