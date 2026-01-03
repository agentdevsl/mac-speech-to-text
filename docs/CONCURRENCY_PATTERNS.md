# Swift Concurrency Patterns and Pitfalls

Common Swift concurrency issues and how to avoid them.

## Critical: @Observable + Actor Existential Types

### Issue

`@Observable` classes with actor existential properties can crash:

```text
EXC_BAD_ACCESS (SIGSEGV)
KERN_INVALID_ADDRESS (possible pointer authentication failure)
```

### Cause

The `@Observable` macro scans all properties. Actor existential types
trigger executor checks that can fail on ARM64.

### Solution

Mark actor existential properties with `@ObservationIgnored`:

```swift
// WRONG - Can crash
@Observable
class MyViewModel {
    private let actorService: any MyActorProtocol
}

// CORRECT - Safe
@Observable
class MyViewModel {
    @ObservationIgnored private let actorService: any MyActorProtocol
}
```

### Detection

SwiftLint rule `observable_actor_existential_warning` detects this.

---

## nonisolated(unsafe) Properties

### Issue (nonisolated)

`nonisolated(unsafe)` bypasses actor isolation, risking data races.

### When to Use (nonisolated)

1. Accessing properties from `deinit` (which is nonisolated)
2. Audio/system callbacks that run on background threads
3. When you have a clear synchronization strategy (e.g., thread-safe types)

### Example (nonisolated)

```swift
@Observable @MainActor
class MyViewModel {
    private var timer: Timer?
    @ObservationIgnored private nonisolated(unsafe) var deinitTimer: Timer?

    func startTimer() {
        let newTimer = Timer.scheduledTimer(...)
        timer = newTimer
        deinitTimer = newTimer
    }

    deinit {
        deinitTimer?.invalidate()
    }
}
```

### Detection (nonisolated)

SwiftLint rule `nonisolated_unsafe_warning` flags these usages.

---

## Audio Callbacks and @MainActor

### Issue (Audio)

Core Audio callbacks run on a real-time audio thread. Calling `@MainActor`
methods directly from these callbacks causes actor isolation crashes.

### Cause (Audio)

```swift
// WRONG - Crashes with actor isolation violation
@MainActor class AudioCaptureService {
    func processBuffer(_ buffer: AVAudioPCMBuffer) { ... }

    func start() {
        inputNode.installTap(...) { buffer, time in
            self.processBuffer(buffer)  // Called from audio thread!
        }
    }
}
```

### Solution (Audio)

1. Make the callback handler `nonisolated`
2. Use `nonisolated(unsafe)` for thread-safe properties accessed from callback
3. Hop to MainActor via `Task` for state updates

```swift
@MainActor class AudioCaptureService {
    // Thread-safe types can be nonisolated(unsafe)
    private nonisolated(unsafe) let pendingWrites = PendingWritesCounter()
    private nonisolated(unsafe) let throttler = AudioLevelThrottler()

    func start() {
        inputNode.installTap(...) { [weak self] buffer, time in
            self?.processBuffer(buffer)
        }
    }

    // nonisolated - safe to call from audio thread
    private nonisolated func processBuffer(_ buffer: AVAudioPCMBuffer) {
        let samples = convertToInt16(buffer)

        pendingWrites.increment()
        Task { @MainActor [weak self] in
            defer { self?.pendingWrites.decrement() }
            // Update MainActor-isolated state here
            await self?.streamingBuffer?.append(samples)
        }
    }
}
```

### Key Points (Audio)

- Audio callbacks are synchronous; cannot use `await`
- Use `Task { @MainActor ... }` to hop to MainActor
- Thread-safe utility classes (`@unchecked Sendable`) can be `nonisolated(unsafe)`
- Never access `@MainActor` `var` properties from `nonisolated` context

---

## AVAudioEngine Format Compatibility

### Issue (Format)

Requesting a specific audio format (e.g., 16kHz Int16) that hardware doesn't
support can cause `audioEngine.start()` to fail.

### Solution (Format)

Use the native format and convert in the callback:

```swift
// WRONG - May fail on some hardware
let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, ...)
inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { ... }

// CORRECT - Use native format, convert manually
let nativeFormat = inputNode.outputFormat(forBus: 0)
inputNode.installTap(
    onBus: 0, bufferSize: 1024, format: nativeFormat
) { buffer, _ in
    // Convert float32 to Int16 in callback
    if let floatData = buffer.floatChannelData {
        let samples = floatData[0].map { Int16($0 * Float(Int16.max)) }
    }
}
```

---

## Task Lifecycle in SwiftUI

### Issue (Tasks)

Tasks in `onAppear` may outlive the view, causing crashes or leaks.

### Solution (Tasks)

Use `.task(id:)` modifier for automatic cancellation:

```swift
struct MyView: View {
    @State private var taskId: UUID?

    var body: some View {
        Text("Hello")
            .task(id: taskId) {
                guard taskId != nil else { return }
                // Work automatically cancelled on disappear
            }
            .onAppear { taskId = UUID() }
    }
}
```

---

## Actor Protocol Conformance

### Issue (Actors)

Swift actors cannot be inherited, preventing mock subclasses.

### Solution (Actors)

Use protocols constrained to `Actor`:

```swift
protocol FluidAudioServiceProtocol: Actor {
    func transcribe(samples: [Int16]) async throws -> TranscriptionResult
}

actor FluidAudioService: FluidAudioServiceProtocol { ... }
actor MockFluidAudioService: FluidAudioServiceProtocol { ... }
```

---

## Testing Concurrency Issues

### Limitations

Some bugs only manifest on real hardware:

- Pointer authentication failures (ARM64)
- Race conditions under load
- SwiftUI rendering issues

### Strategy

1. **Unit Tests**: Logic and state transitions
2. **ViewInspector**: View structure and rendering
3. **Smoke Tests**: Brief app runs checking for crashes
4. **XCUITest**: Full E2E flows

### Crash Detection Test

```swift
func test_viewModel_instantiatesWithoutCrash() {
    let viewModel = MyViewModel()
    XCTAssertNotNil(viewModel)
}
```

---

## Checklist: Adding Actor Services

- [ ] Mark property with `@ObservationIgnored`
- [ ] Use protocol constraint to `Actor`
- [ ] Create actor-based mock for tests
- [ ] Add render crash detection test
- [ ] Run on actual hardware before merging

---

## Related Files

- `.swiftlint.yml` - Custom rules for dangerous patterns
- `Tests/.../RecordingModalRenderTests.swift` - Render crash tests
- `.github/workflows/ci.yml` - CI pipeline
