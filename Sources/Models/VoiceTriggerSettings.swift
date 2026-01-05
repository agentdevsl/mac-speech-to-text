import Foundation

/// Configuration for voice trigger monitoring feature
struct VoiceTriggerConfiguration: Codable, Sendable, Equatable {
    /// Whether voice trigger monitoring is enabled
    var enabled: Bool

    /// List of configured trigger keywords
    var keywords: [TriggerKeyword]

    /// Silence duration (in seconds) to wait before ending capture after keyword detection
    var silenceThresholdSeconds: TimeInterval

    /// Whether to play audio feedback when keyword is detected
    var feedbackSoundEnabled: Bool

    /// Whether to show visual feedback when keyword is detected
    var feedbackVisualEnabled: Bool

    /// Maximum recording duration after keyword (in seconds)
    var maxRecordingDuration: TimeInterval

    /// Default configuration
    static let `default` = VoiceTriggerConfiguration(
        enabled: false,
        keywords: [TriggerKeyword.heyClaudeDefault],
        silenceThresholdSeconds: 5.0,
        feedbackSoundEnabled: true,
        feedbackVisualEnabled: true,
        maxRecordingDuration: 60.0
    )

    init(
        enabled: Bool = false,
        keywords: [TriggerKeyword] = [TriggerKeyword.heyClaudeDefault],
        silenceThresholdSeconds: TimeInterval = 5.0,
        feedbackSoundEnabled: Bool = true,
        feedbackVisualEnabled: Bool = true,
        maxRecordingDuration: TimeInterval = 60.0
    ) {
        self.enabled = enabled
        self.keywords = keywords
        self.silenceThresholdSeconds = silenceThresholdSeconds
        self.feedbackSoundEnabled = feedbackSoundEnabled
        self.feedbackVisualEnabled = feedbackVisualEnabled
        self.maxRecordingDuration = maxRecordingDuration
    }
}

/// Represents a single trigger keyword phrase with detection parameters
struct TriggerKeyword: Codable, Sendable, Identifiable, Equatable {
    /// Unique identifier for this keyword
    let id: UUID

    /// The phrase to detect (e.g., "Hey Claude", "Opus")
    var phrase: String

    /// Boosting score for keyword detection (1.0-2.0)
    /// Higher values make the keyword easier to trigger
    var boostingScore: Float

    /// Minimum acoustic probability threshold for activation (0.0-1.0)
    /// Lower values = more sensitive, higher values = more strict
    var triggerThreshold: Float

    /// Whether this keyword is currently enabled for detection
    var isEnabled: Bool

    /// Display name for UI (defaults to phrase if not set)
    var displayName: String {
        phrase.isEmpty ? "(empty)" : phrase
    }

    /// Default "Hey Claude" keyword
    static let heyClaudeDefault = TriggerKeyword(
        id: UUID(),
        phrase: "Hey Claude",
        boostingScore: 1.5,
        triggerThreshold: 0.35,
        isEnabled: true
    )

    /// Preset for "Claude" keyword
    static let claudePreset = TriggerKeyword(
        id: UUID(),
        phrase: "Claude",
        boostingScore: 1.3,
        triggerThreshold: 0.4,
        isEnabled: false
    )

    /// Preset for "Opus" keyword
    static let opusPreset = TriggerKeyword(
        id: UUID(),
        phrase: "Opus",
        boostingScore: 1.3,
        triggerThreshold: 0.4,
        isEnabled: false
    )

    /// Preset for "Sonnet" keyword
    static let sonnetPreset = TriggerKeyword(
        id: UUID(),
        phrase: "Sonnet",
        boostingScore: 1.3,
        triggerThreshold: 0.4,
        isEnabled: false
    )

    init(
        id: UUID = UUID(),
        phrase: String,
        boostingScore: Float = 1.5,
        triggerThreshold: Float = 0.35,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.phrase = phrase
        self.boostingScore = boostingScore.clamped(to: 1.0...2.0)
        self.triggerThreshold = triggerThreshold.clamped(to: 0.0...1.0)
        self.isEnabled = isEnabled
    }

    /// Validation check
    var isValid: Bool {
        !phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            boostingScore >= 1.0 && boostingScore <= 2.0 &&
            triggerThreshold >= 0.0 && triggerThreshold <= 1.0
    }
}

// MARK: - Float Clamping Extension

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
