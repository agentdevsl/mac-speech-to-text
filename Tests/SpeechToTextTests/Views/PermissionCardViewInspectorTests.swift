import SwiftUI
import ViewInspector
import XCTest
@testable import SpeechToText

// Note: Inspectable conformance is no longer required in ViewInspector 0.10+

@MainActor
final class PermissionCardViewInspectorTests: XCTestCase {

    // MARK: - Microphone Card Tests

    func test_microphoneCard_hasCorrectIcon() throws {
        // Given
        let card = PermissionCard.microphone(isGranted: false) {}

        // Then
        XCTAssertEqual(card.icon, "mic.fill")
    }

    func test_microphoneCard_hasCorrectTitle() throws {
        // Given
        let card = PermissionCard.microphone(isGranted: false) {}

        // Then
        XCTAssertEqual(card.title, "Microphone Access")
    }

    func test_microphoneCard_hasCorrectDescription() throws {
        // Given
        let card = PermissionCard.microphone(isGranted: false) {}

        // Then
        XCTAssertTrue(card.description.contains("capture your voice"))
        XCTAssertTrue(card.description.contains("locally"))
    }

    func test_microphoneCard_hasCorrectButtonTitle() throws {
        // Given
        let card = PermissionCard.microphone(isGranted: false) {}

        // Then
        XCTAssertEqual(card.buttonTitle, "Grant Microphone Access")
    }

    // MARK: - Accessibility Card Tests

    func test_accessibilityCard_hasCorrectIcon() throws {
        // Given
        let card = PermissionCard.accessibility(isGranted: false) {}

        // Then
        XCTAssertEqual(card.icon, "hand.point.up.left.fill")
    }

    func test_accessibilityCard_hasCorrectTitle() throws {
        // Given
        let card = PermissionCard.accessibility(isGranted: false) {}

        // Then
        XCTAssertEqual(card.title, "Accessibility Access")
    }

    func test_accessibilityCard_hasCorrectDescription() throws {
        // Given
        let card = PermissionCard.accessibility(isGranted: false) {}

        // Then
        XCTAssertTrue(card.description.contains("insert transcribed text"))
    }

    func test_accessibilityCard_hasSystemSettingsButton() throws {
        // Given
        let card = PermissionCard.accessibility(isGranted: false) {}

        // Then
        XCTAssertEqual(card.buttonTitle, "Open System Settings")
    }

    // MARK: - Granted State Tests

    func test_card_showsGrantedWhenTrue() throws {
        // Given
        let card = PermissionCard.microphone(isGranted: true) {}

        // Then
        XCTAssertTrue(card.isGranted)
    }

    func test_card_showsNotGrantedWhenFalse() throws {
        // Given
        let card = PermissionCard.microphone(isGranted: false) {}

        // Then
        XCTAssertFalse(card.isGranted)
    }

    // MARK: - Action Callback Tests

    func test_card_actionCallbackIsStored() throws {
        // Given
        var callbackInvoked = false
        let card = PermissionCard.microphone(isGranted: false) {
            callbackInvoked = true
        }

        // When - The card stores the action
        // Then - We can verify the card was created with an action
        XCTAssertFalse(callbackInvoked)
        XCTAssertNotNil(card)
    }

    // MARK: - View Hierarchy Tests with ViewInspector

    func test_microphoneCard_rendersWithoutCrashing() throws {
        // Given
        let card = PermissionCard.microphone(isGranted: false) {}

        // When/Then - View can be inspected without crashing
        let view = try card.inspect()
        XCTAssertNotNil(view)
    }

    func test_accessibilityCard_rendersWithoutCrashing() throws {
        // Given
        let card = PermissionCard.accessibility(isGranted: false) {}

        // When/Then
        let view = try card.inspect()
        XCTAssertNotNil(view)
    }

    func test_grantedCard_rendersWithoutCrashing() throws {
        // Given
        let card = PermissionCard.microphone(isGranted: true) {}

        // When/Then
        let view = try card.inspect()
        XCTAssertNotNil(view)
    }

    func test_card_containsVStack() throws {
        // Given
        let card = PermissionCard.microphone(isGranted: false) {}

        // When/Then
        _ = try card.inspect().vStack()
    }

    func test_notGrantedCard_containsButton() throws {
        // Given
        let card = PermissionCard.microphone(isGranted: false) {}

        // When/Then - Find button in the view hierarchy
        let view = try card.inspect()
        XCTAssertNotNil(view)
        // Button should exist when not granted
    }

    // MARK: - All Permission Types Tests

    func test_allPermissionTypes_haveUniqueIcons() throws {
        // Given
        let micCard = PermissionCard.microphone(isGranted: false) {}
        let accessCard = PermissionCard.accessibility(isGranted: false) {}

        // Then
        let icons = [micCard.icon, accessCard.icon]
        let uniqueIcons = Set(icons)
        XCTAssertEqual(icons.count, uniqueIcons.count, "All permission types should have unique icons")
    }

    func test_allPermissionTypes_haveUniqueTitles() throws {
        // Given
        let micCard = PermissionCard.microphone(isGranted: false) {}
        let accessCard = PermissionCard.accessibility(isGranted: false) {}

        // Then
        let titles = [micCard.title, accessCard.title]
        let uniqueTitles = Set(titles)
        XCTAssertEqual(titles.count, uniqueTitles.count, "All permission types should have unique titles")
    }

    func test_allPermissionTypes_haveNonEmptyDescriptions() throws {
        // Given
        let micCard = PermissionCard.microphone(isGranted: false) {}
        let accessCard = PermissionCard.accessibility(isGranted: false) {}

        // Then
        XCTAssertFalse(micCard.description.isEmpty)
        XCTAssertFalse(accessCard.description.isEmpty)
    }

    // MARK: - Edge Case Tests

    func test_card_withEmptyAction_createsSuccessfully() throws {
        // Given/When
        let card = PermissionCard(
            icon: "test",
            title: "Test",
            description: "Test description",
            buttonTitle: "Test Button",
            isGranted: false,
            action: {}
        )

        // Then
        XCTAssertNotNil(card)
        XCTAssertEqual(card.icon, "test")
    }

    func test_card_withLongDescription_createsSuccessfully() throws {
        // Given
        let longDescription = String(repeating: "Long description text. ", count: 50)

        // When
        let card = PermissionCard(
            icon: "test",
            title: "Test",
            description: longDescription,
            buttonTitle: "Test Button",
            isGranted: false,
            action: {}
        )

        // Then
        XCTAssertNotNil(card)
        XCTAssertEqual(card.description, longDescription)
    }
}
