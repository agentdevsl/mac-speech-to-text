import AVFoundation
import Foundation
import OSLog

/// Service for capturing audio using AVAudioEngine
@MainActor
class AudioCaptureService {
    private let audioEngine = AVAudioEngine()
    private let inputNode: AVAudioInputNode
    private var streamingBuffer: StreamingAudioBuffer?
    private var levelCallback: ((Double) -> Void)?

    /// Counter for pending buffer append operations to ensure all audio is flushed before stop
    /// nonisolated(unsafe) allows access from audio callback thread
    private nonisolated(unsafe) let pendingWrites = PendingWritesCounter()

    /// Throttler for audio level updates to prevent MainActor congestion
    /// Audio callbacks fire every ~64ms; we throttle to ~50ms to reduce Task spawning
    /// nonisolated(unsafe) allows access from audio callback thread
    private nonisolated(unsafe) let levelThrottler = AudioLevelThrottler(minInterval: 0.05)

    /// Native sample rate from hardware (for resampling)
    private var nativeSampleRate: Double = 44100.0

    init() {
        inputNode = audioEngine.inputNode
    }

    /// Start audio capture
    func startCapture(levelCallback: @escaping (Double) -> Void) async throws {
        self.levelCallback = levelCallback
        streamingBuffer = StreamingAudioBuffer()

        // Check microphone permission
        let microphonePermission = await PermissionService().checkMicrophonePermission()
        guard microphonePermission else {
            throw PermissionError.microphoneDenied
        }

        // Use the input node's native format to avoid hardware incompatibility issues
        // macOS audio hardware typically provides float32 at 44.1kHz or 48kHz
        // We'll convert to Int16 in processAudioBuffer
        let nativeFormat = inputNode.outputFormat(forBus: 0)

        // Validate we have a usable format
        guard nativeFormat.sampleRate > 0 && nativeFormat.channelCount > 0 else {
            throw AudioCaptureError.invalidFormat
        }

        // Store native sample rate for resampling calculations
        nativeSampleRate = nativeFormat.sampleRate

        // Install tap on input node using native format
        inputNode.installTap(
            onBus: 0,
            bufferSize: AVAudioFrameCount(Constants.Audio.chunkSize),
            format: nativeFormat
        ) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer, time: time)
        }

        // Start audio engine
        do {
            try audioEngine.start()
        } catch {
            inputNode.removeTap(onBus: 0)  // Clean up the tap on failure
            throw AudioCaptureError.engineStartFailed(error.localizedDescription)
        }
    }

    /// Stop audio capture and return recorded samples
    func stopCapture() async throws -> [Int16] {
        audioEngine.stop()
        inputNode.removeTap(onBus: 0)

        // Wait for all pending buffer writes to complete before retrieving samples
        // This prevents race condition where in-flight Tasks from processAudioBuffer
        // haven't finished appending audio data yet
        await pendingWrites.waitForCompletion()

        guard let streamingBuffer = streamingBuffer else {
            throw AudioCaptureError.noDataRecorded
        }

        await streamingBuffer.markComplete()
        let samples = await streamingBuffer.allSamples

        // Clear buffer
        self.streamingBuffer = nil

        return samples
    }

    /// Process incoming audio buffer
    /// Must be nonisolated because it's called from Core Audio's real-time thread
    private nonisolated func processAudioBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        // Native format is typically float32 - convert to Int16 for our pipeline
        let samples: [Int16]

        if let floatData = buffer.floatChannelData {
            // Convert float32 to Int16 (most common case for native macOS audio)
            let frameLength = Int(buffer.frameLength)
            let floatSamples = UnsafeBufferPointer(start: floatData[0], count: frameLength)
            samples = floatSamples.map { sample in
                // Clamp and convert float [-1.0, 1.0] to Int16 range
                let clamped = max(-1.0, min(1.0, sample))
                return Int16(clamped * Float(Int16.max))
            }
        } else if let int16Data = buffer.int16ChannelData {
            // Already Int16 format
            let frameLength = Int(buffer.frameLength)
            samples = Array(UnsafeBufferPointer(start: int16Data[0], count: frameLength))
        } else {
            AppLogger.audio.warning(
                "Audio buffer has unsupported format at time \(time.sampleTime). Audio samples lost."
            )
            return
        }

        // Create audio buffer
        let audioBuffer = AudioBuffer(samples: samples)

        // Capture Sendable references for the Task closure
        // pendingWrites and levelThrottler are @unchecked Sendable so safe to capture
        let pendingWrites = self.pendingWrites
        let levelThrottler = self.levelThrottler

        // Add to streaming buffer (using Task for non-blocking async execution
        // since Core Audio callbacks run in a synchronous context)
        // Track pending writes to prevent race condition in stopCapture
        pendingWrites.increment()
        Task { @MainActor [weak self] in
            defer { pendingWrites.decrement() }
            guard let self else { return }
            guard let streamingBuffer = self.streamingBuffer else { return }
            await streamingBuffer.append(audioBuffer)
        }

        // Calculate and report audio level (throttled to prevent MainActor congestion)
        let level = audioBuffer.rmsLevel / 32768.0 // Normalize to 0-1 range

        // Only dispatch level update if throttle interval has passed
        // This prevents spawning a Task for every audio buffer (~64ms intervals)
        // which can cause @Observable mutations during SwiftUI body evaluation
        if levelThrottler.shouldUpdate() {
            Task { @MainActor [weak self] in
                self?.levelCallback?(level)
            }
        }
    }

}

/// Audio capture errors
enum AudioCaptureError: Error, LocalizedError, Equatable, Sendable {
    case invalidFormat
    case noDataRecorded
    case engineStartFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid audio format. Expected 16kHz mono PCM"
        case .noDataRecorded:
            return "No audio data was recorded"
        case .engineStartFailed(let message):
            return "Failed to start audio engine: \(message)"
        }
    }
}

/// Thread-safe counter for tracking pending buffer write operations
/// Used to ensure all audio data is flushed before stopCapture returns
final class PendingWritesCounter: @unchecked Sendable {
    private var pendingCount: Int = 0
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Never>?

    var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return pendingCount == 0
    }

    func increment() {
        lock.lock()
        pendingCount += 1
        lock.unlock()
    }

    func decrement() {
        lock.lock()
        pendingCount -= 1
        // Use direct comparison instead of isEmpty to avoid deadlock
        // (isEmpty also acquires lock, NSLock is not reentrant)
        let shouldResume = pendingCount == 0 && continuation != nil
        let cont = continuation
        if shouldResume {
            continuation = nil
        }
        lock.unlock()

        if shouldResume {
            cont?.resume()
        }
    }

    func waitForCompletion() async {
        // Perform atomic check-and-wait in a single lock acquisition
        // to prevent TOCTOU race condition
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            lock.lock()
            if pendingCount == 0 {
                lock.unlock()
                cont.resume()
            } else {
                continuation = cont
                lock.unlock()
            }
        }
    }
}

/// Thread-safe throttler for audio level updates
/// Prevents rapid-fire Task spawning from audio callbacks that can cause
/// @Observable mutations during SwiftUI body evaluation (executor crashes)
final class AudioLevelThrottler: @unchecked Sendable {
    private let minInterval: CFAbsoluteTime
    private var lastUpdateTime: CFAbsoluteTime = 0
    private let lock = NSLock()

    init(minInterval: CFAbsoluteTime) {
        self.minInterval = minInterval
    }

    /// Returns true if enough time has passed since the last update
    /// Thread-safe for use from audio callbacks
    func shouldUpdate() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let now = CFAbsoluteTimeGetCurrent()
        if now - lastUpdateTime >= minInterval {
            lastUpdateTime = now
            return true
        }
        return false
    }

    /// Reset the throttler (e.g., when starting a new recording)
    func reset() {
        lock.lock()
        lastUpdateTime = 0
        lock.unlock()
    }
}
