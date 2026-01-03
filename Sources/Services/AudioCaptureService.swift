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
    private let processorId: String
    private var processedBufferCount: Int = 0
    private let countLock = NSLock()

    init(streamingBuffer: StreamingAudioBuffer, levelCallback: @escaping @Sendable (Double) -> Void) {
        self.streamingBuffer = streamingBuffer
        self.levelCallback = levelCallback
        self.processorId = UUID().uuidString.prefix(8).description
        AppLogger.trace(AppLogger.audio, "AudioBufferProcessor[\(processorId)] created")
    }

    deinit {
        AppLogger.trace(AppLogger.audio, "AudioBufferProcessor[\(processorId)] deallocated after \(processedBufferCount) buffers")
    }

    /// Process audio buffer - safe to call from any thread
    func process(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        // Track buffer count for debugging
        countLock.lock()
        processedBufferCount += 1
        let currentCount = processedBufferCount
        countLock.unlock()

        let frameLength = Int(buffer.frameLength)
        AppLogger.trace(AppLogger.audio, "[\(processorId)] Processing buffer #\(currentCount): frames=\(frameLength), time=\(time.sampleTime)")

        // Convert to Int16 samples
        let samples: [Int16]

        if let floatData = buffer.floatChannelData {
            AppLogger.trace(AppLogger.audio, "[\(processorId)] Buffer #\(currentCount): float format detected")
            let floatSamples = UnsafeBufferPointer(start: floatData[0], count: frameLength)
            samples = floatSamples.map { sample in
                let clamped = max(-1.0, min(1.0, sample))
                return Int16(clamped * Float(Int16.max))
            }
        } else if let int16Data = buffer.int16ChannelData {
            AppLogger.trace(AppLogger.audio, "[\(processorId)] Buffer #\(currentCount): int16 format detected")
            samples = Array(UnsafeBufferPointer(start: int16Data[0], count: frameLength))
        } else {
            AppLogger.warning(AppLogger.audio, "[\(processorId)] Buffer #\(currentCount): UNSUPPORTED FORMAT - samples lost!")
            return
        }

        let audioBuffer = AudioBuffer(samples: samples)
        AppLogger.trace(AppLogger.audio, "[\(processorId)] Buffer #\(currentCount): created AudioBuffer with \(samples.count) samples, RMS=\(audioBuffer.rmsLevel)")

        // Append to streaming buffer via Task (no actor isolation issues)
        pendingWrites.increment()
        let pendingCount = pendingWrites.currentCount
        AppLogger.trace(AppLogger.audio, "[\(processorId)] Buffer #\(currentCount): queuing append, pendingWrites=\(pendingCount)")

        let bufferRef = self.streamingBuffer
        let writes = self.pendingWrites
        let pid = self.processorId
        let bufNum = currentCount
        Task {
            defer {
                writes.decrement()
                AppLogger.trace(AppLogger.audio, "[\(pid)] Buffer #\(bufNum): append completed, pendingWrites=\(writes.currentCount)")
            }
            await bufferRef.append(audioBuffer)
        }

        // Report level (throttled) - callback handles its own MainActor dispatch
        let level = audioBuffer.rmsLevel / 32768.0
        if levelThrottler.shouldUpdate() {
            AppLogger.trace(AppLogger.audio, "[\(processorId)] Buffer #\(currentCount): reporting level=\(String(format: "%.4f", level))")
            levelCallback(level)
        }
    }

    /// Wait for all pending writes to complete
    func waitForCompletion() async {
        let pending = pendingWrites.currentCount
        AppLogger.debug(AppLogger.audio, "[\(processorId)] waitForCompletion: waiting for \(pending) pending writes")
        await pendingWrites.waitForCompletion()
        AppLogger.debug(AppLogger.audio, "[\(processorId)] waitForCompletion: all writes completed, total buffers processed=\(processedBufferCount)")
    }
}

/// Service for capturing audio using AVAudioEngine
@MainActor
class AudioCaptureService {
    private let audioEngine = AVAudioEngine()
    private let inputNode: AVAudioInputNode
    private var streamingBuffer: StreamingAudioBuffer?
    private var bufferProcessor: AudioBufferProcessor?
    private let serviceId: String

    init() {
        inputNode = audioEngine.inputNode
        serviceId = UUID().uuidString.prefix(8).description
        AppLogger.lifecycle(AppLogger.audio, self, event: "init[\(serviceId)]")
    }

    deinit {
        AppLogger.trace(AppLogger.audio, "AudioCaptureService[\(serviceId)] deallocated")
    }

    /// Start audio capture
    func startCapture(levelCallback: @escaping @Sendable (Double) -> Void) async throws {
        AppLogger.info(AppLogger.audio, "[\(serviceId)] startCapture() called")

        let buffer = StreamingAudioBuffer()
        streamingBuffer = buffer
        AppLogger.debug(AppLogger.audio, "[\(serviceId)] StreamingAudioBuffer created")

        // Check microphone permission
        AppLogger.debug(AppLogger.audio, "[\(serviceId)] Checking microphone permission...")
        let microphonePermission = await PermissionService().checkMicrophonePermission()
        AppLogger.debug(AppLogger.audio, "[\(serviceId)] Microphone permission: \(microphonePermission)")
        guard microphonePermission else {
            AppLogger.error(AppLogger.audio, "[\(serviceId)] Microphone permission denied")
            throw PermissionError.microphoneDenied
        }

        // Use the input node's native format to avoid hardware incompatibility issues
        let nativeFormat = inputNode.outputFormat(forBus: 0)
        AppLogger.debug(
            AppLogger.audio,
            "[\(serviceId)] Native format: sampleRate=\(nativeFormat.sampleRate), channels=\(nativeFormat.channelCount), commonFormat=\(nativeFormat.commonFormat.rawValue)"
        )

        guard nativeFormat.sampleRate > 0 && nativeFormat.channelCount > 0 else {
            AppLogger.error(AppLogger.audio, "[\(serviceId)] Invalid audio format detected")
            throw AudioCaptureError.invalidFormat
        }

        // Create processor with captured references (no self needed in tap closure)
        AppLogger.debug(AppLogger.audio, "[\(serviceId)] Creating AudioBufferProcessor...")
        let processor = AudioBufferProcessor(
            streamingBuffer: buffer,
            levelCallback: levelCallback
        )
        bufferProcessor = processor

        // Install tap - processor handles everything, no self reference needed
        let chunkSize = Constants.Audio.chunkSize
        AppLogger.debug(AppLogger.audio, "[\(serviceId)] Installing tap with bufferSize=\(chunkSize)")
        inputNode.installTap(
            onBus: 0,
            bufferSize: AVAudioFrameCount(chunkSize),
            format: nativeFormat
        ) { buffer, time in
            // processor is captured directly - no actor isolation issues
            processor.process(buffer, time: time)
        }
        AppLogger.debug(AppLogger.audio, "[\(serviceId)] Tap installed successfully")

        // Start audio engine
        AppLogger.debug(AppLogger.audio, "[\(serviceId)] Starting audio engine...")
        do {
            try audioEngine.start()
            AppLogger.info(AppLogger.audio, "[\(serviceId)] Audio engine started successfully")
        } catch {
            AppLogger.error(AppLogger.audio, "[\(serviceId)] Audio engine failed to start: \(error.localizedDescription)")
            inputNode.removeTap(onBus: 0)
            throw AudioCaptureError.engineStartFailed(error.localizedDescription)
        }
    }

    /// Stop audio capture and return recorded samples
    func stopCapture() async throws -> [Int16] {
        AppLogger.info(AppLogger.audio, "[\(serviceId)] stopCapture() called")

        AppLogger.debug(AppLogger.audio, "[\(serviceId)] Stopping audio engine...")
        audioEngine.stop()
        AppLogger.debug(AppLogger.audio, "[\(serviceId)] Audio engine stopped")

        AppLogger.debug(AppLogger.audio, "[\(serviceId)] Removing tap...")
        inputNode.removeTap(onBus: 0)
        AppLogger.debug(AppLogger.audio, "[\(serviceId)] Tap removed")

        // Wait for all pending buffer writes to complete
        AppLogger.debug(AppLogger.audio, "[\(serviceId)] Waiting for pending buffer writes...")
        await bufferProcessor?.waitForCompletion()
        AppLogger.debug(AppLogger.audio, "[\(serviceId)] All pending writes completed")

        guard let streamingBuffer = streamingBuffer else {
            AppLogger.error(AppLogger.audio, "[\(serviceId)] No streaming buffer - no data recorded")
            throw AudioCaptureError.noDataRecorded
        }

        AppLogger.debug(AppLogger.audio, "[\(serviceId)] Marking buffer complete...")
        await streamingBuffer.markComplete()

        AppLogger.debug(AppLogger.audio, "[\(serviceId)] Retrieving all samples...")
        let samples = await streamingBuffer.allSamples
        AppLogger.info(AppLogger.audio, "[\(serviceId)] Retrieved \(samples.count) samples")

        // Clear state
        AppLogger.debug(AppLogger.audio, "[\(serviceId)] Clearing state...")
        self.streamingBuffer = nil
        self.bufferProcessor = nil
        AppLogger.debug(AppLogger.audio, "[\(serviceId)] State cleared")

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

    var currentCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return pendingCount
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
