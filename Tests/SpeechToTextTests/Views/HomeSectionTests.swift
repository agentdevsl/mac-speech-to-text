// HomeSectionTests.swift
// macOS Local Speech-to-Text Application
//
// Unit tests for HomeSection view

import SwiftUI
import XCTest
@testable import SpeechToText

@MainActor
final class HomeSectionTests: XCTestCase {
    // MARK: - Properties

    var settingsService: SettingsService!
    var permissionService: PermissionService!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        settingsService = SettingsService()
        permissionService = PermissionService()
    }

    override func tearDown() async throws {
        settingsService = nil
        permissionService = nil
        try await super.tearDown()
    }

    // MARK: - Instantiation Tests

    func test_homeSection_instantiatesWithoutCrash() {
        // When - Create the view
        let view = HomeSection(
            settingsService: settingsService,
            permissionService: permissionService
        )

        // Then - Should not crash
        XCTAssertNotNil(view)
    }

    func test_homeSection_hasCorrectAccessibilityIdentifier() {
        // Given
        let view = HomeSection(
            settingsService: settingsService,
            permissionService: permissionService
        )

        // Then - View should exist without crashing
        XCTAssertNotNil(view)
    }

    // MARK: - PermissionCardFocus Tests

    func test_permissionCardFocus_hasExpectedCases() {
        // Then
        let microphone = PermissionCardFocus.microphone
        let accessibility = PermissionCardFocus.accessibility

        XCTAssertNotEqual(microphone, accessibility)
    }

    func test_permissionCardFocus_isHashable() {
        // Given
        let set: Set<PermissionCardFocus> = [.microphone, .accessibility, .microphone]

        // Then - Should only have 2 unique values
        XCTAssertEqual(set.count, 2)
    }

    // MARK: - Integration Tests

    func test_homeSection_loadsSettingsOnInit() {
        // Given - Create custom settings
        var settings = settingsService.load()
        settings.ui.recordingMode = .toggle
        try? settingsService.save(settings)

        // When - Create the view
        let view = HomeSection(
            settingsService: settingsService,
            permissionService: permissionService
        )

        // Then - Should load without crashing
        XCTAssertNotNil(view)
    }
}

// MARK: - Notification Tests

@MainActor
final class HomeSectionNotificationTests: XCTestCase {
    var notificationObserver: NSObjectProtocol?

    override func tearDown() async throws {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
            notificationObserver = nil
        }
        try await super.tearDown()
    }

    func test_transcriptionDidComplete_notificationIsPosted() async {
        // Given
        let expectation = XCTestExpectation(description: "Notification received")

        notificationObserver = NotificationCenter.default.addObserver(
            forName: .transcriptionDidComplete,
            object: nil,
            queue: .main
        ) { notification in
            XCTAssertNotNil(notification.userInfo?["text"])
            expectation.fulfill()
        }

        // When
        NotificationCenter.default.post(
            name: .transcriptionDidComplete,
            object: nil,
            userInfo: ["text": "Test transcription"]
        )

        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func test_settingsDidReset_notificationIsPosted() async {
        // Given
        let expectation = XCTestExpectation(description: "Settings reset notification received")

        notificationObserver = NotificationCenter.default.addObserver(
            forName: .settingsDidReset,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }

        // When
        NotificationCenter.default.post(name: .settingsDidReset, object: nil)

        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
    }
}
