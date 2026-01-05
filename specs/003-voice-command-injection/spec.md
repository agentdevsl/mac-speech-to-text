# Feature Specification: Voice Command Injection

**Feature Branch**: `003-voice-command-injection`
**Created**: 2026-01-05
**Status**: Draft
**Input**: User description: "Extend speech-to-text to recognize trigger phrases during recording and inject slash commands into terminal applications. For example, saying 'terraform design create a VPC' should inject '/speckit.plan create a VPC' into the terminal."

## User Scenarios & Testing

### User Story 1 - Voice-Triggered Slash Command Injection (Priority: P1)

A developer is working in their terminal with Claude Code. Instead of typing `/speckit.plan`, they hold the speech hotkey, say "terraform design create a VPC for staging", and release. The system recognizes "terraform design" as a trigger phrase, replaces it with `/speckit.plan`, preserves the rest of the dictation, and injects `/speckit.plan create a VPC for staging` into the terminal.

**Why this priority**: This is the core value proposition. Without voice-to-command mapping working in terminals, the feature has no purpose.

**Independent Test**: Can be tested by configuring a command trigger, opening Terminal, holding the hotkey, speaking the trigger phrase plus additional text, and verifying the mapped command plus additional text appears in the terminal.

**Acceptance Scenarios**:

1. **Given** a command trigger "terraform design" → "/speckit.plan" is configured, **When** the user holds the hotkey in Terminal and says "terraform design create a VPC", **Then** the text `/speckit.plan create a VPC` is inserted into the terminal
2. **Given** a terminal app (Terminal.app, iTerm2, Warp, Ghostty) is focused, **When** the user speaks a configured trigger phrase, **Then** the command injection logic is activated
3. **Given** a non-terminal app is focused, **When** the user speaks the same trigger phrase, **Then** normal text insertion occurs (no command replacement)
4. **Given** the user says "terraform design" with slight variations like "terra form design", **When** phonetic matching runs, **Then** the trigger is recognized with high confidence due to phonetic similarity
5. **Given** the user says text that doesn't match any trigger, **When** the recording completes, **Then** normal text insertion behavior occurs unchanged

---

### User Story 2 - YAML Configuration with Settings UI (Priority: P1)

A user wants to define their own voice commands. They open the Settings panel, navigate to the "Voice Commands" section, and see a UI for adding/editing/removing command triggers. Behind the scenes, this is stored as a YAML file they can also edit directly.

**Why this priority**: Without user-configurable commands, the feature is limited to hardcoded triggers. Configurability is essential for real-world usage.

**Independent Test**: Can be tested by opening Settings, adding a new command trigger via the UI, verifying it appears in the list, then checking the YAML file is updated. Also test editing the YAML file directly and verifying the UI reflects changes.

**Acceptance Scenarios**:

1. **Given** the user opens Settings, **When** they navigate to "Voice Commands", **Then** they see a list of configured command triggers with add/edit/delete options
2. **Given** the user clicks "Add Command", **When** they enter trigger phrase "commit changes" and injection "/commit", **Then** the new command appears in the list
3. **Given** the user edits the YAML config file directly, **When** they save and the app reloads, **Then** the Settings UI reflects the changes
4. **Given** the user deletes a command trigger, **When** the deletion is confirmed, **Then** the trigger no longer activates during speech
5. **Given** the user sets a confidence threshold of 0.85 for a trigger, **When** a phrase matches with 0.80 confidence, **Then** the command is NOT triggered (treated as regular text)

---

### User Story 3 - Phonetic Fuzzy Matching (Priority: P2)

Speech-to-text can produce variations in transcription (e.g., "terraform" → "terra form", "speckit" → "spec kit"). The system uses phonetic matching (Soundex/Double Metaphone) to handle these variations while maintaining accuracy.

**Why this priority**: Without fuzzy matching, slight transcription variations would cause commands to fail. This significantly improves reliability but the feature works with exact matching.

**Independent Test**: Can be tested by speaking trigger phrases with intentional pronunciation variations and verifying commands still trigger above the confidence threshold.

**Acceptance Scenarios**:

1. **Given** trigger phrase "terraform design", **When** transcription produces "terra form design", **Then** phonetic matching returns high confidence (>0.85)
2. **Given** trigger phrase "commit changes", **When** transcription produces "kommit changes", **Then** phonetic matching recognizes the similarity
3. **Given** a phrase that sounds completely different from any trigger, **When** phonetic matching runs, **Then** confidence is low and no command is triggered
4. **Given** two configured triggers with similar phonetics, **When** ambiguity exists, **Then** the higher-confidence match is selected (or user preference if tied)

---

### User Story 4 - Terminal App Detection (Priority: P2)

Commands should only be injected when a terminal application is focused. The system maintains a list of known terminal app bundle IDs and checks the focused application before applying command logic.

**Why this priority**: Prevents accidental command injection in non-terminal contexts. Important for UX but feature could work with manual mode toggle.

**Independent Test**: Can be tested by configuring a command, verifying it triggers in Terminal.app, then switching to TextEdit and verifying the same phrase inserts as plain text.

**Acceptance Scenarios**:

1. **Given** Terminal.app is focused, **When** a command trigger is spoken, **Then** command injection is applied
2. **Given** iTerm2 is focused, **When** a command trigger is spoken, **Then** command injection is applied
3. **Given** VS Code is focused, **When** a command trigger is spoken, **Then** command injection is applied (VS Code treated as terminal due to integrated terminal usage)
4. **Given** Safari or Notes is focused (non-terminal app), **When** a command trigger is spoken, **Then** plain text is inserted without command replacement
5. **Given** a new terminal app (e.g., Ghostty) is installed, **When** the user adds its bundle ID to settings, **Then** command injection works for that app

---

### Edge Cases

- What happens when the trigger phrase appears in the middle of dictation instead of the start?
  - Only the first N words (configurable, default 3) are checked for command triggers. Mid-sentence triggers are ignored and inserted as plain text.

- How does the system handle multiple trigger phrases that could match?
  - Triggers are matched in order of specificity (longer phrases first). If "terraform design" and "terraform" are both configured, "terraform design create VPC" matches "terraform design" first.

- What happens when confidence is exactly at the threshold?
  - Confidence >= threshold triggers the command. Confidence < threshold falls back to plain text.

- How does the system handle an empty injection string?
  - Empty injection strings are invalid and rejected in the Settings UI. YAML validation prevents saving invalid configs.

- What happens if the YAML config file is corrupted or has syntax errors?
  - The system falls back to default (empty) command list, logs a warning, and shows a notification to the user that config failed to load.

- How does the system handle very long dictation after the trigger phrase?
  - The remainder after trigger phrase replacement is preserved fully. No truncation occurs.

- What happens when the user speaks only the trigger phrase with nothing after it?
  - Only the injection text is inserted. "terraform design" → "/speckit.plan" with no trailing space or newline added.

## Requirements

### Functional Requirements

- **FR-001**: System MUST detect when the focused application is a terminal or IDE with integrated terminal (Terminal.app, iTerm2, Warp, Ghostty, Kitty, Alacritty, VS Code)
- **FR-002**: System MUST check the first N words (configurable, default 5) of transcribed text against configured command triggers when a terminal is focused
- **FR-003**: System MUST use phonetic matching (Double Metaphone algorithm) to compare trigger phrases with transcription
- **FR-004**: System MUST calculate a confidence score (0.0-1.0) for each potential trigger match
- **FR-005**: System MUST only trigger commands when confidence exceeds the configured threshold (default 0.8)
- **FR-006**: System MUST replace only the matched trigger phrase portion, preserving the remainder of the transcription
- **FR-007**: System MUST inject the resulting text (injection + remainder) into the terminal via existing text insertion mechanism
- **FR-008**: System MUST store command configurations in a YAML file at `~/.config/speech-to-text/commands.yaml`
- **FR-009**: System MUST provide a Settings UI section for managing command triggers (add, edit, delete)
- **FR-010**: System MUST validate YAML config on load and gracefully handle parse errors
- **FR-011**: System MUST allow per-command confidence thresholds (overriding global default)
- **FR-012**: System MUST support user-configurable list of terminal app bundle identifiers
- **FR-013**: System MUST fall back to normal text insertion when no trigger matches or when not in a terminal
- **FR-014**: System MUST log command trigger events for debugging (trigger phrase, confidence, matched command)
- **FR-015**: Users MUST be able to enable/disable voice commands feature globally via Settings toggle
- **FR-016**: System MUST reload YAML config when file changes (file watcher) without requiring app restart

### Key Entities

- **CommandTrigger**: Represents a voice-to-command mapping. Attributes: trigger phrase (string), injection text (string), confidence threshold (float, optional), enabled (bool).

- **CommandConfig**: Represents the full YAML configuration. Attributes: global enabled flag, default confidence threshold, list of CommandTrigger entries, list of terminal bundle IDs.

- **PhoneticMatch**: Represents the result of phonetic comparison. Attributes: trigger phrase, transcribed segment, phonetic codes for each, similarity score (0.0-1.0).

- **TerminalAppRegistry**: Represents known terminal applications. Attributes: bundle ID, display name, whether it's user-added or built-in.

## Success Criteria

### Measurable Outcomes

- **SC-001**: Command triggers activate within 50ms of transcription completion (not including transcription time)
- **SC-002**: Phonetic matching correctly recognizes trigger phrases with common transcription variations (e.g., "terraform" ↔ "terra form") at >95% accuracy
- **SC-003**: False positive rate for command triggering is <1% (commands only trigger when intended)
- **SC-004**: Settings UI allows full CRUD operations on command triggers without needing to edit YAML directly
- **SC-005**: YAML config changes are reflected in Settings UI within 1 second of file modification
- **SC-006**: System correctly identifies terminal focus for built-in terminal apps (Terminal.app, iTerm2, Warp) with 100% accuracy
- **SC-007**: Users can configure a new command trigger and use it successfully within 30 seconds

### Assumptions

- Users have existing speech-to-text functionality working (microphone, permissions, FluidAudio)
- Users primarily use slash commands in terminal/CLI contexts (Claude Code, git aliases, custom scripts)
- Most trigger phrases are 2-4 words long
- Users dictate trigger phrases at the START of their speech, not mid-sentence
- English is the primary language for trigger phrases (phonetic algorithms optimized for English)
- Terminal applications can be identified reliably by bundle ID via macOS accessibility APIs
- FluidAudio transcription provides consistent enough output for phonetic matching to work

## Technical Notes

### Phonetic Matching Algorithm

Double Metaphone is recommended over Soundex because:
- Handles non-English origin words better (e.g., "terraform")
- Produces primary and secondary codes for ambiguous pronunciations
- More accurate for multi-syllable technical terms

Implementation approach:
1. Generate Double Metaphone codes for each word in trigger phrase
2. Generate codes for each word in transcribed segment
3. Compare code sequences, allowing for word boundary differences
4. Calculate similarity as (matched codes / total codes)

### YAML Config Format

```yaml
# ~/.config/speech-to-text/commands.yaml
version: 1
enabled: true
default_threshold: 0.8
match_first_n_words: 5

terminal_apps:
  - com.apple.Terminal
  - com.googlecode.iterm2
  - dev.warp.Warp-Stable
  - com.mitchellh.ghostty
  - net.kovidgoyal.kitty
  - io.alacritty
  - com.microsoft.VSCode

commands:
  - trigger: "terraform design"
    inject: "/speckit.plan"
    threshold: 0.85
    enabled: true

  - trigger: "terraform specify"
    inject: "/speckit.specify"

  - trigger: "terraform tasks"
    inject: "/speckit.tasks"

  - trigger: "commit changes"
    inject: "/commit"
    threshold: 0.9  # Higher threshold to avoid false positives

  - trigger: "review code"
    inject: "/review-pr"
```

### Architecture Integration Point

The command detection should be inserted in `RecordingViewModel.transcribeWithFallback()` after FluidAudio returns and before text insertion:

```swift
// Existing flow
let result = try await fluidAudioService.transcribe(samples, sampleRate)

// NEW: Command detection (only if terminal focused)
let finalText: String
if await commandDetectionService.isTerminalFocused() {
    finalText = await commandDetectionService.processTranscription(result.text)
} else {
    finalText = result.text
}

// Continue with existing insertion
try await insertTextWithFallback(finalText)
```

## Research References

- [Picovoice Porcupine](https://github.com/Picovoice/porcupine) - Wake word detection (not used but informed design)
- [WhisperKit](https://github.com/argmaxinc/WhisperKit) - On-device speech recognition for Apple Silicon
- [Double Metaphone Algorithm](https://en.wikipedia.org/wiki/Metaphone#Double_Metaphone) - Phonetic algorithm for fuzzy matching
- [Privacy-First CoreML Speech-to-Text](https://medium.com/@pbmodi1006/how-i-built-a-privacy-first-speech-to-text-tool-using-coreml-macos-apis-d10861cb2f49) - Similar architecture approach
