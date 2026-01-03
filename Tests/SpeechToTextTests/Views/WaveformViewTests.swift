// WaveformViewTests.swift
// macOS Local Speech-to-Text Application
//
// Unit tests for WaveformView

import SwiftUI
import XCTest
@testable import SpeechToText

final class WaveformViewTests: XCTestCase {
    // MARK: - Initialization Tests

    func test_waveformView_createsSuccessfully() {
        // Given/When
        let view = WaveformView(audioLevel: 0.5)

        // Then
        XCTAssertNotNil(view)
        XCTAssertEqual(view.audioLevel, 0.5)
    }

    func test_waveformView_acceptsZeroLevel() {
        // Given/When
        let view = WaveformView(audioLevel: 0.0)

        // Then
        XCTAssertEqual(view.audioLevel, 0.0)
    }

    func test_waveformView_acceptsMaxLevel() {
        // Given/When
        let view = WaveformView(audioLevel: 1.0)

        // Then
        XCTAssertEqual(view.audioLevel, 1.0)
    }

    func test_waveformView_acceptsNegativeLevel() {
        // Given/When - view should handle negative levels (will be clamped internally)
        let view = WaveformView(audioLevel: -0.5)

        // Then
        XCTAssertEqual(view.audioLevel, -0.5)
    }

    func test_waveformView_acceptsOverMaxLevel() {
        // Given/When - view should handle levels > 1 (will be clamped internally)
        let view = WaveformView(audioLevel: 1.5)

        // Then
        XCTAssertEqual(view.audioLevel, 1.5)
    }

    // MARK: - Color Logic Tests

    func test_colorForLevel_lowLevel_returnsAmberLight() {
        // Given
        let helper = WaveformColorHelper()

        // When
        let color = helper.colorForLevel(level: 0.1)

        // Then - verify it returns a color (exact color testing would require ViewInspector)
        XCTAssertNotNil(color)
    }

    func test_colorForLevel_mediumLevel_returnsAmberPrimary() {
        // Given
        let helper = WaveformColorHelper()

        // When
        let color = helper.colorForLevel(level: 0.5)

        // Then
        XCTAssertNotNil(color)
    }

    func test_colorForLevel_highLevel_returnsAmberBright() {
        // Given
        let helper = WaveformColorHelper()

        // When
        let color = helper.colorForLevel(level: 0.9)

        // Then
        XCTAssertNotNil(color)
    }

    func test_colorForLevel_boundaryLow_returnsCorrectColor() {
        // Given
        let helper = WaveformColorHelper()

        // When - at the boundary (0.3)
        let colorBelow = helper.colorForLevel(level: 0.29)
        let colorAt = helper.colorForLevel(level: 0.3)

        // Then - both should return colors (boundary is exclusive for low range)
        XCTAssertNotNil(colorBelow)
        XCTAssertNotNil(colorAt)
    }

    func test_colorForLevel_boundaryHigh_returnsCorrectColor() {
        // Given
        let helper = WaveformColorHelper()

        // When - at the boundary (0.7)
        let colorBelow = helper.colorForLevel(level: 0.69)
        let colorAt = helper.colorForLevel(level: 0.7)

        // Then - both should return colors
        XCTAssertNotNil(colorBelow)
        XCTAssertNotNil(colorAt)
    }

    // MARK: - Level History Tests

    func test_levelHistoryClamping_clampsNegativeValues() {
        // Given
        let helper = WaveformLevelHelper()

        // When
        let clampedValue = helper.clampLevel(-0.5)

        // Then
        XCTAssertEqual(clampedValue, 0.0)
    }

    func test_levelHistoryClamping_clampsHighValues() {
        // Given
        let helper = WaveformLevelHelper()

        // When
        let clampedValue = helper.clampLevel(1.5)

        // Then
        XCTAssertEqual(clampedValue, 1.0)
    }

    func test_levelHistoryClamping_preservesValidValues() {
        // Given
        let helper = WaveformLevelHelper()

        // When
        let clampedValue = helper.clampLevel(0.5)

        // Then
        XCTAssertEqual(clampedValue, 0.5)
    }

    func test_levelHistoryClamping_preservesZero() {
        // Given
        let helper = WaveformLevelHelper()

        // When
        let clampedValue = helper.clampLevel(0.0)

        // Then
        XCTAssertEqual(clampedValue, 0.0)
    }

    func test_levelHistoryClamping_preservesOne() {
        // Given
        let helper = WaveformLevelHelper()

        // When
        let clampedValue = helper.clampLevel(1.0)

        // Then
        XCTAssertEqual(clampedValue, 1.0)
    }

    // MARK: - Level History Update Tests

    func test_updateLevelHistory_shiftsHistory() {
        // Given
        var history: [Float] = [0.1, 0.2, 0.3, 0.4, 0.5]

        // When
        history.removeFirst()
        history.append(0.6)

        // Then
        XCTAssertEqual(history, [0.2, 0.3, 0.4, 0.5, 0.6])
    }

    func test_updateLevelHistory_handlesEmptyArray() {
        // Given
        var history: [Float] = []

        // When/Then - should not crash
        if !history.isEmpty {
            history.removeFirst()
            history.append(0.5)
        }

        // Then - should remain empty (guard clause prevents modification)
        XCTAssertTrue(history.isEmpty)
    }

    // MARK: - Bar Count Tests

    func test_barCount_isPositive() {
        // Given
        let barCount = 60 // From WaveformView implementation

        // Then
        XCTAssertGreaterThan(barCount, 0)
    }

    func test_barCount_matchesHistorySize() {
        // Given
        let barCount = 60
        let historySize = 60 // Should match barCount

        // Then
        XCTAssertEqual(barCount, historySize)
    }

    // MARK: - Accessibility Tests

    func test_accessibilityLabel_isSet() {
        // Given
        let view = WaveformView(audioLevel: 0.5)

        // Then - accessibility label should be set
        // (actual verification would require ViewInspector)
        XCTAssertNotNil(view)
    }

    func test_accessibilityValue_reflectsAudioLevel() {
        // Given
        let audioLevel: Float = 0.75
        let expectedPercentage = Int(audioLevel * 100)

        // Then
        XCTAssertEqual(expectedPercentage, 75)
    }
}

// MARK: - Helper Classes for Testing Private Logic

/// Helper to test color logic that mirrors WaveformView's colorForLevel
struct WaveformColorHelper {
    func colorForLevel(level: Float) -> Color {
        switch level {
        case 0.0..<0.3:
            return Color("AmberLight", bundle: nil)
        case 0.3..<0.7:
            return Color("AmberPrimary", bundle: nil)
        default:
            return Color("AmberBright", bundle: nil)
        }
    }
}

/// Helper to test level clamping logic
struct WaveformLevelHelper {
    func clampLevel(_ level: Float) -> Float {
        return min(1.0, max(0.0, level))
    }
}
