# Tasks: macOS Local Speech-to-Text Application

**Feature**: 001-local-speech-to-text
**Input**: Design documents from `/specs/001-local-speech-to-text/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

**TDD Approach**: Following RED-GREEN-REFACTOR methodology - tests are written first, implementation follows.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4, US5)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and multi-language architecture setup

- [ ] T001 Create Tauri project structure with React frontend using `bun create tauri-app`
- [ ] T002 Initialize Bun workspace in /src with TypeScript 5.7+ and React 18+ dependencies
- [ ] T003 [P] Initialize Python virtual environment and install MLX + dependencies in /ml-backend
- [ ] T004 [P] Create Swift module structure in /src-tauri/swift/ with subdirectories (GlobalHotkey/, AudioCapture/, TextInsertion/, MenuBar/)
- [ ] T005 [P] Configure ESLint 9 + Prettier 3 for TypeScript in /src
- [ ] T006 [P] Configure Black + mypy for Python in /ml-backend
- [ ] T007 [P] Configure SwiftLint for Swift in /src-tauri/swift
- [ ] T008 Create build.rs integration for Swift compilation in /src-tauri/build.rs
- [ ] T009 [P] Setup Vitest test framework in /src with React Testing Library
- [ ] T010 [P] Setup pytest + pytest-benchmark in /ml-backend/tests
- [ ] T011 [P] Setup XCTest framework for Swift in /src-tauri/swift/Tests
- [ ] T012 Create pre-commit hooks configuration in /.pre-commit-config.yaml
- [ ] T013 Configure GitHub Actions CI workflow in /.github/workflows/ci.yml
- [ ] T014 Create development environment setup script in /scripts/setup-dev.sh
- [ ] T015 [P] Create Swift library build script in /scripts/build-swift.sh
- [ ] T016 [P] Create model download script in /scripts/download-models.sh

**Checkpoint**: Development environment fully configured, all toolchains verified

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Rust/Tauri Core Infrastructure

- [ ] T017 Define Rust data types for RecordingSession in /src-tauri/src/models/recording.rs
- [ ] T018 [P] Define Rust data types for UserSettings in /src-tauri/src/models/settings.rs
- [ ] T019 [P] Define Rust data types for LanguageModel in /src-tauri/src/models/language.rs
- [ ] T020 [P] Define Rust data types for UsageStatistics in /src-tauri/src/models/statistics.rs
- [ ] T021 Create AppState struct with Arc<Mutex<>> for shared state in /src-tauri/src/main.rs
- [ ] T022 Implement settings persistence using Tauri Store plugin in /src-tauri/src/lib/settings_store.rs
- [ ] T023 [P] Setup SQLite database for usage statistics in /src-tauri/src/lib/statistics_db.rs

### Swift Bridge Foundation

- [ ] T024 Define C ABI interface header in /src-tauri/swift/bridge.h
- [ ] T025 Implement Swift FFI wrapper for dylib loading in /src-tauri/src/swift_bridge.rs using libloading
- [ ] T026 Create Swift PermissionManager for checking macOS permissions in /src-tauri/swift/Permissions/PermissionManager.swift
- [ ] T027 Implement Swift FFI callbacks for event emissions in /src-tauri/swift/bridge.swift

### Python ML Backend Foundation

- [ ] T028 Implement JSON-RPC server infrastructure in /ml-backend/src/server.py
- [ ] T029 [P] Create ModelManager for loading/unloading ML models in /ml-backend/src/model_manager.py
- [ ] T030 [P] Implement AudioProcessor for mel-spectrogram extraction in /ml-backend/src/audio_processor.py
- [ ] T031 Implement Python subprocess manager in /src-tauri/src/python_bridge.rs
- [ ] T032 Create Python model download utility in /ml-backend/src/download_model.py

### Frontend Foundation

- [ ] T033 Setup React Context for RecordingContext in /src/contexts/RecordingContext.tsx
- [ ] T034 [P] Setup React Context for SettingsContext in /src/contexts/SettingsContext.tsx
- [ ] T035 [P] Create IPCService wrapper for Tauri commands in /src/services/ipc.service.ts
- [ ] T036 [P] Define TypeScript types matching Rust structs in /src/types/tauri-commands.ts
- [ ] T037 Create Warm Minimalism design system with CSS variables in /src/styles/design-system.css
- [ ] T038 [P] Create base error handling utilities in /src/lib/errors.ts

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Quick Speech-to-Text Capture (Priority: P1) 🎯 MVP

**Goal**: User can press global hotkey, speak, and have text automatically inserted into active application

**Independent Test**: Launch app, press ⌘⌃Space in TextEdit, speak "Hello world", verify text appears at cursor position

### TDD: Write Tests FIRST (RED Phase) ⚠️

- [ ] T039 [P] [US1] Write failing unit test for RecordingSession state machine in /src-tauri/src/models/recording.rs
- [ ] T040 [P] [US1] Write failing unit test for Swift hotkey registration mock in /src-tauri/swift/Tests/GlobalHotkeyTests.swift
- [ ] T041 [P] [US1] Write failing unit test for AudioCapture initialization in /src-tauri/swift/Tests/AudioCaptureTests.swift
- [ ] T042 [P] [US1] Write failing integration test for Python transcriber in /ml-backend/tests/test_transcriber.py
- [ ] T043 [P] [US1] Write failing unit test for Swift text insertion mock in /src-tauri/swift/Tests/TextInsertionTests.swift
- [ ] T044 [US1] Write failing E2E test for hotkey → transcribe → insert flow in /tests/e2e/test_hotkey_flow.rs

### Implementation: Swift Native APIs (GREEN Phase)

- [ ] T045 [P] [US1] Implement GlobalHotkey registration using Carbon API in /src-tauri/swift/GlobalHotkey/hotkey.swift
- [ ] T046 [P] [US1] Implement AudioCapture using AVAudioEngine in /src-tauri/swift/AudioCapture/audio.swift
- [ ] T047 [P] [US1] Implement TextInsertion using Accessibility API in /src-tauri/swift/TextInsertion/accessibility.swift
- [ ] T048 [US1] Compile Swift modules into libswift_native.dylib via build.rs
- [ ] T049 [US1] Test Swift FFI integration from Rust (verify T045, T046, T047 pass)

### Implementation: Python ML Transcription (GREEN Phase)

- [ ] T050 [US1] Implement Transcriber class with MLX model loading in /ml-backend/src/transcriber.py
- [ ] T051 [US1] Implement VAD (voice activity detection) in /ml-backend/src/vad.py
- [ ] T052 [US1] Download English language model using download_model.py script
- [ ] T053 [US1] Implement transcribe JSON-RPC method in /ml-backend/src/server.py
- [ ] T054 [US1] Test Python ML backend standalone (verify T042 passes)

### Implementation: Rust Tauri Commands (GREEN Phase)

- [ ] T055 [US1] Implement register_hotkey command in /src-tauri/src/commands.rs
- [ ] T056 [US1] Implement start_recording command with Swift audio bridge in /src-tauri/src/commands.rs
- [ ] T057 [US1] Implement stop_recording command with Python transcription in /src-tauri/src/commands.rs
- [ ] T058 [US1] Implement insert_text command with Swift Accessibility bridge in /src-tauri/src/commands.rs
- [ ] T059 [US1] Implement audio-level event emission (30fps) in /src-tauri/src/commands.rs
- [ ] T060 [US1] Implement hotkey-pressed event emission in /src-tauri/src/commands.rs
- [ ] T061 [US1] Test Rust command handlers with mocks (verify T039 passes)

### Implementation: React Frontend (GREEN Phase)

- [ ] T062 [P] [US1] Create RecordingModal component with frosted glass UI in /src/components/RecordingModal/RecordingModal.tsx
- [ ] T063 [P] [US1] Create Waveform visualization component using Web Audio API in /src/components/Waveform/Waveform.tsx
- [ ] T064 [US1] Implement useRecording hook with IPC service calls in /src/hooks/useRecording.ts
- [ ] T065 [US1] Implement useAudioLevel hook for event subscription in /src/hooks/useAudioLevel.ts
- [ ] T066 [US1] Wire hotkey-pressed event to show RecordingModal in /src/App.tsx
- [ ] T067 [US1] Add Escape key handler to cancel recording in /src/components/RecordingModal/RecordingModal.tsx
- [ ] T068 [US1] Test React components with Vitest + React Testing Library

### Refactor & Polish (REFACTOR Phase)

- [ ] T069 [US1] Add error handling for microphone permission denial in /src-tauri/src/commands.rs
- [ ] T070 [US1] Add error handling for accessibility permission denial in /src-tauri/src/commands.rs
- [ ] T071 [US1] Add confidence threshold validation in /ml-backend/src/transcriber.py
- [ ] T072 [US1] Optimize Swift audio buffer circular buffer pattern in /src-tauri/swift/AudioCapture/audio.swift
- [ ] T073 [US1] Add logging for transcription latency metrics in /src-tauri/src/commands.rs
- [ ] T074 [US1] Refactor RecordingSession state machine for clarity in /src-tauri/src/models/recording.rs

### Validation & Performance

- [ ] T075 [US1] Verify hotkey response <50ms using criterion benchmark in /src-tauri/benches/hotkey_latency.rs
- [ ] T076 [US1] Verify transcription latency <100ms using pytest-benchmark in /ml-backend/tests/test_transcriber_perf.py
- [ ] T077 [US1] Verify waveform rendering at 30fps using browser performance profiler
- [ ] T078 [US1] Verify idle RAM usage <200MB and active <500MB
- [ ] T079 [US1] Run E2E test (verify T044 passes)

**Checkpoint**: User Story 1 (MVP) is fully functional - user can dictate text via hotkey

---

## Phase 4: User Story 2 - First-Time Setup and Onboarding (Priority: P1)

**Goal**: New users can grant permissions and complete onboarding within 2 minutes

**Independent Test**: Install app on fresh macOS VM, complete onboarding flow, grant all permissions, verify "Try it now" demo works

### TDD: Write Tests FIRST (RED Phase) ⚠️

- [ ] T080 [P] [US2] Write failing unit test for permission status checks in /src-tauri/src/commands.rs
- [ ] T081 [P] [US2] Write failing unit test for onboarding state machine in /src/contexts/OnboardingContext.tsx
- [ ] T082 [US2] Write failing E2E test for onboarding flow in /tests/e2e/test_onboarding.rs

### Implementation: Permission Management (GREEN Phase)

- [ ] T083 [US2] Implement check_permission command for microphone in /src-tauri/src/commands.rs
- [ ] T084 [US2] Implement check_permission command for accessibility in /src-tauri/src/commands.rs
- [ ] T085 [US2] Implement request_permission command with System Settings links in /src-tauri/src/commands.rs
- [ ] T086 [US2] Add permission polling for accessibility grants in /src-tauri/src/swift_bridge.rs
- [ ] T087 [US2] Test permission commands with mocks (verify T080 passes)

### Implementation: Onboarding UI (GREEN Phase)

- [ ] T088 [P] [US2] Create OnboardingModal container component in /src/components/Onboarding/OnboardingModal.tsx
- [ ] T089 [P] [US2] Create PermissionStep component with explanations in /src/components/Onboarding/PermissionStep.tsx
- [ ] T090 [P] [US2] Create WelcomeStep component with privacy messaging in /src/components/Onboarding/WelcomeStep.tsx
- [ ] T091 [P] [US2] Create DemoStep component for "Try it now" in /src/components/Onboarding/DemoStep.tsx
- [ ] T092 [US2] Implement OnboardingContext for state management in /src/contexts/OnboardingContext.tsx
- [ ] T093 [US2] Add onboarding completion persistence to UserSettings in /src-tauri/src/lib/settings_store.rs
- [ ] T094 [US2] Show OnboardingModal on first app launch in /src/App.tsx
- [ ] T095 [US2] Test onboarding components with Vitest (verify T081 passes)

### Implementation: Info.plist Configuration (GREEN Phase)

- [ ] T096 [US2] Add NSMicrophoneUsageDescription to Info.plist in /src-tauri/Info.plist
- [ ] T097 [US2] Add NSAppleEventsUsageDescription to Info.plist in /src-tauri/Info.plist

### Refactor & Polish (REFACTOR Phase)

- [ ] T098 [US2] Add accessibility permission polling timeout (30 seconds) in /src-tauri/src/swift_bridge.rs
- [ ] T099 [US2] Add clear error messaging for permission denials in /src/components/Onboarding/PermissionStep.tsx
- [ ] T100 [US2] Add skip option for optional input monitoring permission in /src/components/Onboarding/PermissionStep.tsx
- [ ] T101 [US2] Add progress indicator for onboarding steps in /src/components/Onboarding/OnboardingModal.tsx

### Validation

- [ ] T102 [US2] Verify onboarding completes in <2 minutes on fresh system
- [ ] T103 [US2] Verify 90% permission grant success rate (manual testing)
- [ ] T104 [US2] Run E2E onboarding test (verify T082 passes)

**Checkpoint**: User Story 2 complete - onboarding flow is seamless and informative

---

## Phase 5: User Story 3 - Menu Bar Quick Access and Stats (Priority: P2)

**Goal**: Users can access app via menu bar icon with quick stats and manual recording trigger

**Independent Test**: Click menu bar icon, verify dropdown shows word count, click "Start Recording", verify modal appears

### TDD: Write Tests FIRST (RED Phase) ⚠️

- [ ] T105 [P] [US3] Write failing unit test for statistics aggregation in /src-tauri/src/models/statistics.rs
- [ ] T106 [P] [US3] Write failing unit test for menu bar integration in /src-tauri/swift/Tests/MenuBarTests.swift
- [ ] T107 [US3] Write failing integration test for statistics persistence in /tests/integration/test_stats_db.rs

### Implementation: Statistics Backend (GREEN Phase)

- [ ] T108 [US3] Implement SQLite schema for daily_stats table in /src-tauri/src/lib/statistics_db.rs
- [ ] T109 [US3] Implement update_statistics method after successful transcription in /src-tauri/src/commands.rs
- [ ] T110 [US3] Implement get_statistics command with period filtering in /src-tauri/src/commands.rs
- [ ] T111 [US3] Implement clear_statistics command in /src-tauri/src/commands.rs
- [ ] T112 [US3] Implement data retention cleanup job in /src-tauri/src/lib/statistics_db.rs
- [ ] T113 [US3] Test statistics persistence (verify T105, T107 pass)

### Implementation: Swift Menu Bar (GREEN Phase)

- [ ] T114 [US3] Implement NSStatusItem creation in /src-tauri/swift/MenuBar/menu.swift
- [ ] T115 [US3] Implement menu dropdown with actions in /src-tauri/swift/MenuBar/menu.swift
- [ ] T116 [US3] Add Swift FFI methods for menu bar updates in /src-tauri/swift/bridge.swift
- [ ] T117 [US3] Test menu bar integration (verify T106 passes)

### Implementation: Rust Menu Bar Commands (GREEN Phase)

- [ ] T118 [US3] Implement show_menu_bar command in /src-tauri/src/commands.rs
- [ ] T119 [US3] Implement update_menu_stats command in /src-tauri/src/commands.rs
- [ ] T120 [US3] Wire menu actions to Tauri event emissions in /src-tauri/src/commands.rs

### Implementation: Frontend Menu Integration (GREEN Phase)

- [ ] T121 [P] [US3] Create MenuBar component placeholder in /src/components/MenuBar/MenuBar.tsx
- [ ] T122 [US3] Subscribe to menu-action events in /src/App.tsx
- [ ] T123 [US3] Update menu bar stats after each transcription in /src/contexts/RecordingContext.tsx

### Refactor & Polish (REFACTOR Phase)

- [ ] T124 [US3] Add menu bar icon variations (idle vs recording) in /src-tauri/swift/MenuBar/menu.swift
- [ ] T125 [US3] Add tooltips for menu items in /src-tauri/swift/MenuBar/menu.swift
- [ ] T126 [US3] Format statistics display (e.g., "1.2k words") in /src-tauri/src/models/statistics.rs

### Validation

- [ ] T127 [US3] Verify menu bar appears on all displays in multi-monitor setup
- [ ] T128 [US3] Verify statistics update in real-time after transcription
- [ ] T129 [US3] Verify data retention policy works (auto-delete old stats)

**Checkpoint**: User Story 3 complete - menu bar provides quick access and insights

---

## Phase 6: User Story 4 - Customizable Settings (Priority: P2)

**Goal**: Users can customize hotkey, language, audio sensitivity, and behavior

**Independent Test**: Open settings, change hotkey to ⌘⌥S, select Spanish, test that new hotkey works and Spanish transcription is accurate

### TDD: Write Tests FIRST (RED Phase) ⚠️

- [ ] T130 [P] [US4] Write failing unit test for settings validation in /src-tauri/src/models/settings.rs
- [ ] T131 [P] [US4] Write failing unit test for hotkey conflict detection in /src-tauri/src/swift_bridge.rs
- [ ] T132 [US4] Write failing integration test for settings persistence in /tests/integration/test_settings.rs

### Implementation: Settings UI (GREEN Phase)

- [ ] T133 [P] [US4] Create Settings window/modal component in /src/components/Settings/SettingsModal.tsx
- [ ] T134 [P] [US4] Create HotkeyPicker component with conflict detection in /src/components/Settings/HotkeyPicker.tsx
- [ ] T135 [P] [US4] Create LanguageSelector component with download status in /src/components/Settings/LanguageSelector.tsx
- [ ] T136 [P] [US4] Create AudioSensitivitySlider with live preview in /src/components/Settings/AudioSensitivitySlider.tsx
- [ ] T137 [P] [US4] Create PrivacySettings toggle for stats collection in /src/components/Settings/PrivacySettings.tsx
- [ ] T138 [US4] Wire settings form to update_settings command in /src/contexts/SettingsContext.tsx

### Implementation: Settings Backend (GREEN Phase)

- [ ] T139 [US4] Implement get_settings command in /src-tauri/src/commands.rs
- [ ] T140 [US4] Implement update_settings command with validation in /src-tauri/src/commands.rs
- [ ] T141 [US4] Implement hotkey conflict detection in /src-tauri/src/swift_bridge.rs
- [ ] T142 [US4] Add settings change event emission in /src-tauri/src/commands.rs
- [ ] T143 [US4] Test settings persistence and validation (verify T130, T132 pass)

### Implementation: Dynamic Hotkey Registration (GREEN Phase)

- [ ] T144 [US4] Implement unregister_hotkey command in /src-tauri/src/commands.rs
- [ ] T145 [US4] Re-register hotkey on settings update in /src-tauri/src/commands.rs
- [ ] T146 [US4] Test hotkey conflict detection (verify T131 passes)

### Refactor & Polish (REFACTOR Phase)

- [ ] T147 [US4] Add settings export/import functionality in /src-tauri/src/commands.rs
- [ ] T148 [US4] Add settings reset to defaults option in /src/components/Settings/SettingsModal.tsx
- [ ] T149 [US4] Add visual feedback for settings save success in /src/components/Settings/SettingsModal.tsx
- [ ] T150 [US4] Validate all settings constraints per data-model.md in /src-tauri/src/models/settings.rs

### Validation

- [ ] T151 [US4] Verify hotkey conflicts are detected accurately
- [ ] T152 [US4] Verify settings persist across app restarts
- [ ] T153 [US4] Verify audio sensitivity affects silence detection threshold

**Checkpoint**: User Story 4 complete - app is fully customizable to user preferences

---

## Phase 7: User Story 5 - Multi-Language Support (Priority: P3)

**Goal**: Users can dictate in 25 different languages with easy switching

**Independent Test**: Switch language from English to French in settings, dictate "Bonjour le monde", verify French text is inserted correctly

### TDD: Write Tests FIRST (RED Phase) ⚠️

- [ ] T154 [P] [US5] Write failing unit test for model manager load/unload in /ml-backend/tests/test_model_manager.py
- [ ] T155 [P] [US5] Write failing integration test for language switching in /tests/integration/test_ml_bridge.rs
- [ ] T156 [US5] Write failing unit test for download progress tracking in /src-tauri/src/models/language.rs

### Implementation: Model Management Backend (GREEN Phase)

- [ ] T157 [US5] Implement load_model JSON-RPC method in /ml-backend/src/server.py
- [ ] T158 [US5] Implement unload_model JSON-RPC method in /ml-backend/src/server.py
- [ ] T159 [US5] Implement get_loaded_models JSON-RPC method in /ml-backend/src/server.py
- [ ] T160 [US5] Add model caching for faster language switching in /ml-backend/src/model_manager.py
- [ ] T161 [US5] Test model manager (verify T154 passes)

### Implementation: Model Download (GREEN Phase)

- [ ] T162 [US5] Implement list_language_models command in /src-tauri/src/commands.rs
- [ ] T163 [US5] Implement download_language_model command with progress in /src-tauri/src/commands.rs
- [ ] T164 [US5] Implement delete_language_model command in /src-tauri/src/commands.rs
- [ ] T165 [US5] Add checksum verification for downloaded models in /src-tauri/src/commands.rs
- [ ] T166 [US5] Emit download-progress events during model download in /src-tauri/src/commands.rs
- [ ] T167 [US5] Test language model download and verification (verify T156 passes)

### Implementation: Language Switching UI (GREEN Phase)

- [ ] T168 [P] [US5] Create LanguageModelList component showing 25 languages in /src/components/Settings/LanguageModelList.tsx
- [ ] T169 [P] [US5] Create ModelDownloadProgress component in /src/components/Settings/ModelDownloadProgress.tsx
- [ ] T170 [US5] Add language quick-switch in menu bar dropdown in /src/components/MenuBar/MenuBar.tsx
- [ ] T171 [US5] Subscribe to download-progress events in /src/contexts/SettingsContext.tsx

### Implementation: Auto Language Detection (GREEN Phase)

- [ ] T172 [US5] Implement basic language detection heuristic in /ml-backend/src/transcriber.py
- [ ] T173 [US5] Add language detection toggle to settings in /src/components/Settings/LanguageSelector.tsx

### Refactor & Polish (REFACTOR Phase)

- [ ] T174 [US5] Add resume capability for interrupted downloads in /src-tauri/src/commands.rs
- [ ] T175 [US5] Add download queue management (max 1 concurrent) in /src-tauri/src/commands.rs
- [ ] T176 [US5] Optimize model loading for <2 second switch time in /ml-backend/src/model_manager.py
- [ ] T177 [US5] Test language switching integration (verify T155 passes)

### Validation

- [ ] T178 [US5] Verify all 25 languages can be downloaded successfully
- [ ] T179 [US5] Verify language switch completes in <2 seconds
- [ ] T180 [US5] Verify transcription accuracy >95% for English (WER benchmark)
- [ ] T181 [US5] Test multi-language workflow (download Spanish, switch, transcribe, verify)

**Checkpoint**: User Story 5 complete - app supports 25 languages with easy switching

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories and production readiness

### Performance Optimization

- [ ] T182 [P] Run automated performance benchmarks in CI (hotkey latency, transcription speed)
- [ ] T183 [P] Profile memory usage with Instruments and optimize circular buffers
- [ ] T184 [P] Optimize waveform rendering to maintain 60fps during recording
- [ ] T185 [P] Add MLX GPU utilization monitoring in Python backend

### Error Handling & Resilience

- [ ] T186 [P] Implement automatic Python subprocess restart on crash in /src-tauri/src/python_bridge.rs
- [ ] T187 [P] Add health check pings to Python backend (5s interval) in /src-tauri/src/python_bridge.rs
- [ ] T188 [P] Implement graceful degradation when no text field focused (clipboard fallback) in /src-tauri/src/commands.rs
- [ ] T189 [P] Add retry logic for model download failures in /src-tauri/src/commands.rs

### Security & Privacy

- [ ] T190 [P] Ensure no audio data persists to disk in /src-tauri/src/commands.rs
- [ ] T191 [P] Ensure no transcribed text stored (only statistics) in /src-tauri/src/lib/statistics_db.rs
- [ ] T192 [P] Implement settings encryption at rest using Tauri Store in /src-tauri/src/lib/settings_store.rs
- [ ] T193 [P] Verify zero network calls during operation (except model downloads) with network profiler

### Accessibility

- [ ] T194 [P] Add VoiceOver support for all UI components in /src/components
- [ ] T195 [P] Add keyboard navigation for settings and onboarding in /src/components
- [ ] T196 [P] Ensure all interactive elements have ARIA labels in /src/components

### Documentation

- [ ] T197 [P] Create user documentation in /docs/user-guide.md
- [ ] T198 [P] Create API documentation for Tauri commands in /docs/api.md
- [ ] T199 [P] Update README.md with build instructions and screenshots

### Distribution

- [ ] T200 Create DMG installer with code signing configuration in /src-tauri/tauri.conf.json
- [ ] T201 Setup Apple notarization workflow in /.github/workflows/release.yml
- [ ] T202 Implement Tauri auto-updater for future releases in /src-tauri/src/main.rs
- [ ] T203 Add crash reporting with privacy-preserving telemetry in /src-tauri/src/lib/crash_reporter.rs

### Final Validation

- [ ] T204 Run full test suite (unit + integration + E2E) across all platforms
- [ ] T205 Verify all success criteria from spec.md are met
- [ ] T206 Perform manual QA following quickstart.md on fresh macOS system
- [ ] T207 Benchmark performance against targets (hotkey <50ms, transcription <100ms, etc.)
- [ ] T208 Security audit: verify no data leaks, no network calls, encrypted settings

**Checkpoint**: Application is production-ready for release

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational - Core MVP functionality
- **User Story 2 (Phase 4)**: Depends on Foundational - Can run parallel to US1 if staffed
- **User Story 3 (Phase 5)**: Depends on US1 (statistics require transcription working)
- **User Story 4 (Phase 6)**: Depends on Foundational - Can run parallel to US1/US2 if staffed
- **User Story 5 (Phase 7)**: Depends on US1 (language switching requires transcription working)
- **Polish (Phase 8)**: Depends on all desired user stories being complete

### User Story Dependencies

- **US1 (P1)**: Can start after Foundational - No dependencies on other stories
- **US2 (P1)**: Can start after Foundational - Independent, can run parallel to US1
- **US3 (P2)**: Depends on US1 transcription for statistics - Sequential after US1
- **US4 (P2)**: Can start after Foundational - Independent, can run parallel to US1/US2
- **US5 (P3)**: Depends on US1 transcription working - Sequential after US1

### Within Each User Story (TDD Flow)

1. Write tests FIRST (RED phase) - ensure they FAIL
2. Implement Swift/Python/Rust backend (GREEN phase)
3. Implement React frontend (GREEN phase)
4. Refactor and add error handling (REFACTOR phase)
5. Verify all tests PASS
6. Verify performance benchmarks meet targets

### Parallel Opportunities

- All Setup tasks marked [P] can run in parallel
- All Foundational tasks marked [P] can run in parallel (within Phase 2)
- Once Foundational phase completes:
  - US1 + US2 + US4 can start in parallel (if team capacity allows)
  - US3 must wait for US1 completion
  - US5 must wait for US1 completion
- Within each user story, tasks marked [P] can run in parallel
- Swift/Python/Rust backend work can proceed in parallel with React frontend work

---

## Parallel Example: User Story 1

```bash
# RED Phase - Write all tests together:
Task T039: "Write failing unit test for RecordingSession state machine"
Task T040: "Write failing unit test for Swift hotkey registration mock"
Task T041: "Write failing unit test for AudioCapture initialization"
Task T042: "Write failing integration test for Python transcriber"
Task T043: "Write failing unit test for Swift text insertion mock"

# GREEN Phase - Implement Swift modules together:
Task T045: "Implement GlobalHotkey registration using Carbon API"
Task T046: "Implement AudioCapture using AVAudioEngine"
Task T047: "Implement TextInsertion using Accessibility API"

# GREEN Phase - Implement frontend components together:
Task T062: "Create RecordingModal component with frosted glass UI"
Task T063: "Create Waveform visualization component"
```

---

## Implementation Strategy

### MVP First (User Stories 1 + 2 Only)

1. Complete Phase 1: Setup (T001-T016)
2. Complete Phase 2: Foundational (T017-T038) - CRITICAL
3. Complete Phase 3: User Story 1 (T039-T079) - Core dictation
4. Complete Phase 4: User Story 2 (T080-T104) - Onboarding
5. **STOP and VALIDATE**: Test both stories independently
6. Build DMG and deploy/demo if ready

**This MVP delivers**:
- Working speech-to-text via hotkey
- Professional onboarding experience
- Ready for beta testing with English-only users

### Incremental Delivery

1. **Foundation** (Phase 1-2) → Codebase ready
2. **MVP** (Phase 3-4) → Test independently → Beta release
3. **Enhanced** (Phase 5) → Add menu bar → Update release
4. **Customizable** (Phase 6) → Add settings → Update release
5. **Multi-language** (Phase 7) → Add 25 languages → Update release
6. **Production** (Phase 8) → Polish and ship → 1.0 release

Each increment adds value without breaking previous functionality.

### Parallel Team Strategy

With 3 developers after Foundational phase completes:

- **Developer A**: User Story 1 (T039-T079) - Core dictation
- **Developer B**: User Story 2 (T080-T104) - Onboarding
- **Developer C**: User Story 4 (T130-T153) - Settings (can start in parallel)

Then sequentially:
- **Team**: User Story 3 (T105-T129) - requires US1 complete
- **Team**: User Story 5 (T154-T181) - requires US1 complete
- **Team**: Polish (T182-T208)

---

## Testing Strategy (TDD Workflow)

### Red-Green-Refactor Cycle

For each user story:

1. **RED**: Write all failing tests first (T039-T044 for US1)
   - Unit tests for each layer (Swift, Rust, Python, React)
   - Integration tests for cross-boundary communication
   - E2E test for complete user journey
   - Run tests → Verify they FAIL

2. **GREEN**: Implement minimal code to pass tests (T045-T068 for US1)
   - Start with backend (Swift/Python/Rust)
   - Then frontend (React)
   - Run tests after each implementation → Verify they PASS

3. **REFACTOR**: Improve code quality (T069-T074 for US1)
   - Add error handling
   - Optimize performance
   - Improve readability
   - Run tests → Verify they still PASS

### Test Coverage Requirements

- Frontend (React/TS): 80% coverage via Vitest
- Rust (Tauri core): 80% coverage via cargo test
- Python (ML backend): 80% coverage via pytest
- Swift (Native APIs): 70% coverage via XCTest
- Integration: All critical paths tested
- E2E: All user stories validated

### Performance Benchmarks (Automated CI)

- Hotkey response: <50ms (criterion benchmark)
- Transcription latency: <100ms (pytest-benchmark)
- Waveform FPS: ≥30fps (browser profiler)
- Idle RAM: <200MB (macOS Activity Monitor)
- Active RAM: <500MB (macOS Activity Monitor)
- UI responsiveness: 60fps (React Profiler)

---

## Risk Mitigation

| Risk | Mitigation Tasks |
|------|------------------|
| Accessibility API unreliable | T188 (clipboard fallback), T070 (error handling) |
| Python subprocess crashes | T186 (auto-restart), T187 (health checks) |
| Global hotkey conflicts | T131 (conflict detection), T146 (testing) |
| Memory leaks in audio | T072 (circular buffer), T183 (profiling) |
| Model download failures | T189 (retry logic), T174 (resume capability) |
| Permission denial by users | T098-T101 (clear messaging), T100 (skip option) |

---

## Success Metrics (from spec.md)

All success criteria must be validated before marking tasks complete:

- ✅ SC-001: Text insertion <100ms from silence detection (T076)
- ✅ SC-002: App bundle <50MB excluding models (T200)
- ✅ SC-003: Transcription accuracy >95% WER (T180)
- ✅ SC-004: Zero network calls during operation (T193)
- ✅ SC-005: Onboarding complete <2 minutes (T102)
- ✅ SC-006: Modal appears <50ms from hotkey (T075)
- ✅ SC-007: RAM usage <200MB idle, <500MB active (T078)
- ✅ SC-008: Waveform 30fps minimum (T077)
- ✅ SC-009: 90% permission grant success (T103)
- ✅ SC-010: Language switch <2 seconds (T179)
- ✅ SC-011: UI 60fps during transcription (T184)
- ✅ SC-012: 95% transcription success rate (T204)

---

## Notes

- **[P] tasks** = Different files, no dependencies, can run in parallel
- **[Story] label** = Maps task to specific user story for traceability
- **TDD mandatory**: All tests written BEFORE implementation
- **File paths** = Absolute paths from repository root
- **Independent stories**: Each user story deliverable and testable on its own
- **Commit strategy**: Commit after each task or logical group
- **Stop at checkpoints**: Validate story independently before proceeding
- **Performance validation**: Run benchmarks continuously, not just at end

---

**Total Tasks**: 208
**MVP Tasks (US1+US2)**: 104 tasks
**Estimated MVP Duration**: 4-6 weeks (single developer)
**Suggested MVP Scope**: User Stories 1 + 2 (P1 priorities)
