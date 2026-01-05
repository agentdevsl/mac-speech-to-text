import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Hold-to-record shortcut
    static let holdToRecord = Self("holdToRecord", default: .init(.space, modifiers: [.control, .shift]))

    /// Toggle recording (for toggle mode)
    static let toggleRecording = Self("toggleRecording")

    /// Toggle voice monitoring on/off
    static let toggleVoiceMonitoring = Self("toggleVoiceMonitoring")
}
