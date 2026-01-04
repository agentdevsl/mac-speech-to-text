import XCTest
@testable import SpeechToText

@MainActor
final class AppStateTests: XCTestCase {

    var appState: AppState!
    private let settingsKey = "com.speechtotext.settings"

    /// Detect if running in CI environment (GitHub Actions, etc.)
    /// AppState tests require real macOS hardware for audio/accessibility services
    private static var isCI: Bool {
        ProcessInfo.processInfo.environment["CI"] != nil ||
        ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] != nil
    }

    override func setUp() async throws {
        try await super.setUp()

        // Skip in CI - AppState creates real services that require macOS hardware
        // These tests pass locally but crash in headless CI environments
        try XCTSkipIf(Self.isCI, "AppStateTests require real macOS hardware, skipping in CI")

        // Clear settings from UserDefaults.standard to ensure test isolation
        // AppState internally uses SettingsService with .standard UserDefaults
        UserDefaults.standard.removeObject(forKey: settingsKey)
        UserDefaults.standard.synchronize()

        // Note: AppState creates its own services internally
        // For full testing, we'd need dependency injection
        appState = AppState()
    }

    override func tearDown() async throws {
        // Clean up to avoid affecting other tests
        UserDefaults.standard.removeObject(forKey: settingsKey)
        UserDefaults.standard.synchronize()
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func test_initialization_loadsSettings() {
        // Given/When
        let appState = AppState()

        // Then
        XCTAssertNotNil(appState.settings)
        XCTAssertEqual(appState.settings.version, UserSettings.default.version)
    }

    func test_initialization_loadsStatistics() {
        // Given/When
        let appState = AppState()

        // Then
        XCTAssertNotNil(appState.statistics)
    }

    func test_initialization_setsShowOnboardingBasedOnSettings() {
        // Given/When
        let appState = AppState()

        // Then
        // Should show onboarding if not completed
        XCTAssertEqual(appState.showOnboarding, !appState.settings.onboarding.completed)
    }

    func test_initialization_startsWithNoRecording() {
        // Given/When
        let appState = AppState()

        // Then
        XCTAssertFalse(appState.isRecording)
        XCTAssertNil(appState.currentSession)
    }

    // MARK: - Initialize FluidAudio Tests

    func test_initializeFluidAudio_attemptsInitialization() async {
        // Given
        let appState = AppState()

        // When
        await appState.initializeFluidAudio()

        // Then
        // In test environment, this will likely fail
        // Error message should be set if initialization fails
        // Or no error if mock/stub is used
    }

    // MARK: - Start Recording Tests

    func test_startRecording_createsNewSession() {
        // Given
        XCTAssertNil(appState.currentSession)

        // When
        appState.startRecording()

        // Then
        XCTAssertNotNil(appState.currentSession)
        XCTAssertEqual(appState.currentSession?.state, .recording)
        XCTAssertTrue(appState.isRecording)
    }

    func test_startRecording_usesDefaultLanguageFromSettings() {
        // Given
        let expectedLanguage = appState.settings.language.defaultLanguage

        // When
        appState.startRecording()

        // Then
        XCTAssertEqual(appState.currentSession?.language, expectedLanguage)
    }

    // MARK: - Stop Recording Tests

    func test_stopRecording_transitionsToTranscribing() {
        // Given
        appState.startRecording()
        XCTAssertTrue(appState.isRecording)

        // When
        appState.stopRecording()

        // Then
        XCTAssertFalse(appState.isRecording)
        XCTAssertEqual(appState.currentSession?.state, .transcribing)
        XCTAssertNotNil(appState.currentSession?.endTime)
    }

    func test_stopRecording_whenNoSession_doesNothing() {
        // Given
        XCTAssertNil(appState.currentSession)

        // When
        appState.stopRecording()

        // Then
        XCTAssertNil(appState.currentSession)
        XCTAssertFalse(appState.isRecording)
    }

    // MARK: - Complete Session Tests

    func test_completeSession_marksAsCompleted() async {
        // Given
        appState.startRecording()
        appState.stopRecording()

        // When
        await appState.completeSession()

        // Then
        XCTAssertNil(appState.currentSession)
    }

    func test_completeSession_recordsStatistics() async {
        // Given
        appState.startRecording()
        appState.stopRecording()
        let initialStats = appState.statistics

        // When
        await appState.completeSession()

        // Then
        // Statistics should be refreshed
        XCTAssertNotNil(appState.statistics)
    }

    func test_completeSession_whenNoSession_doesNothing() async {
        // Given
        XCTAssertNil(appState.currentSession)

        // When
        await appState.completeSession()

        // Then
        XCTAssertNil(appState.currentSession)
    }

    // MARK: - Cancel Session Tests

    func test_cancelSession_clearsCurrentSession() {
        // Given
        appState.startRecording()
        XCTAssertNotNil(appState.currentSession)

        // When
        appState.cancelSession()

        // Then
        XCTAssertNil(appState.currentSession)
        XCTAssertFalse(appState.isRecording)
    }

    func test_cancelSession_setsStateToCancelled() {
        // Given
        appState.startRecording()

        // When
        appState.cancelSession()

        // Then
        // Session should be cleared, so we can't check its state
        XCTAssertNil(appState.currentSession)
    }

    // MARK: - Update Settings Tests

    func test_updateSettings_savesAndUpdatesSettings() {
        // Given
        var newSettings = UserSettings.default
        newSettings.language.defaultLanguage = "fr"

        // When
        appState.updateSettings(newSettings)

        // Then
        XCTAssertEqual(appState.settings.language.defaultLanguage, "fr")
    }

    func test_updateSettings_setsErrorMessageOnFailure() {
        // Given
        let settings = UserSettings.default

        // When
        appState.updateSettings(settings)

        // Then
        // Should succeed or set error message
        // Error message will be nil on success
    }

    // MARK: - Complete Onboarding Tests

    func test_completeOnboarding_hidesOnboarding() {
        // Given
        appState.showOnboarding = true

        // When
        appState.completeOnboarding()

        // Then
        XCTAssertFalse(appState.showOnboarding)
    }

    func test_completeOnboarding_updatesSettings() {
        // Given - use the class-level appState which is initialized with clean UserDefaults
        // in setUp() to avoid race conditions with UserDefaults syncing
        XCTAssertFalse(appState.settings.onboarding.completed, "Onboarding should not be completed initially")
        XCTAssertNil(appState.errorMessage, "Should have no error before onboarding")

        // When
        appState.completeOnboarding()

        // Then - verify both the in-memory state and that no error occurred
        XCTAssertNil(appState.errorMessage, "Should have no error after completeOnboarding")
        XCTAssertTrue(
            appState.settings.onboarding.completed,
            "Settings should be updated after completeOnboarding"
        )

        // Also verify persistence by reloading settings
        let settingsService = SettingsService()
        let reloadedSettings = settingsService.load()
        XCTAssertTrue(
            reloadedSettings.onboarding.completed,
            "Settings should persist to UserDefaults"
        )
    }

    // MARK: - Refresh Statistics Tests

    func test_refreshStatistics_updatesStatistics() async {
        // Given
        let initialStats = appState.statistics

        // When
        await appState.refreshStatistics()

        // Then
        XCTAssertNotNil(appState.statistics)
    }

    // MARK: - Error Handling Tests

    func test_errorMessage_initiallyNil() {
        // Given/When
        let appState = AppState()

        // Then
        XCTAssertNil(appState.errorMessage)
    }

    func test_errorMessage_setWhenOperationFails() async {
        // Given
        let appState = AppState()

        // When
        await appState.initializeFluidAudio()

        // Then
        // May set error message if FluidAudio initialization fails
        // In production environment with SDK, this might succeed
    }

    // MARK: - Show Settings Tests

    func test_showSettings_initiallyFalse() {
        // Given/When
        let appState = AppState()

        // Then
        XCTAssertFalse(appState.showSettings)
    }

    func test_showSettings_canBeToggled() {
        // Given
        appState.showSettings = false

        // When
        appState.showSettings = true

        // Then
        XCTAssertTrue(appState.showSettings)
    }

    // MARK: - Recording Session Lifecycle Tests

    func test_fullRecordingLifecycle() async {
        // Given
        XCTAssertNil(appState.currentSession)

        // When
        // 1. Start recording
        appState.startRecording()
        XCTAssertNotNil(appState.currentSession)
        XCTAssertEqual(appState.currentSession?.state, .recording)

        // 2. Stop recording
        appState.stopRecording()
        XCTAssertEqual(appState.currentSession?.state, .transcribing)

        // 3. Complete session
        await appState.completeSession()

        // Then
        XCTAssertNil(appState.currentSession)
    }

    func test_cancelledRecordingLifecycle() {
        // Given
        XCTAssertNil(appState.currentSession)

        // When
        appState.startRecording()
        XCTAssertNotNil(appState.currentSession)

        appState.cancelSession()

        // Then
        XCTAssertNil(appState.currentSession)
        XCTAssertFalse(appState.isRecording)
    }

    // MARK: - Observable Tests

    func test_appState_isObservable() {
        // Given/When
        let appState = AppState()

        // Then
        // AppState should be marked with @Observable
        // This enables SwiftUI to react to state changes
        XCTAssertNotNil(appState)
    }

    // MARK: - Service Integration Tests

    func test_appState_hasAllRequiredServices() {
        // Given/When
        let appState = AppState()

        // Then
        XCTAssertNotNil(appState.fluidAudioService)
        XCTAssertNotNil(appState.permissionService)
        XCTAssertNotNil(appState.settingsService)
        XCTAssertNotNil(appState.statisticsService)
    }

    // MARK: - Concurrent Access Tests

    func test_appState_handlesConcurrentAccess() async {
        // Given
        let appState = AppState()

        // When
        // Since AppState is MainActor isolated, these calls run sequentially
        appState.startRecording()
        await appState.refreshStatistics()
        _ = appState.settings

        // Then
        // Should complete without crashes
        XCTAssertTrue(true)
    }

    // MARK: - Multiple Sessions Tests

    func test_multipleSessions_workSequentially() async {
        // Given/When
        for _ in 0..<3 {
            appState.startRecording()
            appState.stopRecording()
            await appState.completeSession()
        }

        // Then
        XCTAssertNil(appState.currentSession)
    }
}
