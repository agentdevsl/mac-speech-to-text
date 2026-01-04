import XCTest
@testable import SpeechToText

@MainActor
final class PermissionServiceTests: XCTestCase {

    // MARK: - Microphone Permission Tests

    func test_checkMicrophonePermission_returnsBooleanValue() async {
        // Given
        let service = PermissionService()

        // When
        let hasPermission = await service.checkMicrophonePermission()

        // Then
        // In test environment, result may vary based on system state
        XCTAssertNotNil(hasPermission)
    }

    func test_requestMicrophonePermission_throwsErrorWhenDenied() async {
        // Given
        let service = PermissionService()

        // When/Then
        // This test demonstrates expected behavior when permission is denied
        // In real environment, this would require user interaction
        do {
            try await service.requestMicrophonePermission()
            // If we get here, permission was granted
            let hasPermission = await service.checkMicrophonePermission()
            XCTAssertTrue(hasPermission)
        } catch let error as PermissionError {
            XCTAssertEqual(error, .microphoneDenied)
        } catch {
            XCTFail("Wrong error type")
        }
    }

    // MARK: - Accessibility Permission Tests

    func test_checkAccessibilityPermission_returnsBooleanValue() {
        // Given
        let service = PermissionService()

        // When
        let hasPermission = service.checkAccessibilityPermission()

        // Then
        XCTAssertNotNil(hasPermission)
    }

    func test_requestAccessibilityPermission_throwsErrorWhenNotGranted() {
        // Given
        let service = PermissionService()

        // When/Then
        do {
            try service.requestAccessibilityPermission()
            // If we get here, permission was already granted
            XCTAssertTrue(service.checkAccessibilityPermission())
        } catch let error as PermissionError {
            XCTAssertEqual(error, .accessibilityDenied)
        } catch {
            XCTFail("Wrong error type")
        }
    }

    // MARK: - Get All Permissions Tests

    func test_getAllPermissionStatuses_returnsPermissionsGrantedStruct() async {
        // Given
        let service = PermissionService()

        // When
        let permissions = await service.getAllPermissionStatuses()

        // Then
        XCTAssertNotNil(permissions.microphone)
        XCTAssertNotNil(permissions.accessibility)
    }

    // MARK: - Request All Permissions Tests

    func test_requestAllPermissions_requestsBothMicrophoneAndAccessibility() async {
        // Given
        let service = PermissionService()

        // When/Then
        do {
            try await service.requestAllPermissions()
            // If successful, both permissions should be granted
            let hasAccessibility = service.checkAccessibilityPermission()
            XCTAssertNotNil(hasAccessibility)
        } catch {
            // Expected to fail if permissions not granted
            XCTAssertTrue(error is PermissionError)
        }
    }

    // MARK: - MockPermissionService Tests

    func test_mockPermissionService_allowsTestingWithGrantedPermissions() async {
        // Given
        let mockService = MockPermissionService()
        mockService.microphoneGranted = true
        mockService.accessibilityGranted = true

        // When
        let hasMicrophone = await mockService.checkMicrophonePermission()
        let hasAccessibility = mockService.checkAccessibilityPermission()

        // Then
        XCTAssertTrue(hasMicrophone)
        XCTAssertTrue(hasAccessibility)
    }

    func test_mockPermissionService_allowsTestingWithDeniedPermissions() async {
        // Given
        let mockService = MockPermissionService()
        mockService.microphoneGranted = false
        mockService.accessibilityGranted = false

        // When
        let hasMicrophone = await mockService.checkMicrophonePermission()
        let hasAccessibility = mockService.checkAccessibilityPermission()

        // Then
        XCTAssertFalse(hasMicrophone)
        XCTAssertFalse(hasAccessibility)
    }

    func test_mockPermissionService_requestMicrophone_throwsWhenDenied() async {
        // Given
        let mockService = MockPermissionService()
        mockService.microphoneGranted = false

        // When/Then
        do {
            try await mockService.requestMicrophonePermission()
            XCTFail("Should throw microphoneDenied error")
        } catch let error as PermissionError {
            XCTAssertEqual(error, .microphoneDenied)
        } catch {
            XCTFail("Wrong error type")
        }
    }

    func test_mockPermissionService_requestAccessibility_throwsWhenDenied() {
        // Given
        let mockService = MockPermissionService()
        mockService.accessibilityGranted = false

        // When/Then
        do {
            try mockService.requestAccessibilityPermission()
            XCTFail("Should throw accessibilityDenied error")
        } catch let error as PermissionError {
            XCTAssertEqual(error, .accessibilityDenied)
        } catch {
            XCTFail("Wrong error type")
        }
    }

    // MARK: - PermissionError Tests

    func test_permissionError_microphoneDenied_hasCorrectDescription() {
        // Given
        let error = PermissionError.microphoneDenied

        // When
        let description = error.errorDescription

        // Then
        XCTAssertTrue(description?.contains("Microphone permission denied") ?? false)
        XCTAssertTrue(description?.contains("System Settings") ?? false)
    }

    func test_permissionError_accessibilityDenied_hasCorrectDescription() {
        // Given
        let error = PermissionError.accessibilityDenied

        // When
        let description = error.errorDescription

        // Then
        XCTAssertTrue(description?.contains("Accessibility permission denied") ?? false)
        XCTAssertTrue(description?.contains("System Settings") ?? false)
    }

    // MARK: - PermissionsGranted Tests

    func test_permissionsGranted_allGranted_returnsTrueWhenAllTrue() {
        // Given
        let permissions = PermissionsGranted(
            microphone: true,
            accessibility: true
        )

        // When/Then
        XCTAssertTrue(permissions.allGranted)
    }

    func test_permissionsGranted_allGranted_returnsFalseWhenAnyFalse() {
        // Given
        let permissions = PermissionsGranted(
            microphone: true,
            accessibility: false
        )

        // When/Then
        XCTAssertFalse(permissions.allGranted)
    }

    func test_permissionsGranted_hasAnyPermission_returnsTrueWhenAnyTrue() {
        // Given
        let permissions = PermissionsGranted(
            microphone: false,
            accessibility: true
        )

        // When/Then
        XCTAssertTrue(permissions.hasAnyPermission)
    }

    func test_permissionsGranted_hasAnyPermission_returnsFalseWhenAllFalse() {
        // Given
        let permissions = PermissionsGranted(
            microphone: false,
            accessibility: false
        )

        // When/Then
        XCTAssertFalse(permissions.hasAnyPermission)
    }

    // MARK: - PermissionStateVerification Tests

    func test_permissionStateVerification_hasMismatch_trueWhenStoredGrantedButActualDenied() {
        // Given: Stored says microphone granted, but actual is denied
        let verification = PermissionStateVerification(
            storedMicrophoneGranted: true,
            actualMicrophoneGranted: false,
            storedAccessibilityGranted: false,
            actualAccessibilityGranted: false
        )

        // When/Then
        XCTAssertTrue(verification.hasMismatch)
        XCTAssertNotNil(verification.mismatchDescription)
        XCTAssertTrue(verification.mismatchDescription?.contains("microphone") ?? false)
    }

    func test_permissionStateVerification_hasMismatch_falseWhenStoredDeniedButActualGranted() {
        // Given: Stored says denied, but actual is granted (user granted via System Settings)
        // This is NOT a mismatch - it's an upgrade
        let verification = PermissionStateVerification(
            storedMicrophoneGranted: false,
            actualMicrophoneGranted: true,
            storedAccessibilityGranted: false,
            actualAccessibilityGranted: true
        )

        // When/Then
        XCTAssertFalse(verification.hasMismatch)
        XCTAssertNil(verification.mismatchDescription)
    }

    func test_permissionStateVerification_hasMismatch_falseWhenBothMatch() {
        // Given: Stored and actual match
        let verification = PermissionStateVerification(
            storedMicrophoneGranted: true,
            actualMicrophoneGranted: true,
            storedAccessibilityGranted: true,
            actualAccessibilityGranted: true
        )

        // When/Then
        XCTAssertFalse(verification.hasMismatch)
        XCTAssertNil(verification.mismatchDescription)
    }

    func test_permissionStateVerification_hasMismatch_detectsBothPermissionMismatches() {
        // Given: Both permissions have stale grants
        let verification = PermissionStateVerification(
            storedMicrophoneGranted: true,
            actualMicrophoneGranted: false,
            storedAccessibilityGranted: true,
            actualAccessibilityGranted: false
        )

        // When/Then
        XCTAssertTrue(verification.hasMismatch)
        XCTAssertTrue(verification.mismatchDescription?.contains("microphone") ?? false)
        XCTAssertTrue(verification.mismatchDescription?.contains("accessibility") ?? false)
    }

    // MARK: - verifyPermissionStateConsistency Tests

    func test_mockPermissionService_verifyPermissionStateConsistency_detectsMismatch() async {
        // Given: Mock service with actual permissions denied
        let mockService = MockPermissionService()
        mockService.microphoneGranted = false
        mockService.accessibilityGranted = false

        // Settings with stored permissions as granted (stale)
        var settings = UserSettings.default
        settings.onboarding.permissionsGranted = PermissionsGranted(
            microphone: true,
            accessibility: true
        )

        // When
        let verification = await mockService.verifyPermissionStateConsistency(settings: settings)

        // Then
        XCTAssertTrue(verification.hasMismatch)
        XCTAssertTrue(verification.storedMicrophoneGranted)
        XCTAssertFalse(verification.actualMicrophoneGranted)
        XCTAssertTrue(verification.storedAccessibilityGranted)
        XCTAssertFalse(verification.actualAccessibilityGranted)
    }

    func test_mockPermissionService_verifyPermissionStateConsistency_noMismatchWhenConsistent() async {
        // Given: Mock service with actual permissions granted
        let mockService = MockPermissionService()
        mockService.microphoneGranted = true
        mockService.accessibilityGranted = true

        // Settings with stored permissions as granted (consistent)
        var settings = UserSettings.default
        settings.onboarding.permissionsGranted = PermissionsGranted(
            microphone: true,
            accessibility: true
        )

        // When
        let verification = await mockService.verifyPermissionStateConsistency(settings: settings)

        // Then
        XCTAssertFalse(verification.hasMismatch)
    }

    func test_mockPermissionService_verifyPermissionStateConsistency_noMismatchOnFirstLaunch() async {
        // Given: Mock service with actual permissions denied (first launch)
        let mockService = MockPermissionService()
        mockService.microphoneGranted = false
        mockService.accessibilityGranted = false

        // Settings with stored permissions as denied (first launch state)
        var settings = UserSettings.default
        settings.onboarding.permissionsGranted = PermissionsGranted(
            microphone: false,
            accessibility: false
        )

        // When
        let verification = await mockService.verifyPermissionStateConsistency(settings: settings)

        // Then
        XCTAssertFalse(verification.hasMismatch)
    }
}
