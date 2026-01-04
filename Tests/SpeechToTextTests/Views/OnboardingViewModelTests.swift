import XCTest
@testable import SpeechToText

@MainActor
final class OnboardingViewModelTests: XCTestCase {

    // MARK: - Properties

    private var sut: OnboardingViewModel!
    private var mockPermissionService: MockPermissionService!
    private var mockSettingsService: MockSettingsService!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        mockPermissionService = MockPermissionService()
        // Default all permissions to false for predictable test behavior
        mockPermissionService.microphoneGranted = false
        mockPermissionService.accessibilityGranted = false
        mockSettingsService = MockSettingsService()
        sut = OnboardingViewModel(
            permissionService: mockPermissionService,
            settingsService: mockSettingsService
        )
        // Wait briefly for the init's async checkAllPermissions() to complete
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
    }

    override func tearDown() async throws {
        sut = nil
        mockPermissionService = nil
        mockSettingsService = nil
        try await super.tearDown()
    }

    // MARK: - Initial State Tests

    func test_initialState_startsAtStepZero() {
        XCTAssertEqual(sut.currentStep, 0)
    }

    func test_initialState_isNotComplete() {
        XCTAssertFalse(sut.isComplete)
    }

    func test_initialState_hasNoSkippedSteps() {
        XCTAssertTrue(sut.skippedSteps.isEmpty)
    }

    func test_initialState_showsNoSkipWarning() {
        XCTAssertFalse(sut.showSkipWarning)
    }

    func test_initialState_hasNoPermissionError() {
        XCTAssertNil(sut.permissionError)
    }

    // MARK: - Step Navigation Tests

    func test_nextStep_incrementsCurrentStep() {
        // Given
        XCTAssertEqual(sut.currentStep, 0)

        // When
        sut.nextStep()

        // Then - should move to step 1 (microphone)
        XCTAssertEqual(sut.currentStep, 1)
    }

    func test_previousStep_decrementsCurrentStep() {
        // Given
        sut.nextStep() // Move to step 1
        XCTAssertEqual(sut.currentStep, 1)

        // When
        sut.previousStep()

        // Then
        XCTAssertEqual(sut.currentStep, 0)
    }

    func test_previousStep_doesNotGoBelowZero() {
        // Given
        XCTAssertEqual(sut.currentStep, 0)

        // When
        sut.previousStep()

        // Then
        XCTAssertEqual(sut.currentStep, 0)
    }

    func test_nextStep_autoSkipsMicrophoneWhenGranted() async {
        // Given - only microphone is granted
        mockPermissionService.microphoneGranted = true
        mockPermissionService.accessibilityGranted = false
        await sut.checkAllPermissions()

        // When - move from welcome (0) to next
        sut.nextStep()

        // Then - should skip step 1 (microphone) and go to step 2 (accessibility)
        XCTAssertEqual(sut.currentStep, 2)
    }

    func test_nextStep_autoSkipsAccessibilityWhenGranted() async {
        // Given - microphone and accessibility granted
        mockPermissionService.microphoneGranted = true
        mockPermissionService.accessibilityGranted = true
        await sut.checkAllPermissions()

        // When - move from welcome (0) to next
        sut.nextStep()

        // Then - should skip steps 1 and 2, go to step 3 (demo)
        XCTAssertEqual(sut.currentStep, 3)
    }

    func test_nextStep_autoSkipsAllPermissionsWhenAllGranted() async {
        // Given - all permissions granted
        mockPermissionService.microphoneGranted = true
        mockPermissionService.accessibilityGranted = true
        await sut.checkAllPermissions()

        // When
        sut.nextStep()

        // Then - should skip to demo step (3)
        XCTAssertEqual(sut.currentStep, 3)
    }

    // MARK: - Skip Step Tests

    func test_skipStep_showsWarning() {
        // Given
        sut.nextStep() // Move to step 1 (microphone)

        // When
        sut.skipStep()

        // Then
        XCTAssertTrue(sut.showSkipWarning)
        XCTAssertFalse(sut.skipWarningMessage.isEmpty)
    }

    func test_confirmSkip_addsStepToSkippedSteps() {
        // Given
        sut.nextStep() // Move to step 1 (microphone)
        sut.skipStep()

        // When
        sut.confirmSkip()

        // Then
        XCTAssertTrue(sut.skippedSteps.contains(1))
    }

    func test_confirmSkip_hidesWarning() {
        // Given
        sut.nextStep() // Move to step 1
        sut.skipStep()
        XCTAssertTrue(sut.showSkipWarning)

        // When
        sut.confirmSkip()

        // Then
        XCTAssertFalse(sut.showSkipWarning)
    }

    func test_confirmSkip_movesToNextStep() {
        // Given
        sut.nextStep() // Move to step 1
        sut.skipStep()

        // When
        sut.confirmSkip()

        // Then - should be at step 2 (accessibility)
        XCTAssertEqual(sut.currentStep, 2)
    }

    func test_cancelSkip_hidesWarning() {
        // Given
        sut.nextStep() // Move to step 1
        sut.skipStep()
        XCTAssertTrue(sut.showSkipWarning)

        // When
        sut.cancelSkip()

        // Then
        XCTAssertFalse(sut.showSkipWarning)
    }

    func test_cancelSkip_staysOnCurrentStep() {
        // Given
        sut.nextStep() // Move to step 1
        let stepBeforeSkip = sut.currentStep
        sut.skipStep()

        // When
        sut.cancelSkip()

        // Then
        XCTAssertEqual(sut.currentStep, stepBeforeSkip)
    }

    // MARK: - Can Skip Tests

    func test_canSkipCurrentStep_falseForWelcomeStep() {
        // Given
        XCTAssertEqual(sut.currentStep, 0)

        // Then
        XCTAssertFalse(sut.canSkipCurrentStep)
    }

    func test_canSkipCurrentStep_trueForMicrophoneStep() {
        // Given
        sut.nextStep() // Move to step 1

        // Then
        XCTAssertTrue(sut.canSkipCurrentStep)
    }

    func test_canSkipCurrentStep_trueForAccessibilityStep() {
        // Given
        sut.nextStep() // Step 1
        sut.nextStep() // Step 2

        // Then
        XCTAssertTrue(sut.canSkipCurrentStep)
    }

    func test_canSkipCurrentStep_falseForDemoStep() {
        // Given
        sut.nextStep() // Step 1
        sut.nextStep() // Step 2
        sut.nextStep() // Step 3 (demo)

        // Then
        XCTAssertFalse(sut.canSkipCurrentStep)
    }

    // MARK: - Permission Request Tests

    func test_requestMicrophonePermission_updatesGrantedStatus() async {
        // Given
        mockPermissionService.microphoneGranted = true
        XCTAssertFalse(sut.microphoneGranted)

        // When
        await sut.requestMicrophonePermission()

        // Then
        XCTAssertTrue(sut.microphoneGranted)
    }

    func test_requestMicrophonePermission_setsErrorWhenDenied() async {
        // Given
        mockPermissionService.microphoneGranted = false

        // When
        await sut.requestMicrophonePermission()

        // Then
        XCTAssertNotNil(sut.permissionError)
        XCTAssertTrue(sut.permissionError?.contains("Microphone") ?? false)
    }

    func test_requestMicrophonePermission_advancesStepWhenGranted() async {
        // Given - only microphone will be granted
        mockPermissionService.microphoneGranted = true
        mockPermissionService.accessibilityGranted = false
        sut.nextStep() // Move to microphone step
        XCTAssertEqual(sut.currentStep, 1)

        // When
        await sut.requestMicrophonePermission()

        // Then - should advance to accessibility step (step 2)
        XCTAssertEqual(sut.currentStep, 2)
    }

    func test_requestAccessibilityPermission_updatesGrantedStatus() async {
        // Given
        mockPermissionService.accessibilityGranted = true
        XCTAssertFalse(sut.accessibilityGranted)

        // When
        await sut.requestAccessibilityPermission()

        // Then
        XCTAssertTrue(sut.accessibilityGranted)
    }

    // MARK: - Check All Permissions Tests

    func test_checkAllPermissions_updatesAllStatuses() async {
        // Given
        mockPermissionService.microphoneGranted = true
        mockPermissionService.accessibilityGranted = true

        // When
        await sut.checkAllPermissions()

        // Then
        XCTAssertTrue(sut.microphoneGranted)
        XCTAssertTrue(sut.accessibilityGranted)
    }

    // MARK: - All Permissions Granted Tests

    func test_allPermissionsGranted_trueWhenAllGranted() async {
        // Given
        mockPermissionService.microphoneGranted = true
        mockPermissionService.accessibilityGranted = true
        await sut.checkAllPermissions()

        // Then
        XCTAssertTrue(sut.allPermissionsGranted)
    }

    func test_allPermissionsGranted_falseWhenAnyDenied() async {
        // Given
        mockPermissionService.microphoneGranted = true
        mockPermissionService.accessibilityGranted = false
        await sut.checkAllPermissions()

        // Then
        XCTAssertFalse(sut.allPermissionsGranted)
    }

    // MARK: - Missing Permissions Warning Tests

    func test_missingPermissionsWarning_nilWhenAllGranted() async {
        // Given
        mockPermissionService.microphoneGranted = true
        mockPermissionService.accessibilityGranted = true
        await sut.checkAllPermissions()

        // Then
        XCTAssertNil(sut.missingPermissionsWarning)
    }

    func test_missingPermissionsWarning_listsAllMissingPermissions() async {
        // Given
        mockPermissionService.microphoneGranted = false
        mockPermissionService.accessibilityGranted = false
        await sut.checkAllPermissions()

        // Then
        let warning = sut.missingPermissionsWarning
        XCTAssertNotNil(warning)
        XCTAssertTrue(warning?.contains("Microphone") ?? false)
        XCTAssertTrue(warning?.contains("Accessibility") ?? false)
    }

    func test_missingPermissionsWarning_listsOnlyMissingPermissions() async {
        // Given
        mockPermissionService.microphoneGranted = true
        mockPermissionService.accessibilityGranted = false
        await sut.checkAllPermissions()

        // Then
        let warning = sut.missingPermissionsWarning
        XCTAssertNotNil(warning)
        XCTAssertFalse(warning?.contains("Microphone") ?? true)
        XCTAssertTrue(warning?.contains("Accessibility") ?? false)
    }

    // MARK: - Complete Onboarding Tests

    func test_completeOnboarding_setsIsCompleteTrue() {
        // When
        sut.completeOnboarding()

        // Then
        XCTAssertTrue(sut.isComplete)
    }

    func test_completeOnboarding_savesSettings() {
        // When
        sut.completeOnboarding()

        // Then
        XCTAssertTrue(mockSettingsService.saveWasCalled)
    }

    func test_completeOnboarding_savesCorrectOnboardingState() async {
        // Given
        mockPermissionService.microphoneGranted = true
        mockPermissionService.accessibilityGranted = false
        await sut.checkAllPermissions()

        // Skip a step
        sut.nextStep() // Welcome -> Microphone (auto-skipped due to granted)
        sut.skipStep()
        sut.confirmSkip() // Skip accessibility

        // When
        sut.completeOnboarding()

        // Then
        let savedSettings = mockSettingsService.lastSavedSettings
        XCTAssertNotNil(savedSettings)
        XCTAssertTrue(savedSettings?.onboarding.completed ?? false)
        XCTAssertTrue(savedSettings?.onboarding.permissionsGranted.microphone ?? false)
        XCTAssertFalse(savedSettings?.onboarding.permissionsGranted.accessibility ?? true)
    }

    // MARK: - Step Title Tests

    func test_stepTitle_returnsCorrectTitles() {
        XCTAssertEqual(sut.stepTitle(for: 0), "Welcome")
        XCTAssertEqual(sut.stepTitle(for: 1), "Microphone Access")
        XCTAssertEqual(sut.stepTitle(for: 2), "Accessibility Access")
        XCTAssertEqual(sut.stepTitle(for: 3), "Try It Now")
        XCTAssertEqual(sut.stepTitle(for: 4), "All Set!")
    }

    // MARK: - Step Subtitle Tests

    func test_stepSubtitle_returnsCorrectSubtitles() {
        XCTAssertEqual(sut.stepSubtitle(for: 0), "Privacy-first speech-to-text")
        XCTAssertEqual(sut.stepSubtitle(for: 1), "Required for voice capture")
        XCTAssertEqual(sut.stepSubtitle(for: 2), "Required for text insertion and hotkeys")
        XCTAssertEqual(sut.stepSubtitle(for: 3), "Test your setup")
        XCTAssertEqual(sut.stepSubtitle(for: 4), "Ready to use")
    }

    // MARK: - Edge Case Tests

    func test_nextStep_atLastStep_completesOnboarding() {
        // Given - navigate to last step (4 steps total: 0-4)
        for _ in 0..<4 {
            sut.nextStep()
        }
        XCTAssertEqual(sut.currentStep, 4)

        // When
        sut.nextStep()

        // Then
        XCTAssertTrue(sut.isComplete)
    }

    func test_multipleSkips_tracksAllSkippedSteps() {
        // Given & When - skip multiple steps
        sut.nextStep() // Step 1
        sut.skipStep()
        sut.confirmSkip()

        sut.skipStep() // Step 2
        sut.confirmSkip()

        // Then (only 2 permission steps now)
        XCTAssertTrue(sut.skippedSteps.contains(1))
        XCTAssertTrue(sut.skippedSteps.contains(2))
        XCTAssertEqual(sut.skippedSteps.count, 2)
    }

    func test_permissionError_clearsOnNewRequest() async {
        // Given - set an error
        mockPermissionService.microphoneGranted = false
        await sut.requestMicrophonePermission()
        XCTAssertNotNil(sut.permissionError)

        // When - make a new successful request
        mockPermissionService.microphoneGranted = true
        await sut.requestMicrophonePermission()

        // Then
        XCTAssertNil(sut.permissionError)
    }
}

// MARK: - Mock Settings Service

@MainActor
class MockSettingsService: SettingsServiceProtocol {
    var saveWasCalled = false
    var lastSavedSettings: UserSettings?
    var settingsToLoad: UserSettings = .default
    var shouldThrowOnSave = false

    func load() -> UserSettings {
        return settingsToLoad
    }

    func save(_ settings: UserSettings) throws {
        if shouldThrowOnSave {
            throw NSError(domain: "MockError", code: 1, userInfo: nil)
        }
        saveWasCalled = true
        lastSavedSettings = settings
    }

    func reset() throws {
        settingsToLoad = .default
    }
}
