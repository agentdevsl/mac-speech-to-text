# Swift macOS Application Development Guidelines

## Project Overview

**Speech-to-Text macOS Application**: A privacy-focused, local-first menu bar application for speech-to-text capture using the FluidAudio SDK.

- **Language**: Swift 5.9+ (Swift 6 concurrency enabled)
- **Platform**: macOS 14+
- **Architecture**: Pure Swift (SwiftUI + AppKit hybrid)
- **Build System**: Swift Package Manager
- **Testing**: XCTest framework

---

## AI Assistant Rules

> **Read this section first.** These are hard constraints for code generation.

### MUST

- Use Swift 5.9+ with async/await for all asynchronous operations
- Use Swift actors for thread-safe concurrent access to shared mutable state
- Use @Observable macro (not deprecated @StateObject/@ObservableObject)
- Use @MainActor for UI-bound classes and methods
- Write tests FIRST before implementation (TDD with XCTest)
- Use SwiftLint for code quality enforcement
- Use explicit types for public APIs (no implicit type inference at boundaries)
- Use `let` by default, `var` only when mutation is required
- Implement proper error handling with custom Error enums conforming to LocalizedError
- Follow the service layer pattern for business logic
- Use protocol-based design for testability (dependency injection)
- Use Sendable conformance for types shared across concurrency boundaries
- Follow the "Warm Minimalism" design aesthetic for UI components

### NEVER

- Use force unwrapping (`!`) without explicit justification and guard clauses
- Use `try!` or `try?` for error handling (use proper do-catch blocks)
- Store secrets or API keys in code or version control
- Use synchronous blocking operations on the main thread
- Skip error handling for async/throwing operations
- Use mutable global state (use @Observable or actors instead)
- Commit sensitive files (entitlements with hardcoded teams, credentials)
- Write implementation code without corresponding tests
- Use deprecated APIs (@ObservedObject, @StateObject, etc.)
- Use `print()` for production logging (use proper logging framework)
- Ignore SwiftLint warnings without justification

### PREFER

- Protocol-oriented programming over class inheritance
- Value types (struct) over reference types (class) when possible
- Composition over inheritance
- Small, focused functions (< 30 lines)
- Early returns with guard clauses
- Explicit error types (enum Error) over generic Error
- Named parameters for clarity
- Descriptive variable names over comments
- Property wrappers (@Observable, @MainActor) for clean code
- Red-Green-Refactor TDD cycle

---

## Tech Stack

| Layer | Technology | Notes |
|-------|-----------|-------|
| Language | Swift 5.9+ | Strict type safety, modern concurrency |
| UI Framework | SwiftUI | Declarative UI with @Observable state |
| System Integration | AppKit | Menu bar, hotkeys, accessibility APIs |
| Audio Processing | AVFoundation | AVAudioEngine for 16kHz mono capture |
| Speech Recognition | FluidAudio SDK | Local ML models, 25 languages |
| Testing | XCTest | Native Swift testing framework |
| Code Quality | SwiftLint | Static analysis and style enforcement |
| Build System | Swift Package Manager | Dependency management |
| Git Hooks | pre-commit | Automated quality checks |
| CI/CD | GitHub Actions | Automated testing pipeline |

---

## Test-Driven Development (TDD)

### The TDD Cycle

1. **RED**: Write a failing test that defines the expected behavior
2. **GREEN**: Write minimal code to make the test pass
3. **REFACTOR**: Improve the code while keeping tests green

### TDD Workflow Example

```swift
// Step 1: RED - Write the failing test first
import XCTest
@testable import SpeechToText

final class RecordingSessionTests: XCTestCase {
    func testSessionStartsInIdleState() {
        // Arrange
        let session = RecordingSession()

        // Act & Assert
        XCTAssertEqual(session.state, .idle)
        XCTAssertNil(session.startTime)
    }

    func testSessionTransitionsToRecording() {
        // Arrange
        var session = RecordingSession()

        // Act
        session.start()

        // Assert
        XCTAssertEqual(session.state, .recording)
        XCTAssertNotNil(session.startTime)
    }
}

// Step 2: GREEN - Implement minimal code to pass
struct RecordingSession {
    enum State {
        case idle, recording, transcribing, completed
    }

    var state: State = .idle
    var startTime: Date?

    mutating func start() {
        state = .recording
        startTime = Date()
    }
}

// Step 3: REFACTOR - Add validation, error handling
struct RecordingSession {
    // ... existing code ...

    mutating func start() throws {
        guard state == .idle else {
            throw RecordingError.invalidStateTransition(from: state, to: .recording)
        }
        state = .recording
        startTime = Date()
    }
}
```

### Test Structure

```swift
import XCTest
@testable import SpeechToText

final class FluidAudioServiceTests: XCTestCase {
    // MARK: - Properties
    var sut: FluidAudioService!
    var mockPermissionService: MockPermissionService!

    // MARK: - Setup & Teardown
    override func setUp() async throws {
        try await super.setUp()
        mockPermissionService = MockPermissionService()
        sut = FluidAudioService(permissionService: mockPermissionService)
    }

    override func tearDown() async throws {
        sut = nil
        mockPermissionService = nil
        try await super.tearDown()
    }

    // MARK: - Tests
    func testInitializeCreatesASRManager() async throws {
        // Arrange
        let modelPath = "/path/to/model"

        // Act
        try await sut.initialize(modelPath: modelPath)

        // Assert
        let isInitialized = await sut.isInitialized
        XCTAssertTrue(isInitialized)
    }

    func testTranscribeThrowsWhenNotInitialized() async {
        // Arrange
        let audioData = Data()

        // Act & Assert
        await XCTAssertThrowsError(
            try await sut.transcribe(audioData: audioData)
        ) { error in
            XCTAssertEqual(error as? FluidAudioError, .notInitialized)
        }
    }
}
```

---

## Architecture

### Project Structure

```
SpeechToText/
├── Sources/
│   ├── SpeechToTextApp/          # App entry point
│   │   ├── SpeechToTextApp.swift # @main App struct
│   │   ├── AppDelegate.swift     # macOS lifecycle & menu bar
│   │   └── AppState.swift        # @Observable app state
│   │
│   ├── Services/                 # Business logic layer
│   │   ├── FluidAudioService.swift      # actor for ML model
│   │   ├── AudioCaptureService.swift    # AVAudioEngine wrapper
│   │   ├── PermissionService.swift      # macOS permissions
│   │   ├── HotkeyService.swift          # Global hotkey registration
│   │   ├── TextInsertionService.swift   # Accessibility text insertion
│   │   ├── SettingsService.swift        # UserDefaults persistence
│   │   └── StatisticsService.swift      # Usage tracking
│   │
│   ├── Models/                   # Data structures
│   │   ├── RecordingSession.swift
│   │   ├── UserSettings.swift
│   │   ├── LanguageModel.swift
│   │   ├── UsageStatistics.swift
│   │   └── AudioBuffer.swift
│   │
│   ├── Views/                    # SwiftUI views
│   │   ├── MenuBarView.swift
│   │   ├── RecordingModal.swift
│   │   ├── RecordingViewModel.swift
│   │   ├── OnboardingView.swift
│   │   ├── OnboardingViewModel.swift
│   │   └── Components/
│   │       ├── WaveformView.swift
│   │       └── PermissionCard.swift
│   │
│   └── Utilities/
│       ├── Constants.swift
│       └── Extensions/
│           └── Color+Theme.swift
│
├── Tests/
│   └── SpeechToTextTests/
│       ├── Models/               # Model tests (5 files)
│       ├── Services/             # Service tests (7 files)
│       ├── App/                  # App state tests
│       └── Utilities/            # Utility tests
│
├── Resources/                    # Assets, models
├── Package.swift                 # SPM manifest
├── .swiftlint.yml               # Linting config
└── SpeechToText.entitlements    # macOS permissions

```

### Service Layer Pattern

```swift
// Services/AudioCaptureService.swift
import AVFoundation

enum AudioCaptureError: LocalizedError {
    case engineStartFailed
    case noInputNode
    case invalidFormat

    var errorDescription: String? {
        switch self {
        case .engineStartFailed: return "Failed to start audio engine"
        case .noInputNode: return "No audio input available"
        case .invalidFormat: return "Invalid audio format"
        }
    }
}

@MainActor
class AudioCaptureService {
    private let audioEngine = AVAudioEngine()
    private var streamingBuffer: StreamingAudioBuffer?

    func startCapture(levelCallback: @escaping (Double) -> Void) async throws {
        guard let inputNode = audioEngine.inputNode else {
            throw AudioCaptureError.noInputNode
        }

        let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16000,
            channels: 1,
            interleaved: true
        )

        guard let format else {
            throw AudioCaptureError.invalidFormat
        }

        streamingBuffer = StreamingAudioBuffer()

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            Task { [weak self] in
                await self?.processBuffer(buffer, levelCallback: levelCallback)
            }
        }

        do {
            try audioEngine.start()
        } catch {
            throw AudioCaptureError.engineStartFailed
        }
    }

    func stopCapture() async throws -> Data {
        audioEngine.stop()
        guard let buffer = streamingBuffer else {
            return Data()
        }
        return await buffer.getData()
    }

    private func processBuffer(_ buffer: AVAudioPCMBuffer, levelCallback: @escaping (Double) -> Void) async {
        // Calculate audio level
        let level = calculateLevel(from: buffer)
        await MainActor.run {
            levelCallback(level)
        }

        // Store in buffer
        await streamingBuffer?.append(buffer)
    }
}
```

### Protocol-Based Design for Testing

```swift
// Services/PermissionService.swift
protocol PermissionChecker {
    func checkMicrophonePermission() async -> Bool
    func requestMicrophonePermission() async throws
    func checkAccessibilityPermission() -> Bool
    func openAccessibilitySettings()
}

class PermissionService: PermissionChecker {
    func checkMicrophonePermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        return status == .authorized
    }

    func requestMicrophonePermission() async throws {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        if !granted {
            throw PermissionError.microphoneDenied
        }
    }

    func checkAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }

    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}

// Tests/Services/PermissionServiceTests.swift
class MockPermissionService: PermissionChecker {
    var microphoneGranted = false
    var accessibilityGranted = false

    func checkMicrophonePermission() async -> Bool {
        return microphoneGranted
    }

    func requestMicrophonePermission() async throws {
        if !microphoneGranted {
            throw PermissionError.microphoneDenied
        }
    }

    func checkAccessibilityPermission() -> Bool {
        return accessibilityGranted
    }

    func openAccessibilitySettings() {
        // No-op in tests
    }
}
```

---

## Actor-Based Concurrency

Use Swift actors for thread-safe access to shared mutable state:

```swift
// Services/FluidAudioService.swift
import FluidAudio

actor FluidAudioService {
    private var asrManager: AsrManager?
    private var isInitialized = false

    func initialize(modelPath: String) async throws {
        let config = ASRConfig(modelPath: modelPath)
        asrManager = AsrManager(config: config)
        isInitialized = true
    }

    func transcribe(audioData: Data) async throws -> String {
        guard isInitialized, let manager = asrManager else {
            throw FluidAudioError.notInitialized
        }

        // Thread-safe access to asrManager
        let result = manager.process(audioData)
        return result.text
    }
}

// Usage from @MainActor context
@MainActor
class RecordingViewModel: Observable {
    private let fluidAudioService: FluidAudioService

    func processAudio(_ data: Data) async {
        do {
            // await needed to cross actor boundary
            let text = try await fluidAudioService.transcribe(audioData: data)
            self.transcribedText = text
        } catch {
            self.error = error
        }
    }
}
```

---

## SwiftUI + AppKit Integration

### Menu Bar Application Pattern

```swift
// SpeechToTextApp.swift
import SwiftUI

@main
struct SpeechToTextApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("Speech-to-Text", systemImage: "mic.fill") {
            MenuBarView()
                .environment(appState)
        }
        .menuBarExtraStyle(.window)
    }
}

// AppDelegate.swift
import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotkeyService: HotkeyService?
    private var recordingWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Prevent multiple instances
        if NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier!).count > 1 {
            NSApp.terminate(nil)
            return
        }

        // Setup global hotkey
        hotkeyService = HotkeyService()
        try? hotkeyService?.register { [weak self] in
            await self?.showRecordingModal()
        }
    }

    @MainActor
    private func showRecordingModal() {
        guard recordingWindow == nil else { return }

        let contentView = RecordingModal(
            viewModel: RecordingViewModel(),
            onDismiss: { [weak self] in
                self?.recordingWindow?.close()
                self?.recordingWindow = nil
            }
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.contentView = NSHostingView(rootView: contentView)
        window.backgroundColor = .clear
        window.isOpaque = false
        window.level = .floating
        window.center()
        window.makeKeyAndOrderFront(nil)

        recordingWindow = window
    }
}
```

### SwiftUI View with @Observable

```swift
// Views/RecordingViewModel.swift
import Observation

@Observable @MainActor
class RecordingViewModel {
    // MARK: - State
    enum State {
        case idle
        case recording
        case transcribing
        case completed
        case error(Error)
    }

    var state: State = .idle
    var audioLevel: Double = 0.0
    var transcribedText: String = ""
    var confidenceScore: Double = 0.0

    // MARK: - Services (injected)
    private let audioCaptureService: AudioCaptureService
    private let fluidAudioService: FluidAudioService
    private let textInsertionService: TextInsertionService

    init(
        audioCaptureService: AudioCaptureService = AudioCaptureService(),
        fluidAudioService: FluidAudioService = FluidAudioService(),
        textInsertionService: TextInsertionService = TextInsertionService()
    ) {
        self.audioCaptureService = audioCaptureService
        self.fluidAudioService = fluidAudioService
        self.textInsertionService = textInsertionService
    }

    // MARK: - Actions
    func startRecording() async {
        state = .recording

        do {
            try await audioCaptureService.startCapture { [weak self] level in
                self?.audioLevel = level
            }
        } catch {
            state = .error(error)
        }
    }

    func stopRecording() async {
        state = .transcribing

        do {
            let audioData = try await audioCaptureService.stopCapture()
            let text = try await fluidAudioService.transcribe(audioData: audioData)
            transcribedText = text

            try await textInsertionService.insertText(text)
            state = .completed
        } catch {
            state = .error(error)
        }
    }
}

// Views/RecordingModal.swift
import SwiftUI

struct RecordingModal: View {
    @State var viewModel: RecordingViewModel
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Waveform visualization
            WaveformView(audioLevel: viewModel.audioLevel)
                .frame(height: 100)

            // Status text
            Text(statusText)
                .font(.headline)

            // Transcribed text (if available)
            if !viewModel.transcribedText.isEmpty {
                Text(viewModel.transcribedText)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            // Action button
            Button(action: handleAction) {
                Text(buttonTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(width: 480, height: 320)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            Task { await viewModel.startRecording() }
        }
    }

    private var statusText: String {
        switch viewModel.state {
        case .idle: return "Ready"
        case .recording: return "Recording..."
        case .transcribing: return "Transcribing..."
        case .completed: return "Done!"
        case .error(let error): return "Error: \(error.localizedDescription)"
        }
    }

    private var buttonTitle: String {
        switch viewModel.state {
        case .recording: return "Stop Recording"
        case .completed: return "Close"
        default: return "Cancel"
        }
    }

    private func handleAction() {
        Task {
            switch viewModel.state {
            case .recording:
                await viewModel.stopRecording()
            default:
                onDismiss()
            }
        }
    }
}
```

---

## Error Handling

```swift
// Models/Errors.swift
enum RecordingError: LocalizedError {
    case permissionDenied
    case audioCaptureFailed
    case transcriptionFailed
    case invalidStateTransition(from: RecordingSession.State, to: RecordingSession.State)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission is required"
        case .audioCaptureFailed:
            return "Failed to capture audio"
        case .transcriptionFailed:
            return "Failed to transcribe audio"
        case .invalidStateTransition(let from, let to):
            return "Cannot transition from \(from) to \(to)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            return "Please grant microphone access in System Settings"
        case .audioCaptureFailed:
            return "Check your microphone connection and try again"
        case .transcriptionFailed:
            return "Try recording again with clearer audio"
        case .invalidStateTransition:
            return "Please restart the recording session"
        }
    }
}

// Usage
do {
    try await session.start()
} catch let error as RecordingError {
    print("Recording error: \(error.localizedDescription)")
    if let suggestion = error.recoverySuggestion {
        print("Suggestion: \(suggestion)")
    }
} catch {
    print("Unexpected error: \(error)")
}
```

---

## Design Aesthetic: "Warm Minimalism"

### Color Palette

```swift
// Utilities/Extensions/Color+Theme.swift
import SwiftUI

extension Color {
    // Amber palette
    static let amberLight = Color(red: 1.0, green: 0.9, blue: 0.7)
    static let amberPrimary = Color(red: 1.0, green: 0.75, blue: 0.3)
    static let amberBright = Color(red: 1.0, green: 0.6, blue: 0.0)

    // Semantic colors
    static let recordingActive = amberBright
    static let transcribing = amberPrimary
    static let completed = Color.green
}
```

### Animation Style

```swift
// Use spring animations for natural feel
.animation(.spring(response: 0.5, dampingFraction: 0.7), value: state)

// Example: Recording button
Button("Record") {
    startRecording()
}
.scaleEffect(isRecording ? 1.1 : 1.0)
.animation(.spring(response: 0.5, dampingFraction: 0.7), value: isRecording)
```

### Material & Effects

```swift
// Frosted glass modal
VStack {
    // Content
}
.background(.ultraThinMaterial)
.clipShape(RoundedRectangle(cornerRadius: 16))

// Glow effect for waveform
Circle()
    .fill(Color.amberBright)
    .shadow(color: Color.amberBright.opacity(0.6), radius: 10)
```

---

## Code Quality Tools

### SwiftLint Configuration

The project uses SwiftLint with the following key rules:

```yaml
# .swiftlint.yml (summary)
opt_in_rules:
  - empty_count
  - empty_string
  - explicit_init
  - first_where
  - sorted_imports
  - closure_spacing

line_length: 120
function_body_length: 50
type_body_length: 300
file_length: 500
```

### Pre-commit Hooks

Git hooks run automatically on commit:
- SwiftLint validation
- Secret detection (Gitleaks)
- YAML/JSON validation
- Large file detection
- Trailing whitespace removal

---

## Testing with XCTest

### Async Testing

```swift
func testAsyncOperation() async throws {
    // Arrange
    let service = MyAsyncService()

    // Act
    let result = try await service.performOperation()

    // Assert
    XCTAssertEqual(result, expectedValue)
}
```

### Actor Testing

```swift
func testActorIsolatedState() async {
    // Arrange
    let actorService = MyActorService()

    // Act
    await actorService.updateState(newValue: 42)

    // Assert
    let state = await actorService.getState()
    XCTAssertEqual(state, 42)
}
```

### Mock Services

```swift
class MockFluidAudioService: FluidAudioService {
    var transcribeCallCount = 0
    var stubbedTranscription = "Test transcription"

    override func transcribe(audioData: Data) async throws -> String {
        transcribeCallCount += 1
        return stubbedTranscription
    }
}
```

---

## Naming Conventions

| Type | Convention | Example |
|------|-----------|---------|
| Files | PascalCase | `RecordingSession.swift` |
| Classes/Structs | PascalCase | `AudioCaptureService` |
| Protocols | PascalCase | `PermissionChecker` |
| Functions | camelCase | `startRecording()` |
| Variables | camelCase | `audioLevel` |
| Constants | camelCase | `maxRecordingDuration` |
| Enums | PascalCase | `RecordingState` |
| Enum Cases | camelCase | `.recording`, `.completed` |

---

## Common Commands

```bash
# Development
swift package resolve           # Resolve dependencies
swift build                     # Build project
swift build -c release          # Release build
open Package.swift              # Open in Xcode

# Testing
swift test                      # Run all tests
swift test --parallel           # Parallel test execution
swift test --filter TestName    # Run specific test

# Code Quality
swiftlint                       # Run linter
swiftlint lint --strict         # Strict mode (zero tolerance)
swiftlint autocorrect           # Auto-fix violations
swiftlint analyze              # Deep analysis

# Git Hooks
pre-commit install              # Install hooks
pre-commit run --all-files      # Run all hooks manually

# CI/CD
# GitHub Actions runs automatically
# See .github/workflows/ci.yml
```

---

## Key Performance Considerations

- **Hotkey latency**: < 50ms (Carbon APIs)
- **Modal appearance**: Optimize spring animations for 60fps
- **Transcription**: FluidAudio handles ~25ms latency
- **Waveform rendering**: Canvas API for 60fps updates
- **Text insertion**: Accessibility API dependent

---

## Privacy & Security

- **Local-first**: All transcription happens on-device
- **No network calls**: After model download, fully offline
- **Permission-based**: Requires microphone & accessibility permissions
- **Anonymous statistics**: No PII in usage tracking
- **Sandboxed**: macOS entitlements for security

---

## Troubleshooting Common Issues

### Actor Isolation Errors
**Problem**: "Expression is 'async' but is not marked with 'await'"
**Solution**: Add `await` when crossing actor boundaries

```swift
// ❌ Wrong
let result = actorService.getValue()

// ✅ Correct
let result = await actorService.getValue()
```

### SwiftUI State Updates
**Problem**: "Publishing changes from background threads"
**Solution**: Use `@MainActor` for UI-bound classes

```swift
@Observable @MainActor
class ViewModel {
    var state: String = ""
}
```

### Memory Leaks with Closures
**Problem**: Retain cycles with self in closures
**Solution**: Use `[weak self]` or `[unowned self]`

```swift
// ❌ Wrong
Task {
    self.updateState()
}

// ✅ Correct
Task { [weak self] in
    self?.updateState()
}
```

---

## Additional Resources

- **Swift Documentation**: https://docs.swift.org
- **SwiftUI Tutorials**: https://developer.apple.com/tutorials/swiftui
- **Swift Concurrency**: https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html
- **FluidAudio SDK**: (SDK documentation)
- **macOS Human Interface Guidelines**: https://developer.apple.com/design/human-interface-guidelines/macos
