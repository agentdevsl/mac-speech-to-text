import Foundation

/// User configuration stored locally
struct UserSettings: Codable, Sendable {
    var version: Int
    var general: GeneralConfiguration
    var hotkey: HotkeyConfiguration
    var language: LanguageConfiguration
    var audio: AudioConfiguration
    var ui: UIConfiguration
    var privacy: PrivacyConfiguration
    var onboarding: OnboardingState
    var lastModified: Date

    // Typealiases for view compatibility
    typealias HotkeyConfig = HotkeyConfiguration
    typealias HotkeyModifier = KeyModifier

    /// Default user settings
    static let `default` = UserSettings(
        version: 1,
        general: GeneralConfiguration(
            launchAtLogin: false,
            autoInsertText: true,
            copyToClipboard: true
        ),
        hotkey: HotkeyConfiguration(
            enabled: true,
            keyCode: 49, // Space key
            modifiers: [.command, .control],
            conflictDetected: false
        ),
        language: LanguageConfiguration(
            defaultLanguage: "en",
            recentLanguages: ["en"],
            autoDetectEnabled: false,
            downloadedModels: ["en"]
        ),
        audio: AudioConfiguration(
            inputDeviceId: nil,
            sensitivity: 0.3,
            silenceThreshold: 1.5,
            noiseSuppression: true,
            autoGainControl: true
        ),
        ui: UIConfiguration(
            theme: .system,
            modalPosition: .center,
            showWaveform: true,
            showConfidenceIndicator: true,
            animationsEnabled: true,
            menuBarIcon: .default
        ),
        privacy: PrivacyConfiguration(
            collectAnonymousStats: true,
            storagePolicy: .sessionOnly,
            dataRetentionDays: 7,
            storeHistory: false
        ),
        onboarding: OnboardingState(
            completed: false,
            currentStep: 0,
            permissionsGranted: PermissionsGranted(
                microphone: false,
                accessibility: false
            ),
            skippedSteps: []
        ),
        lastModified: Date()
    )
}

struct GeneralConfiguration: Codable, Sendable {
    var launchAtLogin: Bool
    var autoInsertText: Bool
    var copyToClipboard: Bool
}

struct HotkeyConfiguration: Codable, Sendable {
    var enabled: Bool
    var keyCode: Int
    var modifiers: [KeyModifier]
    var conflictDetected: Bool
    // Note: alternativeHotkey removed to avoid recursive type definition
    // Consider using enum with indirect case if alternative hotkey needed
}

enum KeyModifier: String, Codable, CaseIterable, Sendable {
    case command
    case control
    case option
    case shift

    var displayName: String {
        switch self {
        case .command: return "⌘"
        case .control: return "⌃"
        case .option: return "⌥"
        case .shift: return "⇧"
        }
    }
}

struct LanguageConfiguration: Codable, Sendable {
    var defaultLanguage: String
    var recentLanguages: [String]
    var autoDetectEnabled: Bool
    var downloadedModels: [String]
}

struct AudioConfiguration: Codable, Sendable {
    var inputDeviceId: String?
    var sensitivity: Double // 0.0 - 1.0
    var silenceThreshold: TimeInterval // seconds (0.5 - 3.0)
    var noiseSuppression: Bool
    var autoGainControl: Bool
}

struct UIConfiguration: Codable, Sendable {
    var theme: Theme
    var modalPosition: ModalPosition
    var showWaveform: Bool
    var showConfidenceIndicator: Bool
    var animationsEnabled: Bool
    var menuBarIcon: MenuBarIcon
}

enum Theme: String, Codable, Sendable {
    case light
    case dark
    case system

    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }
}

enum ModalPosition: String, Codable, Sendable {
    case center
    case cursor

    var displayName: String {
        switch self {
        case .center: return "Center of screen"
        case .cursor: return "At cursor position"
        }
    }
}

enum MenuBarIcon: String, Codable, Sendable {
    case `default`
    case minimal

    var displayName: String {
        switch self {
        case .default: return "Default"
        case .minimal: return "Minimal"
        }
    }
}

struct PrivacyConfiguration: Codable, Sendable {
    var collectAnonymousStats: Bool
    var storagePolicy: StoragePolicy
    var dataRetentionDays: Int
    var storeHistory: Bool
}

enum StoragePolicy: String, Codable, Sendable {
    case none
    case sessionOnly
    case persistent

    var displayName: String {
        switch self {
        case .none: return "Don't store"
        case .sessionOnly: return "Session only"
        case .persistent: return "Keep history"
        }
    }
}

struct OnboardingState: Codable, Sendable {
    var completed: Bool
    var currentStep: Int
    var permissionsGranted: PermissionsGranted
    var skippedSteps: [String]
}

struct PermissionsGranted: Codable, Sendable {
    var microphone: Bool
    var accessibility: Bool

    var allGranted: Bool {
        microphone && accessibility
    }

    var hasAnyPermission: Bool {
        microphone || accessibility
    }
}
