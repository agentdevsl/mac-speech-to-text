# Feature Specification: macOS Local Speech-to-Text Application

**Feature Branch**: `001-local-speech-to-text`
**Created**: 2026-01-02
**Updated**: 2026-01-02 (Pure Swift + SwiftUI Architecture)
**Status**: Draft
**Input**: User description: "Build a macOS local speech-to-text application with a beautiful, privacy-focused design. The app should be invisible until triggered by a global hotkey (⌘⌃Space), then appear with an elegant recording modal. Key features: Pure Swift + SwiftUI frontend with native macOS design, FluidAudio Swift SDK for local ML inference on Apple Silicon with Parakeet TDT v3, 'Warm Minimalism' design aesthetic with frosted glass UI (.ultraThinMaterial), Real-time audio waveform visualization, Automatic text insertion into active applications, Settings for hotkey customization and language selection, Onboarding flow with permission requests, Menu bar integration with quick stats, Complete privacy - 100% local processing via Apple Neural Engine"

## User Scenarios & Testing

### User Story 1 - Quick Speech-to-Text Capture (Priority: P1)

A user is working in any macOS application and wants to dictate text instead of typing. They press the global hotkey, speak their content, and have it automatically inserted into their active application at the cursor position.

**Why this priority**: This is the core value proposition of the application. Without this fundamental flow working, the application has no purpose. This is the minimum viable product.

**Independent Test**: Can be fully tested by launching the app, pressing the hotkey in a text editor, speaking a simple phrase like "Hello world", and verifying the text appears at the cursor position. Delivers immediate dictation value.

**Acceptance Scenarios**:

1. **Given** the app is running in the background, **When** the user presses ⌘⌃Space in any text field, **Then** a recording modal appears centered on screen with visual feedback
2. **Given** the recording modal is active, **When** the user speaks clearly for 5 seconds and stops, **Then** the app detects silence, transcribes the speech, and inserts the text at the cursor position
3. **Given** the user is speaking, **When** the recording modal displays, **Then** a real-time waveform visualization shows audio input levels
4. **Given** transcription is complete, **When** text is inserted, **Then** the modal disappears automatically and focus returns to the original application
5. **Given** the user presses the hotkey accidentally, **When** they press Escape or click outside the modal, **Then** recording stops and the modal closes without inserting text

---

### User Story 2 - First-Time Setup and Onboarding (Priority: P1)

A new user installs the application for the first time. They need to grant necessary system permissions (microphone access, accessibility permissions for text insertion, hotkey registration) and understand how to use the app.

**Why this priority**: Without proper permissions, the core functionality cannot work. First-time experience determines whether users continue using the app or uninstall it immediately.

**Independent Test**: Can be tested by installing the app on a fresh macOS system, following the onboarding flow, granting permissions, and verifying the "Try it now" demo works. Delivers a functional app setup.

**Acceptance Scenarios**:

1. **Given** the user launches the app for the first time, **When** the app initializes, **Then** an onboarding modal appears explaining the app's privacy-first approach
2. **Given** the onboarding flow is active, **When** the user proceeds through steps, **Then** the app requests microphone access with clear explanation of why it's needed
3. **Given** microphone access is granted, **When** the next step appears, **Then** the app requests accessibility permissions for text insertion with visual instructions
4. **Given** accessibility permissions are granted, **When** the user reaches the final step, **Then** a "Try it now" interactive demo allows them to test the hotkey and see a transcription
5. **Given** the user denies a required permission, **When** they try to proceed, **Then** the app explains which features won't work and provides a link to System Settings to grant permissions later

---

### User Story 3 - Menu Bar Quick Access and Stats (Priority: P2)

A user wants quick access to the app without launching a full window. They can click the menu bar icon to see recent usage stats, access settings, or manually trigger recording.

**Why this priority**: Provides persistent visibility and quick access without cluttering the screen. Essential for discoverability and power user workflows, but the app functions without it.

**Independent Test**: Can be tested by clicking the menu bar icon and verifying the dropdown menu shows options (Open Settings, Start Recording, View Stats, Quit) and displays today's word count. Delivers convenient access.

**Acceptance Scenarios**:

1. **Given** the app is running, **When** the menu bar icon is visible, **Then** it displays a microphone icon with system-appropriate styling
2. **Given** the user clicks the menu bar icon, **When** the dropdown appears, **Then** it shows quick stats (words transcribed today, total sessions) and menu options
3. **Given** the dropdown menu is open, **When** the user selects "Start Recording", **Then** the recording modal appears immediately
4. **Given** the dropdown menu is open, **When** the user selects "Open Settings", **Then** the settings window opens with all configuration options
5. **Given** the user has transcribed 500 words today, **When** they open the menu, **Then** the stats display "500 words today" with an icon

---

### User Story 4 - Customizable Settings (Priority: P2)

A user wants to customize the application behavior to match their workflow. They need to change the global hotkey, select a preferred language for transcription, adjust audio sensitivity, and configure automatic text insertion behavior.

**Why this priority**: Customization improves user satisfaction and handles edge cases (hotkey conflicts, accent variations, different use cases), but default settings make the app functional.

**Independent Test**: Can be tested by opening settings, changing the hotkey to ⌘⌥S, selecting Spanish as the language, testing that the new hotkey works and Spanish transcription is accurate. Delivers personalization.

**Acceptance Scenarios**:

1. **Given** the settings window is open, **When** the user clicks the hotkey field, **Then** they can record a new key combination by pressing it
2. **Given** the user sets a hotkey that conflicts with a system shortcut, **When** they save, **Then** the app warns them about the conflict and suggests alternatives
3. **Given** the user opens language settings, **When** they browse available languages, **Then** they see 25 supported languages with native names (e.g., "Español", "Français")
4. **Given** the user selects a new language, **When** they save settings, **Then** the language model downloads if not present (with progress indicator) and becomes active
5. **Given** the user adjusts audio sensitivity slider, **When** they test the microphone, **Then** a live visualization shows the current threshold and detected audio levels

---

### User Story 5 - Multi-Language Support (Priority: P3)

A multilingual user wants to dictate in different languages depending on context. They can quickly switch languages or enable automatic language detection.

**Why this priority**: Expands the user base and handles international use cases, but most users will use a single language primarily. Nice-to-have feature.

**Independent Test**: Can be tested by switching the language from English to French in settings, dictating "Bonjour le monde", and verifying French text is inserted correctly. Delivers multi-language capability.

**Acceptance Scenarios**:

1. **Given** the user has English selected, **When** they open quick language switch (via menu bar), **Then** they see recently used languages and can switch with one click
2. **Given** the user enables automatic language detection, **When** they speak in French, **Then** the app detects the language and transcribes accordingly without manual switching
3. **Given** the user switches from English to Spanish, **When** they trigger recording for the first time, **Then** the Spanish model loads with a brief loading indicator (1-2 seconds)

---

### Edge Cases

- What happens when the user's microphone is disconnected or disabled during recording?
  - The app should detect the disconnection, display an error message in the modal, and allow the user to reconnect and retry.

- How does the system handle extremely long recordings (5+ minutes)?
  - The app should process audio in chunks to maintain responsiveness and prevent memory issues. A progress indicator shows transcription status for long recordings.

- What happens when the user presses the hotkey while the recording modal is already open?
  - The hotkey acts as a toggle: pressing it again stops recording and closes the modal.

- How does the app behave when no active text field has focus?
  - The app still allows recording but displays a notification that text cannot be inserted automatically. The transcribed text is copied to the clipboard instead.

- What happens when the app loses accessibility permissions after initial setup?
  - The app detects the permission loss and displays a non-intrusive notification with a link to restore permissions in System Settings.

- How does the system handle background noise or unclear speech?
  - The app includes a confidence threshold. Low-confidence transcriptions are flagged, and the user can review/edit before insertion via an optional confirmation step.

- What happens when multiple instances of the app are launched?
  - The app uses a singleton pattern to prevent multiple instances. Launching a second instance brings the existing instance to focus.

- How does the app handle updates to the ML models?
  - Model updates are downloaded in the background and applied on next app restart. The user is notified when updates are available.

## Requirements

### Functional Requirements

- **FR-001**: System MUST register a global hotkey (default ⌘⌃Space) that triggers the recording modal from any application
- **FR-002**: System MUST display a recording modal with real-time audio waveform visualization when the hotkey is activated
- **FR-003**: System MUST capture audio from the default system microphone at minimum 16kHz sample rate
- **FR-004**: System MUST detect silence periods (configurable threshold, default 1.5 seconds) to automatically stop recording
- **FR-005**: System MUST transcribe captured audio locally using FluidAudio SDK with Parakeet TDT v3 model on Apple Neural Engine without network calls
- **FR-006**: System MUST insert transcribed text at the current cursor position in the active application
- **FR-007**: System MUST request and verify microphone access permission during onboarding
- **FR-008**: System MUST request and verify accessibility permissions for text insertion during onboarding
- **FR-009**: Users MUST be able to customize the global hotkey via settings
- **FR-010**: Users MUST be able to select from 25 supported languages for transcription
- **FR-011**: System MUST display a menu bar icon with quick access to settings, stats, and manual recording trigger
- **FR-012**: System MUST persist user settings (hotkey, language, audio sensitivity) across app restarts
- **FR-013**: System MUST display an onboarding flow on first launch with permission requests and usage instructions
- **FR-014**: Users MUST be able to cancel recording by pressing Escape or clicking outside the modal
- **FR-015**: System MUST return focus to the original application after text insertion
- **FR-016**: System MUST track usage statistics (words transcribed, session count) without identifying content
- **FR-017**: System MUST display transcription progress for recordings longer than 10 seconds
- **FR-018**: System MUST copy transcribed text to clipboard when no active text field is detected
- **FR-019**: System MUST warn users when attempting to set a hotkey that conflicts with system shortcuts
- **FR-020**: System MUST download required language models on first use of a language with progress indication
- **FR-021**: System MUST operate entirely offline after initial model download
- **FR-022**: System MUST gracefully handle microphone disconnection with error messaging and recovery options
- **FR-023**: Users MUST be able to adjust audio sensitivity threshold for silence detection
- **FR-024**: System MUST prevent multiple app instances from running simultaneously
- **FR-025**: System MUST apply "Warm Minimalism" design aesthetic with native SwiftUI frosted glass effects (.ultraThinMaterial)

### Key Entities

- **Recording Session**: Represents a single speech-to-text capture event. Attributes: start time, duration, audio data, transcribed text, language used, confidence score, insertion success status.

- **User Settings**: Represents persistent user configuration. Attributes: global hotkey combination, selected language, audio sensitivity threshold, auto-insert enabled, silence detection duration, onboarding completed flag.

- **Language Model**: Represents a downloaded ML model for a specific language. Attributes: language code, language display name, model file path, download status, file size, last updated date.

- **Usage Statistics**: Represents aggregated usage metrics. Attributes: total sessions, total words transcribed, average session duration, most used languages, daily/weekly/monthly breakdowns.

- **Audio Buffer**: Represents captured audio during a recording session. Attributes: raw audio samples, sample rate, duration, peak amplitude for visualization.

## Success Criteria

### Measurable Outcomes

- **SC-001**: Transcribed text appears in the active application within 100 milliseconds of speech ending (from silence detection to text insertion)
- **SC-002**: Application bundle size remains under 50MB excluding ML models
- **SC-003**: Transcription accuracy exceeds 95% for clear English speech in quiet environments (measured using standard WER - Word Error Rate - benchmarks)
- **SC-004**: Zero network calls are made during normal operation (verifiable via network monitoring tools)
- **SC-005**: Users can complete the onboarding flow and perform their first successful transcription within 2 minutes of installation
- **SC-006**: The recording modal appears within 50 milliseconds of pressing the global hotkey
transcription
- **SC-008**: Real-time waveform visualization updates at minimum 30 frames per second during recording
- **SC-009**: 90% of users successfully grant all required permissions during onboarding without external help
- **SC-010**: Language switching completes within 2 seconds for already-downloaded models
- **SC-011**: The application remains responsive (UI at 60fps) during transcription processing
- **SC-012**: 95% of transcriptions complete successfully without errors or crashes

### Assumptions

- Users have macOS 12.0 (Monterey) or later with Apple Silicon (M1/M2/M3/M4)
- Users have at least 2GB of free disk space for ML models
- Users have a functional built-in or external microphone
- Users dictate in environments with moderate noise levels (typical office/home settings)
- Default hotkey (⌘⌃Space) does not conflict with user's existing shortcuts
- Users understand basic macOS permission dialogs and System Settings navigation
- FluidAudio SDK with Parakeet TDT v3 model provides baseline accuracy for all 25 supported European languages
- Users will primarily dictate short to medium-length text (10 seconds to 2 minutes per recording)
- Accessibility permissions allow programmatic text insertion into most standard macOS applications
- Users prefer automatic silence detection over manual stop controls for typical use cases
