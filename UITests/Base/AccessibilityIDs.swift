// AccessibilityIDs.swift
// macOS Local Speech-to-Text Application
//
// Centralized accessibility identifiers for all UI tests
// These identifiers must match those defined in the SwiftUI views
//
// Part of the code deduplication initiative

import Foundation

/// Centralized accessibility identifiers for all UI tests
/// Must match identifiers defined in the SwiftUI views
enum AccessibilityIDs {

    // MARK: - Main Window & Navigation

    enum MainWindow {
        static let window = "mainWindow"
        static let view = "mainView"
        static let sidebar = "mainViewSidebar"
    }

    enum Sidebar {
        static let home = "sidebarHome"
        static let general = "sidebarGeneral"
        static let audio = "sidebarAudio"
        static let language = "sidebarLanguage"
        static let privacy = "sidebarPrivacy"
        static let about = "sidebarAbout"
        static let quitButton = "quitButton"
    }

    // MARK: - Home Section

    enum HomeSection {
        static let container = "homeSection"
        static let hero = "heroSection"
        static let micIcon = "homeMicIcon"
        static let permissionCards = "permissionCards"
        static let microphoneCard = "microphonePermissionCard"
        static let accessibilityCard = "accessibilityPermissionCard"
        static let hotkeyDisplay = "hotkeyDisplay"
        static let typingPreview = "typingPreview"
    }

    // MARK: - General Section

    enum GeneralSection {
        static let container = "generalSection"
        static let content = "generalSectionContent"
        static let recordingMode = "recordingModeSection"
        static let holdToRecordCard = "holdToRecordCard"
        static let toggleModeCard = "toggleModeCard"
        static let behaviorSection = "behaviorSection"
        static let launchAtLoginToggle = "launchAtLoginToggle"
        static let autoInsertToggle = "autoInsertToggle"
        static let copyToClipboardToggle = "copyToClipboardToggle"
        static let hotkeySection = "hotkeySection"
    }

    // MARK: - Audio Section

    enum AudioSection {
        static let container = "audioSection"
        static let sensitivitySection = "sensitivitySection"
        static let sensitivitySlider = "sensitivitySlider"
        static let silenceThresholdSection = "silenceThresholdSection"
        static let silenceThresholdSlider = "silenceThresholdSlider"
        static let processingSection = "processingSection"
        static let noiseSuppressionToggle = "noiseSuppressionToggle"
        static let autoGainToggle = "autoGainControlToggle"
    }

    // MARK: - Language Section

    enum LanguageSection {
        static let container = "languageSection"
        static let currentLanguage = "languageSection.currentLanguage"
        static let autoDetectToggle = "languageSection.autoDetectToggle"
        static let allLanguagesToggle = "languageSection.allLanguagesToggle"
        static let recentLanguages = "languageSection.recentLanguages"
        static let searchField = "languageSection.searchField"
        static let downloadedModels = "languageSection.downloadedModels"
        static let languageList = "languageSection.languageList"
    }

    // MARK: - Privacy Section

    enum PrivacySection {
        static let container = "privacySection"
        static let localProcessing = "privacySection.localProcessing"
        static let statsToggle = "privacySection.statsToggle"
        static let storagePolicy = "privacySection.storagePolicy"
        static let persistentStorage = "privacySection.storage.persistent"
        static let retentionSlider = "privacySection.retentionSlider"
        static let footer = "privacySection.footer"
    }

    // MARK: - About Section

    enum AboutSection {
        static let container = "aboutSection"
        static let identity = "aboutSection.identity"
        static let shortcuts = "aboutSection.shortcuts"
        static let links = "aboutSection.links"
        static let supportLink = "aboutSection.supportLink"
        static let privacyLink = "aboutSection.privacyLink"
        static let acknowledgementsLink = "aboutSection.acknowledgementsLink"
        static let copyright = "aboutSection.copyright"
    }

    // MARK: - Glass Recording Overlay

    enum GlassOverlay {
        static let overlay = "glassRecordingOverlay"
        static let container = "glassRecordingOverlayContainer"
        static let statusText = "overlayStatusText"
        static let timer = "overlayTimer"
        /// Canonical name for the waveform view (resolves naming inconsistency)
        static let waveform = "dynamicWaveformView"
        static let recordingDot = "recordingIndicatorDot"
        static let transcribingSpinner = "transcribingSpinner"
    }
}
