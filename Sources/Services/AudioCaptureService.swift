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
    private let pendingWrites = PendingWritesCounter()

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

        // Configure audio format: 16kHz mono
        let recordingFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: Double(Constants.Audio.sampleRate),
            channels: AVAudioChannelCount(Constants.Audio.channels),
            interleaved: false
        )

        guard let recordingFormat = recordingFormat else {
            throw AudioCaptureError.invalidFormat
        }

        // Install tap on input node
        inputNode.installTap(
            onBus: 0,
            bufferSize: AVAudioFrameCount(Constants.Audio.chunkSize),
            format: recordingFormat
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
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        guard let channelData = buffer.int16ChannelData else {
            AppLogger.audio.warning(
                "Audio buffer missing int16ChannelData at time \(time.sampleTime). Audio samples lost."
            )
            return
        }

        let frameLength = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))

        // Create audio buffer
        let audioBuffer = AudioBuffer(samples: samples)

        // Add to streaming buffer (using Task for non-blocking async execution
        // since Core Audio callbacks run in a synchronous context)
        // Track pending writes to prevent race condition in stopCapture
        let pendingWrites = self.pendingWrites
        pendingWrites.increment()
        Task { [weak self] in
            defer { pendingWrites.decrement() }
            do {
                try await self?.appendToStreamingBuffer(audioBuffer)
            } catch {
                AppLogger.audio.error("Failed to append audio buffer: \(error.localizedDescription)")
            }
        }

        // Calculate and report audio level
        let level = audioBuffer.rmsLevel / 32768.0 // Normalize to 0-1 range

        // Dispatch to MainActor for UI updates
        Task { @MainActor [weak self] in
            do {
                try self?.invokeLeveCallback(level)
            } catch {
                AppLogger.audio.error("Failed to invoke level callback: \(error.localizedDescription)")
            }
        }
    }

    /// Appends audio buffer to streaming buffer - throws if buffer is nil
    private func appendToStreamingBuffer(_ audioBuffer: AudioBuffer) async throws {
        guard let streamingBuffer = streamingBuffer else {
            throw AudioCaptureError.noDataRecorded
        }
        await streamingBuffer.append(audioBuffer)
    }

    /// Invokes the level callback - throws if callback is nil
    private func invokeLeveCallback(_ level: Double) throws {
        guard let callback = levelCallback else {
            return  // No callback set is not an error, just skip
        }
        callback(level)
    }
}

/// Audio capture errors
enum AudioCaptureError: Error, LocalizedError, Equatable {
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
