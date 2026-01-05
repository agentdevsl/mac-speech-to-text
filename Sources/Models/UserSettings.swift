import AppKit
import Foundation
import SwiftUI

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
    var voiceTrigger: VoiceTriggerConfiguration
    var lastModified: Date

    // Custom decoder to handle migration from existing settings without voiceTrigger
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        general = try container.decode(GeneralConfiguration.self, forKey: .general)
        hotkey = try container.decode(HotkeyConfiguration.self, forKey: .hotkey)
        language = try container.decode(LanguageConfiguration.self, forKey: .language)
        audio = try container.decode(AudioConfiguration.self, forKey: .audio)
        ui = try container.decode(UIConfiguration.self, forKey: .ui)
        privacy = try container.decode(PrivacyConfiguration.self, forKey: .privacy)
        onboarding = try container.decode(OnboardingState.self, forKey: .onboarding)
        voiceTrigger = try container.decodeIfPresent(VoiceTriggerConfiguration.self, forKey: .voiceTrigger) ?? .default
        lastModified = try container.decode(Date.self, forKey: .lastModified)
    }

    init(
        version: Int,
        general: GeneralConfiguration,
        hotkey: HotkeyConfiguration,
        language: LanguageConfiguration,
        audio: AudioConfiguration,
        ui: UIConfiguration,
        privacy: PrivacyConfiguration,
        onboarding: OnboardingState,
        voiceTrigger: VoiceTriggerConfiguration = .default,
        lastModified: Date
    ) {
        self.version = version
        self.general = general
        self.hotkey = hotkey
        self.language = language
        self.audio = audio
        self.ui = ui
        self.privacy = privacy
        self.onboarding = onboarding
        self.voiceTrigger = voiceTrigger
        self.lastModified = lastModified
    }

    // Typealiases for view compatibility
    typealias HotkeyConfig = HotkeyConfiguration
    typealias HotkeyModifier = KeyModifier

    /// Default user settings
    static let `default` = UserSettings(
        version: 1,
        general: GeneralConfiguration(
            launchAtLogin: false,
            autoInsertText: true,
            copyToClipboard: true,
            accessibilityPromptDismissed: false,
            clipboardOnlyMode: false
        ),
        hotkey: HotkeyConfiguration(
            enabled: true,
            keyCode: 49, // Space key
            modifiers: [.control, .shift], // ⌃⇧Space - avoids conflict with macOS emoji picker (⌘⌃Space)
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
            menuBarIcon: .default,
            recordingMode: .holdToRecord,
            waveformStyle: .aurora
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
        voiceTrigger: VoiceTriggerConfiguration.default,
        lastModified: Date()
    )
}

/// Controls what happens after text is pasted
enum PasteBehavior: String, Codable, Sendable, CaseIterable {
    /// Just paste the text
    case pasteOnly = "paste"
    /// Paste the text and press Enter
    case pasteAndEnter = "pasteAndEnter"

    var displayName: String {
        switch self {
        case .pasteOnly: return "Paste only"
        case .pasteAndEnter: return "Paste and Enter"
        }
    }
}

struct GeneralConfiguration: Codable, Sendable {
    var launchAtLogin: Bool
    var autoInsertText: Bool
    var copyToClipboard: Bool
    var accessibilityPromptDismissed: Bool
    var clipboardOnlyMode: Bool
    var pasteBehavior: PasteBehavior

    // Custom decoder to handle missing pasteBehavior in existing settings
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        launchAtLogin = try container.decode(Bool.self, forKey: .launchAtLogin)
        autoInsertText = try container.decode(Bool.self, forKey: .autoInsertText)
        copyToClipboard = try container.decode(Bool.self, forKey: .copyToClipboard)
        accessibilityPromptDismissed = try container.decode(Bool.self, forKey: .accessibilityPromptDismissed)
        clipboardOnlyMode = try container.decode(Bool.self, forKey: .clipboardOnlyMode)
        pasteBehavior = try container.decodeIfPresent(PasteBehavior.self, forKey: .pasteBehavior) ?? .pasteOnly
    }

    init(
        launchAtLogin: Bool = false,
        autoInsertText: Bool = true,
        copyToClipboard: Bool = true,
        accessibilityPromptDismissed: Bool = false,
        clipboardOnlyMode: Bool = false,
        pasteBehavior: PasteBehavior = .pasteOnly
    ) {
        self.launchAtLogin = launchAtLogin
        self.autoInsertText = autoInsertText
        self.copyToClipboard = copyToClipboard
        self.accessibilityPromptDismissed = accessibilityPromptDismissed
        self.clipboardOnlyMode = clipboardOnlyMode
        self.pasteBehavior = pasteBehavior
    }
}

struct HotkeyConfiguration: Codable, Sendable {
    /// Whether hotkey functionality is enabled
    var enabled: Bool

    /// @deprecated - Shortcuts are now managed by KeyboardShortcuts library.
    /// This field is kept for backward compatibility but should not be relied upon.
    /// Use KeyboardShortcuts.getShortcut(for:) to read the current shortcut.
    var keyCode: Int

    /// @deprecated - Shortcuts are now managed by KeyboardShortcuts library.
    /// This field is kept for backward compatibility but should not be relied upon.
    var modifiers: [KeyModifier]

    /// Whether a conflict with system shortcuts was detected
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
    var recordingMode: RecordingMode
    var waveformStyle: WaveformStyleOption

    // Custom decoder to handle missing waveformStyle in existing settings
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        theme = try container.decode(Theme.self, forKey: .theme)
        modalPosition = try container.decode(ModalPosition.self, forKey: .modalPosition)
        showWaveform = try container.decode(Bool.self, forKey: .showWaveform)
        showConfidenceIndicator = try container.decode(Bool.self, forKey: .showConfidenceIndicator)
        animationsEnabled = try container.decode(Bool.self, forKey: .animationsEnabled)
        menuBarIcon = try container.decode(MenuBarIcon.self, forKey: .menuBarIcon)
        recordingMode = try container.decode(RecordingMode.self, forKey: .recordingMode)
        waveformStyle = try container.decodeIfPresent(WaveformStyleOption.self, forKey: .waveformStyle) ?? .aurora
    }

    init(
        theme: Theme = .system,
        modalPosition: ModalPosition = .center,
        showWaveform: Bool = true,
        showConfidenceIndicator: Bool = true,
        animationsEnabled: Bool = true,
        menuBarIcon: MenuBarIcon = .default,
        recordingMode: RecordingMode = .holdToRecord,
        waveformStyle: WaveformStyleOption = .aurora
    ) {
        self.theme = theme
        self.modalPosition = modalPosition
        self.showWaveform = showWaveform
        self.showConfidenceIndicator = showConfidenceIndicator
        self.animationsEnabled = animationsEnabled
        self.menuBarIcon = menuBarIcon
        self.recordingMode = recordingMode
        self.waveformStyle = waveformStyle
    }
}

/// Waveform visualization style options (stored in settings)
enum WaveformStyleOption: String, Codable, CaseIterable, Sendable {
    case aurora
    case siriRings
    case particleVortex
    case crystalline
    case liquidOrb
    case flowingRibbon

    var displayName: String {
        switch self {
        case .aurora: return "Aurora"
        case .siriRings: return "Siri Rings"
        case .particleVortex: return "Particle Vortex"
        case .crystalline: return "Crystalline"
        case .liquidOrb: return "Liquid Orb"
        case .flowingRibbon: return "Flowing Ribbon"
        }
    }

    var description: String {
        switch self {
        case .aurora: return "Flowing aurora waves with prismatic colors"
        case .siriRings: return "Concentric rings that pulse outward"
        case .particleVortex: return "Swirling particles in orbital patterns"
        case .crystalline: return "Geometric crystalline patterns that morph"
        case .liquidOrb: return "Morphing liquid orb visualization"
        case .flowingRibbon: return "Ribbon-like flowing waveform"
        }
    }

    var iconName: String {
        switch self {
        case .aurora: return "waveform.path"
        case .siriRings: return "circle.circle"
        case .particleVortex: return "sparkles"
        case .crystalline: return "hexagon"
        case .liquidOrb: return "circle.fill"
        case .flowingRibbon: return "wind"
        }
    }
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

extension Theme {
    /// Convert to NSAppearance for app-wide theming
    var nsAppearance: NSAppearance? {
        switch self {
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        case .system: return nil
        }
    }

    /// Convert to SwiftUI ColorScheme
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
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

enum RecordingMode: String, Codable, CaseIterable, Sendable {
    case holdToRecord
    case toggle

    var displayName: String {
        switch self {
        case .holdToRecord: return "Hold to Record"
        case .toggle: return "Toggle"
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

    /// Last known app bundle ID when permissions were granted
    /// Used to detect signing/rebuild changes that invalidate permissions
    var lastKnownBundleId: String?

    /// Last known team ID when permissions were granted
    /// Used to detect signing identity changes
    var lastKnownTeamId: String?
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
