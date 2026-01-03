// IntegrationTestBase.swift
// Real-world integration tests using actual services (not mocks)
//
// These tests require:
// - Microphone permission granted
// - Accessibility permission granted
// - Input monitoring permission granted
// - Network access for model download (first run)

import XCTest
@testable import SpeechToText

/// Base class for integration tests that use real services
@MainActor
class IntegrationTestBase: XCTestCase {
    // MARK: - Real Services (not mocks)

    var permissionService: PermissionService!
    var audioCaptureService: AudioCaptureService!
    var fluidAudioService: FluidAudioService!
    var textInsertionService: TextInsertionService!
    var settingsService: SettingsService!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        // Initialize real services
        permissionService = PermissionService()
        audioCaptureService = AudioCaptureService()
        fluidAudioService = FluidAudioService()
        textInsertionService = TextInsertionService()
        settingsService = SettingsService()

        // Log test start
        AppLogger.service.info("🧪 Starting integration test: \(self.name)")
    }

    override func tearDown() async throws {
        // Cleanup
        await fluidAudioService.shutdown()

        AppLogger.service.info("🧪 Finished integration test: \(self.name)")

        try await super.tearDown()
    }

    // MARK: - Permission Helpers

    /// Skip test if microphone permission not granted
    func skipIfMicrophoneNotGranted() async throws {
        let granted = await permissionService.checkMicrophonePermission()
        try XCTSkipUnless(granted, "Microphone permission required - grant in System Settings")
    }

    /// Skip test if accessibility permission not granted
    func skipIfAccessibilityNotGranted() throws {
        let granted = permissionService.checkAccessibilityPermission()
        try XCTSkipUnless(granted, "Accessibility permission required - grant in System Settings")
    }

    /// Skip test if input monitoring not granted
    func skipIfInputMonitoringNotGranted() throws {
        let granted = permissionService.checkInputMonitoringPermission()
        try XCTSkipUnless(granted, "Input monitoring permission required - grant in System Settings")
    }

    /// Skip test if any required permission is missing
    func skipIfPermissionsMissing() async throws {
        try await skipIfMicrophoneNotGranted()
        try skipIfAccessibilityNotGranted()
        try skipIfInputMonitoringNotGranted()
    }
}
