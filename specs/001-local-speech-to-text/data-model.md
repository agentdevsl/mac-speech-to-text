# Data Model: macOS Local Speech-to-Text Application

**Feature**: 001-local-speech-to-text
**Date**: 2026-01-02
**Purpose**: Define core entities, relationships, and state management patterns

---

## Entity Definitions

### 1. RecordingSession

Represents a single speech-to-text capture event from start to completion.

**Attributes**:
```typescript
interface RecordingSession {
  id: string;                    // UUID v4
  startTime: Date;               // ISO 8601 timestamp
  endTime: Date | null;          // null if in progress
  duration: number;              // milliseconds
  audioData: Int16Array | null;  // Raw audio samples (16kHz mono)
  transcribedText: string;       // Final transcription
  language: string;              // Language code (e.g., 'en', 'es')
  confidenceScore: number;       // 0.0 - 1.0
  insertionSuccess: boolean;     // Whether text was inserted successfully
  errorMessage: string | null;   // Error details if failed
  peakAmplitude: number;         // For statistics
  wordCount: number;             // Calculated from transcribedText
  segments: TranscriptionSegment[]; // Word-level timestamps
}

interface TranscriptionSegment {
  text: string;                  // Word or phrase
  startTime: number;             // Milliseconds from recording start
  endTime: number;
  confidence: number;            // 0.0 - 1.0
}
```

**Relationships**:
- Many RecordingSessions → One UserSettings (language preference)
- Many RecordingSessions → One LanguageModel (used for transcription)
- Many RecordingSessions contribute to UsageStatistics

**Lifecycle**:
1. Created when user triggers hotkey (status: `recording`)
2. Updated when audio capture starts (audioData populated)
3. Updated when silence detected (endTime set, status: `transcribing`)
4. Updated when transcription completes (transcribedText populated)
5. Updated when text inserted (insertionSuccess set)
6. Persisted to statistics (if successful)

**Storage**: In-memory during session, statistics aggregated to SQLite

**Validation Rules**:
- `id` must be valid UUID v4
- `startTime` cannot be in the future
- `endTime` must be after `startTime`
- `duration` = `endTime - startTime`
- `language` must be one of supported languages
- `confidenceScore` must be between 0.0 and 1.0
- `audioData` sample rate must be 16000 Hz
- `wordCount` calculated as `transcribedText.split(/\s+/).length`

---

### 2. UserSettings

Represents persistent user configuration stored locally.

**Attributes**:
```typescript
interface UserSettings {
  version: number;                        // Schema version for migration
  hotkey: HotkeyConfiguration;
  language: LanguageConfiguration;
  audio: AudioConfiguration;
  ui: UIConfiguration;
  privacy: PrivacyConfiguration;
  onboarding: OnboardingState;
  lastModified: Date;
}

interface HotkeyConfiguration {
  enabled: boolean;
  keyCode: number;                        // Virtual key code
  modifiers: KeyModifier[];               // ['command', 'control', 'space']
  conflictDetected: boolean;
  alternativeHotkey: HotkeyConfiguration | null;
}

type KeyModifier = 'command' | 'control' | 'option' | 'shift';

interface LanguageConfiguration {
  defaultLanguage: string;                // Primary language code
  recentLanguages: string[];              // Last 5 used languages
  autoDetectEnabled: boolean;
  downloadedModels: string[];             // List of available language codes
}

interface AudioConfiguration {
  inputDeviceId: string | null;           // null = system default
  sensitivity: number;                    // 0.0 - 1.0, controls noise gate
  silenceThreshold: number;               // milliseconds (500 - 3000)
  noiseSuppression: boolean;
  autoGainControl: boolean;
}

interface UIConfiguration {
  theme: 'light' | 'dark' | 'system';
  modalPosition: 'center' | 'cursor';
  showWaveform: boolean;
  showConfidenceIndicator: boolean;
  animationsEnabled: boolean;
  menuBarIcon: 'default' | 'minimal';
}

interface PrivacyConfiguration {
  collectAnonymousStats: boolean;         // Word count, session count only
  storagePolicy: 'none' | 'session-only' | 'persistent';
  dataRetentionDays: number;              // 0, 7, 30, 90, 365
}

interface OnboardingState {
  completed: boolean;
  currentStep: number;
  permissionsGranted: {
    microphone: boolean;
    accessibility: boolean;
    inputMonitoring: boolean;
  };
  skippedSteps: string[];
}
```

**Relationships**:
- One UserSettings per application installation
- Influences all RecordingSessions (language, audio config)
- Determines which LanguageModels are downloaded

**Storage**: JSON file via Tauri Store plugin at:
- macOS: `~/Library/Application Support/com.example.speech-to-text/settings.json`

**Validation Rules**:
- `hotkey.keyCode` must be valid macOS virtual key code
- `language.defaultLanguage` must be in supported languages list
- `audio.sensitivity` must be between 0.0 and 1.0
- `audio.silenceThreshold` must be between 500 and 3000 ms
- `ui.theme` must be 'light', 'dark', or 'system'
- `privacy.dataRetentionDays` must be 0, 7, 30, 90, or 365
- `onboarding.currentStep` must be >= 0 and <= 5

**Default Values**:
```typescript
const DEFAULT_SETTINGS: UserSettings = {
  version: 1,
  hotkey: {
    enabled: true,
    keyCode: 49,              // Space key
    modifiers: ['command', 'control'],
    conflictDetected: false,
    alternativeHotkey: null,
  },
  language: {
    defaultLanguage: 'en',
    recentLanguages: ['en'],
    autoDetectEnabled: false,
    downloadedModels: ['en'],
  },
  audio: {
    inputDeviceId: null,      // System default
    sensitivity: 0.3,
    silenceThreshold: 1500,   // 1.5 seconds
    noiseSuppression: true,
    autoGainControl: true,
  },
  ui: {
    theme: 'system',
    modalPosition: 'center',
    showWaveform: true,
    showConfidenceIndicator: true,
    animationsEnabled: true,
    menuBarIcon: 'default',
  },
  privacy: {
    collectAnonymousStats: true,
    storagePolicy: 'session-only',
    dataRetentionDays: 7,
  },
  onboarding: {
    completed: false,
    currentStep: 0,
    permissionsGranted: {
      microphone: false,
      accessibility: false,
      inputMonitoring: false,
    },
    skippedSteps: [],
  },
  lastModified: new Date(),
};
```

---

### 3. LanguageModel

Represents a downloaded ML model for a specific language.

**Attributes**:
```typescript
interface LanguageModel {
  languageCode: string;                   // ISO 639-1 code
  displayName: string;                    // Native name (e.g., "Español")
  modelPath: string;                      // Absolute filesystem path
  downloadStatus: DownloadStatus;
  fileSize: number;                       // Bytes
  downloadedAt: Date | null;
  lastUsed: Date | null;
  version: string;                        // Model version (e.g., "0.6b-v3")
  checksumSHA256: string;                 // Verify integrity
}

type DownloadStatus =
  | { type: 'not_downloaded' }
  | { type: 'downloading'; progress: number; bytesDownloaded: number }
  | { type: 'downloaded' }
  | { type: 'error'; message: string };
```

**Supported Languages** (25 total):
```typescript
const SUPPORTED_LANGUAGES: Record<string, string> = {
  'en': 'English',
  'es': 'Español',
  'fr': 'Français',
  'de': 'Deutsch',
  'it': 'Italiano',
  'pt': 'Português',
  'ru': 'Русский',
  'zh': '中文',
  'ja': '日本語',
  'ko': '한국어',
  'ar': 'العربية',
  'hi': 'हिन्दी',
  'tr': 'Türkçe',
  'pl': 'Polski',
  'nl': 'Nederlands',
  'sv': 'Svenska',
  'da': 'Dansk',
  'no': 'Norsk',
  'fi': 'Suomi',
  'cs': 'Čeština',
  'ro': 'Română',
  'uk': 'Українська',
  'el': 'Ελληνικά',
  'he': 'עברית',
  'th': 'ไทย',
  'vi': 'Tiếng Việt',
};
```

**Relationships**:
- Many LanguageModels available per installation
- One LanguageModel used per RecordingSession
- UserSettings determines which models are downloaded

**Storage**:
- Model files: `~/Library/Application Support/com.example.speech-to-text/models/parakeet-tdt-0.6b-{lang}/`
- Metadata: SQLite database

**Validation Rules**:
- `languageCode` must be in SUPPORTED_LANGUAGES
- `modelPath` must exist if downloadStatus is 'downloaded'
- `fileSize` must match actual file size
- `checksumSHA256` must match calculated hash
- `downloadStatus.progress` must be between 0.0 and 1.0

**File Structure**:
```text
models/
├── parakeet-tdt-0.6b-en/
│   ├── config.json
│   ├── weights.safetensors
│   └── tokenizer.json
├── parakeet-tdt-0.6b-es/
│   └── ...
└── metadata.db (SQLite)
```

---

### 4. UsageStatistics

Represents aggregated usage metrics without storing sensitive content.

**Attributes**:
```typescript
interface UsageStatistics {
  id: string;                             // UUID
  date: Date;                             // Day bucket (midnight UTC)
  totalSessions: number;
  successfulSessions: number;
  failedSessions: number;
  totalWordsTranscribed: number;
  totalDurationMs: number;
  averageConfidence: number;              // 0.0 - 1.0
  languageBreakdown: LanguageStats[];
  errorBreakdown: ErrorStats[];
}

interface LanguageStats {
  languageCode: string;
  sessionCount: number;
  wordCount: number;
}

interface ErrorStats {
  errorType: string;                      // e.g., 'permission_denied', 'model_error'
  count: number;
}

interface AggregatedStats {
  today: UsageStatistics;
  thisWeek: UsageStatistics;
  thisMonth: UsageStatistics;
  allTime: UsageStatistics;
}
```

**Privacy Guarantees**:
- NO transcribed text is stored
- NO audio data is stored
- Only aggregate counts and averages
- User can disable collection via UserSettings.privacy.collectAnonymousStats
- Data can be cleared via Settings

**Relationships**:
- Many RecordingSessions contribute to one daily UsageStatistics
- UsageStatistics aggregated into weekly/monthly views

**Storage**: SQLite database at:
- macOS: `~/Library/Application Support/com.example.speech-to-text/stats.db`

**Queries**:
```sql
-- Daily statistics
CREATE TABLE daily_stats (
    id TEXT PRIMARY KEY,
    date TEXT NOT NULL,  -- ISO 8601 date (YYYY-MM-DD)
    total_sessions INTEGER DEFAULT 0,
    successful_sessions INTEGER DEFAULT 0,
    failed_sessions INTEGER DEFAULT 0,
    total_words INTEGER DEFAULT 0,
    total_duration_ms INTEGER DEFAULT 0,
    average_confidence REAL DEFAULT 0.0,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

-- Language breakdown
CREATE TABLE language_stats (
    id TEXT PRIMARY KEY,
    daily_stat_id TEXT NOT NULL,
    language_code TEXT NOT NULL,
    session_count INTEGER DEFAULT 0,
    word_count INTEGER DEFAULT 0,
    FOREIGN KEY (daily_stat_id) REFERENCES daily_stats(id)
);

-- Error tracking
CREATE TABLE error_stats (
    id TEXT PRIMARY KEY,
    daily_stat_id TEXT NOT NULL,
    error_type TEXT NOT NULL,
    count INTEGER DEFAULT 0,
    FOREIGN KEY (daily_stat_id) REFERENCES daily_stats(id)
);
```

**Retention Policy**:
- Daily stats retained per UserSettings.privacy.dataRetentionDays
- Auto-delete rows older than retention period
- Run cleanup on app start and daily at midnight

---

### 5. AudioBuffer

Represents in-memory audio data during recording.

**Attributes**:
```typescript
interface AudioBuffer {
  samples: Int16Array;                    // Raw audio samples
  sampleRate: number;                     // Always 16000 Hz
  channels: number;                       // Always 1 (mono)
  duration: number;                       // milliseconds
  peakAmplitude: number;                  // Max absolute value
  rmsLevel: number;                       // Root mean square energy
  timestamp: Date;                        // When buffer was created
}

interface StreamingAudioBuffer {
  chunks: AudioBuffer[];                  // Array of audio segments
  totalDuration: number;                  // Sum of all chunk durations
  maxChunkSize: number;                   // 100ms chunks (1600 samples)
  isComplete: boolean;
}
```

**Lifecycle**:
1. Created when recording starts
2. Updated every 100ms with new audio chunk
3. Analyzed for VAD (voice activity detection via FluidAudio)
4. Sent to FluidAudio Swift SDK for transcription
5. Cleared after transcription completes

**Memory Management**:
- Maximum buffer size: 2 minutes of audio = 1.92 million samples = 3.84 MB
- Automatic chunking every 100ms to prevent UI blocking
- Circular buffer pattern for long recordings
- Cleared immediately after transcription

**Validation Rules**:
- `sampleRate` must be exactly 16000 Hz
- `channels` must be 1 (mono)
- `samples` length must equal `sampleRate * duration / 1000`
- `peakAmplitude` must be <= 32767 (Int16 max)

---

## State Machine: RecordingSession Lifecycle

```
┌─────────────┐
│    IDLE     │
└─────────────┘
      │
      │ (Hotkey pressed)
      ▼
┌─────────────┐
│  RECORDING  │ ─────────┐
└─────────────┘          │
      │                  │ (Escape or click outside)
      │ (Silence         │
      │  detected)       ▼
      ▼            ┌─────────────┐
┌─────────────┐    │  CANCELLED  │
│TRANSCRIBING │    └─────────────┘
└─────────────┘          │
      │                  │
      │ (Success)        │
      ▼                  ▼
┌─────────────┐    ┌─────────────┐
│  INSERTING  │    │    IDLE     │
└─────────────┘    └─────────────┘
      │
      │ (Text inserted)
      ▼
┌─────────────┐
│  COMPLETED  │
└─────────────┘
      │
      │ (Stats saved)
      ▼
┌─────────────┐
│    IDLE     │
└─────────────┘
```

**State Transitions**:

| From | To | Trigger | Side Effects |
|------|-----|---------|--------------|
| IDLE | RECORDING | Hotkey pressed | Show modal, start audio capture, create RecordingSession |
| RECORDING | TRANSCRIBING | Silence detected (1.5s) | Stop audio capture, send to ML backend |
| RECORDING | CANCELLED | Escape key or outside click | Stop audio capture, hide modal, discard session |
| TRANSCRIBING | INSERTING | Transcription complete | Insert text via Swift bridge |
| TRANSCRIBING | CANCELLED | Transcription error | Show error, hide modal |
| INSERTING | COMPLETED | Text inserted successfully | Update stats, hide modal |
| INSERTING | CANCELLED | Text insertion failed | Show error, copy to clipboard |
| COMPLETED | IDLE | After 500ms | Clear session data |
| CANCELLED | IDLE | Immediately | Clear session data |

---

## Data Flow Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                        React Frontend                         │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  RecordingContext (React Context + State)              │  │
│  │  - currentSession: RecordingSession | null             │  │
│  │  - audioLevel: number                                  │  │
│  │  - isRecording: boolean                                │  │
│  │  - isTranscribing: boolean                             │  │
│  └────────────────────────────────────────────────────────┘  │
│               │                                    ▲           │
│               │ Tauri IPC Commands                 │           │
│               ▼                                    │           │
└───────────────┼────────────────────────────────────┼───────────┘
                │                                    │
┌───────────────┼────────────────────────────────────┼───────────┐
│               │      Rust Tauri Core               │           │
│  ┌────────────▼─────────────────────────────┐     │           │
│  │  AppState (Shared State)                 │     │           │
│  │  - settings: Arc<Mutex<UserSettings>>    │     │           │
│  │  - current_session: Arc<Mutex<Option<    │     │           │
│  │      RecordingSession>>>                 │     │           │
│  │  - ml_backend: Arc<Mutex<MLBackend>>     │     │           │
│  │  - swift_bridge: Arc<Mutex<SwiftBridge>> │     │           │
│  └──────────────────────────────────────────┘     │           │
│       │                                             │           │
│       │ (Swift FFI)                               │           │
│       ▼                                           │           │
│  ┌──────────────────────────────────┐             │           │
│  │   Swift Native + FluidAudio      │             │           │
│  │   - Hotkey                       │             │           │
│  │   - FluidAudio (ASR + VAD)       │             │           │
│  │   - Text Insert                  │             │           │
│  │   - Model Management             │             │           │
│  └──────────────────────────────────┘             │           │
└────────────────────────────────────────────────────┼───────────┘
                                                     │
┌────────────────────────────────────────────────────┼───────────┐
│                    Persistence Layer               ▼           │
│  ┌───────────────────────────────────────────────────────┐    │
│  │  Settings (JSON)    Stats (SQLite)    Models (Files)  │    │
│  │  ~/Library/...      ~/Library/...     ~/Library/...   │    │
│  └───────────────────────────────────────────────────────┘    │
└───────────────────────────────────────────────────────────────┘
```

---

## Validation & Business Rules

### Cross-Entity Rules

1. **Language Consistency**:
   - RecordingSession.language must exist in LanguageModel.languageCode
   - LanguageModel must be downloaded before use
   - UserSettings.language.defaultLanguage must have corresponding LanguageModel

2. **Permission Enforcement**:
   - Cannot start recording without UserSettings.onboarding.permissionsGranted.microphone
   - Cannot insert text without UserSettings.onboarding.permissionsGranted.accessibility
   - Hotkey registration requires UserSettings.onboarding.permissionsGranted.inputMonitoring (macOS 10.15+)

3. **Resource Limits**:
   - Maximum RecordingSession duration: 5 minutes (300,000 ms)
   - Maximum AudioBuffer size: 3.84 MB (2 minutes at 16kHz)
   - Maximum concurrent LanguageModel downloads: 1
   - Maximum installed LanguageModels: 25 (all supported languages)

4. **Data Retention**:
   - UsageStatistics retention follows UserSettings.privacy.dataRetentionDays
   - RecordingSession not persisted if UserSettings.privacy.storagePolicy is 'none'
   - Audio data always cleared immediately after transcription (privacy guarantee)

---

## Testing Considerations

### Unit Test Coverage

Each entity should have tests for:
- Constructor validation
- Attribute constraints
- Default values
- Serialization/deserialization (JSON, SQLite)
- Business rule enforcement

### Example Test (TypeScript):
```typescript
describe('RecordingSession', () => {
  it('should calculate wordCount from transcribedText', () => {
    const session = new RecordingSession({
      transcribedText: 'Hello world this is a test',
    });

    expect(session.wordCount).toBe(6);
  });

  it('should reject invalid confidence score', () => {
    expect(() => {
      new RecordingSession({ confidenceScore: 1.5 });
    }).toThrow('Confidence score must be between 0.0 and 1.0');
  });

  it('should enforce endTime after startTime', () => {
    const startTime = new Date('2026-01-02T10:00:00Z');
    const endTime = new Date('2026-01-02T09:59:00Z');

    expect(() => {
      new RecordingSession({ startTime, endTime });
    }).toThrow('endTime must be after startTime');
  });
});
```

---

**Data Model Complete**: All entities defined with attributes, relationships, validation rules, and state machine. Ready for contract generation (Phase 1 continued).
