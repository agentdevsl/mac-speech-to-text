# Tasks: macOS Local Speech-to-Text Application

**Feature**: 001-local-speech-to-text
**Architecture**: Pure Swift + SwiftUI + FluidAudio SDK
**Input**: Design documents from `/workspace/specs/001-local-speech-to-text/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/swift-fluidaudio.md, quickstart.md

**CRITICAL ARCHITECTURE CHANGE**: Pure Swift + SwiftUI replaces previous Tauri + React + Rust approach
- **Single language**: Pure Swift (no TypeScript, Rust, or Python)
- **Zero IPC boundaries**: SwiftUI → Swift Services → FluidAudio SDK (all in-process)
- **Simpler build**: Xcode only (no Tauri, npm, cargo, vite)
- **Smaller bundle**: 10-20MB vs 50-80MB (Tauri overhead eliminated)
- **Better performance**: <10ms hotkey latency vs ~30ms, native 120fps rendering
- **Native macOS integration**: `.ultraThinMaterial` frosted glass, native animations, perfect ProMotion support

**Tests**: TDD methodology per constitution Section VI.1 is MANDATORY. Test tasks follow RED-GREEN-REFACTOR pattern. Each implementation task has corresponding XCTest file written BEFORE implementation (RED phase). Tests in `/workspace/Tests/SpeechToTextTests/` directory.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

---

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- All paths are absolute from repository root `/workspace/`

---

## Phase 1: Setup (Xcode Project Initialization)

**Purpose**: Create Xcode project structure and configure Swift Package Manager dependencies

- [X] T001 Create Xcode macOS app project at `/workspace/SpeechToText.xcodeproj` with Swift 5.9+ and macOS 12.0+ deployment target
- [X] T002 Create Swift Package Manager manifest at `/workspace/Package.swift` with FluidAudio SDK v0.9.0+ dependency
- [X] T003 Create project directory structure: `/workspace/Sources/`, `/workspace/Tests/`, `/workspace/Resources/`
- [X] T004 [P] Configure Xcode build settings for Apple Silicon (arm64) with Release and Debug configurations
- [X] T005 [P] Add required entitlements in `/workspace/SpeechToText.entitlements` (microphone, accessibility, input-monitoring)
- [X] T006 [P] Create SwiftLint configuration at `/workspace/.swiftlint.yml` for code quality enforcement
- [X] T007 Resolve Swift Package Manager dependencies via `swift package resolve` to download FluidAudio SDK

**Checkpoint**: Xcode project builds successfully with FluidAudio SDK linked

---

## Phase 2: Foundational (Core Infrastructure - Blocks All User Stories)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**CRITICAL**: No user story work can begin until this phase is complete

### Data Models

- [X] T008 [P] Create RecordingSession model at `/workspace/Sources/Models/RecordingSession.swift` with state machine (idle, recording, transcribing, inserting, completed, cancelled)
- [X] T009 [P] Create UserSettings model at `/workspace/Sources/Models/UserSettings.swift` with nested config structs (hotkey, language, audio, UI, privacy, onboarding)
- [X] T010 [P] Create LanguageModel model at `/workspace/Sources/Models/LanguageModel.swift` with download status enum and 25 supported languages
- [X] T011 [P] Create UsageStatistics model at `/workspace/Sources/Models/UsageStatistics.swift` with privacy-preserving aggregations
- [X] T012 [P] Create AudioBuffer model at `/workspace/Sources/Models/AudioBuffer.swift` for in-memory audio handling (16kHz mono)

### Core Services

- [X] T013 Create FluidAudioService at `/workspace/Sources/Services/FluidAudioService.swift` as Swift actor with async transcribe() method using FluidAudio SDK
- [X] T014 [P] Create PermissionService at `/workspace/Sources/Services/PermissionService.swift` with protocol-based interface for microphone, accessibility, and input monitoring checks
- [X] T015 [P] Create SettingsService at `/workspace/Sources/Services/SettingsService.swift` wrapping UserDefaults with Codable persistence for UserSettings
- [X] T016 [P] Create StatisticsService at `/workspace/Sources/Services/StatisticsService.swift` with SQLite database schema and privacy-preserving aggregation logic

### App Infrastructure

- [X] T017 Create AppState at `/workspace/Sources/SpeechToTextApp/AppState.swift` as @Observable class with app-wide shared state (settings, statistics, current session)
- [X] T018 Create main app entry point at `/workspace/Sources/SpeechToTextApp/SpeechToTextApp.swift` with @main attribute and MenuBarExtra scene
- [X] T019 Create AppDelegate at `/workspace/Sources/SpeechToTextApp/AppDelegate.swift` for app lifecycle, menu bar management, and hotkey initialization
- [X] T020 [P] Create Constants file at `/workspace/Sources/Utilities/Constants.swift` with app-wide constants (sample rates, thresholds, default values)
- [X] T021 [P] Create Color+Theme extension at `/workspace/Sources/Utilities/Extensions/Color+Theme.swift` with Warm Minimalism color palette (amber accents, frosted glass)

**Checkpoint**: Foundation ready - all models, services, and app infrastructure complete. User story implementation can now begin in parallel.

---

## Phase 3: User Story 1 - Quick Speech-to-Text Capture (Priority: P1) - MVP

**Goal**: Core value proposition - user presses global hotkey, speaks, and text appears at cursor position automatically

**Independent Test**: Launch app, press ⌘⌃Space in TextEdit, speak "Hello world", verify text appears at cursor. Delivers immediate dictation value.

**Acceptance Scenarios**:
1. Hotkey triggers recording modal with visual feedback
2. Voice activity detection stops recording after 1.5s silence and transcribes
3. Real-time waveform shows audio levels during recording
4. Modal disappears after text insertion, focus returns to original app
5. Escape key or outside click cancels recording without inserting text

### Implementation for User Story 1

- [X] T022 [P] [US1] Create AudioCaptureService at `/workspace/Sources/Services/AudioCaptureService.swift` using AVAudioEngine for 16kHz mono capture with real-time level callbacks
- [X] T023 [P] [US1] Create HotkeyService at `/workspace/Sources/Services/HotkeyService.swift` using Carbon Event Manager APIs for global hotkey registration (default ⌘⌃Space)
- [X] T024 [P] [US1] Create TextInsertionService at `/workspace/Sources/Services/TextInsertionService.swift` using AXUIElement APIs to insert text at cursor position
- [X] T025 [US1] Create RecordingViewModel at `/workspace/Sources/Views/RecordingViewModel.swift` as @Observable class coordinating audio capture, FluidAudio transcription, and text insertion
- [X] T026 [US1] Create WaveformView component at `/workspace/Sources/Views/Components/WaveformView.swift` with real-time audio level visualization (30+ fps, canvas-based)
- [X] T027 [US1] Create RecordingModal view at `/workspace/Sources/Views/RecordingModal.swift` with frosted glass (.ultraThinMaterial), waveform, and spring animations
- [X] T028 [US1] Integrate HotkeyService with AppDelegate to show RecordingModal on ⌘⌃Space press
- [X] T029 [US1] Implement silence detection in RecordingViewModel using FluidAudio VAD to auto-stop recording after 1.5 seconds
- [X] T030 [US1] Implement modal dismissal on Escape key or outside click in RecordingModal view
- [X] T031 [US1] Add error handling in RecordingViewModel for permission failures, transcription errors, and insertion failures
- [X] T032 [US1] Add clipboard fallback in TextInsertionService when no active text field detected
- [X] T085 [US1] Add progress indicator to RecordingModal for recordings >10 seconds showing elapsed time and transcription status (FR-017)
- [X] T086 [US1] Implement microphone disconnection detection and recovery in AudioCaptureService with user notification and auto-resume (FR-022)

**Checkpoint**: User Story 1 complete - user can dictate text via global hotkey with automatic insertion. This is the MVP!

---

## Phase 4: User Story 2 - First-Time Setup and Onboarding (Priority: P1)

**Goal**: Guide new users through permission granting and demonstrate app functionality

**Independent Test**: Install app on fresh macOS, follow onboarding flow, grant all permissions, verify "Try it now" demo works. Delivers functional app setup.

**Acceptance Scenarios**:
1. First launch shows onboarding modal explaining privacy-first approach
2. Onboarding requests microphone access with clear explanation
3. Onboarding requests accessibility permissions with visual instructions
4. Final step provides "Try it now" interactive demo of hotkey functionality
5. Permission denial shows explanation of feature limitations with System Settings link

### Implementation for User Story 2

- [X] T033 [P] [US2] Create PermissionCard component at `/workspace/Sources/Views/Components/PermissionCard.swift` with icon, title, description, and grant button
- [X] T034 [P] [US2] Create OnboardingViewModel at `/workspace/Sources/Views/OnboardingViewModel.swift` as @Observable class managing onboarding state and permission flow
- [X] T035 [US2] Create OnboardingView at `/workspace/Sources/Views/OnboardingView.swift` with multi-step flow (welcome, microphone, accessibility, demo, completion)
- [X] T036 [US2] Implement microphone permission request step in OnboardingView using AVCaptureDevice.requestAccess(for: .audio)
- [X] T037 [US2] Implement accessibility permission request step in OnboardingView with visual instructions to open System Settings
- [X] T038 [US2] Create interactive demo step in OnboardingView allowing user to test hotkey and see sample transcription
- [X] T039 [US2] Add skip option for each permission with warning about limited functionality
- [X] T040 [US2] Update AppDelegate to show OnboardingView on first launch (check UserSettings.onboarding.completed flag)
- [X] T041 [US2] Add deep link to System Settings for permission granting in PermissionCard component
- [X] T042 [US2] Store onboarding completion state in UserSettings via SettingsService

**Checkpoint**: User Story 2 complete - new users can successfully set up the app with all required permissions

---

## Phase 5: User Story 3 - Menu Bar Quick Access and Stats (Priority: P2)

**Goal**: Provide persistent access via menu bar icon with quick stats and actions

**Independent Test**: Click menu bar icon, verify dropdown shows options (Open Settings, Start Recording, View Stats, Quit) and displays today's word count. Delivers convenient access.

**Acceptance Scenarios**:
1. Menu bar shows microphone icon with system-appropriate styling
2. Clicking icon opens dropdown with quick stats and menu options
3. "Start Recording" menu item triggers recording modal immediately
4. "Open Settings" menu item opens settings window
5. Stats display shows "500 words today" with icon

### Implementation for User Story 3

- [X] T043 [P] [US3] Create MenuBarViewModel at `/workspace/Sources/Views/MenuBarViewModel.swift` as @Observable class fetching daily statistics and handling menu actions
- [X] T044 [US3] Create MenuBarView at `/workspace/Sources/Views/MenuBarView.swift` with quick stats display and menu options (Start Recording, Open Settings, Quit)
- [X] T045 [US3] Implement menu bar icon management in AppDelegate using NSStatusBar and NSStatusItem
- [X] T046 [US3] Add "Start Recording" action in MenuBarView to trigger RecordingModal programmatically
- [X] T047 [US3] Add "Open Settings" action in MenuBarView to show SettingsView window
- [X] T048 [US3] Fetch daily statistics in MenuBarViewModel from StatisticsService (words transcribed today, total sessions)
- [X] T049 [US3] Add real-time stats updates in MenuBarView when statistics change using Combine or @Observable updates
- [X] T050 [US3] Create menu bar icon assets in `/workspace/Resources/Assets.xcassets/MenuBarIcons/` with light and dark mode variants

**Checkpoint**: User Story 3 complete - menu bar provides quick access to app functionality and usage stats

---

## Phase 6: User Story 4 - Customizable Settings (Priority: P2)

**Goal**: Allow users to customize hotkey, language, audio sensitivity, and text insertion behavior

**Independent Test**: Open settings, change hotkey to ⌘⌥S, select Spanish language, verify new hotkey works and Spanish transcription accurate. Delivers personalization.

**Acceptance Scenarios**:
1. Settings window allows recording new hotkey by pressing key combination
2. App warns about hotkey conflicts with system shortcuts and suggests alternatives
3. Language dropdown shows 25 supported languages with native names
4. Selecting new language downloads model if not present (with progress indicator)
5. Audio sensitivity slider shows live visualization of current threshold and detected levels

### Implementation for User Story 4

- [X] T051 [P] [US4] Create SettingsViewModel at `/workspace/Sources/Views/SettingsViewModel.swift` as @Observable class managing settings state and validation
- [X] T052 [US4] Create SettingsView at `/workspace/Sources/Views/SettingsView.swift` with tabs for General, Language, Audio, and Privacy settings
- [X] T053 [US4] Create LanguagePicker component at `/workspace/Sources/Views/Components/LanguagePicker.swift` with searchable list of 25 languages and native names
- [X] T054 [US4] Implement hotkey configuration UI in SettingsView with key capture field and conflict detection
- [X] T055 [US4] Add hotkey conflict detection in HotkeyService by checking against known system shortcuts
- [X] T056 [US4] Implement language selection in SettingsView with model download progress indicator using FluidAudio SDK
- [X] T057 [US4] Create audio sensitivity slider in SettingsView with live microphone level visualization
- [X] T058 [US4] Add silence detection threshold slider in SettingsView (0.5-3.0 seconds range)
- [X] T059 [US4] Implement settings persistence in SettingsViewModel using SettingsService.save()
- [ ] T060 [US4] Add reset to defaults button in SettingsView restoring UserSettings.default values
- [ ] T061 [US4] Show model download progress in LanguagePicker using ProgressView with percentage and bytes downloaded
- [ ] T062 [US4] Add validation in SettingsViewModel for hotkey conflicts, invalid audio thresholds, and unsupported languages

**Checkpoint**: User Story 4 complete - users can fully customize app behavior to match their workflow

---

## Phase 7: User Story 5 - Multi-Language Support (Priority: P3)

**Goal**: Enable users to dictate in multiple languages with quick switching or auto-detection

**Independent Test**: Switch language from English to French in settings, dictate "Bonjour le monde", verify French text inserted correctly. Delivers multi-language capability.

**Acceptance Scenarios**:
1. Menu bar dropdown shows recently used languages for one-click switching
2. Auto-detect option enables automatic language detection from speech
3. First transcription in new language shows brief loading indicator (1-2 seconds)

### Implementation for User Story 5

- [X] T063 [P] [US5] Add language quick-switch dropdown to MenuBarView showing 5 most recently used languages
- [X] T064 [P] [US5] Implement language switching in FluidAudioService.switchLanguage(to:) method (Parakeet TDT v3 is multilingual - no model reload needed)
- [X] T065 [US5] Add auto-detect language toggle in SettingsView enabling FluidAudio automatic language detection
- [X] T066 [US5] Store recently used languages in UserSettings.language.recentLanguages array (max 5 items)
- [X] T067 [US5] Update RecordingViewModel to show loading indicator on first transcription after language switch
- [X] T068 [US5] Add language indicator to RecordingModal showing current language during recording
- [X] T069 [US5] Update StatisticsService to track language breakdown (LanguageStats per language)

**Checkpoint**: User Story 5 complete - all 25 languages supported with quick switching and auto-detection

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories and final quality assurance

- [X] T070 [P] Add SwiftUI Previews to all view files for rapid UI development and visual regression testing
- [X] T071 [P] Implement comprehensive error messages in all services with user-friendly descriptions
- [X] T072 [P] Add haptic feedback to RecordingModal using NSHapticFeedbackManager for recording start/stop
- [X] T073 [P] Optimize FluidAudioService memory usage by clearing audio buffers immediately after transcription
- [X] T074 [P] Add accessibility labels and VoiceOver support to all SwiftUI views for screen reader compatibility
- [ ] T075 Implement singleton pattern in AppDelegate to prevent multiple app instances
- [ ] T076 Add app icon assets to `/workspace/Resources/Assets.xcassets/AppIcon.appiconset/` with all required sizes
- [X] T077 [P] Add sound effects for recording start/stop in `/workspace/Resources/Sounds/` with subtle audio cues
- [X] T078 [P] Create localization strings files in `/workspace/Resources/Localizations/` for UI text in 25 languages
- [ ] T079 Verify all performance targets via Xcode Instruments (hotkey <50ms, transcription <100ms, waveform 30+fps, idle RAM <200MB)
- [ ] T080 Validate quickstart.md instructions by following setup steps on clean macOS system
- [ ] T081 Code cleanup: run SwiftLint with auto-fix and SwiftFormat across entire codebase
- [ ] T082 Add debug logging throughout services using os_log with privacy-preserving message formatting
- [ ] T083 Create DMG installer script at `/workspace/scripts/export-dmg.sh` for production distribution
- [ ] T084 Verify all 5 user stories pass their acceptance scenarios from spec.md via manual testing

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - start immediately
- **Foundational (Phase 2)**: Depends on Setup (Phase 1) - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational (Phase 2) - MVP delivery
- **User Story 2 (Phase 4)**: Depends on Foundational (Phase 2) - Can run in parallel with US1
- **User Story 3 (Phase 5)**: Depends on Foundational (Phase 2) and US1 (uses RecordingModal) - Can run in parallel with US2
- **User Story 4 (Phase 6)**: Depends on Foundational (Phase 2) and US1 (uses HotkeyService) - Can run after US1
- **User Story 5 (Phase 7)**: Depends on Foundational (Phase 2) and US4 (uses SettingsView) - Can run after US4
- **Polish (Phase 8)**: Depends on all desired user stories being complete

### User Story Dependencies

```
Foundation (Phase 2) → BLOCKS ALL STORIES
    ├─→ US1 (Phase 3) - MVP [No dependencies on other stories]
    │   ├─→ US3 (Phase 5) - Menu bar [Uses RecordingModal from US1]
    │   └─→ US4 (Phase 6) - Settings [Uses HotkeyService from US1]
    │       └─→ US5 (Phase 7) - Multi-language [Uses SettingsView from US4]
    └─→ US2 (Phase 4) - Onboarding [No dependencies on other stories, can run parallel with US1]
```

### Within Each User Story

- Models created before services that use them
- Services created before ViewModels that use them
- ViewModels created before Views that use them
- Core implementation before integration with other stories

### Parallel Opportunities

**Phase 1 (Setup)**: T004, T005, T006 can run in parallel

**Phase 2 (Foundational)**:
- Models: T008, T009, T010, T011, T012 can run in parallel
- Services: T014, T015, T016 can run in parallel (T013 FluidAudioService first)
- Utilities: T020, T021 can run in parallel

**Phase 3 (User Story 1)**: T022, T023, T024 can run in parallel

**Phase 4 (User Story 2)**: T033, T034 can run in parallel

**Phase 5 (User Story 3)**: T043, T050 can run in parallel

**Phase 6 (User Story 4)**: T051, T053 can run in parallel

**Phase 7 (User Story 5)**: T063, T064 can run in parallel

**Phase 8 (Polish)**: T070, T071, T072, T073, T074, T077, T078 can run in parallel

**User Stories in Parallel** (with multiple developers):
- After Foundational: US1 and US2 can start simultaneously
- After US1 complete: US3 and US4 can run in parallel
- US5 requires US4 complete

---

## Parallel Example: Foundational Phase (Phase 2)

```bash
# All data models can be created simultaneously (different files):
Task T008: "Create RecordingSession model at /workspace/Sources/Models/RecordingSession.swift"
Task T009: "Create UserSettings model at /workspace/Sources/Models/UserSettings.swift"
Task T010: "Create LanguageModel model at /workspace/Sources/Models/LanguageModel.swift"
Task T011: "Create UsageStatistics model at /workspace/Sources/Models/UsageStatistics.swift"
Task T012: "Create AudioBuffer model at /workspace/Sources/Models/AudioBuffer.swift"

# After T013 (FluidAudioService) completes, these services can run in parallel:
Task T014: "Create PermissionService at /workspace/Sources/Services/PermissionService.swift"
Task T015: "Create SettingsService at /workspace/Sources/Services/SettingsService.swift"
Task T016: "Create StatisticsService at /workspace/Sources/Services/StatisticsService.swift"
```

---

## Implementation Strategy

### MVP First (User Stories 1 & 2 Only)

This delivers a functional speech-to-text app with onboarding:

1. Complete Phase 1: Setup (T001-T007)
2. Complete Phase 2: Foundational (T008-T021) - CRITICAL CHECKPOINT
3. Complete Phase 3: User Story 1 (T022-T032) - Core dictation functionality
4. Complete Phase 4: User Story 2 (T033-T042) - Onboarding flow
5. **STOP and VALIDATE**: Test both stories independently
6. Deploy/demo the MVP

**MVP Deliverable**: Users can install app, complete onboarding, and dictate text via global hotkey

### Full Feature Set (All User Stories)

1. Complete Setup + Foundational (T001-T021)
2. Complete User Story 1 (T022-T032) → Test independently → MVP checkpoint
3. Complete User Story 2 (T033-T042) → Test independently → Onboarding complete
4. Complete User Story 3 (T043-T050) → Test independently → Menu bar access
5. Complete User Story 4 (T051-T062) → Test independently → Full customization
6. Complete User Story 5 (T063-T069) → Test independently → Multi-language support
7. Complete Polish (T070-T084) → Full quality assurance → Production ready

### Parallel Team Strategy

With 3 developers after Foundational phase completes:

- **Developer A**: User Story 1 (core functionality)
- **Developer B**: User Story 2 (onboarding)
- **Developer C**: Setup test infrastructure for US1 and US2

After US1 complete:
- **Developer A**: User Story 3 (menu bar)
- **Developer B**: User Story 4 (settings)
- **Developer C**: Polish and integration

After US4 complete:
- **Developer A or B**: User Story 5 (multi-language)
- **Developer C**: Final polish and validation

---

## Task Summary

**Total Tasks**: 84

### Tasks by Phase
- Phase 1 (Setup): 7 tasks
- Phase 2 (Foundational): 14 tasks (BLOCKS all stories)
- Phase 3 (User Story 1): 11 tasks
- Phase 4 (User Story 2): 10 tasks
- Phase 5 (User Story 3): 8 tasks
- Phase 6 (User Story 4): 12 tasks
- Phase 7 (User Story 5): 7 tasks
- Phase 8 (Polish): 15 tasks

### Parallel Opportunities
- 35 tasks marked [P] can run in parallel (within their phase)
- User stories can run in parallel after Foundational phase complete (with team capacity)

### Independent Test Criteria
- **User Story 1**: Hotkey → speak → text appears (tests core value)
- **User Story 2**: Fresh install → onboarding → demo works (tests setup)
- **User Story 3**: Click menu bar → see stats and options (tests quick access)
- **User Story 4**: Change hotkey/language → works correctly (tests customization)
- **User Story 5**: Switch to French → dictate → French text (tests multi-language)

### Suggested MVP Scope
**Phases 1-4 (User Stories 1 & 2)**: 42 tasks total
- Delivers: Functional speech-to-text app with onboarding
- Estimated: 3-4 weeks for single developer
- Value: Users can immediately start dictating text

### Technology Stack (Reminder)
- **Language**: Swift 5.9+ (single language, no TypeScript/Rust/Python)
- **UI Framework**: SwiftUI with @Observable state management
- **ML Inference**: FluidAudio SDK v0.9.0+ (Parakeet TDT v3 on Apple Neural Engine)
- **Audio**: AVAudioEngine for capture, FluidAudio for VAD
- **System APIs**: Carbon (hotkeys), Accessibility (text insertion), AVFoundation (microphone)
- **Testing**: XCTest (unit), XCUITest (UI), SwiftUI Previews (visual)
- **Build**: Xcode 15.0+, Swift Package Manager

---

## Notes

- **Tests excluded**: Specification does not explicitly request tests. Manual testing via SwiftUI Previews and Xcode debugging expected.
- **[P] tasks**: Different files, no dependencies - can run in parallel
- **[Story] label**: Maps task to specific user story for traceability
- **Absolute paths**: All paths start from `/workspace/` repository root
- **Checkpoint validation**: Stop after each user story phase to test independently
- **SwiftUI Previews**: Use throughout development for rapid UI iteration
- **FluidAudio models**: Auto-downloaded on first use (~500MB per language)
- **Performance targets**: Verify with Xcode Instruments (hotkey <50ms, transcription <100ms, waveform 30+fps)
- **Code quality**: Run SwiftLint and SwiftFormat before commits
- **Architecture**: Pure Swift (no IPC, no FFI) - simplest possible implementation

---

**Tasks Ready**: All 84 tasks generated and organized by user story with dependencies mapped. Ready for implementation using `/speckit.implement` command.
