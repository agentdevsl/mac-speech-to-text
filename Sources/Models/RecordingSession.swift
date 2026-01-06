import Foundation

/// Represents a single speech-to-text capture event from start to completion
struct RecordingSession: Identifiable, Sendable, Codable {
    let id: UUID
    let startTime: Date
    var endTime: Date?
    var duration: TimeInterval {
        guard let endTime = endTime else {
            return Date().timeIntervalSince(startTime)
        }
        return endTime.timeIntervalSince(startTime)
    }
    var audioData: [Int16]?
    var transcribedText: String
    let language: String
    var confidenceScore: Double
    var insertionSuccess: Bool
    var errorMessage: String?
    var peakAmplitude: Int16
    var wordCount: Int {
        transcribedText.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .count
    }
    var segments: [TranscriptionSegment]
    var state: SessionState

    init(id: UUID = UUID(),
         startTime: Date = Date(),
         language: String = "en",
         state: SessionState = .idle) {
        self.id = id
        self.startTime = startTime
        self.endTime = nil
        self.audioData = nil
        self.transcribedText = ""
        self.language = language
        self.confidenceScore = 0.0
        self.insertionSuccess = false
        self.errorMessage = nil
        self.peakAmplitude = 0
        self.segments = []
        self.state = state
    }

    /// Validation check for session data
    var isValid: Bool {
        // End time must be after start time
        if let endTime = endTime, endTime < startTime {
            return false
        }

        // Confidence score must be between 0 and 1
        if confidenceScore < 0.0 || confidenceScore > 1.0 {
            return false
        }

        // Language must not be empty
        if language.isEmpty {
            return false
        }

        return true
    }
}

/// Represents word-level timestamps in transcription
struct TranscriptionSegment: Identifiable, Sendable, Codable {
    let id: UUID
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let confidence: Double

    init(id: UUID = UUID(),
         text: String,
         startTime: TimeInterval,
         endTime: TimeInterval,
         confidence: Double) {
        self.id = id
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.confidence = confidence
    }
}

/// State machine for recording session lifecycle
enum SessionState: String, Codable, CaseIterable, Sendable {
    case idle
    case recording
    case transcribing
    case inserting
    case completed
    case cancelled

    var description: String {
        switch self {
        case .idle: return "Idle"
        case .recording: return "Recording..."
        case .transcribing: return "Transcribing..."
        case .inserting: return "Inserting text..."
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }

    var isActive: Bool {
        switch self {
        case .recording, .transcribing, .inserting:
            return true
        case .idle, .completed, .cancelled:
            return false
        }
    }
}
