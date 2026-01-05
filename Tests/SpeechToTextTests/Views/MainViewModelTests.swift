// MainViewModelTests.swift
// macOS Local Speech-to-Text Application
//
// Unit tests for MainViewModel

import XCTest
@testable import SpeechToText

@MainActor
final class MainViewModelTests: XCTestCase {
    // MARK: - Properties

    var sut: MainViewModel!
    var testDefaults: UserDefaults!
    var testSuiteName: String!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()

        // Create isolated UserDefaults for testing - use unique name per test to avoid parallel test interference
        testSuiteName = "MainViewModelTests.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: testSuiteName)!
        testDefaults.removePersistentDomain(forName: testSuiteName)
        testDefaults.synchronize()

        sut = MainViewModel(userDefaults: testDefaults)
    }

    override func tearDown() async throws {
        sut?.reset()
        sut = nil
        if let suiteName = testSuiteName {
            testDefaults?.removePersistentDomain(forName: suiteName)
        }
        testDefaults?.synchronize()
        testDefaults = nil
        testSuiteName = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func test_initialization_defaultsToHomeSection() {
        XCTAssertEqual(sut.selectedSection, .home)
    }

    func test_initialization_isFirstLaunchTrueOnFirstLaunch() {
        XCTAssertTrue(sut.isFirstLaunch)
    }

    func test_initialization_restoresPersistedSection() {
        // Given: A persisted section (set AFTER setUp clears defaults)
        testDefaults.set("general", forKey: "MainView.selectedSection")
        testDefaults.synchronize()

        // When: Creating a new ViewModel
        let newViewModel = MainViewModel(userDefaults: testDefaults)

        // Then: The persisted section is restored
        XCTAssertEqual(newViewModel.selectedSection, .general)
    }

    func test_initialization_restoresIsFirstLaunchFalseWhenHasLaunchedBefore() {
        // Given: hasLaunchedBefore is true
        testDefaults.set(true, forKey: "MainView.hasLaunchedBefore")
        testDefaults.synchronize()

        // When: Creating a new ViewModel
        let newViewModel = MainViewModel(userDefaults: testDefaults)

        // Then: isFirstLaunch is false
        XCTAssertFalse(newViewModel.isFirstLaunch)
    }

    func test_initialization_defaultsToHomeWhenInvalidSectionPersisted() {
        // Given: An invalid section string persisted
        testDefaults.set("invalid_section", forKey: "MainView.selectedSection")
        testDefaults.synchronize()

        // When: Creating a new ViewModel
        let newViewModel = MainViewModel(userDefaults: testDefaults)

        // Then: Defaults to home
        XCTAssertEqual(newViewModel.selectedSection, .home)
    }

    // MARK: - SidebarSection Enum Tests

    func test_sidebarSection_allCasesCount() {
        XCTAssertEqual(SidebarSection.allCases.count, 7)
    }

    func test_sidebarSection_hasCorrectTitles() {
        XCTAssertEqual(SidebarSection.home.title, "Home")
        XCTAssertEqual(SidebarSection.general.title, "General")
        XCTAssertEqual(SidebarSection.audio.title, "Audio")
        XCTAssertEqual(SidebarSection.language.title, "Language")
        XCTAssertEqual(SidebarSection.theme.title, "Theme")
        XCTAssertEqual(SidebarSection.privacy.title, "Privacy")
        XCTAssertEqual(SidebarSection.about.title, "About")
    }

    func test_sidebarSection_hasCorrectIcons() {
        XCTAssertEqual(SidebarSection.home.icon, "house.fill")
        XCTAssertEqual(SidebarSection.general.icon, "gear")
        XCTAssertEqual(SidebarSection.audio.icon, "waveform")
        XCTAssertEqual(SidebarSection.language.icon, "globe")
        XCTAssertEqual(SidebarSection.theme.icon, "paintbrush")
        XCTAssertEqual(SidebarSection.privacy.icon, "lock.shield")
        XCTAssertEqual(SidebarSection.about.icon, "info.circle")
    }

    func test_sidebarSection_hasCorrectAccessibilityLabels() {
        XCTAssertEqual(SidebarSection.home.accessibilityLabel, "Home section")
        XCTAssertEqual(SidebarSection.general.accessibilityLabel, "General section")
        XCTAssertEqual(SidebarSection.audio.accessibilityLabel, "Audio section")
        XCTAssertEqual(SidebarSection.language.accessibilityLabel, "Language section")
        XCTAssertEqual(SidebarSection.theme.accessibilityLabel, "Theme section")
        XCTAssertEqual(SidebarSection.privacy.accessibilityLabel, "Privacy section")
        XCTAssertEqual(SidebarSection.about.accessibilityLabel, "About section")
    }

    func test_sidebarSection_hasCorrectRawValues() {
        XCTAssertEqual(SidebarSection.home.rawValue, "home")
        XCTAssertEqual(SidebarSection.general.rawValue, "general")
        XCTAssertEqual(SidebarSection.audio.rawValue, "audio")
        XCTAssertEqual(SidebarSection.language.rawValue, "language")
        XCTAssertEqual(SidebarSection.theme.rawValue, "theme")
        XCTAssertEqual(SidebarSection.privacy.rawValue, "privacy")
        XCTAssertEqual(SidebarSection.about.rawValue, "about")
    }

    func test_sidebarSection_idEqualsRawValue() {
        for section in SidebarSection.allCases {
            XCTAssertEqual(section.id, section.rawValue)
        }
    }

    func test_sidebarSection_canBeInitializedFromRawValue() {
        XCTAssertEqual(SidebarSection(rawValue: "home"), .home)
        XCTAssertEqual(SidebarSection(rawValue: "general"), .general)
        XCTAssertEqual(SidebarSection(rawValue: "audio"), .audio)
        XCTAssertEqual(SidebarSection(rawValue: "language"), .language)
        XCTAssertEqual(SidebarSection(rawValue: "privacy"), .privacy)
        XCTAssertEqual(SidebarSection(rawValue: "about"), .about)
        XCTAssertNil(SidebarSection(rawValue: "invalid"))
    }

    // MARK: - navigateTo() Tests

    func test_navigateTo_updatesSelectedSection() {
        sut.navigateTo(.general)
        XCTAssertEqual(sut.selectedSection, .general)
    }

    func test_navigateTo_updatesToAllSections() {
        for section in SidebarSection.allCases {
            sut.navigateTo(section)
            XCTAssertEqual(sut.selectedSection, section)
        }
    }

    func test_navigateTo_persistsNewSection() {
        // When: Navigate to a section
        sut.navigateTo(.audio)

        // Then: The section is persisted
        let persistedSection = testDefaults.string(forKey: "MainView.selectedSection")
        XCTAssertEqual(persistedSection, "audio")
    }

    func test_navigateTo_persistedSectionRestoredOnNewInstance() {
        // Given: Navigate to a section
        sut.navigateTo(.privacy)

        // When: Creating a new ViewModel
        let newViewModel = MainViewModel(userDefaults: testDefaults)

        // Then: The section is restored
        XCTAssertEqual(newViewModel.selectedSection, .privacy)
    }

    // MARK: - selectedSection didSet Tests

    func test_selectedSection_directAssignmentPersists() {
        // When: Directly setting the section
        sut.selectedSection = .language

        // Then: The section is persisted
        let persistedSection = testDefaults.string(forKey: "MainView.selectedSection")
        XCTAssertEqual(persistedSection, "language")
    }

    // MARK: - markFirstLaunchComplete() Tests

    func test_markFirstLaunchComplete_setsIsFirstLaunchFalse() {
        // Given: First launch
        XCTAssertTrue(sut.isFirstLaunch)

        // When
        sut.markFirstLaunchComplete()

        // Then
        XCTAssertFalse(sut.isFirstLaunch)
    }

    func test_markFirstLaunchComplete_persistsToUserDefaults() {
        // When
        sut.markFirstLaunchComplete()

        // Then
        let hasLaunchedBefore = testDefaults.bool(forKey: "MainView.hasLaunchedBefore")
        XCTAssertTrue(hasLaunchedBefore)
    }

    func test_markFirstLaunchComplete_persistedValueRestoredOnNewInstance() {
        // Given
        sut.markFirstLaunchComplete()

        // When: Creating a new ViewModel
        let newViewModel = MainViewModel(userDefaults: testDefaults)

        // Then
        XCTAssertFalse(newViewModel.isFirstLaunch)
    }

    func test_markFirstLaunchComplete_doesNothingWhenAlreadyComplete() {
        // Given: First launch already complete
        sut.markFirstLaunchComplete()
        XCTAssertFalse(sut.isFirstLaunch)

        // When: Called again
        sut.markFirstLaunchComplete()

        // Then: Still false (no change)
        XCTAssertFalse(sut.isFirstLaunch)
    }

    // MARK: - reset() Tests

    func test_reset_setsSelectedSectionToHome() {
        // Given: A non-home section
        sut.navigateTo(.privacy)
        XCTAssertEqual(sut.selectedSection, .privacy)

        // When
        sut.reset()

        // Then
        XCTAssertEqual(sut.selectedSection, .home)
    }

    func test_reset_setsIsFirstLaunchTrue() {
        // Given: First launch complete
        sut.markFirstLaunchComplete()
        XCTAssertFalse(sut.isFirstLaunch)

        // When
        sut.reset()

        // Then
        XCTAssertTrue(sut.isFirstLaunch)
    }

    func test_reset_setsPersistedSectionToHome() {
        // Given: A non-home persisted section
        sut.navigateTo(.audio)
        XCTAssertEqual(testDefaults.string(forKey: "MainView.selectedSection"), "audio")

        // When
        sut.reset()

        // Then: Persisted section is cleared (nil) so next instance gets default state
        // Note: MED-4 fix ensures removeObject happens AFTER didSet, clearing the value
        let persistedSection = testDefaults.string(forKey: "MainView.selectedSection")
        XCTAssertNil(persistedSection, "reset() should clear persisted section from UserDefaults")
    }

    func test_reset_removesHasLaunchedBefore() {
        // Given: Has launched before
        sut.markFirstLaunchComplete()

        // When
        sut.reset()

        // Then: hasLaunchedBefore is removed (defaults to false)
        let hasLaunchedBefore = testDefaults.bool(forKey: "MainView.hasLaunchedBefore")
        XCTAssertFalse(hasLaunchedBefore)
    }

    func test_reset_newInstanceHasDefaultState() {
        // Given: Modified state
        sut.navigateTo(.about)
        sut.markFirstLaunchComplete()
        sut.reset()

        // When: Creating a new ViewModel
        let newViewModel = MainViewModel(userDefaults: testDefaults)

        // Then: New instance has default state
        XCTAssertEqual(newViewModel.selectedSection, .home)
        XCTAssertTrue(newViewModel.isFirstLaunch)
    }

    // MARK: - Full Workflow Tests

    func test_fullNavigationWorkflow() {
        // Given: Initial state
        XCTAssertEqual(sut.selectedSection, .home)
        XCTAssertTrue(sut.isFirstLaunch)

        // When: User completes onboarding and navigates
        sut.markFirstLaunchComplete()
        sut.navigateTo(.general)
        sut.navigateTo(.audio)
        sut.navigateTo(.privacy)

        // Then: State reflects navigation
        XCTAssertEqual(sut.selectedSection, .privacy)
        XCTAssertFalse(sut.isFirstLaunch)

        // When: Reset
        sut.reset()

        // Then: Back to initial state
        XCTAssertEqual(sut.selectedSection, .home)
        XCTAssertTrue(sut.isFirstLaunch)
    }

    func test_persistenceAcrossInstances() {
        // Given: First instance sets state
        sut.markFirstLaunchComplete()
        sut.navigateTo(.language)

        // When: Second instance created
        let secondInstance = MainViewModel(userDefaults: testDefaults)

        // Then: State persisted
        XCTAssertEqual(secondInstance.selectedSection, .language)
        XCTAssertFalse(secondInstance.isFirstLaunch)

        // When: Second instance changes state
        secondInstance.navigateTo(.about)

        // Then: Third instance sees second instance's changes
        let thirdInstance = MainViewModel(userDefaults: testDefaults)
        XCTAssertEqual(thirdInstance.selectedSection, .about)
    }
}
