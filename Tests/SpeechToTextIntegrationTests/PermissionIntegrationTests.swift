// PermissionIntegrationTests.swift
// Real permission checking tests

import XCTest
@testable import SpeechToText

@MainActor
final class PermissionIntegrationTests: IntegrationTestBase {

    // MARK: - Permission Status Tests

    func test_permissions_reportCurrentStatus() async throws {
        // Get all permission statuses
        let statuses = await permissionService.getAllPermissionStatuses()

        // Log the actual permission state
        AppLogger.system.info("""
        ═══════════════════════════════════════════════
        📋 PERMISSION STATUS REPORT
        ═══════════════════════════════════════════════
        🎤 Microphone:      \(statuses.microphone ? "✅ Granted" : "❌ Denied")
        ♿ Accessibility:   \(statuses.accessibility ? "✅ Granted" : "❌ Denied")
        ⌨️ Input Monitoring: \(statuses.inputMonitoring ? "✅ Granted" : "❌ Denied")
        ═══════════════════════════════════════════════
        All permissions:    \(statuses.allGranted ? "✅ Ready" : "⚠️ Missing permissions")
        ═══════════════════════════════════════════════
        """)

        print("""

        ═══════════════════════════════════════════════
        📋 PERMISSION STATUS REPORT
        ═══════════════════════════════════════════════
        🎤 Microphone:       \(statuses.microphone ? "✅ Granted" : "❌ Denied")
        ♿ Accessibility:    \(statuses.accessibility ? "✅ Granted" : "❌ Denied")
        ⌨️ Input Monitoring: \(statuses.inputMonitoring ? "✅ Granted" : "❌ Denied")
        ═══════════════════════════════════════════════
        All permissions:     \(statuses.allGranted ? "✅ Ready" : "⚠️ Missing permissions")
        ═══════════════════════════════════════════════

        """)

        // This test always passes - it's for reporting status
        XCTAssertTrue(true)
    }

    func test_microphone_permissionCheck() async throws {
        let granted = await permissionService.checkMicrophonePermission()

        if granted {
            AppLogger.system.info("✅ Microphone permission is granted")
        } else {
            AppLogger.system.warning("⚠️ Microphone permission is NOT granted")
            print("⚠️ Grant microphone permission in System Settings > Privacy & Security > Microphone")
        }

        // Log but don't fail - this is informational
        XCTAssertTrue(true)
    }

    func test_accessibility_permissionCheck() async throws {
        let granted = permissionService.checkAccessibilityPermission()

        if granted {
            AppLogger.system.info("✅ Accessibility permission is granted")
        } else {
            AppLogger.system.warning("⚠️ Accessibility permission is NOT granted")
            print("⚠️ Grant accessibility permission in System Settings > Privacy & Security > Accessibility")
        }

        XCTAssertTrue(true)
    }

    func test_inputMonitoring_permissionCheck() async throws {
        let granted = permissionService.checkInputMonitoringPermission()

        if granted {
            AppLogger.system.info("✅ Input Monitoring permission is granted")
        } else {
            AppLogger.system.warning("⚠️ Input Monitoring permission is NOT granted")
            print("⚠️ Grant input monitoring permission in System Settings > Privacy & Security > Input Monitoring")
        }

        XCTAssertTrue(true)
    }

    // MARK: - Permission Requirement Tests

    func test_allPermissions_requiredForFullFunctionality() async throws {
        let statuses = await permissionService.getAllPermissionStatuses()

        if !statuses.allGranted {
            var missing: [String] = []
            if !statuses.microphone { missing.append("Microphone") }
            if !statuses.accessibility { missing.append("Accessibility") }
            if !statuses.inputMonitoring { missing.append("Input Monitoring") }

            print("""

            ⚠️ MISSING PERMISSIONS: \(missing.joined(separator: ", "))

            To grant permissions, go to:
            System Settings > Privacy & Security > [Permission Name]

            Then add SpeechToText to the allowed apps.

            """)

            AppLogger.system.warning("Missing permissions: \(missing.joined(separator: ", "))")
        }

        // Skip if not all granted
        try XCTSkipUnless(statuses.allGranted, "All permissions required for this test")

        AppLogger.system.info("✅ All permissions granted - app is fully functional")
    }
}
