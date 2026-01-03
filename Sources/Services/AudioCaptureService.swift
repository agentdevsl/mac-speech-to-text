import AVFoundation
import Foundation
import OSLog

/// Handles audio buffer processing on the audio thread without actor isolation
/// This class is intentionally NOT @MainActor to avoid actor isolation crashes
/// when called from Core Audio's real-time thread
final class AudioBufferProcessor: @unchecked Sendable {
    private let pendingWrites = PendingWritesCounter()
    private let levelThrottler = AudioLevelThrottler(minInterval: 0.05)
    private let streamingBuffer: StreamingAudioBuffer
    private let levelCallback: @Sendable (Double) -> Void

    init(streamingBuffer: StreamingAudioBuffer, levelCallback: @escaping @Sendable (Double) -> Void) {
        self.streamingBuffer = streamingBuffer
        self.levelCallback = levelCallback
    }

    /// Process audio buffer - safe to call from any thread
    func process(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        // Convert to Int16 samples
        let samples: [Int16]

        if let floatData = buffer.floatChannelData {
            let frameLength = Int(buffer.frameLength)
            let floatSamples = UnsafeBufferPointer(start: floatData[0], count: frameLength)
            samples = floatSamples.map { sample in
                let clamped = max(-1.0, min(1.0, sample))
                return Int16(clamped * Float(Int16.max))
            }
        } else if let int16Data = buffer.int16ChannelData {
            let frameLength = Int(buffer.frameLength)
            samples = Array(UnsafeBufferPointer(start: int16Data[0], count: frameLength))
        } else {
            AppLogger.audio.warning(
                "Audio buffer has unsupported format at time \(time.sampleTime). Audio samples lost."
            )
            return
        }

        let audioBuffer = AudioBuffer(samples: samples)

        // Append to streaming buffer via Task (no actor isolation issues)
        pendingWrites.increment()
        let buffer = self.streamingBuffer
        let writes = self.pendingWrites
        Task {
            defer { writes.decrement() }
            await buffer.append(audioBuffer)
        }

        // Report level (throttled)
        let level = audioBuffer.rmsLevel / 32768.0
        if levelThrottler.shouldUpdate() {
            let callback = self.levelCallback
            Task { @MainActor in
                callback(level)
            }
        }
    }

    /// Wait for all pending writes to complete
    func waitForCompletion() async {
        await pendingWrites.waitForCompletion()
    }
}

/// Service for capturing audio using AVAudioEngine
@MainActor
class AudioCaptureService {
    private let audioEngine = AVAudioEngine()
    private let inputNode: AVAudioInputNode
    private var streamingBuffer: StreamingAudioBuffer?
    private var bufferProcessor: AudioBufferProcessor?

    init() {
        inputNode = audioEngine.inputNode
    }

    /// Start audio capture
    func startCapture(levelCallback: @escaping (Double) -> Void) async throws {
        let buffer = StreamingAudioBuffer()
        streamingBuffer = buffer

        // Check microphone permission
        let microphonePermission = await PermissionService().checkMicrophonePermission()
        guard microphonePermission else {
            throw PermissionError.microphoneDenied
        }

        // Use the input node's native format to avoid hardware incompatibility issues
        let nativeFormat = inputNode.outputFormat(forBus: 0)

        guard nativeFormat.sampleRate > 0 && nativeFormat.channelCount > 0 else {
            throw AudioCaptureError.invalidFormat
        }

        // Create processor with captured references (no self needed in tap closure)
        let processor = AudioBufferProcessor(
            streamingBuffer: buffer,
            levelCallback: { @Sendable level in levelCallback(level) }
        )
        bufferProcessor = processor

        // Install tap - processor handles everything, no self reference needed
        inputNode.installTap(
            onBus: 0,
            bufferSize: AVAudioFrameCount(Constants.Audio.chunkSize),
            format: nativeFormat
        ) { buffer, time in
            // processor is captured directly - no actor isolation issues
            processor.process(buffer, time: time)
        }

        // Start audio engine
        do {
            try audioEngine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            throw AudioCaptureError.engineStartFailed(error.localizedDescription)
        }
    }

    /// Stop audio capture and return recorded samples
    func stopCapture() async throws -> [Int16] {
        audioEngine.stop()
        inputNode.removeTap(onBus: 0)

        // Wait for all pending buffer writes to complete
        await bufferProcessor?.waitForCompletion()

        guard let streamingBuffer = streamingBuffer else {
            throw AudioCaptureError.noDataRecorded
        }

        await streamingBuffer.markComplete()
        let samples = await streamingBuffer.allSamples

        // Clear state
        self.streamingBuffer = nil
        self.bufferProcessor = nil

        return samples
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
