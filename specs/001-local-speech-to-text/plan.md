# Implementation Plan: macOS Local Speech-to-Text Application

**Branch**: `001-local-speech-to-text` | **Date**: 2026-01-02 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-local-speech-to-text/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Build a privacy-first macOS speech-to-text application that runs 100% locally on Apple Silicon. The app uses a global hotkey to trigger an elegant recording modal, captures audio, transcribes locally using MLX-optimized models, and automatically inserts text into the active application. Technical stack: Tauri 2.0 + React + TypeScript frontend, Python + MLX + parakeet-tdt for ML inference, Swift for native macOS APIs (hotkeys, audio, accessibility).

## Technical Context

**Language/Version**:
- Frontend: TypeScript 5.7+ (strict mode), React 18+
- Backend/ML: Python 3.11+ with MLX framework
- Native: Swift 5.9+ for macOS APIs
- Build: Rust 1.75+ (Tauri framework)

**Primary Dependencies**:
- Tauri 2.0 (cross-platform app framework with Rust core)
- React 18+ with TypeScript (UI layer)
- MLX + parakeet-tdt-0.6b-v3 (Apple Silicon optimized ML inference)
- Swift: AVFoundation (audio capture), Carbon/Cocoa (global hotkeys), Accessibility APIs (text insertion)
- NEEDS CLARIFICATION: Audio preprocessing requirements (noise reduction, VAD)
- NEEDS CLARIFICATION: IPC protocol between Tauri/React and Python ML backend
- NEEDS CLARIFICATION: Swift bridge mechanism (FFI, XPC, or subprocess)

**Storage**:
- User settings: Local JSON/SQLite via Tauri Store plugin
- ML models: Local filesystem (~500MB per language model)
- Usage statistics: Local SQLite database
- No cloud storage or network calls

**Testing**:
- Frontend: Vitest + React Testing Library
- Python/ML: pytest with MLX test harness
- Swift: XCTest for native API integrations
- E2E: Tauri WebDriver for full application flow
- NEEDS CLARIFICATION: Performance benchmarking strategy for ML inference
- NEEDS CLARIFICATION: Testing approach for accessibility permissions and global hotkeys

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

This project diverges significantly from the web-centric TypeScript/Node.js constitution but the differences are justified by the desktop/ML nature:

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
| "Node.js 24+ runtime" | Uses Tauri (Rust) + Python runtime | Desktop apps require native performance and ML inference. Tauri provides secure native APIs, Python/MLX provides Apple Silicon ML optimization. Node.js cannot access macOS Accessibility APIs or run optimized ML. |
| "Web application structure" | Desktop application structure | macOS desktop app with native UI requirements (global hotkeys, menu bar, system permissions). Web architecture inappropriate for system-level integrations. |
| "All code in TypeScript" | Python for ML, Swift for native APIs | ML inference requires Python/MLX ecosystem. macOS APIs (AVFoundation, Accessibility) require Swift/Objective-C. TypeScript cannot fulfill these requirements. |
| "Single language stack" | Multi-language (TS/Rust/Python/Swift) | Each language serves essential purpose: TS for UI, Rust for security, Python for ML, Swift for macOS APIs. No single language can fulfill all requirements. |

**NO VIOLATIONS**:
- Security-first development: All secrets in env vars, input validation, no credential storage
- Test-driven development: TDD for all layers (frontend Vitest, Python pytest, Swift XCTest)
- Code quality: ESLint + Prettier for TS, Black + mypy for Python, SwiftLint for Swift
- Architecture patterns: Service layer for business logic, repository pattern for data access

**GATE STATUS**: ✅ PASS - Deviations are necessary and well-justified for desktop ML application. The constitution's TypeScript/web principles apply to frontend layer. Additional language ecosystems are required for platform capabilities not achievable in web stack.

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

**Structure Decision**: Tauri desktop application with multi-language architecture. Frontend (React/TS) communicates with Rust core via Tauri IPC. Rust core orchestrates Swift native APIs and Python ML backend. This structure separates concerns by technology boundaries while maintaining clear IPC contracts.

```text
src-tauri/                    # Rust backend (Tauri core)
├── src/
│   ├── main.rs              # Tauri app entry point
│   ├── commands.rs          # IPC command handlers
│   ├── swift_bridge.rs      # Swift interop via FFI/XPC
│   ├── python_bridge.rs     # Python ML backend interface
│   ├── models/              # Rust data types
│   └── lib/                 # Shared utilities
├── swift/                   # Swift native modules
│   ├── GlobalHotkey/        # Hotkey registration (Carbon API)
│   ├── AudioCapture/        # Microphone input (AVFoundation)
│   ├── TextInsertion/       # Accessibility API bridge
│   └── MenuBar/             # NSStatusItem integration
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

ml-backend/                  # Python ML inference service
├── src/
│   ├── server.py           # IPC/subprocess interface
│   ├── transcriber.py      # MLX model wrapper
│   ├── vad.py              # Voice activity detection
│   ├── audio_processor.py  # Preprocessing pipeline
│   └── model_manager.py    # Language model loading
├── models/                 # Downloaded parakeet models
│   └── .gitkeep
├── tests/
│   ├── test_transcriber.py
│   └── test_vad.py
├── pyproject.toml          # Poetry/pip dependencies
└── requirements.txt

tests/                      # Cross-layer integration tests
├── e2e/
│   ├── test_hotkey_flow.rs  # Full recording flow
│   ├── test_onboarding.rs   # Permission grants
│   └── test_settings.rs     # Configuration changes
└── integration/
    ├── test_swift_bridge.rs # Native API integration
    └── test_ml_bridge.rs    # Python ML integration

scripts/                    # Build and development tools
├── setup-dev.sh           # Development environment setup
├── build-swift.sh         # Swift module compilation
└── download-models.sh     # ML model fetcher
```

## Complexity Tracking

| Deviation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|--------------------------------------|
| Multi-language stack (TS/Rust/Python/Swift) | Each language provides irreplaceable capabilities: TS for modern UI, Rust for secure system integration, Python for MLX ML framework, Swift for macOS native APIs | Electron: Cannot access Accessibility APIs or global hotkeys. Pure Swift: No MLX support, poor web UI tooling. Python-only: Cannot build native macOS apps with system permissions. |
| Python ML backend subprocess | MLX framework only available in Python. Apple Silicon optimization requires Metal GPU access via MLX | Rust ML: No equivalent to MLX for Apple Silicon. WASM ML: Insufficient performance, no Metal acceleration. Server-based: Violates privacy requirement for 100% local processing. |
| Swift native bridge | macOS Accessibility API, global hotkey registration (Carbon), menu bar integration require Objective-C/Swift runtime | Rust only: Cannot access Accessibility framework or Carbon API. JavaScript bridge: Performance penalty, security risk for system APIs. |

---

## Phase 0: Research & Discovery

**Status**: ✅ COMPLETE

All "NEEDS CLARIFICATION" items from Technical Context have been resolved. See [research.md](./research.md) for detailed findings.

**Key Decisions**:
1. Audio preprocessing: Hybrid VAD with MLX-accelerated silence detection
2. IPC architecture: Subprocess with JSON-RPC over stdin/stdout
3. Swift bridge: Dynamic library via FFI with C ABI
4. Performance benchmarking: Multi-tier with automated regression detection
5. Permission testing: Mocked unit tests + pre-authorized integration tests
6. Tauri + React: Typed IPC commands + React Context for state
7. MLX integration: Model loaded at startup, Metal GPU inference
8. macOS permissions: Incremental onboarding with explanations

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
   - 16 command definitions with request/response schemas
   - 4 event emissions for real-time updates
   - Error handling patterns and codes
   - TypeScript type generation strategy

3. **contracts/python-jsonrpc.md**: Python ML backend protocol
   - JSON-RPC 2.0 over stdin/stdout
   - 7 method definitions (transcribe, load_model, etc.)
   - 3 notification types (progress, logs)
   - Error codes and implementation patterns

4. **quickstart.md**: Developer onboarding guide
   - System requirements and dependencies
   - Step-by-step environment setup
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
│  • Python ML backend manager (JSON-RPC subprocess)          │
└──────┬────────────────────────────────────────────┬─────────┘
       │                                            │
       │ Swift FFI (C ABI)                          │ JSON-RPC
       │                                            │ (stdin/stdout)
┌──────▼─────────────────────┐            ┌────────▼─────────────────┐
│   Swift Native Modules     │            │  Python ML Backend       │
│  • GlobalHotkey (Carbon)   │            │  • MLX transcription     │
│  • AudioCapture            │            │  • Model management      │
│    (AVFoundation)          │            │  • Voice activity        │
│  • TextInsertion           │            │    detection             │
│    (Accessibility API)     │            │  • Audio preprocessing   │
│  • MenuBar (NSStatusItem)  │            │                          │
└────────────────────────────┘            └──────────────────────────┘
```

### Data Flow: User Dictation

```
1. User presses ⌘⌃Space
   ↓
2. Swift detects hotkey → emits event to Rust
   ↓
3. Rust emits 'hotkey-pressed' → React shows modal
   ↓
4. React calls invoke('start_recording')
   ↓
5. Rust calls Swift AudioCapture → starts AVAudioEngine
   ↓
6. Audio chunks (100ms) → Swift → Rust → buffered
   ↓
7. Audio levels → React (30fps) for waveform
   ↓
8. Silence detected (1.5s) → auto-stop
   ↓
9. Rust sends audio to Python via JSON-RPC
   ↓
10. Python MLX transcribes → returns text + confidence
    ↓
11. Rust calls Swift TextInsertion → Accessibility API
    ↓
12. Text inserted at cursor → modal closes
    ↓
13. Statistics updated → SQLite
```

### Technology Integration Points

| Integration | Mechanism | Purpose |
|-------------|-----------|---------|
| React ↔ Rust | Tauri IPC commands | UI state management, trigger actions |
| Rust ↔ Swift | FFI with C ABI (dylib) | Native macOS APIs (hotkey, audio, text) |
| Rust ↔ Python | JSON-RPC subprocess | ML inference, model management |
| Swift → Hardware | AVFoundation, Carbon | Microphone capture, system hotkeys |
| Python → GPU | MLX framework | Apple Silicon Metal acceleration |

### Security & Privacy Architecture

**Privacy Guarantees**:
- 100% local processing (zero network calls post-setup)
- No audio data persisted to disk
- No transcribed text stored (only statistics)
- User settings encrypted at rest (Tauri Store)
- Models downloaded from trusted source (HTTPS + checksum)

**Permission Boundaries**:
- Microphone: Required for audio capture
- Accessibility: Required for text insertion
- Input Monitoring: Required for global hotkeys (macOS 10.15+)
- No network permission needed
- No file system access beyond app sandbox

**Sandboxing**:
- Python subprocess isolated from Rust process
- Swift native code runs in same process (FFI) but with clearly defined C ABI boundary
- Frontend (React) has no direct access to native APIs
- All cross-boundary communication validated

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
| Rust (Tauri core) | cargo test + mockall | 80% | Commands, bridges, state |
| Python (ML backend) | pytest + pytest-mock | 80% | Transcriber, VAD, model mgr |
| Swift (Native APIs) | XCTest + mocks | 70% | Hotkey, audio, text insertion |
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
- [ ] Swift dylib build integration (build.rs)
- [ ] Python ML backend subprocess manager
- [ ] Basic IPC commands (start_recording, stop_recording)
- [ ] Swift global hotkey registration
- [ ] Swift audio capture (AVAudioEngine)
- [ ] Python MLX transcriber (English only)
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
- [ ] Model download manager with progress
- [ ] Python model manager (load/unload models)
- [ ] Language switching (reload model)
- [ ] Model integrity verification (checksum)
- **Deliverable**: 25 languages supported

### Milestone 4: Testing & Quality (All Priorities)
- [ ] Unit tests for all layers (80% coverage)
- [ ] Integration tests (Swift bridge, Python bridge)
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
| MLX model download failures | Medium | Resume capability, checksum verification, retry logic |
| Global hotkey conflicts | Medium | Conflict detection, alternative hotkey suggestions |
| Memory leaks in audio capture | High | Circular buffer, automated memory profiling in CI |
| Python subprocess crashes | High | Automatic restart, health checks (ping), error logging |
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
