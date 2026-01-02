# Data Model: macOS Local Speech-to-Text Application

**Feature**: 001-local-speech-to-text
**Date**: 2026-01-02
**Purpose**: Define core entities, relationships, and state management patterns

---

## Entity Definitions

### 1. RecordingSession

Represents a single speech-to-text capture event from start to completion.

**Attributes**:
```swift
struct RecordingSession {
  let id: UUID                   // UUID v4
  let startTime: Date            // ISO 8601 timestamp
  var endTime: Date?             // nil if in progress
  var duration: TimeInterval     // seconds
  var audioData: [Int16]?        // Raw audio samples (16kHz mono)
  var transcribedText: String    // Final transcription
  let language: String           // Language code (e.g., 'en', 'es')
  var confidenceScore: Double    // 0.0 - 1.0
  var insertionSuccess: Bool     // Whether text was inserted successfully
  var errorMessage: String?      // Error details if failed
  var peakAmplitude: Int16       // For statistics
  var wordCount: Int             // Calculated from transcribedText
  var segments: [TranscriptionSegment] // Word-level timestamps
}

struct TranscriptionSegment {
  let text: String               // Word or phrase
  let startTime: TimeInterval    // Seconds from recording start
  let endTime: TimeInterval
  let confidence: Double         // 0.0 - 1.0
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
- `duration` = `endTime.timeIntervalSince(startTime)`
- `language` must be one of supported languages
- `confidenceScore` must be between 0.0 and 1.0
- `audioData` sample rate must be 16000 Hz
- `wordCount` calculated as `transcribedText.components(separatedBy: .whitespaces).count`

---

### 2. UserSettings

Represents persistent user configuration stored locally.

**Attributes**:
```swift
struct UserSettings: Codable {
  var version: Int                        // Schema version for migration
  var hotkey: HotkeyConfiguration
  var language: LanguageConfiguration
  var audio: AudioConfiguration
  var ui: UIConfiguration
  var privacy: PrivacyConfiguration
  var onboarding: OnboardingState
  var lastModified: Date
}

struct HotkeyConfiguration: Codable {
  var enabled: Bool
  var keyCode: Int                        // Virtual key code
  var modifiers: [KeyModifier]            // [.command, .control, etc.]
  var conflictDetected: Bool
  var alternativeHotkey: HotkeyConfiguration?
}

enum KeyModifier: String, Codable {
  case command
  case control
  case option
  case shift
}

struct LanguageConfiguration: Codable {
  var defaultLanguage: String             // Primary language code
  var recentLanguages: [String]           // Last 5 used languages
  var autoDetectEnabled: Bool
  var downloadedModels: [String]          // List of available language codes
}

struct AudioConfiguration: Codable {
  var inputDeviceId: String?              // nil = system default
  var sensitivity: Double                 // 0.0 - 1.0, controls noise gate
  var silenceThreshold: TimeInterval      // seconds (0.5 - 3.0)
  var noiseSuppression: Bool
  var autoGainControl: Bool
}

struct UIConfiguration: Codable {
  var theme: Theme
  var modalPosition: ModalPosition
  var showWaveform: Bool
  var showConfidenceIndicator: Bool
  var animationsEnabled: Bool
  var menuBarIcon: MenuBarIcon
}

enum Theme: String, Codable {
  case light
  case dark
  case system
}

enum ModalPosition: String, Codable {
  case center
  case cursor
}

enum MenuBarIcon: String, Codable {
  case `default`
  case minimal
}

struct PrivacyConfiguration: Codable {
  var collectAnonymousStats: Bool         // Word count, session count only
  var storagePolicy: StoragePolicy
  var dataRetentionDays: Int              // 0, 7, 30, 90, 365
}

enum StoragePolicy: String, Codable {
  case none
  case sessionOnly
  case persistent
}

struct OnboardingState: Codable {
  var completed: Bool
  var currentStep: Int
  var permissionsGranted: PermissionsGranted
  var skippedSteps: [String]
}

struct PermissionsGranted: Codable {
  var microphone: Bool
  var accessibility: Bool
  var inputMonitoring: Bool
}
```

**Relationships**:
- One UserSettings per application installation
- Influences all RecordingSessions (language, audio config)
- Determines which LanguageModels are downloaded

**Storage**: JSON file via UserDefaults or PropertyListEncoder at:
- macOS: `~/Library/Application Support/com.example.speech-to-text/settings.json`

**Validation Rules**:
- `hotkey.keyCode` must be valid macOS virtual key code
- `language.defaultLanguage` must be in supported languages list
- `audio.sensitivity` must be between 0.0 and 1.0
- `audio.silenceThreshold` must be between 0.5 and 3.0 seconds
- `ui.theme` must be .light, .dark, or .system
- `privacy.dataRetentionDays` must be 0, 7, 30, 90, or 365
- `onboarding.currentStep` must be >= 0 and <= 5

**Default Values**:
```swift
extension UserSettings {
  static let `default` = UserSettings(
    version: 1,
    hotkey: HotkeyConfiguration(
      enabled: true,
      keyCode: 49,              // Space key
      modifiers: [.command, .control],
      conflictDetected: false,
      alternativeHotkey: nil
    ),
    language: LanguageConfiguration(
      defaultLanguage: "en",
      recentLanguages: ["en"],
      autoDetectEnabled: false,
      downloadedModels: ["en"]
    ),
    audio: AudioConfiguration(
      inputDeviceId: nil,       // System default
      sensitivity: 0.3,
      silenceThreshold: 1.5,    // 1.5 seconds
      noiseSuppression: true,
      autoGainControl: true
    ),
    ui: UIConfiguration(
      theme: .system,
      modalPosition: .center,
      showWaveform: true,
      showConfidenceIndicator: true,
      animationsEnabled: true,
      menuBarIcon: .default
    ),
    privacy: PrivacyConfiguration(
      collectAnonymousStats: true,
      storagePolicy: .sessionOnly,
      dataRetentionDays: 7
    ),
    onboarding: OnboardingState(
      completed: false,
      currentStep: 0,
      permissionsGranted: PermissionsGranted(
        microphone: false,
        accessibility: false,
        inputMonitoring: false
      ),
      skippedSteps: []
    ),
    lastModified: Date()
  )
}
```

---

### 3. LanguageModel

Represents a downloaded ML model for a specific language.

**Attributes**:
```swift
struct LanguageModel: Codable {
  let languageCode: String                // ISO 639-1 code
  let displayName: String                 // Native name (e.g., "Español")
  var modelPath: URL                      // Absolute filesystem path
  var downloadStatus: DownloadStatus
  let fileSize: Int64                     // Bytes
  var downloadedAt: Date?
  var lastUsed: Date?
  let version: String                     // Model version (e.g., "0.6b-v3")
  let checksumSHA256: String              // Verify integrity
}

enum DownloadStatus: Codable {
  case notDownloaded
  case downloading(progress: Double, bytesDownloaded: Int64)
  case downloaded
  case error(message: String)
}
```

**Supported Languages** (25 total):
```swift
enum SupportedLanguage: String, CaseIterable, Codable {
  case en, es, fr, de, it, pt, ru, zh, ja, ko
  case ar, hi, tr, pl, nl, sv, da, no, fi, cs
  case ro, uk, el, he, th, vi

  var displayName: String {
    switch self {
    case .en: return "English"
    case .es: return "Español"
    case .fr: return "Français"
    case .de: return "Deutsch"
    case .it: return "Italiano"
    case .pt: return "Português"
    case .ru: return "Русский"
    case .zh: return "中文"
    case .ja: return "日本語"
    case .ko: return "한국어"
    case .ar: return "العربية"
    case .hi: return "हिन्दी"
    case .tr: return "Türkçe"
    case .pl: return "Polski"
    case .nl: return "Nederlands"
    case .sv: return "Svenska"
    case .da: return "Dansk"
    case .no: return "Norsk"
    case .fi: return "Suomi"
    case .cs: return "Čeština"
    case .ro: return "Română"
    case .uk: return "Українська"
    case .el: return "Ελληνικά"
    case .he: return "עברית"
    case .th: return "ไทย"
    case .vi: return "Tiếng Việt"
    }
  }
}
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
```swift
struct UsageStatistics: Codable {
  let id: UUID
  let date: Date                          // Day bucket (midnight UTC)
  var totalSessions: Int
  var successfulSessions: Int
  var failedSessions: Int
  var totalWordsTranscribed: Int
  var totalDurationSeconds: TimeInterval
  var averageConfidence: Double           // 0.0 - 1.0
  var languageBreakdown: [LanguageStats]
  var errorBreakdown: [ErrorStats]
}

struct LanguageStats: Codable {
  let languageCode: String
  var sessionCount: Int
  var wordCount: Int
}

struct ErrorStats: Codable {
  let errorType: String                   // e.g., 'permission_denied', 'model_error'
  var count: Int
}

struct AggregatedStats {
  let today: UsageStatistics
  let thisWeek: UsageStatistics
  let thisMonth: UsageStatistics
  let allTime: UsageStatistics
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
```swift
struct AudioBuffer {
  let samples: [Int16]                    // Raw audio samples
  let sampleRate: Int                     // Always 16000 Hz
  let channels: Int                       // Always 1 (mono)
  let duration: TimeInterval              // seconds
  let peakAmplitude: Int16                // Max absolute value
  let rmsLevel: Double                    // Root mean square energy
  let timestamp: Date                     // When buffer was created
}

class StreamingAudioBuffer {
  var chunks: [AudioBuffer]               // Array of audio segments
  var totalDuration: TimeInterval {       // Sum of all chunk durations
    chunks.reduce(0) { $0 + $1.duration }
  }
  let maxChunkSize: Int                   // 100ms chunks (1600 samples)
  var isComplete: Bool

  init(maxChunkSize: Int = 1600) {
    self.chunks = []
    self.maxChunkSize = maxChunkSize
    self.isComplete = false
  }
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
- `samples` length must equal `Int(Double(sampleRate) * duration)`
- `peakAmplitude` must be <= Int16.max (32767)

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
│                      SwiftUI Frontend                         │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  RecordingViewModel (@ObservableObject)                │  │
│  │  - @Published currentSession: RecordingSession?        │  │
│  │  - @Published audioLevel: Double                       │  │
│  │  - @Published isRecording: Bool                        │  │
│  │  - @Published isTranscribing: Bool                     │  │
│  └────────────────────────────────────────────────────────┘  │
│               │                                    ▲           │
│               │ Swift Method Calls                 │           │
│               ▼                                    │           │
└───────────────┼────────────────────────────────────┼───────────┘
                │                                    │
┌───────────────┼────────────────────────────────────┼───────────┐
│               │      Swift App Layer               │           │
│  ┌────────────▼─────────────────────────────┐     │           │
│  │  AppState (Shared State)                 │     │           │
│  │  - settings: UserSettings                │     │           │
│  │  - currentSession: RecordingSession?     │     │           │
│  │  - audioManager: AudioManager            │     │           │
│  │  - transcriptionManager: Manager         │     │           │
│  │  - hotkeyManager: HotkeyManager          │     │           │
│  └──────────────────────────────────────────┘     │           │
│       │                                             │           │
│       │ (FluidAudio SDK)                          │           │
│       ▼                                           │           │
│  ┌──────────────────────────────────┐             │           │
│  │   FluidAudio Swift SDK           │             │           │
│  │   - Speech Recognition (ASR)     │             │           │
│  │   - Voice Activity Detection     │             │           │
│  │   - Model Management             │             │           │
│  │   - Audio Processing             │             │           │
│  └──────────────────────────────────┘             │           │
│       │                                             │           │
│       │ (macOS APIs)                              │           │
│       ▼                                           │           │
│  ┌──────────────────────────────────┐             │           │
│  │   macOS System APIs              │             │           │
│  │   - AVFoundation (Audio)         │             │           │
│  │   - Accessibility (Text Insert)  │             │           │
│  │   - Carbon (Hotkey Registration) │             │           │
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

### Example Test (Swift with XCTest):
```swift
import XCTest
@testable import SpeechToText

class RecordingSessionTests: XCTestCase {
  func testWordCountCalculation() {
    var session = RecordingSession(
      id: UUID(),
      startTime: Date(),
      language: "en"
    )
    session.transcribedText = "Hello world this is a test"

    XCTAssertEqual(session.wordCount, 6)
  }

  func testInvalidConfidenceScore() {
    var session = RecordingSession(
      id: UUID(),
      startTime: Date(),
      language: "en"
    )

    // Should fail validation when confidence > 1.0
    session.confidenceScore = 1.5
    XCTAssertFalse(session.isValid, "Confidence score must be between 0.0 and 1.0")
  }

  func testEndTimeAfterStartTime() {
    let startTime = Date(timeIntervalSince1970: 1735819200) // 2026-01-02 10:00:00 UTC
    let endTime = Date(timeIntervalSince1970: 1735819140)   // 2026-01-02 09:59:00 UTC

    var session = RecordingSession(
      id: UUID(),
      startTime: startTime,
      language: "en"
    )
    session.endTime = endTime

    XCTAssertFalse(session.isValid, "endTime must be after startTime")
  }
}
```

---

**Data Model Complete**: All entities defined with attributes, relationships, validation rules, and state machine. Ready for contract generation (Phase 1 continued).
