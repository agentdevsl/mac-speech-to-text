import XCTest
@testable import SpeechToText

final class VoiceTriggerSettingsTests: XCTestCase {

    // MARK: - TriggerKeyword Initialization Tests

    func test_triggerKeyword_initWithDefaults_hasCorrectValues() {
        let keyword = TriggerKeyword(phrase: "Test Phrase")

        XCTAssertFalse(keyword.id.uuidString.isEmpty)
        XCTAssertEqual(keyword.phrase, "Test Phrase")
        XCTAssertEqual(keyword.boostingScore, 1.5)
        XCTAssertEqual(keyword.triggerThreshold, 0.35)
        XCTAssertTrue(keyword.isEnabled)
    }

    func test_triggerKeyword_initWithCustomValues_hasCorrectValues() {
        let customId = UUID()
        let keyword = TriggerKeyword(
            id: customId,
            phrase: "Custom Phrase",
            boostingScore: 1.8,
            triggerThreshold: 0.5,
            isEnabled: false
        )

        XCTAssertEqual(keyword.id, customId)
        XCTAssertEqual(keyword.phrase, "Custom Phrase")
        XCTAssertEqual(keyword.boostingScore, 1.8)
        XCTAssertEqual(keyword.triggerThreshold, 0.5)
        XCTAssertFalse(keyword.isEnabled)
    }

    // MARK: - TriggerKeyword Validation Tests

    func test_triggerKeyword_isValid_returnsTrueForValidKeyword() {
        let keyword = TriggerKeyword(
            phrase: "Valid Phrase",
            boostingScore: 1.5,
            triggerThreshold: 0.5,
            isEnabled: true
        )

        XCTAssertTrue(keyword.isValid)
    }

    func test_triggerKeyword_isValid_returnsFalseForEmptyPhrase() {
        let keyword = TriggerKeyword(
            phrase: "",
            boostingScore: 1.5,
            triggerThreshold: 0.5,
            isEnabled: true
        )

        XCTAssertFalse(keyword.isValid)
    }

    func test_triggerKeyword_isValid_returnsFalseForWhitespaceOnlyPhrase() {
        let keyword = TriggerKeyword(
            phrase: "   ",
            boostingScore: 1.5,
            triggerThreshold: 0.5,
            isEnabled: true
        )

        XCTAssertFalse(keyword.isValid)
    }

    func test_triggerKeyword_isValid_returnsTrueAtBoostingScoreBoundaries() {
        let keywordAtMin = TriggerKeyword(phrase: "Test", boostingScore: 1.0, triggerThreshold: 0.5)
        let keywordAtMax = TriggerKeyword(phrase: "Test", boostingScore: 2.0, triggerThreshold: 0.5)

        XCTAssertTrue(keywordAtMin.isValid)
        XCTAssertTrue(keywordAtMax.isValid)
    }

    func test_triggerKeyword_isValid_returnsTrueAtTriggerThresholdBoundaries() {
        let keywordAtMin = TriggerKeyword(phrase: "Test", boostingScore: 1.5, triggerThreshold: 0.0)
        let keywordAtMax = TriggerKeyword(phrase: "Test", boostingScore: 1.5, triggerThreshold: 1.0)

        XCTAssertTrue(keywordAtMin.isValid)
        XCTAssertTrue(keywordAtMax.isValid)
    }

    // MARK: - TriggerKeyword Value Clamping Tests

    func test_triggerKeyword_boostingScore_clampsToMinimum() {
        let keyword = TriggerKeyword(
            phrase: "Test",
            boostingScore: 0.5,  // Below minimum of 1.0
            triggerThreshold: 0.5
        )

        XCTAssertEqual(keyword.boostingScore, 1.0)
    }

    func test_triggerKeyword_boostingScore_clampsToMaximum() {
        let keyword = TriggerKeyword(
            phrase: "Test",
            boostingScore: 3.0,  // Above maximum of 2.0
            triggerThreshold: 0.5
        )

        XCTAssertEqual(keyword.boostingScore, 2.0)
    }

    func test_triggerKeyword_boostingScore_preservesValidValues() {
        let keyword = TriggerKeyword(
            phrase: "Test",
            boostingScore: 1.75,  // Within valid range
            triggerThreshold: 0.5
        )

        XCTAssertEqual(keyword.boostingScore, 1.75)
    }

    func test_triggerKeyword_triggerThreshold_clampsToMinimum() {
        let keyword = TriggerKeyword(
            phrase: "Test",
            boostingScore: 1.5,
            triggerThreshold: -0.5  // Below minimum of 0.0
        )

        XCTAssertEqual(keyword.triggerThreshold, 0.0)
    }

    func test_triggerKeyword_triggerThreshold_clampsToMaximum() {
        let keyword = TriggerKeyword(
            phrase: "Test",
            boostingScore: 1.5,
            triggerThreshold: 1.5  // Above maximum of 1.0
        )

        XCTAssertEqual(keyword.triggerThreshold, 1.0)
    }

    func test_triggerKeyword_triggerThreshold_preservesValidValues() {
        let keyword = TriggerKeyword(
            phrase: "Test",
            boostingScore: 1.5,
            triggerThreshold: 0.65  // Within valid range
        )

        XCTAssertEqual(keyword.triggerThreshold, 0.65)
    }

    // MARK: - TriggerKeyword Codable Tests

    func test_triggerKeyword_codableRoundtrip() throws {
        let original = TriggerKeyword(
            phrase: "Hey Claude",
            boostingScore: 1.7,
            triggerThreshold: 0.4,
            isEnabled: true
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TriggerKeyword.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.phrase, original.phrase)
        XCTAssertEqual(decoded.boostingScore, original.boostingScore)
        XCTAssertEqual(decoded.triggerThreshold, original.triggerThreshold)
        XCTAssertEqual(decoded.isEnabled, original.isEnabled)
    }

    func test_triggerKeyword_decode_clampsBoostingScoreBelowMinimum() throws {
        // Create JSON with out-of-range boostingScore
        let json = """
        {
            "id": "12345678-1234-1234-1234-123456789012",
            "phrase": "Test",
            "boostingScore": 0.5,
            "triggerThreshold": 0.5,
            "isEnabled": true
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(TriggerKeyword.self, from: json)

        XCTAssertEqual(decoded.boostingScore, 1.0)  // Clamped to minimum
    }

    func test_triggerKeyword_decode_clampsBoostingScoreAboveMaximum() throws {
        let json = """
        {
            "id": "12345678-1234-1234-1234-123456789012",
            "phrase": "Test",
            "boostingScore": 5.0,
            "triggerThreshold": 0.5,
            "isEnabled": true
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(TriggerKeyword.self, from: json)

        XCTAssertEqual(decoded.boostingScore, 2.0)  // Clamped to maximum
    }

    func test_triggerKeyword_decode_clampsTriggerThresholdBelowMinimum() throws {
        let json = """
        {
            "id": "12345678-1234-1234-1234-123456789012",
            "phrase": "Test",
            "boostingScore": 1.5,
            "triggerThreshold": -0.5,
            "isEnabled": true
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(TriggerKeyword.self, from: json)

        XCTAssertEqual(decoded.triggerThreshold, 0.0)  // Clamped to minimum
    }

    func test_triggerKeyword_decode_clampsTriggerThresholdAboveMaximum() throws {
        let json = """
        {
            "id": "12345678-1234-1234-1234-123456789012",
            "phrase": "Test",
            "boostingScore": 1.5,
            "triggerThreshold": 2.0,
            "isEnabled": true
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(TriggerKeyword.self, from: json)

        XCTAssertEqual(decoded.triggerThreshold, 1.0)  // Clamped to maximum
    }

    // MARK: - TriggerKeyword Preset Constants Tests

    func test_triggerKeyword_heyClaudeDefault_hasCorrectValues() {
        let preset = TriggerKeyword.heyClaudeDefault

        XCTAssertEqual(preset.id, UUID(uuidString: "00000001-0000-0000-0000-000000000001")!)
        XCTAssertEqual(preset.phrase, "Hey Claude")
        XCTAssertEqual(preset.boostingScore, 1.5)
        XCTAssertEqual(preset.triggerThreshold, 0.35)
        XCTAssertTrue(preset.isEnabled)
        XCTAssertTrue(preset.isValid)
    }

    func test_triggerKeyword_claudePreset_hasCorrectValues() {
        let preset = TriggerKeyword.claudePreset

        XCTAssertEqual(preset.id, UUID(uuidString: "00000001-0000-0000-0000-000000000002")!)
        XCTAssertEqual(preset.phrase, "Claude")
        XCTAssertEqual(preset.boostingScore, 1.3)
        XCTAssertEqual(preset.triggerThreshold, 0.4)
        XCTAssertFalse(preset.isEnabled)
        XCTAssertTrue(preset.isValid)
    }

    func test_triggerKeyword_opusPreset_hasCorrectValues() {
        let preset = TriggerKeyword.opusPreset

        XCTAssertEqual(preset.id, UUID(uuidString: "00000001-0000-0000-0000-000000000003")!)
        XCTAssertEqual(preset.phrase, "Opus")
        XCTAssertEqual(preset.boostingScore, 1.3)
        XCTAssertEqual(preset.triggerThreshold, 0.4)
        XCTAssertFalse(preset.isEnabled)
        XCTAssertTrue(preset.isValid)
    }

    func test_triggerKeyword_sonnetPreset_hasCorrectValues() {
        let preset = TriggerKeyword.sonnetPreset

        XCTAssertEqual(preset.id, UUID(uuidString: "00000001-0000-0000-0000-000000000004")!)
        XCTAssertEqual(preset.phrase, "Sonnet")
        XCTAssertEqual(preset.boostingScore, 1.3)
        XCTAssertEqual(preset.triggerThreshold, 0.4)
        XCTAssertFalse(preset.isEnabled)
        XCTAssertTrue(preset.isValid)
    }

    func test_triggerKeyword_presets_haveUniqueIds() {
        let presetIds = [
            TriggerKeyword.heyClaudeDefault.id,
            TriggerKeyword.claudePreset.id,
            TriggerKeyword.opusPreset.id,
            TriggerKeyword.sonnetPreset.id
        ]

        let uniqueIds = Set(presetIds)
        XCTAssertEqual(uniqueIds.count, presetIds.count, "All preset keywords should have unique IDs")
    }

    // MARK: - TriggerKeyword DisplayName Tests

    func test_triggerKeyword_displayName_returnsPhrase() {
        let keyword = TriggerKeyword(phrase: "Hey Claude")

        XCTAssertEqual(keyword.displayName, "Hey Claude")
    }

    func test_triggerKeyword_displayName_returnsEmptyPlaceholderForEmptyPhrase() {
        let keyword = TriggerKeyword(phrase: "")

        XCTAssertEqual(keyword.displayName, "(empty)")
    }

    func test_triggerKeyword_displayName_preservesWhitespaceInPhrase() {
        let keyword = TriggerKeyword(phrase: "  Hey Claude  ")

        XCTAssertEqual(keyword.displayName, "  Hey Claude  ")
    }

    // MARK: - TriggerKeyword Equatable Tests

    func test_triggerKeyword_equatable_sameValuesAreEqual() {
        let id = UUID()
        let keyword1 = TriggerKeyword(id: id, phrase: "Test", boostingScore: 1.5, triggerThreshold: 0.5, isEnabled: true)
        let keyword2 = TriggerKeyword(id: id, phrase: "Test", boostingScore: 1.5, triggerThreshold: 0.5, isEnabled: true)

        XCTAssertEqual(keyword1, keyword2)
    }

    func test_triggerKeyword_equatable_differentIdsAreNotEqual() {
        let keyword1 = TriggerKeyword(id: UUID(), phrase: "Test", boostingScore: 1.5, triggerThreshold: 0.5, isEnabled: true)
        let keyword2 = TriggerKeyword(id: UUID(), phrase: "Test", boostingScore: 1.5, triggerThreshold: 0.5, isEnabled: true)

        XCTAssertNotEqual(keyword1, keyword2)
    }

    // MARK: - VoiceTriggerConfiguration Initialization Tests

    func test_voiceTriggerConfiguration_initWithDefaults_hasCorrectValues() {
        let config = VoiceTriggerConfiguration()

        XCTAssertFalse(config.enabled)
        XCTAssertEqual(config.keywords.count, 1)
        XCTAssertEqual(config.keywords.first, TriggerKeyword.heyClaudeDefault)
        XCTAssertEqual(config.silenceThresholdSeconds, 5.0)
        XCTAssertTrue(config.feedbackSoundEnabled)
        XCTAssertTrue(config.feedbackVisualEnabled)
        XCTAssertEqual(config.maxRecordingDuration, 60.0)
    }

    func test_voiceTriggerConfiguration_initWithCustomValues_hasCorrectValues() {
        let customKeywords = [
            TriggerKeyword(phrase: "Custom 1"),
            TriggerKeyword(phrase: "Custom 2")
        ]
        let config = VoiceTriggerConfiguration(
            enabled: true,
            keywords: customKeywords,
            silenceThresholdSeconds: 3.0,
            feedbackSoundEnabled: false,
            feedbackVisualEnabled: false,
            maxRecordingDuration: 30.0
        )

        XCTAssertTrue(config.enabled)
        XCTAssertEqual(config.keywords.count, 2)
        XCTAssertEqual(config.keywords[0].phrase, "Custom 1")
        XCTAssertEqual(config.keywords[1].phrase, "Custom 2")
        XCTAssertEqual(config.silenceThresholdSeconds, 3.0)
        XCTAssertFalse(config.feedbackSoundEnabled)
        XCTAssertFalse(config.feedbackVisualEnabled)
        XCTAssertEqual(config.maxRecordingDuration, 30.0)
    }

    // MARK: - VoiceTriggerConfiguration Default Static Property Tests

    func test_voiceTriggerConfiguration_default_hasCorrectValues() {
        let defaultConfig = VoiceTriggerConfiguration.default

        XCTAssertFalse(defaultConfig.enabled)
        XCTAssertEqual(defaultConfig.keywords.count, 1)
        XCTAssertEqual(defaultConfig.keywords.first, TriggerKeyword.heyClaudeDefault)
        XCTAssertEqual(defaultConfig.silenceThresholdSeconds, 5.0)
        XCTAssertTrue(defaultConfig.feedbackSoundEnabled)
        XCTAssertTrue(defaultConfig.feedbackVisualEnabled)
        XCTAssertEqual(defaultConfig.maxRecordingDuration, 60.0)
    }

    func test_voiceTriggerConfiguration_default_matchesParameterlessInit() {
        let defaultConfig = VoiceTriggerConfiguration.default
        let initConfig = VoiceTriggerConfiguration()

        XCTAssertEqual(defaultConfig.enabled, initConfig.enabled)
        XCTAssertEqual(defaultConfig.keywords, initConfig.keywords)
        XCTAssertEqual(defaultConfig.silenceThresholdSeconds, initConfig.silenceThresholdSeconds)
        XCTAssertEqual(defaultConfig.feedbackSoundEnabled, initConfig.feedbackSoundEnabled)
        XCTAssertEqual(defaultConfig.feedbackVisualEnabled, initConfig.feedbackVisualEnabled)
        XCTAssertEqual(defaultConfig.maxRecordingDuration, initConfig.maxRecordingDuration)
    }

    // MARK: - VoiceTriggerConfiguration Codable Tests

    func test_voiceTriggerConfiguration_codableRoundtrip() throws {
        let original = VoiceTriggerConfiguration(
            enabled: true,
            keywords: [TriggerKeyword.heyClaudeDefault, TriggerKeyword.claudePreset],
            silenceThresholdSeconds: 4.0,
            feedbackSoundEnabled: false,
            feedbackVisualEnabled: true,
            maxRecordingDuration: 45.0
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(VoiceTriggerConfiguration.self, from: data)

        XCTAssertEqual(decoded.enabled, original.enabled)
        XCTAssertEqual(decoded.keywords.count, original.keywords.count)
        XCTAssertEqual(decoded.keywords, original.keywords)
        XCTAssertEqual(decoded.silenceThresholdSeconds, original.silenceThresholdSeconds)
        XCTAssertEqual(decoded.feedbackSoundEnabled, original.feedbackSoundEnabled)
        XCTAssertEqual(decoded.feedbackVisualEnabled, original.feedbackVisualEnabled)
        XCTAssertEqual(decoded.maxRecordingDuration, original.maxRecordingDuration)
    }

    func test_voiceTriggerConfiguration_codableRoundtrip_withDefaultConfig() throws {
        let original = VoiceTriggerConfiguration.default

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(VoiceTriggerConfiguration.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func test_voiceTriggerConfiguration_codableRoundtrip_withEmptyKeywords() throws {
        let original = VoiceTriggerConfiguration(
            enabled: false,
            keywords: [],
            silenceThresholdSeconds: 5.0,
            feedbackSoundEnabled: true,
            feedbackVisualEnabled: true,
            maxRecordingDuration: 60.0
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(VoiceTriggerConfiguration.self, from: data)

        XCTAssertEqual(decoded.keywords.count, 0)
        XCTAssertEqual(decoded, original)
    }

    func test_voiceTriggerConfiguration_codableRoundtrip_withMultipleKeywords() throws {
        let keywords = [
            TriggerKeyword.heyClaudeDefault,
            TriggerKeyword.claudePreset,
            TriggerKeyword.opusPreset,
            TriggerKeyword.sonnetPreset
        ]
        let original = VoiceTriggerConfiguration(
            enabled: true,
            keywords: keywords,
            silenceThresholdSeconds: 3.5,
            feedbackSoundEnabled: true,
            feedbackVisualEnabled: false,
            maxRecordingDuration: 120.0
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(VoiceTriggerConfiguration.self, from: data)

        XCTAssertEqual(decoded.keywords.count, 4)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - VoiceTriggerConfiguration Equatable Tests

    func test_voiceTriggerConfiguration_equatable_sameValuesAreEqual() {
        let config1 = VoiceTriggerConfiguration.default
        let config2 = VoiceTriggerConfiguration.default

        XCTAssertEqual(config1, config2)
    }

    func test_voiceTriggerConfiguration_equatable_differentEnabledAreNotEqual() {
        let config1 = VoiceTriggerConfiguration(enabled: true)
        let config2 = VoiceTriggerConfiguration(enabled: false)

        XCTAssertNotEqual(config1, config2)
    }

    func test_voiceTriggerConfiguration_equatable_differentKeywordsAreNotEqual() {
        let config1 = VoiceTriggerConfiguration(keywords: [TriggerKeyword.heyClaudeDefault])
        let config2 = VoiceTriggerConfiguration(keywords: [TriggerKeyword.claudePreset])

        XCTAssertNotEqual(config1, config2)
    }

    // MARK: - VoiceTriggerConfiguration Mutability Tests

    func test_voiceTriggerConfiguration_canModifyEnabled() {
        var config = VoiceTriggerConfiguration.default
        config.enabled = true

        XCTAssertTrue(config.enabled)
    }

    func test_voiceTriggerConfiguration_canModifyKeywords() {
        var config = VoiceTriggerConfiguration.default
        config.keywords.append(TriggerKeyword.claudePreset)

        XCTAssertEqual(config.keywords.count, 2)
    }

    func test_voiceTriggerConfiguration_canModifySilenceThreshold() {
        var config = VoiceTriggerConfiguration.default
        config.silenceThresholdSeconds = 10.0

        XCTAssertEqual(config.silenceThresholdSeconds, 10.0)
    }

    func test_voiceTriggerConfiguration_canModifyFeedbackSettings() {
        var config = VoiceTriggerConfiguration.default
        config.feedbackSoundEnabled = false
        config.feedbackVisualEnabled = false

        XCTAssertFalse(config.feedbackSoundEnabled)
        XCTAssertFalse(config.feedbackVisualEnabled)
    }

    func test_voiceTriggerConfiguration_canModifyMaxRecordingDuration() {
        var config = VoiceTriggerConfiguration.default
        config.maxRecordingDuration = 120.0

        XCTAssertEqual(config.maxRecordingDuration, 120.0)
    }

    // MARK: - TriggerKeyword Identifiable Tests

    func test_triggerKeyword_identifiable_idIsStable() {
        let keyword = TriggerKeyword(phrase: "Test")
        let id1 = keyword.id
        let id2 = keyword.id

        XCTAssertEqual(id1, id2)
    }

    func test_triggerKeyword_identifiable_presetsHaveStableIds() {
        // Verify preset IDs are fixed and don't change
        XCTAssertEqual(TriggerKeyword.heyClaudeDefault.id.uuidString, "00000001-0000-0000-0000-000000000001")
        XCTAssertEqual(TriggerKeyword.claudePreset.id.uuidString, "00000001-0000-0000-0000-000000000002")
        XCTAssertEqual(TriggerKeyword.opusPreset.id.uuidString, "00000001-0000-0000-0000-000000000003")
        XCTAssertEqual(TriggerKeyword.sonnetPreset.id.uuidString, "00000001-0000-0000-0000-000000000004")
    }

    // MARK: - Sendable Conformance Tests

    func test_triggerKeyword_isSendable() {
        // This test verifies TriggerKeyword can be passed across concurrency boundaries
        let keyword = TriggerKeyword(phrase: "Test")

        Task {
            let _ = keyword  // If this compiles, TriggerKeyword is Sendable
        }
    }

    func test_voiceTriggerConfiguration_isSendable() {
        // This test verifies VoiceTriggerConfiguration can be passed across concurrency boundaries
        let config = VoiceTriggerConfiguration.default

        Task {
            let _ = config  // If this compiles, VoiceTriggerConfiguration is Sendable
        }
    }
}
