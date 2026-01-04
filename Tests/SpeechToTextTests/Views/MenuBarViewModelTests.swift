// MenuBarViewModelTests.swift
// macOS Local Speech-to-Text Application
//
// Unit tests for MenuBarViewModel (Ultra-minimal version)

import XCTest
@testable import SpeechToText

@MainActor
final class MenuBarViewModelTests: XCTestCase {
    // MARK: - Properties

    var sut: MenuBarViewModel!
    var notificationObserver: NSObjectProtocol?

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        sut = MenuBarViewModel()

        // Wait for init task to complete (permission check)
        try await Task.sleep(nanoseconds: 100_000_000)
    }

    override func tearDown() async throws {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
            notificationObserver = nil
        }
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func test_initialization_setsDefaultState() {
        let viewModel = MenuBarViewModel()

        // Then - check initial state
        XCTAssertFalse(viewModel.isRecording)
        // hasPermission depends on system state, so we don't assert on it
    }

    // MARK: - Status Icon Tests

    func test_statusIcon_returnsMicSlashWhenNoPermission() {
        // Given
        sut.hasPermission = false

        // Then
        XCTAssertEqual(sut.statusIcon, "mic.slash")
    }

    func test_statusIcon_returnsMicFillWhenHasPermission() {
        // Given
        sut.hasPermission = true
        sut.isRecording = false

        // Then
        XCTAssertEqual(sut.statusIcon, "mic.fill")
    }

    func test_statusIcon_returnsMicFillWhenRecording() {
        // Given
        sut.hasPermission = true
        sut.isRecording = true

        // Then
        XCTAssertEqual(sut.statusIcon, "mic.fill")
    }

    // MARK: - Icon Color Tests

    func test_iconColor_returnsGrayWhenNoPermission() {
        // Given
        sut.hasPermission = false

        // Then
        XCTAssertEqual(sut.iconColor, .gray)
    }

    func test_iconColor_returnsRedWhenRecording() {
        // Given
        sut.hasPermission = true
        sut.isRecording = true

        // Then
        XCTAssertEqual(sut.iconColor, .red)
    }

    // MARK: - openMainView Tests

    func test_openMainView_postsShowMainViewNotification() {
        // Given
        var notificationReceived = false
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .showMainView,
            object: nil,
            queue: .main
        ) { _ in
            notificationReceived = true
        }

        // When
        sut.openMainView()

        // Then
        XCTAssertTrue(notificationReceived)
    }
}
