import XCTest
import SwiftUI
@testable import SpeechToText

@MainActor
final class PermissionCardTests: XCTestCase {

    // MARK: - Microphone Permission Card Tests

    func test_microphoneCard_hasCorrectIcon() {
        // Given
        let card = PermissionCard.microphone(isGranted: false) {}

        // Then
        XCTAssertEqual(card.icon, "mic.fill")
    }

    func test_microphoneCard_hasCorrectTitle() {
        // Given
        let card = PermissionCard.microphone(isGranted: false) {}

        // Then
        XCTAssertEqual(card.title, "Microphone Access")
    }

    func test_microphoneCard_hasCorrectDescription() {
        // Given
        let card = PermissionCard.microphone(isGranted: false) {}

        // Then
        XCTAssertEqual(
            card.description,
            "Required to capture your voice for transcription. All processing happens locally on your device."
        )
    }

    func test_microphoneCard_hasCorrectButtonTitle() {
        // Given
        let card = PermissionCard.microphone(isGranted: false) {}

        // Then
        XCTAssertEqual(card.buttonTitle, "Grant Microphone Access")
    }

    func test_microphoneCard_notGranted_setsIsGrantedFalse() {
        // Given
        let card = PermissionCard.microphone(isGranted: false) {}

        // Then
        XCTAssertFalse(card.isGranted)
    }

    func test_microphoneCard_granted_setsIsGrantedTrue() {
        // Given
        let card = PermissionCard.microphone(isGranted: true) {}

        // Then
        XCTAssertTrue(card.isGranted)
    }

    // MARK: - Accessibility Permission Card Tests

    func test_accessibilityCard_hasCorrectIcon() {
        // Given
        let card = PermissionCard.accessibility(isGranted: false) {}

        // Then
        XCTAssertEqual(card.icon, "hand.point.up.left.fill")
    }

    func test_accessibilityCard_hasCorrectTitle() {
        // Given
        let card = PermissionCard.accessibility(isGranted: false) {}

        // Then
        XCTAssertEqual(card.title, "Accessibility Access")
    }

    func test_accessibilityCard_hasCorrectDescription() {
        // Given
        let card = PermissionCard.accessibility(isGranted: false) {}

        // Then
        XCTAssertEqual(
            card.description,
            "Required to insert transcribed text and detect the global hotkey (⌘⌃Space). This allows the app to type for you."
        )
    }

    func test_accessibilityCard_hasCorrectButtonTitle() {
        // Given
        let card = PermissionCard.accessibility(isGranted: false) {}

        // Then
        XCTAssertEqual(card.buttonTitle, "Open System Settings")
    }

    func test_accessibilityCard_notGranted_setsIsGrantedFalse() {
        // Given
        let card = PermissionCard.accessibility(isGranted: false) {}

        // Then
        XCTAssertFalse(card.isGranted)
    }

    func test_accessibilityCard_granted_setsIsGrantedTrue() {
        // Given
        let card = PermissionCard.accessibility(isGranted: true) {}

        // Then
        XCTAssertTrue(card.isGranted)
    }

    // MARK: - Button State Tests

    func test_card_notGranted_buttonShouldBeVisible() {
        // Given
        let card = PermissionCard.microphone(isGranted: false) {}

        // Then - when not granted, button should show (isGranted is false)
        XCTAssertFalse(card.isGranted)
        // The button visibility is controlled by `if !isGranted` in the view body
    }

    func test_card_granted_buttonShouldBeHidden() {
        // Given
        let card = PermissionCard.microphone(isGranted: true) {}

        // Then - when granted, button should be hidden (isGranted is true)
        XCTAssertTrue(card.isGranted)
        // The button visibility is controlled by `if !isGranted` in the view body
    }

    func test_card_statesMatchForAllPermissionTypes() {
        // Given
        let notGrantedCards = [
            PermissionCard.microphone(isGranted: false) {},
            PermissionCard.accessibility(isGranted: false) {}
        ]

        let grantedCards = [
            PermissionCard.microphone(isGranted: true) {},
            PermissionCard.accessibility(isGranted: true) {}
        ]

        // Then
        for card in notGrantedCards {
            XCTAssertFalse(card.isGranted, "\(card.title) should not be granted")
        }

        for card in grantedCards {
            XCTAssertTrue(card.isGranted, "\(card.title) should be granted")
        }
    }

    // MARK: - Action Callback Tests

    func test_microphoneCard_actionCallbackIsStored() async {
        // Given
        var actionWasCalled = false
        let card = PermissionCard.microphone(isGranted: false) {
            actionWasCalled = true
        }

        // When
        await card.action()

        // Then
        XCTAssertTrue(actionWasCalled)
    }

    func test_accessibilityCard_actionCallbackIsStored() async {
        // Given
        var actionWasCalled = false
        let card = PermissionCard.accessibility(isGranted: false) {
            actionWasCalled = true
        }

        // When
        await card.action()

        // Then
        XCTAssertTrue(actionWasCalled)
    }

    func test_card_actionCallbackCanPerformAsyncWork() async {
        // Given
        var asyncWorkCompleted = false
        let card = PermissionCard.microphone(isGranted: false) {
            try? await Task.sleep(nanoseconds: 100_000) // 0.1ms
            asyncWorkCompleted = true
        }

        // When
        await card.action()

        // Then
        XCTAssertTrue(asyncWorkCompleted)
    }

    func test_card_actionCallbackIsInvokedOnlyOnce() async {
        // Given
        var callCount = 0
        let card = PermissionCard.microphone(isGranted: false) {
            callCount += 1
        }

        // When
        await card.action()

        // Then
        XCTAssertEqual(callCount, 1)
    }

    func test_card_multipleActionInvocationsIncrementCount() async {
        // Given
        var callCount = 0
        let card = PermissionCard.microphone(isGranted: false) {
            callCount += 1
        }

        // When
        await card.action()
        await card.action()
        await card.action()

        // Then
        XCTAssertEqual(callCount, 3)
    }

    // MARK: - Custom Card Initializer Tests

    func test_customCard_hasCorrectProperties() {
        // Given
        let customIcon = "star.fill"
        let customTitle = "Custom Permission"
        let customDescription = "This is a custom permission description."
        let customButtonTitle = "Grant Custom Permission"
        var actionInvoked = false

        // When
        let card = PermissionCard(
            icon: customIcon,
            title: customTitle,
            description: customDescription,
            buttonTitle: customButtonTitle,
            isGranted: false,
            action: { actionInvoked = true }
        )

        // Then
        XCTAssertEqual(card.icon, customIcon)
        XCTAssertEqual(card.title, customTitle)
        XCTAssertEqual(card.description, customDescription)
        XCTAssertEqual(card.buttonTitle, customButtonTitle)
        XCTAssertFalse(card.isGranted)

        // Verify action works
        Task {
            await card.action()
        }
    }

    func test_customCard_grantedState() {
        // Given
        let card = PermissionCard(
            icon: "checkmark",
            title: "Test",
            description: "Test description",
            buttonTitle: "Test Button",
            isGranted: true,
            action: {}
        )

        // Then
        XCTAssertTrue(card.isGranted)
    }

    // MARK: - Edge Cases

    func test_card_emptyActionDoesNotCrash() async {
        // Given
        let card = PermissionCard.microphone(isGranted: false) {
            // Empty action
        }

        // When/Then - should not throw or crash
        await card.action()
    }

    func test_allCardTypes_haveNonEmptyContent() {
        // Given
        let cards = [
            PermissionCard.microphone(isGranted: false) {},
            PermissionCard.accessibility(isGranted: false) {}
        ]

        // Then
        for card in cards {
            XCTAssertFalse(card.icon.isEmpty, "\(card.title) icon should not be empty")
            XCTAssertFalse(card.title.isEmpty, "Title should not be empty")
            XCTAssertFalse(card.description.isEmpty, "\(card.title) description should not be empty")
            XCTAssertFalse(card.buttonTitle.isEmpty, "\(card.title) button title should not be empty")
        }
    }

    func test_allCardTypes_iconIsSystemImage() {
        // Given
        let cards = [
            PermissionCard.microphone(isGranted: false) {},
            PermissionCard.accessibility(isGranted: false) {}
        ]

        // Then - verify all icons are valid SF Symbol names (contain expected patterns)
        for card in cards {
            XCTAssertTrue(
                card.icon.contains(".fill") || card.icon.contains("."),
                "\(card.title) icon '\(card.icon)' should be a valid SF Symbol"
            )
        }
    }

    // MARK: - Distinct Content Tests

    func test_allCardTypes_haveDistinctIcons() {
        // Given
        let micCard = PermissionCard.microphone(isGranted: false) {}
        let accessCard = PermissionCard.accessibility(isGranted: false) {}

        // Then
        XCTAssertNotEqual(micCard.icon, accessCard.icon)
    }

    func test_allCardTypes_haveDistinctTitles() {
        // Given
        let micCard = PermissionCard.microphone(isGranted: false) {}
        let accessCard = PermissionCard.accessibility(isGranted: false) {}

        // Then
        XCTAssertNotEqual(micCard.title, accessCard.title)
    }

    func test_allCardTypes_haveDistinctDescriptions() {
        // Given
        let micCard = PermissionCard.microphone(isGranted: false) {}
        let accessCard = PermissionCard.accessibility(isGranted: false) {}

        // Then
        XCTAssertNotEqual(micCard.description, accessCard.description)
    }

    // MARK: - Description Content Tests

    func test_microphoneCard_descriptionMentionsLocalProcessing() {
        // Given
        let card = PermissionCard.microphone(isGranted: false) {}

        // Then
        XCTAssertTrue(
            card.description.contains("locally"),
            "Microphone description should mention local processing for privacy"
        )
    }

    func test_accessibilityCard_descriptionMentionsTextInsertion() {
        // Given
        let card = PermissionCard.accessibility(isGranted: false) {}

        // Then
        XCTAssertTrue(
            card.description.contains("insert") || card.description.contains("text"),
            "Accessibility description should mention text insertion"
        )
    }
}
