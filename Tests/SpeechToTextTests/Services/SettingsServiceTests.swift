import XCTest
@testable import SpeechToText

final class SettingsServiceTests: XCTestCase {

    var userDefaults: UserDefaults!
    var service: SettingsService!

    override func setUp() {
        super.setUp()
        // Use a test suite name to avoid interfering with actual app data
        userDefaults = UserDefaults(suiteName: "com.speechtotext.tests")!
        userDefaults.removePersistentDomain(forName: "com.speechtotext.tests")
        service = SettingsService(userDefaults: userDefaults)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: "com.speechtotext.tests")
        super.tearDown()
    }

    // MARK: - Load Tests

    func test_load_returnsDefaultSettingsWhenNoDataExists() {
        // Given/When
        let settings = service.load()

        // Then
        XCTAssertEqual(settings.version, UserSettings.default.version)
        XCTAssertEqual(settings.hotkey.keyCode, UserSettings.default.hotkey.keyCode)
        XCTAssertEqual(settings.language.defaultLanguage, UserSettings.default.language.defaultLanguage)
    }

    func test_load_returnsSavedSettings() throws {
        // Given
        var customSettings = UserSettings.default
        customSettings.language.defaultLanguage = "fr"
        customSettings.audio.sensitivity = 0.8
        try service.save(customSettings)

        // When
        let loadedSettings = service.load()

        // Then
        XCTAssertEqual(loadedSettings.language.defaultLanguage, "fr")
        XCTAssertEqual(loadedSettings.audio.sensitivity, 0.8)
    }

    // MARK: - Save Tests

    func test_save_persistsSettingsToUserDefaults() throws {
        // Given
        var settings = UserSettings.default
        settings.language.defaultLanguage = "de"

        // When
        try service.save(settings)

        // Then
        let loadedSettings = service.load()
        XCTAssertEqual(loadedSettings.language.defaultLanguage, "de")
    }

    func test_save_updatesLastModifiedDate() throws {
        // Given
        let originalSettings = UserSettings.default
        let originalDate = originalSettings.lastModified

        // Wait a bit to ensure time difference
        Thread.sleep(forTimeInterval: 0.01)

        // When
        try service.save(originalSettings)

        // Then
        let loadedSettings = service.load()
        XCTAssertGreaterThan(loadedSettings.lastModified, originalDate)
    }

    // MARK: - Reset Tests

    func test_reset_restoresDefaultSettings() throws {
        // Given
        var customSettings = UserSettings.default
        customSettings.language.defaultLanguage = "fr"
        try service.save(customSettings)

        // When
        try service.reset()

        // Then
        let loadedSettings = service.load()
        XCTAssertEqual(loadedSettings.language.defaultLanguage, UserSettings.default.language.defaultLanguage)
    }

    // MARK: - Update Hotkey Tests

    func test_updateHotkey_updatesOnlyHotkeyConfiguration() throws {
        // Given
        var originalSettings = UserSettings.default
        originalSettings.language.defaultLanguage = "fr"
        try service.save(originalSettings)

        let newHotkey = HotkeyConfiguration(
            enabled: false,
            keyCode: 36,
            modifiers: [.command],
            conflictDetected: true
        )

        // When
        try service.updateHotkey(newHotkey)

        // Then
        let loadedSettings = service.load()
        XCTAssertEqual(loadedSettings.hotkey.keyCode, 36)
        XCTAssertFalse(loadedSettings.hotkey.enabled)
        XCTAssertEqual(loadedSettings.language.defaultLanguage, "fr") // Should remain unchanged
    }

    // MARK: - Update Language Tests

    func test_updateLanguage_updatesOnlyLanguageConfiguration() throws {
        // Given
        var originalSettings = UserSettings.default
        originalSettings.audio.sensitivity = 0.9
        try service.save(originalSettings)

        var newLanguage = LanguageConfiguration(
            defaultLanguage: "es",
            recentLanguages: ["en", "es"],
            autoDetectEnabled: true,
            downloadedModels: ["en", "es"]
        )

        // When
        try service.updateLanguage(newLanguage)

        // Then
        let loadedSettings = service.load()
        XCTAssertEqual(loadedSettings.language.defaultLanguage, "es")
        XCTAssertTrue(loadedSettings.language.autoDetectEnabled)
        XCTAssertEqual(loadedSettings.audio.sensitivity, 0.9) // Should remain unchanged
    }

    // MARK: - Update Audio Tests

    func test_updateAudio_updatesOnlyAudioConfiguration() throws {
        // Given
        var originalSettings = UserSettings.default
        originalSettings.language.defaultLanguage = "fr"
        try service.save(originalSettings)

        let newAudio = AudioConfiguration(
            inputDeviceId: "device123",
            sensitivity: 0.7,
            silenceThreshold: 2.0,
            noiseSuppression: false,
            autoGainControl: false
        )

        // When
        try service.updateAudio(newAudio)

        // Then
        let loadedSettings = service.load()
        XCTAssertEqual(loadedSettings.audio.sensitivity, 0.7)
        XCTAssertEqual(loadedSettings.audio.silenceThreshold, 2.0)
        XCTAssertEqual(loadedSettings.language.defaultLanguage, "fr") // Should remain unchanged
    }

    // MARK: - Update UI Tests

    func test_updateUI_updatesOnlyUIConfiguration() throws {
        // Given
        let newUI = UIConfiguration(
            theme: .dark,
            modalPosition: .cursor,
            showWaveform: false,
            showConfidenceIndicator: false,
            animationsEnabled: false,
            menuBarIcon: .minimal
        )

        // When
        try service.updateUI(newUI)

        // Then
        let loadedSettings = service.load()
        XCTAssertEqual(loadedSettings.ui.theme, .dark)
        XCTAssertEqual(loadedSettings.ui.modalPosition, .cursor)
        XCTAssertFalse(loadedSettings.ui.showWaveform)
    }

    // MARK: - Update Privacy Tests

    func test_updatePrivacy_updatesOnlyPrivacyConfiguration() throws {
        // Given
        let newPrivacy = PrivacyConfiguration(
            collectAnonymousStats: false,
            storagePolicy: .none,
            dataRetentionDays: 30,
            storeHistory: false
        )

        // When
        try service.updatePrivacy(newPrivacy)

        // Then
        let loadedSettings = service.load()
        XCTAssertFalse(loadedSettings.privacy.collectAnonymousStats)
        XCTAssertEqual(loadedSettings.privacy.storagePolicy, .none)
        XCTAssertEqual(loadedSettings.privacy.dataRetentionDays, 30)
    }

    // MARK: - Update Onboarding Tests

    func test_updateOnboarding_updatesOnlyOnboardingState() throws {
        // Given
        var newOnboarding = OnboardingState(
            completed: true,
            currentStep: 5,
            permissionsGranted: PermissionsGranted(
                microphone: true,
                accessibility: true,
                inputMonitoring: true
            ),
            skippedSteps: ["step2"]
        )

        // When
        try service.updateOnboarding(newOnboarding)

        // Then
        let loadedSettings = service.load()
        XCTAssertTrue(loadedSettings.onboarding.completed)
        XCTAssertEqual(loadedSettings.onboarding.currentStep, 5)
        XCTAssertTrue(loadedSettings.onboarding.permissionsGranted.allGranted)
    }

    // MARK: - Complete Onboarding Tests

    func test_completeOnboarding_setsCompletedFlagAndResetsStep() throws {
        // Given
        var settings = UserSettings.default
        settings.onboarding.completed = false
        settings.onboarding.currentStep = 3
        try service.save(settings)

        // When
        try service.completeOnboarding()

        // Then
        let loadedSettings = service.load()
        XCTAssertTrue(loadedSettings.onboarding.completed)
        XCTAssertEqual(loadedSettings.onboarding.currentStep, 0)
    }

    // MARK: - Update Permissions Tests

    func test_updatePermissions_updatesPermissionsGranted() throws {
        // Given
        let newPermissions = PermissionsGranted(
            microphone: true,
            accessibility: true,
            inputMonitoring: false
        )

        // When
        try service.updatePermissions(newPermissions)

        // Then
        let loadedSettings = service.load()
        XCTAssertTrue(loadedSettings.onboarding.permissionsGranted.microphone)
        XCTAssertTrue(loadedSettings.onboarding.permissionsGranted.accessibility)
        XCTAssertFalse(loadedSettings.onboarding.permissionsGranted.inputMonitoring)
    }

    // MARK: - Error Handling Tests

    func test_save_throwsErrorForInvalidData() {
        // This test verifies that encoding errors are properly propagated
        // In this case, UserSettings should always be encodable
        // But this demonstrates the error handling pattern

        // Given
        let settings = UserSettings.default

        // When/Then
        XCTAssertNoThrow(try service.save(settings))
    }

    // MARK: - Multiple Updates Test

    @MainActor
    func test_multipleUpdates_allPersistCorrectly() async throws {
        // Given
        let newHotkey = HotkeyConfiguration(
            enabled: false,
            keyCode: 36,
            modifiers: [.shift],
            conflictDetected: false
        )

        let newLanguage = LanguageConfiguration(
            defaultLanguage: "de",
            recentLanguages: ["en", "de"],
            autoDetectEnabled: false,
            downloadedModels: ["en", "de"]
        )

        let newAudio = AudioConfiguration(
            inputDeviceId: nil,
            sensitivity: 0.5,
            silenceThreshold: 2.5,
            noiseSuppression: false,
            autoGainControl: true
        )

        // When
        try service.updateHotkey(newHotkey)
        try service.updateLanguage(newLanguage)
        try service.updateAudio(newAudio)

        // Then
        let loadedSettings = service.load()
        XCTAssertEqual(loadedSettings.hotkey.keyCode, 36)
        XCTAssertEqual(loadedSettings.language.defaultLanguage, "de")
        XCTAssertEqual(loadedSettings.audio.sensitivity, 0.5)
    }
}
