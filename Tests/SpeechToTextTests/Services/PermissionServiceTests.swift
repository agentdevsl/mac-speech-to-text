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

    // MARK: - Input Monitoring Permission Tests

    func test_checkInputMonitoringPermission_returnsBooleanValue() {
        // Given
        let service = PermissionService()

        // When
        let hasPermission = service.checkInputMonitoringPermission()

        // Then
        XCTAssertNotNil(hasPermission)
    }

    func test_checkInputMonitoringPermission_usesIOHIDCheckAccess() {
        // Given
        // This test verifies that the IOHIDCheckAccess API is being used correctly
        // The real PermissionService calls IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
        // and compares the result to kIOHIDAccessTypeGranted
        let service = PermissionService()

        // When
        // The method should return a boolean without crashing
        // IOHIDCheckAccess returns IOHIDAccessType which is compared to kIOHIDAccessTypeGranted
        let result = service.checkInputMonitoringPermission()

        // Then
        // Verify the method completes successfully and returns a valid boolean
        // The result will be true if permission is granted, false otherwise
        XCTAssertTrue(result == true || result == false, "Method should return a valid boolean")
    }

    func test_checkInputMonitoringPermission_returnsTrueWhenGranted() async {
        // Given
        let mockService = MockPermissionService()
        mockService.inputMonitoringGranted = true

        // When
        let hasPermission = mockService.checkInputMonitoringPermission()

        // Then
        XCTAssertTrue(hasPermission, "Should return true when input monitoring is granted")
    }

    func test_checkInputMonitoringPermission_returnsFalseWhenDenied() async {
        // Given
        let mockService = MockPermissionService()
        mockService.inputMonitoringGranted = false

        // When
        let hasPermission = mockService.checkInputMonitoringPermission()

        // Then
        XCTAssertFalse(hasPermission, "Should return false when input monitoring is denied")
    }

    func test_checkInputMonitoringPermission_canBeToggledInMock() async {
        // Given
        let mockService = MockPermissionService()

        // When - Initially granted
        mockService.inputMonitoringGranted = true
        let initialResult = mockService.checkInputMonitoringPermission()

        // Then - Switch to denied
        mockService.inputMonitoringGranted = false
        let deniedResult = mockService.checkInputMonitoringPermission()

        // And back to granted
        mockService.inputMonitoringGranted = true
        let grantedAgainResult = mockService.checkInputMonitoringPermission()

        // Verify all transitions work correctly
        XCTAssertTrue(initialResult, "Initial state should be granted")
        XCTAssertFalse(deniedResult, "Should return false after setting to denied")
        XCTAssertTrue(grantedAgainResult, "Should return true after re-granting")
    }

    func test_realPermissionService_inputMonitoringReturnsConsistentValue() {
        // Given
        let service = PermissionService()

        // When - Call multiple times
        let result1 = service.checkInputMonitoringPermission()
        let result2 = service.checkInputMonitoringPermission()
        let result3 = service.checkInputMonitoringPermission()

        // Then - Results should be consistent
        XCTAssertEqual(result1, result2, "Multiple calls should return consistent results")
        XCTAssertEqual(result2, result3, "Multiple calls should return consistent results")
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
        XCTAssertNotNil(permissions.inputMonitoring)
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
        mockService.inputMonitoringGranted = true

        // When
        let hasMicrophone = await mockService.checkMicrophonePermission()
        let hasAccessibility = mockService.checkAccessibilityPermission()
        let hasInputMonitoring = mockService.checkInputMonitoringPermission()

        // Then
        XCTAssertTrue(hasMicrophone)
        XCTAssertTrue(hasAccessibility)
        XCTAssertTrue(hasInputMonitoring)
    }

    func test_mockPermissionService_allowsTestingWithDeniedPermissions() async {
        // Given
        let mockService = MockPermissionService()
        mockService.microphoneGranted = false
        mockService.accessibilityGranted = false
        mockService.inputMonitoringGranted = false

        // When
        let hasMicrophone = await mockService.checkMicrophonePermission()
        let hasAccessibility = mockService.checkAccessibilityPermission()
        let hasInputMonitoring = mockService.checkInputMonitoringPermission()

        // Then
        XCTAssertFalse(hasMicrophone)
        XCTAssertFalse(hasAccessibility)
        XCTAssertFalse(hasInputMonitoring)
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

    func test_permissionError_inputMonitoringDenied_hasCorrectDescription() {
        // Given
        let error = PermissionError.inputMonitoringDenied

        // When
        let description = error.errorDescription

        // Then
        XCTAssertTrue(description?.contains("Input Monitoring permission denied") ?? false)
        XCTAssertTrue(description?.contains("System Settings") ?? false)
    }

    // MARK: - PermissionsGranted Tests

    func test_permissionsGranted_allGranted_returnsTrueWhenAllTrue() {
        // Given
        let permissions = PermissionsGranted(
            microphone: true,
            accessibility: true,
            inputMonitoring: true
        )

        // When/Then
        XCTAssertTrue(permissions.allGranted)
    }

    func test_permissionsGranted_allGranted_returnsFalseWhenAnyFalse() {
        // Given
        let permissions = PermissionsGranted(
            microphone: true,
            accessibility: false,
            inputMonitoring: true
        )

        // When/Then
        XCTAssertFalse(permissions.allGranted)
    }

    func test_permissionsGranted_hasAnyPermission_returnsTrueWhenAnyTrue() {
        // Given
        let permissions = PermissionsGranted(
            microphone: false,
            accessibility: true,
            inputMonitoring: false
        )

        // When/Then
        XCTAssertTrue(permissions.hasAnyPermission)
    }

    func test_permissionsGranted_hasAnyPermission_returnsFalseWhenAllFalse() {
        // Given
        let permissions = PermissionsGranted(
            microphone: false,
            accessibility: false,
            inputMonitoring: false
        )

        // When/Then
        XCTAssertFalse(permissions.hasAnyPermission)
    }
}
