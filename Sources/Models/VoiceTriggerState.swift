import Foundation

/// Error types for voice trigger operations
enum VoiceTriggerError: Error, Sendable, Equatable {
    case wakeWordInitFailed(String)
    case noKeywordsConfigured
    case audioCaptureFailed(String)
    case transcriptionFailed(String)
    case insertionFailed(String)
    case silenceTimeoutExceeded
    case maxDurationExceeded

    var description: String {
        switch self {
        case .wakeWordInitFailed(let reason):
            return "Wake word initialization failed: \(reason)"
        case .noKeywordsConfigured:
            return "No wake word keywords configured"
        case .audioCaptureFailed(let reason):
            return "Audio capture failed: \(reason)"
        case .transcriptionFailed(let reason):
            return "Transcription failed: \(reason)"
        case .insertionFailed(let reason):
            return "Text insertion failed: \(reason)"
        case .silenceTimeoutExceeded:
            return "Silence timeout exceeded"
        case .maxDurationExceeded:
            return "Maximum recording duration exceeded"
        }
    }
}

/// State machine for voice trigger monitoring lifecycle
///
/// The voice trigger feature listens for wake words using sherpa-onnx,
/// then captures audio and transcribes it using FluidAudio.
///
/// State flow:
/// ```
/// idle -> monitoring -> triggered -> capturing -> transcribing -> inserting -> idle
///                  \                                                      /
///                   \---------------------> error <----------------------/
/// ```
enum VoiceTriggerState: Sendable, Equatable {
    /// Not monitoring for wake words
    case idle

    /// Listening for wake words via sherpa-onnx
    case monitoring

    /// Wake word detected, transitioning to capture
    case triggered(keyword: String)

    /// Recording audio after keyword detection
    case capturing

    /// Processing audio with FluidAudio
    case transcribing

    /// Inserting transcribed text into the active application
    case inserting

    /// Error state with associated error details
    case error(VoiceTriggerError)

    var description: String {
        switch self {
        case .idle:
            return "Idle"
        case .monitoring:
            return "Listening for wake word..."
        case .triggered(let keyword):
            return "Wake word detected: \(keyword)"
        case .capturing:
            return "Capturing speech..."
        case .transcribing:
            return "Transcribing..."
        case .inserting:
            return "Inserting text..."
        case .error(let error):
            return "Error: \(error.description)"
        }
    }

    /// Whether the voice trigger is actively processing
    var isActive: Bool {
        switch self {
        case .monitoring, .triggered, .capturing, .transcribing, .inserting:
            return true
        case .idle, .error:
            return false
        }
    }

    /// Whether the voice trigger is in an error state
    var isError: Bool {
        if case .error = self {
            return true
        }
        return false
    }

    /// Whether the voice trigger is currently monitoring for wake words
    var isMonitoring: Bool {
        if case .monitoring = self {
            return true
        }
        return false
    }

    /// Whether the voice trigger has been triggered and is processing
    var isProcessing: Bool {
        switch self {
        case .triggered, .capturing, .transcribing, .inserting:
            return true
        case .idle, .monitoring, .error:
            return false
        }
    }
}
