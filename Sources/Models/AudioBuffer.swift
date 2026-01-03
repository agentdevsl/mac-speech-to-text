import Foundation

/// Represents in-memory audio data during recording
struct AudioBuffer: Sendable {
    let samples: [Int16]
    let sampleRate: Int
    let channels: Int
    let duration: TimeInterval
    let peakAmplitude: Int16
    let rmsLevel: Double
    let timestamp: Date

    init(samples: [Int16],
         sampleRate: Int = 16000,
         channels: Int = 1,
         timestamp: Date = Date()) {
        self.samples = samples
        self.sampleRate = sampleRate
        self.channels = channels
        self.duration = Double(samples.count) / Double(sampleRate * channels)
        self.timestamp = timestamp

        // Calculate peak amplitude (handle Int16.min overflow: abs(-32768) would overflow)
        self.peakAmplitude = samples.map { $0 == Int16.min ? Int16.max : abs($0) }.max() ?? 0

        // Calculate RMS level
        if samples.isEmpty {
            self.rmsLevel = 0.0
        } else {
            let sumOfSquares = samples.reduce(0.0) { $0 + pow(Double($1), 2) }
            self.rmsLevel = sqrt(sumOfSquares / Double(samples.count))
        }
    }

    var isValid: Bool {
        sampleRate == 16000 &&
        channels == 1 &&
        !samples.isEmpty &&
        peakAmplitude > 0  // Meaningful check: buffer has actual audio content
    }
}

/// Streaming audio buffer for real-time capture
/// Thread-safe actor for concurrent access from audio callback thread
actor StreamingAudioBuffer {
    private(set) var chunks: [AudioBuffer] = []
    let maxChunkSize: Int

    var totalDuration: TimeInterval {
        chunks.reduce(0) { $0 + $1.duration }
    }

    var isComplete: Bool = false

    var allSamples: [Int16] {
        chunks.flatMap { $0.samples }
    }

    init(maxChunkSize: Int = 1600) { // 100ms chunks at 16kHz
        self.maxChunkSize = maxChunkSize
    }

    func append(_ buffer: AudioBuffer) {
        chunks.append(buffer)
    }

    func clear() {
        chunks.removeAll()
        isComplete = false
    }

    func markComplete() {
        isComplete = true
    }

    var currentLevel: Double {
        guard let lastChunk = chunks.last else { return 0.0 }
        return lastChunk.rmsLevel
    }

    var peakLevel: Int16 {
        chunks.map { $0.peakAmplitude }.max() ?? 0
    }
}
