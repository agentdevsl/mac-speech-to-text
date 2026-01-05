import AVFoundation
import CoreAudio
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
    private let bufferCallback: (@Sendable (AVAudioPCMBuffer) -> Void)?
    private let processorId: String
    private var processedBufferCount: Int = 0
    private let countLock = NSLock()

    /// Native sample rate (stored for downstream resampling)
    let nativeSampleRate: Double

    init(
        streamingBuffer: StreamingAudioBuffer,
        nativeFormat: AVAudioFormat,
        levelCallback: @escaping @Sendable (Double) -> Void,
        bufferCallback: (@Sendable (AVAudioPCMBuffer) -> Void)? = nil
    ) {
        self.streamingBuffer = streamingBuffer
        self.levelCallback = levelCallback
        self.bufferCallback = bufferCallback
        self.processorId = UUID().uuidString.prefix(8).description
        self.nativeSampleRate = nativeFormat.sampleRate

        print("[DEBUG] AudioBufferProcessor[\(processorId)] created: nativeRate=\(Int(nativeSampleRate))Hz, targetRate=\(Constants.Audio.sampleRate)Hz")
        fflush(stdout)
        AppLogger.debug(AppLogger.audio, "AudioBufferProcessor[\(processorId)] created: nativeRate=\(Int(nativeSampleRate))Hz")
    }

    deinit {
        // Acquire lock for thread-safe read of processedBufferCount
        countLock.lock()
        let finalCount = processedBufferCount
        countLock.unlock()
        AppLogger.trace(AppLogger.audio, "AudioBufferProcessor[\(processorId)] deallocated after \(finalCount) buffers")
    }

    /// Process audio buffer - safe to call from any thread
    /// Note: Samples are stored at native rate - resampling to 16kHz happens at transcription time
    func process(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        // Track buffer count for debugging
        countLock.lock()
        processedBufferCount += 1
        let currentCount = processedBufferCount
        countLock.unlock()

        let frameLength = Int(buffer.frameLength)
        AppLogger.trace(AppLogger.audio, "[\(processorId)] Processing buffer #\(currentCount): frames=\(frameLength), time=\(time.sampleTime)")

        // Convert to Int16 samples (keeping native sample rate)
        let samples: [Int16]

        if let floatData = buffer.floatChannelData {
            let floatSamples = UnsafeBufferPointer(start: floatData[0], count: frameLength)
            samples = floatSamples.map { sample in
                let clamped = max(-1.0, min(1.0, sample))
                return Int16(clamped * Float(Int16.max))
            }
        } else if let int16Data = buffer.int16ChannelData {
            samples = Array(UnsafeBufferPointer(start: int16Data[0], count: frameLength))
        } else {
            AppLogger.warning(AppLogger.audio, "[\(processorId)] Buffer #\(currentCount): UNSUPPORTED FORMAT - samples lost!")
            return
        }

        let audioBuffer = AudioBuffer(samples: samples, sampleRate: Int(nativeSampleRate))
        AppLogger.trace(AppLogger.audio, "[\(processorId)] Buffer #\(currentCount): created AudioBuffer with \(samples.count) samples at \(Int(nativeSampleRate))Hz")

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

        // Invoke buffer callback for real-time processing (e.g., wake word detection)
        bufferCallback?(buffer)
    }

    /// Wait for all pending writes to complete
    func waitForCompletion() async {
        let pending = pendingWrites.currentCount
        AppLogger.debug(AppLogger.audio, "[\(processorId)] waitForCompletion: waiting for \(pending) pending writes")
        await pendingWrites.waitForCompletion()
        // Acquire lock for thread-safe read of processedBufferCount
        countLock.lock()
        let totalCount = processedBufferCount
        countLock.unlock()
        AppLogger.debug(AppLogger.audio, "[\(processorId)] waitForCompletion: all writes completed, total buffers processed=\(totalCount)")
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
    private var isCapturing: Bool = false
    private let settingsService: SettingsService

    init(settingsService: SettingsService = SettingsService()) {
        self.settingsService = settingsService
        inputNode = audioEngine.inputNode
        serviceId = UUID().uuidString.prefix(8).description
        AppLogger.lifecycle(AppLogger.audio, self, event: "init[\(serviceId)]")
    }

    deinit {
        AppLogger.trace(AppLogger.audio, "AudioCaptureService[\(serviceId)] deallocated")
    }

    /// Start audio capture
    /// - Parameters:
    ///   - levelCallback: Called with audio level (0.0-1.0) for visualization
    ///   - bufferCallback: Optional callback for real-time audio buffer processing (e.g., wake word detection)
    func startCapture(
        levelCallback: @escaping @Sendable (Double) -> Void,
        bufferCallback: (@Sendable (AVAudioPCMBuffer) -> Void)? = nil
    ) async throws {
        AppLogger.info(AppLogger.audio, "[\(serviceId)] startCapture() called")

        // Guard against concurrent capture attempts
        guard !isCapturing else {
            AppLogger.warning(AppLogger.audio, "[\(serviceId)] startCapture() called while already capturing")
            throw AudioCaptureError.alreadyCapturing
        }
        isCapturing = true

        do {
            try await performCapture(levelCallback: levelCallback, bufferCallback: bufferCallback)
        } catch {
            isCapturing = false
            throw error
        }
    }

    /// Internal capture implementation
    /// Note: Caller must ensure microphone permission is granted before calling this method
    private func performCapture(
        levelCallback: @escaping @Sendable (Double) -> Void,
        bufferCallback: (@Sendable (AVAudioPCMBuffer) -> Void)? = nil
    ) async throws {
        let buffer = StreamingAudioBuffer()
        streamingBuffer = buffer

        // Configure the audio engine to use the selected input device (CRIT-1 fix)
        try configureInputDevice()

        // Use the input node's native format to avoid hardware incompatibility issues
        let nativeFormat = inputNode.outputFormat(forBus: 0)
        guard nativeFormat.sampleRate > 0 && nativeFormat.channelCount > 0 else {
            AppLogger.error(AppLogger.audio, "[\(serviceId)] Invalid audio format detected")
            throw AudioCaptureError.invalidFormat
        }

        // Create processor and install tap
        let processor = AudioBufferProcessor(
            streamingBuffer: buffer,
            nativeFormat: nativeFormat,
            levelCallback: levelCallback,
            bufferCallback: bufferCallback
        )
        bufferProcessor = processor
        inputNode.installTap(
            onBus: 0,
            bufferSize: AVAudioFrameCount(Constants.Audio.chunkSize),
            format: nativeFormat
        ) { @Sendable buffer, time in
            processor.process(buffer, time: time)
        }

        // Start audio engine
        do {
            try audioEngine.start()
            AppLogger.info(AppLogger.audio, "[\(serviceId)] Audio engine started successfully")
        } catch {
            inputNode.removeTap(onBus: 0)
            throw AudioCaptureError.engineStartFailed(error.localizedDescription)
        }
    }

    /// Configure the audio engine to use the selected input device from settings
    /// Falls back to system default if the selected device is unavailable
    private func configureInputDevice() throws {
        let settings = settingsService.load()
        guard let selectedDeviceId = settings.audio.inputDeviceId else {
            AppLogger.debug(AppLogger.audio, "[\(serviceId)] No specific device selected, using system default")
            return
        }

        #if os(macOS)
        // Find the selected device using AVCaptureDevice
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )

        guard let selectedDevice = discoverySession.devices.first(where: { $0.uniqueID == selectedDeviceId }) else {
            AppLogger.warning(
                AppLogger.audio,
                "[\(serviceId)] Selected device '\(selectedDeviceId)' not found, using system default"
            )
            return
        }

        // Get the Core Audio device ID from the AVCaptureDevice
        // AVCaptureDevice's uniqueID for audio devices corresponds to the Core Audio device UID
        var deviceId: AudioDeviceID = 0
        var deviceIdSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDeviceForUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        // Create a CFString from the device UID
        var deviceUID: CFString = selectedDevice.uniqueID as CFString
        var translation = AudioValueTranslation(
            mInputData: &deviceUID,
            mInputDataSize: UInt32(MemoryLayout<CFString>.size),
            mOutputData: &deviceId,
            mOutputDataSize: UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        var translationSize = UInt32(MemoryLayout<AudioValueTranslation>.size)

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &translationSize,
            &translation
        )

        guard status == noErr, deviceId != 0 else {
            AppLogger.warning(
                AppLogger.audio,
                "[\(serviceId)] Failed to get Core Audio device ID for '\(selectedDevice.localizedName)', status=\(status)"
            )
            return
        }

        // Set the audio engine's input device
        let audioUnit = audioEngine.inputNode.audioUnit
        guard let audioUnit = audioUnit else {
            AppLogger.warning(AppLogger.audio, "[\(serviceId)] No audio unit available on input node")
            return
        }

        let setStatus = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceId,
            deviceIdSize
        )

        if setStatus == noErr {
            AppLogger.info(
                AppLogger.audio,
                "[\(serviceId)] Successfully set input device to '\(selectedDevice.localizedName)' (ID: \(deviceId))"
            )
        } else {
            AppLogger.warning(
                AppLogger.audio,
                "[\(serviceId)] Failed to set input device '\(selectedDevice.localizedName)', status=\(setStatus)"
            )
        }
        #endif
    }

    /// Stop audio capture and return recorded samples with native sample rate
    /// - Returns: Tuple of (samples at native rate, native sample rate in Hz)
    func stopCapture() async throws -> (samples: [Int16], sampleRate: Double) {
        AppLogger.info(AppLogger.audio, "[\(serviceId)] stopCapture() called")

        // Get native sample rate before clearing processor
        let nativeSampleRate = bufferProcessor?.nativeSampleRate ?? Double(Constants.Audio.sampleRate)

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
        print("[DEBUG] stopCapture: \(samples.count) samples at \(Int(nativeSampleRate))Hz")
        fflush(stdout)
        AppLogger.info(AppLogger.audio, "[\(serviceId)] Retrieved \(samples.count) samples at \(Int(nativeSampleRate))Hz")

        // Clear state
        AppLogger.debug(AppLogger.audio, "[\(serviceId)] Clearing state...")
        self.streamingBuffer = nil
        self.bufferProcessor = nil
        self.isCapturing = false
        AppLogger.debug(AppLogger.audio, "[\(serviceId)] State cleared")

        return (samples, nativeSampleRate)
    }
}

/// Audio capture errors
enum AudioCaptureError: Error, LocalizedError, Equatable, Sendable {
    case invalidFormat
    case noDataRecorded
    case engineStartFailed(String)
    case alreadyCapturing

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid audio format. Expected 16kHz mono PCM"
        case .noDataRecorded:
            return "No audio data was recorded"
        case .engineStartFailed(let message):
            return "Failed to start audio engine: \(message)"
        case .alreadyCapturing:
            return "Audio capture is already in progress"
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
