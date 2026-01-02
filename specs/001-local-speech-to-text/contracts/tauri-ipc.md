# Tauri IPC Contract: React ↔ Rust

**Feature**: 001-local-speech-to-text
**Date**: 2026-01-02
**Protocol**: Tauri IPC Commands (async invoke from frontend)

---

## Command Overview

| Command | Purpose | Auth Required |
|---------|---------|---------------|
| `start_recording` | Begin audio capture | Microphone permission |
| `stop_recording` | Stop capture and trigger transcription | - |
| `cancel_recording` | Stop capture without transcription | - |
| `get_audio_level` | Get current audio input level (real-time) | - |
| `transcribe_audio` | Transcribe provided audio buffer | Accessibility permission |
| `insert_text` | Insert text at cursor via Accessibility API | Accessibility permission |
| `register_hotkey` | Register global hotkey | Input monitoring permission |
| `unregister_hotkey` | Unregister global hotkey | - |
| `check_permission` | Check macOS permission status | - |
| `request_permission` | Request macOS permission | - |
| `get_settings` | Retrieve user settings | - |
| `update_settings` | Update user settings | - |
| `get_statistics` | Retrieve usage statistics | - |
| `clear_statistics` | Clear usage statistics | - |
| `list_language_models` | List available language models | - |
| `download_language_model` | Download language model | - |
| `delete_language_model` | Delete language model | - |
| `get_audio_devices` | List available microphone devices | - |

---

## Command Definitions

### Recording Commands

#### `start_recording`

Begins audio capture from the configured microphone.

**Request**:
```typescript
invoke('start_recording'): Promise<void>
```

**Success Response**:
```typescript
void
```

**Error Responses**:
```typescript
{
  code: 'PERMISSION_DENIED',
  message: 'Microphone permission not granted'
}

{
  code: 'DEVICE_UNAVAILABLE',
  message: 'Microphone not found or already in use'
}

{
  code: 'ALREADY_RECORDING',
  message: 'Recording already in progress'
}
```

**Side Effects**:
- Creates new RecordingSession in AppState
- Starts Swift audio capture via FFI
- Emits 'audio-level' events (30fps)

---

#### `stop_recording`

Stops audio capture and initiates transcription.

**Request**:
```typescript
invoke('stop_recording'): Promise<TranscriptionResult>
```

**Success Response**:
```typescript
interface TranscriptionResult {
  text: string;                // Transcribed text
  confidence: number;          // 0.0 - 1.0
  duration_ms: number;         // Transcription processing time
  word_count: number;
  segments: Array<{
    text: string;
    start_time: number;        // ms from recording start
    end_time: number;
    confidence: number;
  }>;
}
```

**Example**:
```json
{
  "text": "Hello world this is a test",
  "confidence": 0.95,
  "duration_ms": 87,
  "word_count": 6,
  "segments": [
    { "text": "Hello", "start_time": 0, "end_time": 320, "confidence": 0.98 },
    { "text": "world", "start_time": 320, "end_time": 680, "confidence": 0.96 }
  ]
}
```

**Error Responses**:
```typescript
{
  code: 'NO_ACTIVE_RECORDING',
  message: 'No recording in progress'
}

{
  code: 'TRANSCRIPTION_FAILED',
  message: 'Failed to transcribe audio: {details}'
}

{
  code: 'ML_BACKEND_ERROR',
  message: 'Python ML backend error: {details}'
}
```

**Side Effects**:
- Stops Swift audio capture
- Sends audio to Python ML backend via JSON-RPC
- Updates RecordingSession with transcription result
- Updates usage statistics
- Emits 'transcription-progress' events during processing

---

#### `cancel_recording`

Cancels the current recording without transcription.

**Request**:
```typescript
invoke('cancel_recording'): Promise<void>
```

**Success Response**:
```typescript
void
```

**Error Responses**:
```typescript
{
  code: 'NO_ACTIVE_RECORDING',
  message: 'No recording in progress'
}
```

**Side Effects**:
- Stops Swift audio capture
- Clears current RecordingSession
- Releases audio resources

---

#### `get_audio_level`

Returns current audio input level for waveform visualization.

**Request**:
```typescript
invoke('get_audio_level'): Promise<AudioLevel>
```

**Success Response**:
```typescript
interface AudioLevel {
  rms: number;           // Root mean square level (0.0 - 1.0)
  peak: number;          // Peak amplitude (0.0 - 1.0)
  is_speech: boolean;    // VAD prediction
}
```

**Example**:
```json
{
  "rms": 0.35,
  "peak": 0.67,
  "is_speech": true
}
```

**Note**: Prefer subscribing to 'audio-level' events instead of polling this command.

---

### Text Insertion Commands

#### `insert_text`

Inserts text at the current cursor position using macOS Accessibility API.

**Request**:
```typescript
interface InsertTextRequest {
  text: string;
  focus_if_needed?: boolean;  // Default: false
}

invoke('insert_text', request: InsertTextRequest): Promise<InsertTextResult>
```

**Success Response**:
```typescript
interface InsertTextResult {
  success: boolean;
  target_application: string;  // Bundle ID of focused app
  fallback_to_clipboard: boolean;
}
```

**Example**:
```json
{
  "success": true,
  "target_application": "com.apple.TextEdit",
  "fallback_to_clipboard": false
}
```

**Error Responses**:
```typescript
{
  code: 'PERMISSION_DENIED',
  message: 'Accessibility permission not granted'
}

{
  code: 'NO_FOCUSED_ELEMENT',
  message: 'No text field in focus. Text copied to clipboard.'
}

{
  code: 'INSERTION_FAILED',
  message: 'Failed to insert text: {details}'
}
```

**Side Effects**:
- Inserts text via Swift Accessibility API
- If insertion fails, copies text to clipboard
- Updates RecordingSession.insertionSuccess

---

### Permission Commands

#### `check_permission`

Checks the status of a macOS permission.

**Request**:
```typescript
type PermissionType = 'microphone' | 'accessibility' | 'input_monitoring';

interface CheckPermissionRequest {
  permission: PermissionType;
}

invoke('check_permission', request: CheckPermissionRequest): Promise<PermissionStatus>
```

**Success Response**:
```typescript
interface PermissionStatus {
  granted: boolean;
  denied: boolean;
  not_determined: boolean;
}
```

**Example**:
```json
{
  "granted": true,
  "denied": false,
  "not_determined": false
}
```

---

#### `request_permission`

Requests a macOS permission from the user.

**Request**:
```typescript
interface RequestPermissionRequest {
  permission: PermissionType;
}

invoke('request_permission', request: RequestPermissionRequest): Promise<PermissionRequestResult>
```

**Success Response**:
```typescript
interface PermissionRequestResult {
  granted: boolean;
  requires_manual_action: boolean;  // true for accessibility
  system_settings_url?: string;     // URL to open System Settings
}
```

**Example** (Microphone):
```json
{
  "granted": true,
  "requires_manual_action": false
}
```

**Example** (Accessibility):
```json
{
  "granted": false,
  "requires_manual_action": true,
  "system_settings_url": "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
}
```

**Side Effects**:
- For microphone: Triggers system permission dialog
- For accessibility: Opens System Settings
- For input monitoring: Opens System Settings
- Polls for permission grant (accessibility only)

---

### Settings Commands

#### `get_settings`

Retrieves current user settings.

**Request**:
```typescript
invoke('get_settings'): Promise<UserSettings>
```

**Success Response**:
```typescript
// See data-model.md for full UserSettings type
{
  "version": 1,
  "hotkey": {
    "enabled": true,
    "keyCode": 49,
    "modifiers": ["command", "control"],
    "conflictDetected": false
  },
  "language": {
    "defaultLanguage": "en",
    "recentLanguages": ["en", "es"],
    "autoDetectEnabled": false,
    "downloadedModels": ["en", "es"]
  },
  // ... (see data-model.md)
}
```

---

#### `update_settings`

Updates user settings (partial update supported).

**Request**:
```typescript
interface UpdateSettingsRequest {
  settings: Partial<UserSettings>;
}

invoke('update_settings', request: UpdateSettingsRequest): Promise<UserSettings>
```

**Example**:
```typescript
await invoke('update_settings', {
  settings: {
    language: {
      defaultLanguage: 'es'
    },
    audio: {
      sensitivity: 0.5
    }
  }
});
```

**Success Response**:
```typescript
// Full updated UserSettings object
```

**Error Responses**:
```typescript
{
  code: 'VALIDATION_ERROR',
  message: 'Invalid settings: {details}',
  field: 'audio.sensitivity'
}

{
  code: 'HOTKEY_CONFLICT',
  message: 'Hotkey conflicts with system shortcut: {conflicting_hotkey}'
}
```

**Side Effects**:
- Persists settings to JSON file
- Updates AppState
- If hotkey changed, re-registers global hotkey
- If language changed, loads new ML model

---

### Statistics Commands

#### `get_statistics`

Retrieves usage statistics.

**Request**:
```typescript
type StatsPeriod = 'today' | 'week' | 'month' | 'all_time';

interface GetStatisticsRequest {
  period: StatsPeriod;
}

invoke('get_statistics', request: GetStatisticsRequest): Promise<UsageStatistics>
```

**Success Response**:
```typescript
// See data-model.md for full UsageStatistics type
{
  "id": "...",
  "date": "2026-01-02",
  "totalSessions": 42,
  "successfulSessions": 39,
  "failedSessions": 3,
  "totalWordsTranscribed": 1250,
  "totalDurationMs": 125000,
  "averageConfidence": 0.94,
  "languageBreakdown": [
    { "languageCode": "en", "sessionCount": 35, "wordCount": 1050 },
    { "languageCode": "es", "sessionCount": 7, "wordCount": 200 }
  ],
  "errorBreakdown": [
    { "errorType": "TRANSCRIPTION_FAILED", "count": 2 },
    { "errorType": "NO_FOCUSED_ELEMENT", "count": 1 }
  ]
}
```

---

#### `clear_statistics`

Clears usage statistics.

**Request**:
```typescript
invoke('clear_statistics'): Promise<void>
```

**Success Response**:
```typescript
void
```

**Side Effects**:
- Deletes all rows from SQLite stats.db
- Resets in-memory statistics

---

### Language Model Commands

#### `list_language_models`

Lists all available language models and their download status.

**Request**:
```typescript
invoke('list_language_models'): Promise<LanguageModel[]>
```

**Success Response**:
```typescript
// See data-model.md for full LanguageModel type
[
  {
    "languageCode": "en",
    "displayName": "English",
    "modelPath": "/Users/.../models/parakeet-tdt-0.6b-en",
    "downloadStatus": { "type": "downloaded" },
    "fileSize": 524288000,
    "downloadedAt": "2026-01-01T10:00:00Z",
    "lastUsed": "2026-01-02T14:30:00Z",
    "version": "0.6b-v3",
    "checksumSHA256": "abc123..."
  },
  {
    "languageCode": "es",
    "displayName": "Español",
    "downloadStatus": {
      "type": "downloading",
      "progress": 0.67,
      "bytesDownloaded": 350000000
    },
    "fileSize": 524288000,
    // ...
  }
]
```

---

#### `download_language_model`

Downloads a language model.

**Request**:
```typescript
interface DownloadLanguageModelRequest {
  language_code: string;
}

invoke('download_language_model', request: DownloadLanguageModelRequest): Promise<DownloadProgress>
```

**Success Response**:
```typescript
interface DownloadProgress {
  language_code: string;
  status: 'queued' | 'downloading' | 'completed' | 'error';
  progress: number;              // 0.0 - 1.0
  bytes_downloaded: number;
  total_bytes: number;
  estimated_seconds_remaining?: number;
}
```

**Error Responses**:
```typescript
{
  code: 'INVALID_LANGUAGE',
  message: 'Language code not supported: {language_code}'
}

{
  code: 'ALREADY_DOWNLOADING',
  message: 'Model download already in progress'
}

{
  code: 'DOWNLOAD_FAILED',
  message: 'Failed to download model: {details}'
}

{
  code: 'CHECKSUM_MISMATCH',
  message: 'Downloaded model checksum does not match expected value'
}
```

**Side Effects**:
- Spawns background download task
- Emits 'download-progress' events
- Updates LanguageModel metadata in SQLite
- Verifies checksum after download

---

#### `delete_language_model`

Deletes a downloaded language model.

**Request**:
```typescript
interface DeleteLanguageModelRequest {
  language_code: string;
}

invoke('delete_language_model', request: DeleteLanguageModelRequest): Promise<void>
```

**Success Response**:
```typescript
void
```

**Error Responses**:
```typescript
{
  code: 'MODEL_NOT_FOUND',
  message: 'Language model not downloaded: {language_code}'
}

{
  code: 'CANNOT_DELETE_ACTIVE',
  message: 'Cannot delete currently active language model'
}
```

**Side Effects**:
- Deletes model files from disk
- Updates LanguageModel metadata
- Frees disk space (~500MB)

---

### Utility Commands

#### `register_hotkey`

Registers a global hotkey.

**Request**:
```typescript
interface RegisterHotkeyRequest {
  key_code: number;
  modifiers: KeyModifier[];
}

invoke('register_hotkey', request: RegisterHotkeyRequest): Promise<HotkeyRegistrationResult>
```

**Success Response**:
```typescript
interface HotkeyRegistrationResult {
  success: boolean;
  conflict_detected: boolean;
  conflicting_app?: string;
}
```

**Example**:
```json
{
  "success": true,
  "conflict_detected": false
}
```

**Error Responses**:
```typescript
{
  code: 'PERMISSION_DENIED',
  message: 'Input monitoring permission not granted'
}

{
  code: 'HOTKEY_CONFLICT',
  message: 'Hotkey already registered by: {app_name}',
  conflicting_app: 'com.apple.Spotlight'
}
```

**Side Effects**:
- Registers hotkey via Swift FFI
- Updates UserSettings.hotkey.conflictDetected
- Emits 'hotkey-pressed' events when triggered

---

#### `get_audio_devices`

Lists available audio input devices.

**Request**:
```typescript
invoke('get_audio_devices'): Promise<AudioDevice[]>
```

**Success Response**:
```typescript
interface AudioDevice {
  id: string;
  name: string;
  is_default: boolean;
  channels: number;
  sample_rate: number;
}
```

**Example**:
```json
[
  {
    "id": "default",
    "name": "Built-in Microphone",
    "is_default": true,
    "channels": 1,
    "sample_rate": 48000
  },
  {
    "id": "external_usb_mic_01",
    "name": "Blue Yeti Microphone",
    "is_default": false,
    "channels": 2,
    "sample_rate": 48000
  }
]
```

---

## Event Emissions (Rust → Frontend)

### `audio-level`

Emitted during recording (30fps) with real-time audio levels.

**Payload**:
```typescript
interface AudioLevelEvent {
  rms: number;           // 0.0 - 1.0
  peak: number;          // 0.0 - 1.0
  is_speech: boolean;
  timestamp: number;     // milliseconds since recording started
}
```

**Frontend Usage**:
```typescript
import { listen } from '@tauri-apps/api/event';

const unlisten = await listen<AudioLevelEvent>('audio-level', (event) => {
  updateWaveform(event.payload.peak);
});
```

---

### `transcription-progress`

Emitted during transcription with progress updates.

**Payload**:
```typescript
interface TranscriptionProgressEvent {
  percent: number;       // 0 - 100
  stage: 'preprocessing' | 'inference' | 'decoding' | 'postprocessing';
  estimated_seconds_remaining?: number;
}
```

---

### `download-progress`

Emitted during language model download.

**Payload**:
```typescript
interface DownloadProgressEvent {
  language_code: string;
  progress: number;      // 0.0 - 1.0
  bytes_downloaded: number;
  total_bytes: number;
  download_speed_mbps: number;
}
```

---

### `hotkey-pressed`

Emitted when the registered global hotkey is pressed.

**Payload**:
```typescript
interface HotkeyPressedEvent {
  key_code: number;
  modifiers: KeyModifier[];
  timestamp: number;
}
```

**Frontend Usage**:
```typescript
await listen('hotkey-pressed', () => {
  // Trigger recording modal
  showRecordingModal();
});
```

---

## Error Handling

All commands follow a consistent error structure:

```typescript
interface TauriError {
  code: string;          // Machine-readable error code
  message: string;       // Human-readable error message
  field?: string;        // Optional field name for validation errors
  details?: unknown;     // Optional additional error context
}
```

**Frontend Error Handling**:
```typescript
try {
  const result = await invoke('start_recording');
} catch (error) {
  if (error.code === 'PERMISSION_DENIED') {
    showPermissionPrompt();
  } else if (error.code === 'DEVICE_UNAVAILABLE') {
    showDeviceSelectionDialog();
  } else {
    showGenericError(error.message);
  }
}
```

---

## TypeScript Type Generation

Use Tauri's type generation to auto-generate TypeScript types from Rust structs:

```rust
// src-tauri/src/commands.rs
#[derive(serde::Serialize, serde::Deserialize, specta::Type)]
#[serde(rename_all = "camelCase")]
pub struct TranscriptionResult {
    pub text: String,
    pub confidence: f32,
    pub duration_ms: u64,
    pub word_count: usize,
    pub segments: Vec<TranscriptionSegment>,
}
```

**Generate types**:
```bash
cargo tauri dev --export-types
# Outputs: src/types/tauri-commands.ts
```

---

**Contract Complete**: All Tauri IPC commands defined with request/response schemas, error codes, and event emissions.
