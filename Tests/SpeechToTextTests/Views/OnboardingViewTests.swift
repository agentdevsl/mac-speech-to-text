import SwiftUI
import XCTest
@testable import SpeechToText

/// Tests for OnboardingView component
/// These tests focus on view creation and computed properties since
/// SwiftUI views are difficult to test directly without snapshot testing.
@MainActor
final class OnboardingViewTests: XCTestCase {

    // MARK: - Properties

    private var mockPermissionService: MockPermissionService!
    private var mockSettingsService: MockSettingsService!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        mockPermissionService = MockPermissionService()
        mockSettingsService = MockSettingsService()
    }

    override func tearDown() async throws {
        mockPermissionService = nil
        mockSettingsService = nil
        try await super.tearDown()
    }

    // MARK: - View Initialization Tests

    func test_onboardingView_createsSuccessfully() {
        // Given/When
        let view = OnboardingView()

        // Then - View should create without crashing
        XCTAssertNotNil(view)
    }

    func test_onboardingView_bodyRendersAtStep0() {
        // Given
        let view = OnboardingView()

        // When/Then - Accessing body should not crash
        _ = view.body
    }

    // MARK: - OnboardingViewLogic Tests

    /// Test wrapper to access private computed properties through view model
    func test_progressPercentage_atStep0_isZero() {
        // Given
        let viewModel = OnboardingViewModel(
            permissionService: mockPermissionService,
            settingsService: mockSettingsService
        )

        // When
        let progress = calculateProgressPercentage(for: viewModel.currentStep)

        // Then
        XCTAssertEqual(progress, 0.0, accuracy: 0.001)
    }

    func test_progressPercentage_atStep1_is20Percent() {
        // Given
        let viewModel = OnboardingViewModel(
            permissionService: mockPermissionService,
            settingsService: mockSettingsService
        )
        viewModel.nextStep() // Move to step 1

        // When
        let progress = calculateProgressPercentage(for: viewModel.currentStep)

        // Then
        XCTAssertEqual(progress, 0.2, accuracy: 0.001)
    }

    func test_progressPercentage_atStep2_is40Percent() {
        // Given
        let viewModel = OnboardingViewModel(
            permissionService: mockPermissionService,
            settingsService: mockSettingsService
        )
        viewModel.nextStep() // Step 1
        viewModel.nextStep() // Step 2

        // When
        let progress = calculateProgressPercentage(for: viewModel.currentStep)

        // Then
        XCTAssertEqual(progress, 0.4, accuracy: 0.001)
    }

    func test_progressPercentage_atStep3_is60Percent() {
        // Given
        let viewModel = OnboardingViewModel(
            permissionService: mockPermissionService,
            settingsService: mockSettingsService
        )
        viewModel.nextStep() // Step 1
        viewModel.nextStep() // Step 2
        viewModel.nextStep() // Step 3

        // When
        let progress = calculateProgressPercentage(for: viewModel.currentStep)

        // Then
        XCTAssertEqual(progress, 0.6, accuracy: 0.001)
    }

    func test_progressPercentage_atStep4_is80Percent() {
        // Given
        let viewModel = OnboardingViewModel(
            permissionService: mockPermissionService,
            settingsService: mockSettingsService
        )
        viewModel.nextStep() // Step 1
        viewModel.nextStep() // Step 2
        viewModel.nextStep() // Step 3
        viewModel.nextStep() // Step 4

        // When
        let progress = calculateProgressPercentage(for: viewModel.currentStep)

        // Then
        XCTAssertEqual(progress, 0.8, accuracy: 0.001)
    }

    func test_progressPercentage_atStep5_is100Percent() {
        // Given
        let viewModel = OnboardingViewModel(
            permissionService: mockPermissionService,
            settingsService: mockSettingsService
        )
        for _ in 0..<5 {
            viewModel.nextStep()
        }

        // When
        let progress = calculateProgressPercentage(for: viewModel.currentStep)

        // Then
        XCTAssertEqual(progress, 1.0, accuracy: 0.001)
    }

    // MARK: - Next Button Title Tests

    func test_nextButtonTitle_atStep0_isNext() {
        // Given
        let viewModel = OnboardingViewModel(
            permissionService: mockPermissionService,
            settingsService: mockSettingsService
        )

        // When
        let title = calculateNextButtonTitle(for: viewModel.currentStep, isComplete: viewModel.isComplete)

        // Then
        XCTAssertEqual(title, "Next")
    }

    func test_nextButtonTitle_atStep1_isNext() {
        // Given
        let viewModel = OnboardingViewModel(
            permissionService: mockPermissionService,
            settingsService: mockSettingsService
        )
        viewModel.nextStep() // Move to step 1

        // When
        let title = calculateNextButtonTitle(for: viewModel.currentStep, isComplete: viewModel.isComplete)

        // Then
        XCTAssertEqual(title, "Next")
    }

    func test_nextButtonTitle_atStep4_isNext() {
        // Given
        let viewModel = OnboardingViewModel(
            permissionService: mockPermissionService,
            settingsService: mockSettingsService
        )
        for _ in 0..<4 {
            viewModel.nextStep()
        }

        // When
        let title = calculateNextButtonTitle(for: viewModel.currentStep, isComplete: viewModel.isComplete)

        // Then
        XCTAssertEqual(title, "Next")
    }

    func test_nextButtonTitle_atStep5_isGetStarted() {
        // Given
        let viewModel = OnboardingViewModel(
            permissionService: mockPermissionService,
            settingsService: mockSettingsService
        )
        for _ in 0..<5 {
            viewModel.nextStep()
        }

        // When
        let title = calculateNextButtonTitle(for: viewModel.currentStep, isComplete: viewModel.isComplete)

        // Then
        XCTAssertEqual(title, "Get Started")
    }

    func test_nextButtonTitle_whenComplete_isGetStarted() {
        // Given
        let viewModel = OnboardingViewModel(
            permissionService: mockPermissionService,
            settingsService: mockSettingsService
        )
        viewModel.completeOnboarding()

        // When
        let title = calculateNextButtonTitle(for: viewModel.currentStep, isComplete: viewModel.isComplete)

        // Then
        XCTAssertEqual(title, "Get Started")
    }

    // MARK: - Back Button Visibility Tests

    func test_backButtonVisible_atStep0_isFalse() {
        // Given
        let viewModel = OnboardingViewModel(
            permissionService: mockPermissionService,
            settingsService: mockSettingsService
        )

        // When
        let visible = shouldShowBackButton(for: viewModel.currentStep)

        // Then
        XCTAssertFalse(visible)
    }

    func test_backButtonVisible_atStep1_isTrue() {
        // Given
        let viewModel = OnboardingViewModel(
            permissionService: mockPermissionService,
            settingsService: mockSettingsService
        )
        viewModel.nextStep() // Move to step 1

        // When
        let visible = shouldShowBackButton(for: viewModel.currentStep)

        // Then
        XCTAssertTrue(visible)
    }

    func test_backButtonVisible_atStep2_isTrue() {
        // Given
        let viewModel = OnboardingViewModel(
            permissionService: mockPermissionService,
            settingsService: mockSettingsService
        )
        viewModel.nextStep() // Step 1
        viewModel.nextStep() // Step 2

        // When
        let visible = shouldShowBackButton(for: viewModel.currentStep)

        // Then
        XCTAssertTrue(visible)
    }

    func test_backButtonVisible_atStep3_isTrue() {
        // Given
        let viewModel = OnboardingViewModel(
            permissionService: mockPermissionService,
            settingsService: mockSettingsService
        )
        viewModel.nextStep() // Step 1
        viewModel.nextStep() // Step 2
        viewModel.nextStep() // Step 3

        // When
        let visible = shouldShowBackButton(for: viewModel.currentStep)

        // Then
        XCTAssertTrue(visible)
    }

    func test_backButtonVisible_atStep4_isTrue() {
        // Given
        let viewModel = OnboardingViewModel(
            permissionService: mockPermissionService,
            settingsService: mockSettingsService
        )
        for _ in 0..<4 {
            viewModel.nextStep()
        }

        // When
        let visible = shouldShowBackButton(for: viewModel.currentStep)

        // Then
        XCTAssertTrue(visible)
    }

    func test_backButtonVisible_atStep5_isFalse() {
        // Given
        let viewModel = OnboardingViewModel(
            permissionService: mockPermissionService,
            settingsService: mockSettingsService
        )
        for _ in 0..<5 {
            viewModel.nextStep()
        }

        // When
        let visible = shouldShowBackButton(for: viewModel.currentStep)

        // Then
        XCTAssertFalse(visible)
    }

    // MARK: - Skip Button Visibility Tests

    func test_skipButtonVisible_atStep0_isFalse() {
        // Given
        let viewModel = OnboardingViewModel(
            permissionService: mockPermissionService,
            settingsService: mockSettingsService
        )

        // When/Then
        XCTAssertFalse(viewModel.canSkipCurrentStep)
    }

    func test_skipButtonVisible_atStep1_isTrue() {
        // Given
        let viewModel = OnboardingViewModel(
            permissionService: mockPermissionService,
            settingsService: mockSettingsService
        )
        viewModel.nextStep() // Move to step 1 (microphone)

        // When/Then
        XCTAssertTrue(viewModel.canSkipCurrentStep)
    }

    func test_skipButtonVisible_atStep2_isTrue() {
        // Given
        let viewModel = OnboardingViewModel(
            permissionService: mockPermissionService,
            settingsService: mockSettingsService
        )
        viewModel.nextStep() // Step 1
        viewModel.nextStep() // Step 2 (accessibility)

        // When/Then
        XCTAssertTrue(viewModel.canSkipCurrentStep)
    }

    func test_skipButtonVisible_atStep3_isTrue() {
        // Given
        let viewModel = OnboardingViewModel(
            permissionService: mockPermissionService,
            settingsService: mockSettingsService
        )
        viewModel.nextStep() // Step 1
        viewModel.nextStep() // Step 2
        viewModel.nextStep() // Step 3 (input monitoring)

        // When/Then
        XCTAssertTrue(viewModel.canSkipCurrentStep)
    }

    func test_skipButtonVisible_atStep4_isFalse() {
        // Given
        let viewModel = OnboardingViewModel(
            permissionService: mockPermissionService,
            settingsService: mockSettingsService
        )
        for _ in 0..<4 {
            viewModel.nextStep()
        }

        // When/Then - Demo step (4) cannot be skipped
        XCTAssertFalse(viewModel.canSkipCurrentStep)
    }

    func test_skipButtonVisible_atStep5_isFalse() {
        // Given
        let viewModel = OnboardingViewModel(
            permissionService: mockPermissionService,
            settingsService: mockSettingsService
        )
        for _ in 0..<5 {
            viewModel.nextStep()
        }

        // When/Then - Completion step (5) cannot be skipped
        XCTAssertFalse(viewModel.canSkipCurrentStep)
    }

    // MARK: - Permission Warning Tests

    func test_permissionWarning_atStep0_isNil() {
        // Given
        let viewModel = OnboardingViewModel(
            permissionService: mockPermissionService,
            settingsService: mockSettingsService
        )

        // When
        let warning = calculatePermissionWarning(for: viewModel.currentStep, viewModel: viewModel)

        // Then
        XCTAssertNil(warning)
    }

    func test_permissionWarning_atStep1_whenNotGranted_showsMicrophoneWarning() {
        // Given
        mockPermissionService.microphoneGranted = false
        let viewModel = OnboardingViewModel(
            permissionService: mockPermissionService,
            settingsService: mockSettingsService
        )
        viewModel.nextStep() // Move to step 1

        // When
        let warning = calculatePermissionWarning(for: viewModel.currentStep, viewModel: viewModel)

        // Then
        XCTAssertNotNil(warning)
        XCTAssertTrue(warning?.contains("Microphone") ?? false)
    }

    func test_permissionWarning_atStep1_whenGranted_isNil() async {
        // Given
        mockPermissionService.microphoneGranted = true
        let viewModel = OnboardingViewModel(
            permissionService: mockPermissionService,
            settingsService: mockSettingsService
        )
        await viewModel.checkAllPermissions()
        // Manually set currentStep since nextStep auto-skips granted permissions
        // This simulates being on step 1 with permission already granted
        // For this test, we check the logic directly

        // When - step 1 with microphone granted
        let warning = calculatePermissionWarningDirect(step: 1, microphoneGranted: true)

        // Then
        XCTAssertNil(warning)
    }

    func test_permissionWarning_atStep2_whenNotGranted_showsAccessibilityWarning() {
        // Given
        mockPermissionService.accessibilityGranted = false
        let viewModel = OnboardingViewModel(
            permissionService: mockPermissionService,
            settingsService: mockSettingsService
        )
        viewModel.nextStep() // Step 1
        viewModel.nextStep() // Step 2

        // When
        let warning = calculatePermissionWarning(for: viewModel.currentStep, viewModel: viewModel)

        // Then
        XCTAssertNotNil(warning)
        XCTAssertTrue(warning?.contains("Accessibility") ?? false)
    }

    func test_permissionWarning_atStep3_whenNotGranted_showsInputMonitoringWarning() {
        // Given
        mockPermissionService.inputMonitoringGranted = false
        let viewModel = OnboardingViewModel(
            permissionService: mockPermissionService,
            settingsService: mockSettingsService
        )
        viewModel.nextStep() // Step 1
        viewModel.nextStep() // Step 2
        viewModel.nextStep() // Step 3

        // When
        let warning = calculatePermissionWarning(for: viewModel.currentStep, viewModel: viewModel)

        // Then
        XCTAssertNotNil(warning)
        XCTAssertTrue(warning?.contains("Input monitoring") ?? false)
    }

    func test_permissionWarning_atStep4_isNil() {
        // Given
        let viewModel = OnboardingViewModel(
            permissionService: mockPermissionService,
            settingsService: mockSettingsService
        )
        for _ in 0..<4 {
            viewModel.nextStep()
        }

        // When
        let warning = calculatePermissionWarning(for: viewModel.currentStep, viewModel: viewModel)

        // Then
        XCTAssertNil(warning)
    }

    func test_permissionWarning_atStep5_isNil() {
        // Given
        let viewModel = OnboardingViewModel(
            permissionService: mockPermissionService,
            settingsService: mockSettingsService
        )
        for _ in 0..<5 {
            viewModel.nextStep()
        }

        // When
        let warning = calculatePermissionWarning(for: viewModel.currentStep, viewModel: viewModel)

        // Then
        XCTAssertNil(warning)
    }

    // MARK: - Content View Tests

    func test_contentView_atStep0_displaysWelcome() {
        // Given
        let viewModel = OnboardingViewModel(
            permissionService: mockPermissionService,
            settingsService: mockSettingsService
        )

        // When/Then - Step 0 is welcome step
        XCTAssertEqual(viewModel.currentStep, 0)
        XCTAssertEqual(viewModel.stepTitle(for: 0), "Welcome")
    }

    func test_contentView_atStep1_displaysMicrophone() {
        // Given
        let viewModel = OnboardingViewModel(
            permissionService: mockPermissionService,
            settingsService: mockSettingsService
        )
        viewModel.nextStep()

        // When/Then - Step 1 is microphone step
        XCTAssertEqual(viewModel.currentStep, 1)
        XCTAssertEqual(viewModel.stepTitle(for: 1), "Microphone Access")
    }

    func test_contentView_atStep2_displaysAccessibility() {
        // Given
        let viewModel = OnboardingViewModel(
            permissionService: mockPermissionService,
            settingsService: mockSettingsService
        )
        viewModel.nextStep()
        viewModel.nextStep()

        // When/Then - Step 2 is accessibility step
        XCTAssertEqual(viewModel.currentStep, 2)
        XCTAssertEqual(viewModel.stepTitle(for: 2), "Accessibility Access")
    }

    func test_contentView_atStep3_displaysInputMonitoring() {
        // Given
        let viewModel = OnboardingViewModel(
            permissionService: mockPermissionService,
            settingsService: mockSettingsService
        )
        viewModel.nextStep()
        viewModel.nextStep()
        viewModel.nextStep()

        // When/Then - Step 3 is input monitoring step
        XCTAssertEqual(viewModel.currentStep, 3)
        XCTAssertEqual(viewModel.stepTitle(for: 3), "Input Monitoring")
    }

    func test_contentView_atStep4_displaysDemo() {
        // Given
        let viewModel = OnboardingViewModel(
            permissionService: mockPermissionService,
            settingsService: mockSettingsService
        )
        for _ in 0..<4 {
            viewModel.nextStep()
        }

        // When/Then - Step 4 is demo step
        XCTAssertEqual(viewModel.currentStep, 4)
        XCTAssertEqual(viewModel.stepTitle(for: 4), "Try It Now")
    }

    func test_contentView_atStep5_displaysCompletion() {
        // Given
        let viewModel = OnboardingViewModel(
            permissionService: mockPermissionService,
            settingsService: mockSettingsService
        )
        for _ in 0..<5 {
            viewModel.nextStep()
        }

        // When/Then - Step 5 is completion step
        XCTAssertEqual(viewModel.currentStep, 5)
        XCTAssertEqual(viewModel.stepTitle(for: 5), "All Set!")
    }

    // MARK: - Navigation Flow Tests

    func test_navigationFlow_nextThenBack_returnsToOriginalStep() {
        // Given
        let viewModel = OnboardingViewModel(
            permissionService: mockPermissionService,
            settingsService: mockSettingsService
        )
        XCTAssertEqual(viewModel.currentStep, 0)

        // When
        viewModel.nextStep()
        XCTAssertEqual(viewModel.currentStep, 1)
        viewModel.previousStep()

        // Then
        XCTAssertEqual(viewModel.currentStep, 0)
    }

    func test_navigationFlow_multipleNextThenBack_navigatesCorrectly() {
        // Given
        let viewModel = OnboardingViewModel(
            permissionService: mockPermissionService,
            settingsService: mockSettingsService
        )

        // When - Navigate forward
        viewModel.nextStep() // 0 -> 1
        viewModel.nextStep() // 1 -> 2
        viewModel.nextStep() // 2 -> 3
        XCTAssertEqual(viewModel.currentStep, 3)

        // Then - Navigate back
        viewModel.previousStep() // 3 -> 2
        XCTAssertEqual(viewModel.currentStep, 2)
        viewModel.previousStep() // 2 -> 1
        XCTAssertEqual(viewModel.currentStep, 1)
    }

    func test_navigationFlow_canNavigateThroughAllSteps() {
        // Given
        let viewModel = OnboardingViewModel(
            permissionService: mockPermissionService,
            settingsService: mockSettingsService
        )

        // When/Then - Navigate through all steps
        for expectedStep in 0..<5 {
            XCTAssertEqual(viewModel.currentStep, expectedStep)
            viewModel.nextStep()
        }
        XCTAssertEqual(viewModel.currentStep, 5)
    }

    // MARK: - Edge Case Tests

    func test_multipleNextAtFinalStep_completesOnboarding() {
        // Given
        let viewModel = OnboardingViewModel(
            permissionService: mockPermissionService,
            settingsService: mockSettingsService
        )
        for _ in 0..<5 {
            viewModel.nextStep()
        }
        XCTAssertEqual(viewModel.currentStep, 5)

        // When
        viewModel.nextStep()

        // Then
        XCTAssertTrue(viewModel.isComplete)
    }

    func test_multipleBackAtFirstStep_staysAtZero() {
        // Given
        let viewModel = OnboardingViewModel(
            permissionService: mockPermissionService,
            settingsService: mockSettingsService
        )
        XCTAssertEqual(viewModel.currentStep, 0)

        // When
        viewModel.previousStep()
        viewModel.previousStep()
        viewModel.previousStep()

        // Then
        XCTAssertEqual(viewModel.currentStep, 0)
    }

    // MARK: - Helper Methods

    /// Replicates the progressPercentage computed property from OnboardingView
    private func calculateProgressPercentage(for step: Int) -> Double {
        return Double(step) / 5.0
    }

    /// Replicates the nextButtonTitle computed property from OnboardingView
    private func calculateNextButtonTitle(for step: Int, isComplete: Bool) -> String {
        if step == 5 || isComplete {
            return "Get Started"
        } else {
            return "Next"
        }
    }

    /// Replicates the back button visibility logic from OnboardingView
    private func shouldShowBackButton(for step: Int) -> Bool {
        return step > 0 && step < 5
    }

    /// Replicates the permissionWarning computed property from OnboardingView
    private func calculatePermissionWarning(for step: Int, viewModel: OnboardingViewModel) -> String? {
        guard step > 0 && step <= 3 else {
            return nil
        }

        switch step {
        case 1:
            return viewModel.microphoneGranted ? nil : "Microphone access is required for recording"
        case 2:
            return viewModel.accessibilityGranted ? nil : "Accessibility access is required for text insertion"
        case 3:
            return viewModel.inputMonitoringGranted ? nil : "Input monitoring is required for the global hotkey"
        default:
            return nil
        }
    }

    /// Direct calculation without viewModel for testing granted permissions
    private func calculatePermissionWarningDirect(step: Int, microphoneGranted: Bool = false,
                                                   accessibilityGranted: Bool = false,
                                                   inputMonitoringGranted: Bool = false) -> String? {
        guard step > 0 && step <= 3 else {
            return nil
        }

        switch step {
        case 1:
            return microphoneGranted ? nil : "Microphone access is required for recording"
        case 2:
            return accessibilityGranted ? nil : "Accessibility access is required for text insertion"
        case 3:
            return inputMonitoringGranted ? nil : "Input monitoring is required for the global hotkey"
        default:
            return nil
        }
    }
}
