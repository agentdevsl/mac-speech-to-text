import XCTest
@testable import SpeechToText

final class AudioBufferTests: XCTestCase {

    // MARK: - Initialization Tests

    func test_initialization_createsAudioBufferWithSamples() {
        // Given
        let samples: [Int16] = [100, 200, 300, 400, 500]
        let sampleRate = 16000
        let channels = 1

        // When
        let buffer = AudioBuffer(samples: samples, sampleRate: sampleRate, channels: channels)

        // Then
        XCTAssertEqual(buffer.samples, samples)
        XCTAssertEqual(buffer.sampleRate, sampleRate)
        XCTAssertEqual(buffer.channels, channels)
        XCTAssertNotNil(buffer.timestamp)
    }

    func test_initialization_calculatesCorrectDuration() {
        // Given
        let samples: [Int16] = Array(repeating: 100, count: 16000) // 1 second at 16kHz
        let sampleRate = 16000
        let channels = 1

        // When
        let buffer = AudioBuffer(samples: samples, sampleRate: sampleRate, channels: channels)

        // Then
        XCTAssertEqual(buffer.duration, 1.0, accuracy: 0.01)
    }

    func test_initialization_calculatesPeakAmplitude() {
        // Given
        let samples: [Int16] = [100, -500, 300, -1000, 500]

        // When
        let buffer = AudioBuffer(samples: samples)

        // Then
        XCTAssertEqual(buffer.peakAmplitude, 1000) // abs(-1000)
    }

    func test_initialization_calculatesRMSLevel() {
        // Given
        let samples: [Int16] = [100, 200, 300, 400, 500]

        // When
        let buffer = AudioBuffer(samples: samples)

        // Then
        XCTAssertGreaterThan(buffer.rmsLevel, 0)
        // RMS = sqrt((100^2 + 200^2 + 300^2 + 400^2 + 500^2) / 5) = sqrt(110000) ≈ 331.66
        XCTAssertEqual(buffer.rmsLevel, 331.66, accuracy: 1.0)
    }

    func test_initialization_usesDefaultSampleRate() {
        // Given
        let samples: [Int16] = [100, 200, 300]

        // When
        let buffer = AudioBuffer(samples: samples)

        // Then
        XCTAssertEqual(buffer.sampleRate, 16000)
    }

    func test_initialization_usesDefaultChannels() {
        // Given
        let samples: [Int16] = [100, 200, 300]

        // When
        let buffer = AudioBuffer(samples: samples)

        // Then
        XCTAssertEqual(buffer.channels, 1)
    }

    // MARK: - Validation Tests

    func test_isValid_returnsTrueForValidBuffer() {
        // Given
        let samples: [Int16] = [100, 200, 300]
        let buffer = AudioBuffer(samples: samples, sampleRate: 16000, channels: 1)

        // When/Then
        XCTAssertTrue(buffer.isValid)
    }

    func test_isValid_returnsFalseForInvalidSampleRate() {
        // Given
        let samples: [Int16] = [100, 200, 300]
        let buffer = AudioBuffer(samples: samples, sampleRate: 44100, channels: 1)

        // When/Then
        XCTAssertFalse(buffer.isValid)
    }

    func test_isValid_returnsFalseForInvalidChannels() {
        // Given
        let samples: [Int16] = [100, 200, 300]
        let buffer = AudioBuffer(samples: samples, sampleRate: 16000, channels: 2)

        // When/Then
        XCTAssertFalse(buffer.isValid)
    }

    func test_isValid_returnsFalseForEmptySamples() {
        // Given
        let samples: [Int16] = []
        let buffer = AudioBuffer(samples: samples)

        // When/Then
        XCTAssertFalse(buffer.isValid)
    }

    // MARK: - StreamingAudioBuffer Tests

    func test_streamingAudioBuffer_initialization_createsEmptyBuffer() async {
        // Given/When
        let streamingBuffer = StreamingAudioBuffer()

        // Then
        let chunks = await streamingBuffer.chunks
        let maxChunkSize = await streamingBuffer.maxChunkSize
        let isComplete = await streamingBuffer.isComplete
        let totalDuration = await streamingBuffer.totalDuration

        XCTAssertTrue(chunks.isEmpty)
        XCTAssertEqual(maxChunkSize, 1600) // default 100ms at 16kHz
        XCTAssertFalse(isComplete)
        XCTAssertEqual(totalDuration, 0.0)
    }

    func test_streamingAudioBuffer_append_addsChunk() async {
        // Given
        let streamingBuffer = StreamingAudioBuffer()
        let samples: [Int16] = Array(repeating: 100, count: 160) // 10ms at 16kHz
        let audioBuffer = AudioBuffer(samples: samples)

        // When
        await streamingBuffer.append(audioBuffer)

        // Then
        let chunks = await streamingBuffer.chunks
        let totalDuration = await streamingBuffer.totalDuration
        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(totalDuration, 0.01, accuracy: 0.001)
    }

    func test_streamingAudioBuffer_append_addsMultipleChunks() async {
        // Given
        let streamingBuffer = StreamingAudioBuffer()
        let samples1: [Int16] = Array(repeating: 100, count: 160)
        let samples2: [Int16] = Array(repeating: 200, count: 160)

        // When
        await streamingBuffer.append(AudioBuffer(samples: samples1))
        await streamingBuffer.append(AudioBuffer(samples: samples2))

        // Then
        let chunks = await streamingBuffer.chunks
        let totalDuration = await streamingBuffer.totalDuration
        XCTAssertEqual(chunks.count, 2)
        XCTAssertEqual(totalDuration, 0.02, accuracy: 0.001)
    }

    func test_streamingAudioBuffer_clear_removesAllChunks() async {
        // Given
        let streamingBuffer = StreamingAudioBuffer()
        await streamingBuffer.append(AudioBuffer(samples: [100, 200, 300]))
        await streamingBuffer.append(AudioBuffer(samples: [400, 500, 600]))

        // When
        await streamingBuffer.clear()

        // Then
        let chunks = await streamingBuffer.chunks
        let isComplete = await streamingBuffer.isComplete
        XCTAssertTrue(chunks.isEmpty)
        XCTAssertFalse(isComplete)
    }

    func test_streamingAudioBuffer_markComplete_setsCompleteFlag() async {
        // Given
        let streamingBuffer = StreamingAudioBuffer()
        let initialIsComplete = await streamingBuffer.isComplete
        XCTAssertFalse(initialIsComplete)

        // When
        await streamingBuffer.markComplete()

        // Then
        let isComplete = await streamingBuffer.isComplete
        XCTAssertTrue(isComplete)
    }

    func test_streamingAudioBuffer_allSamples_concatenatesChunks() async {
        // Given
        let streamingBuffer = StreamingAudioBuffer()
        let samples1: [Int16] = [100, 200]
        let samples2: [Int16] = [300, 400]
        await streamingBuffer.append(AudioBuffer(samples: samples1))
        await streamingBuffer.append(AudioBuffer(samples: samples2))

        // When
        let allSamples = await streamingBuffer.allSamples

        // Then
        XCTAssertEqual(allSamples, [100, 200, 300, 400])
    }

    func test_streamingAudioBuffer_currentLevel_returnsZeroForEmptyBuffer() async {
        // Given
        let streamingBuffer = StreamingAudioBuffer()

        // When
        let level = await streamingBuffer.currentLevel

        // Then
        XCTAssertEqual(level, 0.0)
    }

    func test_streamingAudioBuffer_currentLevel_returnsLastChunkLevel() async {
        // Given
        let streamingBuffer = StreamingAudioBuffer()
        await streamingBuffer.append(AudioBuffer(samples: [100, 200]))
        await streamingBuffer.append(AudioBuffer(samples: [300, 400, 500]))

        // When
        let level = await streamingBuffer.currentLevel

        // Then
        XCTAssertGreaterThan(level, 0.0)
    }

    func test_streamingAudioBuffer_peakLevel_returnsMaxPeakAcrossChunks() async {
        // Given
        let streamingBuffer = StreamingAudioBuffer()
        await streamingBuffer.append(AudioBuffer(samples: [100, 200]))
        await streamingBuffer.append(AudioBuffer(samples: [-1000, 400]))
        await streamingBuffer.append(AudioBuffer(samples: [300, 500]))

        // When
        let peakLevel = await streamingBuffer.peakLevel

        // Then
        XCTAssertEqual(peakLevel, 1000)
    }

    func test_streamingAudioBuffer_customMaxChunkSize() async {
        // Given/When
        let streamingBuffer = StreamingAudioBuffer(maxChunkSize: 3200) // 200ms at 16kHz

        // Then
        let maxChunkSize = await streamingBuffer.maxChunkSize
        XCTAssertEqual(maxChunkSize, 3200)
    }

    // MARK: - Edge Cases

    func test_audioBuffer_handlesSilence() {
        // Given
        let samples: [Int16] = Array(repeating: 0, count: 100)

        // When
        let buffer = AudioBuffer(samples: samples)

        // Then
        XCTAssertEqual(buffer.peakAmplitude, 0)
        XCTAssertEqual(buffer.rmsLevel, 0.0)
    }

    func test_audioBuffer_handlesMaxAmplitude() {
        // Given
        let samples: [Int16] = [Int16.max, Int16.min, 0]

        // When
        let buffer = AudioBuffer(samples: samples)

        // Then
        XCTAssertEqual(buffer.peakAmplitude, Int16.max)
        XCTAssertTrue(buffer.isValid) // peakAmplitude <= Int16.max
    }
}
