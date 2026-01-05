// HotkeyManagerTests.swift
// macOS Local Speech-to-Text Application
//
// Unit tests for HotkeyManager

import XCTest
@testable import SpeechToText

@MainActor
final class HotkeyManagerTests: XCTestCase {
    // MARK: - Properties

    var sut: HotkeyManager!
    var recordingStartCallCount: Int = 0
    var recordingStopCallCount: Int = 0
    var recordingCancelCallCount: Int = 0
    var lastStopDuration: TimeInterval?
    var currentTestTime: Date = Date()

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()

        currentTestTime = Date()

        // Create HotkeyManager with skipHotkeySetup to avoid KeyboardShortcuts dependency in tests
        sut = HotkeyManager(
            minimumHoldDuration: 0.1,
            cooldownInterval: 0.3,
            skipHotkeySetup: true
        )

        // Inject test time provider
        sut.currentTimeProvider = { [weak self] in
            self?.currentTestTime ?? Date()
        }

        // Reset counters
        recordingStartCallCount = 0
        recordingStopCallCount = 0
        recordingCancelCallCount = 0
        lastStopDuration = nil

        // Set up callbacks
        sut.onRecordingStart = { [weak self] in
            self?.recordingStartCallCount += 1
        }
        sut.onRecordingStop = { [weak self] duration in
            self?.recordingStopCallCount += 1
            self?.lastStopDuration = duration
        }
        sut.onRecordingCancel = { [weak self] in
            self?.recordingCancelCallCount += 1
        }
    }

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func test_initialization_setsDefaultConfiguration() {
        // Given/When
        let manager = HotkeyManager(skipHotkeySetup: true)

        // Then
        XCTAssertEqual(manager.minimumHoldDuration, 0.1)
        XCTAssertEqual(manager.cooldownInterval, 0.3)
        XCTAssertFalse(manager.isCurrentlyProcessing)
    }

    func test_initialization_acceptsCustomConfiguration() {
        // Given/When
        let manager = HotkeyManager(
            minimumHoldDuration: 0.5,
            cooldownInterval: 1.0,
            skipHotkeySetup: true
        )

        // Then
        XCTAssertEqual(manager.minimumHoldDuration, 0.5)
        XCTAssertEqual(manager.cooldownInterval, 1.0)
    }

    // MARK: - handleKeyDown Tests

    func test_handleKeyDown_invokesOnRecordingStartCallback() async {
        // When
        await sut.handleKeyDown()

        // Then
        XCTAssertEqual(recordingStartCallCount, 1)
        XCTAssertTrue(sut.isCurrentlyProcessing)
    }

    func test_handleKeyDown_ignoresDuplicateWhileProcessing() async {
        // Given
        await sut.handleKeyDown()
        XCTAssertEqual(recordingStartCallCount, 1)

        // When - second key down while processing
        await sut.handleKeyDown()

        // Then - should still be 1
        XCTAssertEqual(recordingStartCallCount, 1)
    }

    func test_handleKeyDown_ignoresKeyPressWithinCooldown() async {
        // Given - complete one cycle
        await sut.handleKeyDown()

        // Advance time by 0.5 seconds (enough hold duration)
        currentTestTime = currentTestTime.addingTimeInterval(0.5)
        await sut.handleKeyUp()

        XCTAssertEqual(recordingStartCallCount, 1)
        XCTAssertEqual(recordingStopCallCount, 1)

        // When - try to start again immediately (within 0.3s cooldown)
        currentTestTime = currentTestTime.addingTimeInterval(0.1)
        await sut.handleKeyDown()

        // Then - should still be 1 (blocked by cooldown)
        XCTAssertEqual(recordingStartCallCount, 1)
    }

    func test_handleKeyDown_allowsKeyPressAfterCooldownExpires() async {
        // Given - complete one cycle
        await sut.handleKeyDown()
        currentTestTime = currentTestTime.addingTimeInterval(0.5)
        await sut.handleKeyUp()

        XCTAssertEqual(recordingStartCallCount, 1)

        // When - wait for cooldown to expire (0.4s > 0.3s)
        currentTestTime = currentTestTime.addingTimeInterval(0.4)
        await sut.handleKeyDown()

        // Then - should be 2 now
        XCTAssertEqual(recordingStartCallCount, 2)
    }

    // MARK: - handleKeyUp Tests

    func test_handleKeyUp_ignoresWhenNotProcessing() async {
        // When - key up without prior key down
        await sut.handleKeyUp()

        // Then
        XCTAssertEqual(recordingStopCallCount, 0)
        XCTAssertEqual(recordingCancelCallCount, 0)
    }

    func test_handleKeyUp_invokesOnRecordingStopWhenDurationSufficient() async {
        // Given
        await sut.handleKeyDown()

        // Advance time by 0.5 seconds
        currentTestTime = currentTestTime.addingTimeInterval(0.5)

        // When
        await sut.handleKeyUp()

        // Then
        XCTAssertEqual(recordingStopCallCount, 1)
        XCTAssertEqual(recordingCancelCallCount, 0)
        XCTAssertNotNil(lastStopDuration)
        XCTAssertEqual(lastStopDuration!, 0.5, accuracy: 0.01)
        XCTAssertFalse(sut.isCurrentlyProcessing)
    }

    func test_handleKeyUp_invokesOnRecordingCancelWhenDurationTooShort() async {
        // Given
        await sut.handleKeyDown()

        // Advance time by only 0.05 seconds (below 0.1s minimum)
        currentTestTime = currentTestTime.addingTimeInterval(0.05)

        // When
        await sut.handleKeyUp()

        // Then
        XCTAssertEqual(recordingStopCallCount, 0)
        XCTAssertEqual(recordingCancelCallCount, 1)
        XCTAssertFalse(sut.isCurrentlyProcessing)
    }

    func test_handleKeyUp_resetsStateAfterCompletion() async {
        // Given
        await sut.handleKeyDown()
        XCTAssertTrue(sut.isCurrentlyProcessing)

        currentTestTime = currentTestTime.addingTimeInterval(0.5)

        // When
        await sut.handleKeyUp()

        // Then
        XCTAssertFalse(sut.isCurrentlyProcessing)
    }

    func test_handleKeyUp_passesAccurateDuration() async {
        // Given
        await sut.handleKeyDown()

        // Advance by exactly 2.5 seconds
        currentTestTime = currentTestTime.addingTimeInterval(2.5)

        // When
        await sut.handleKeyUp()

        // Then
        XCTAssertEqual(lastStopDuration!, 2.5, accuracy: 0.001)
    }

    // MARK: - cancel() Tests

    func test_cancel_resetsProcessingState() async {
        // Given
        await sut.handleKeyDown()
        XCTAssertTrue(sut.isCurrentlyProcessing)

        // When
        sut.cancel()

        // Then
        XCTAssertFalse(sut.isCurrentlyProcessing)
    }

    func test_cancel_preventsSubsequentKeyUpFromInvokingCallback() async {
        // Given
        await sut.handleKeyDown()
        XCTAssertEqual(recordingStartCallCount, 1)

        // When
        sut.cancel()
        await sut.handleKeyUp()

        // Then - no callbacks should be invoked
        XCTAssertEqual(recordingStopCallCount, 0)
        XCTAssertEqual(recordingCancelCallCount, 0)
    }

    func test_cancel_isSafeWhenNotProcessing() {
        // Given - not processing
        XCTAssertFalse(sut.isCurrentlyProcessing)

        // When
        sut.cancel()

        // Then - no crash, state unchanged
        XCTAssertFalse(sut.isCurrentlyProcessing)
    }

    // MARK: - Edge Case Tests

    func test_exactlyMinimumDuration_triggersStop() async {
        // Given
        await sut.handleKeyDown()

        // Advance by exactly minimum duration (0.1s)
        currentTestTime = currentTestTime.addingTimeInterval(0.1)

        // When
        await sut.handleKeyUp()

        // Then - should trigger stop, not cancel
        XCTAssertEqual(recordingStopCallCount, 1)
        XCTAssertEqual(recordingCancelCallCount, 0)
    }

    func test_slightlyBelowMinimumDuration_triggersCancel() async {
        // Given
        await sut.handleKeyDown()

        // Advance by just below minimum duration
        currentTestTime = currentTestTime.addingTimeInterval(0.099)

        // When
        await sut.handleKeyUp()

        // Then - should trigger cancel
        XCTAssertEqual(recordingStopCallCount, 0)
        XCTAssertEqual(recordingCancelCallCount, 1)
    }

    func test_multipleCompleteCycles_workCorrectly() async {
        // Cycle 1
        await sut.handleKeyDown()
        currentTestTime = currentTestTime.addingTimeInterval(0.5)
        await sut.handleKeyUp()

        XCTAssertEqual(recordingStartCallCount, 1)
        XCTAssertEqual(recordingStopCallCount, 1)

        // Wait for cooldown
        currentTestTime = currentTestTime.addingTimeInterval(0.4)

        // Cycle 2
        await sut.handleKeyDown()
        currentTestTime = currentTestTime.addingTimeInterval(1.0)
        await sut.handleKeyUp()

        XCTAssertEqual(recordingStartCallCount, 2)
        XCTAssertEqual(recordingStopCallCount, 2)

        // Wait for cooldown
        currentTestTime = currentTestTime.addingTimeInterval(0.4)

        // Cycle 3 (short - cancelled)
        await sut.handleKeyDown()
        currentTestTime = currentTestTime.addingTimeInterval(0.05)
        await sut.handleKeyUp()

        XCTAssertEqual(recordingStartCallCount, 3)
        XCTAssertEqual(recordingStopCallCount, 2)
        XCTAssertEqual(recordingCancelCallCount, 1)
    }

    func test_cooldownAppliedImmediatelyOnKeyUp() async {
        // Given - start recording
        await sut.handleKeyDown()
        let keyUpTime = currentTestTime.addingTimeInterval(0.5)
        currentTestTime = keyUpTime
        await sut.handleKeyUp()

        // Then - lastActionTime should be set to keyUp time
        XCTAssertEqual(sut.lastActionTime, keyUpTime)
    }

    // MARK: - Additional Edge Case Tests

    func test_handleKeyDown_worksWhenCallbacksAreNil() async {
        // Given - nil callbacks
        sut.onRecordingStart = nil
        sut.onRecordingStop = nil
        sut.onRecordingCancel = nil

        // When/Then - should not crash
        await sut.handleKeyDown()
        XCTAssertTrue(sut.isCurrentlyProcessing)

        currentTestTime = currentTestTime.addingTimeInterval(0.5)
        await sut.handleKeyUp()

        XCTAssertFalse(sut.isCurrentlyProcessing)
    }

    func test_cooldownAppliesAfterCancelledRecording() async {
        // Given - start and cancel (too short)
        await sut.handleKeyDown()
        currentTestTime = currentTestTime.addingTimeInterval(0.05) // Below minimum
        await sut.handleKeyUp()
        XCTAssertEqual(recordingCancelCallCount, 1)

        // When - try to start immediately (within cooldown)
        currentTestTime = currentTestTime.addingTimeInterval(0.1)
        await sut.handleKeyDown()

        // Then - should be blocked by cooldown
        XCTAssertEqual(recordingStartCallCount, 1) // Still 1, not 2
    }

    func test_zeroDuration_triggersCancel() async {
        // Given
        await sut.handleKeyDown()
        // No time advancement - key up immediately (zero duration)

        // When
        await sut.handleKeyUp()

        // Then
        XCTAssertEqual(recordingCancelCallCount, 1)
        XCTAssertEqual(recordingStopCallCount, 0)
    }

    func test_cancel_doesNotApplyCooldown() async {
        // Given - start recording
        await sut.handleKeyDown()
        XCTAssertEqual(recordingStartCallCount, 1)

        // When - cancel (not key up)
        sut.cancel()

        // Then - should be able to start immediately (no cooldown from cancel)
        await sut.handleKeyDown()
        XCTAssertEqual(recordingStartCallCount, 2)
    }

    func test_veryLongDuration_handledCorrectly() async {
        // Given
        await sut.handleKeyDown()

        // Advance by 5 minutes
        currentTestTime = currentTestTime.addingTimeInterval(300.0)

        // When
        await sut.handleKeyUp()

        // Then
        XCTAssertEqual(lastStopDuration!, 300.0, accuracy: 0.01)
        XCTAssertEqual(recordingStopCallCount, 1)
    }
}
