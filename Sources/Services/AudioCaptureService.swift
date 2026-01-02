import Foundation
import AVFoundation

/// Service for capturing audio using AVAudioEngine
class AudioCaptureService {
    private let audioEngine = AVAudioEngine()
    private let inputNode: AVAudioInputNode
    private var streamingBuffer: StreamingAudioBuffer?
    private var levelCallback: ((Double) -> Void)?

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
        try audioEngine.start()
    }

    /// Stop audio capture and return recorded samples
    func stopCapture() async throws -> [Int16] {
        audioEngine.stop()
        inputNode.removeTap(onBus: 0)

        guard let streamingBuffer = streamingBuffer else {
            throw AudioCaptureError.noDataRecorded
        }

        streamingBuffer.markComplete()
        let samples = streamingBuffer.allSamples

        // Clear buffer
        self.streamingBuffer = nil

        return samples
    }

    /// Process incoming audio buffer
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        guard let channelData = buffer.int16ChannelData else { return }

        let frameLength = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))

        // Create audio buffer
        let audioBuffer = AudioBuffer(samples: samples)

        // Add to streaming buffer
        streamingBuffer?.append(audioBuffer)

        // Calculate and report audio level
        let level = audioBuffer.rmsLevel / 32768.0 // Normalize to 0-1 range
        levelCallback?(level)
    }
}

/// Audio capture errors
enum AudioCaptureError: Error, LocalizedError {
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
