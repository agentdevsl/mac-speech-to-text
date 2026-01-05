// AboutSection.swift
// macOS Local Speech-to-Text Application
//
// Part 2: Unified Main View - About Section
// Displays app info, version, keyboard shortcuts, and links

import SwiftUI

/// About section for the Main View sidebar
/// Displays app identity, keyboard shortcuts reference, and support links
struct AboutSection: View {
    // MARK: - Dependencies

    @Bindable var viewModel: AboutSectionViewModel

    // MARK: - Environment

    @Environment(\.openURL) private var openURL

    // MARK: - Animation State

    @State private var isPulsing: Bool = false

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // App identity header
            appIdentitySection

            Divider()

            // Keyboard shortcuts
            keyboardShortcutsSection

            Divider()

            // Technology section
            technologySection

            Divider()

            // Links section
            linksSection

            Spacer()

            // Footer with copyright
            copyrightFooter
        }
        .padding(20)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("aboutSection")
    }

    // MARK: - Logo Loading

    /// Load app logo from various sources with fallback
    private static func loadAppLogo() -> NSImage {
        // Try main bundle Resources folder first (xcodebuild copies resources here)
        if let url = Bundle.main.url(forResource: "app_logov2", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }

        // Try xcassets
        if let image = NSImage(named: "AppLogo") {
            return image
        }

        // Fallback to app icon
        return NSApp.applicationIconImage
    }

    // MARK: - App Identity Section

    private var appIdentitySection: some View {
        VStack(spacing: 16) {
            // App logo with circular crop and animation (matching welcome screen)
            ZStack {
                // Animated outer pulse ring
                Circle()
                    .stroke(Color.amberPrimary.opacity(isPulsing ? 0.15 : 0.4), lineWidth: isPulsing ? 6 : 3)
                    .frame(width: isPulsing ? 108 : 100, height: isPulsing ? 108 : 100)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isPulsing)

                // Outer glow ring
                Circle()
                    .stroke(Color.amberPrimary.opacity(0.4), lineWidth: 2)
                    .frame(width: 100, height: 100)

                // App logo - circular crop (with fallback to app icon)
                Image(nsImage: Self.loadAppLogo())
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 96, height: 96)
                    .clipShape(Circle())
            }
            .shadow(color: Color.amberPrimary.opacity(0.3), radius: 10, y: 3)
            .accessibilityHidden(true)
            .onAppear {
                isPulsing = true
            }

            VStack(spacing: 4) {
                // App name
                Text("Speech to Text")
                    .font(.title2)
                    .fontWeight(.semibold)

                // Version
                Text("Version \(viewModel.appVersion) (\(viewModel.buildNumber))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Tagline
                Text("Local. Private. Fast.")
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.warmAmber)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Speech to Text, Version \(viewModel.appVersion), Local Private Fast")
        .accessibilityIdentifier("aboutSection.identity")
    }

    // MARK: - Keyboard Shortcuts Section

    private var keyboardShortcutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Keyboard Shortcuts")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 8) {
                ForEach(viewModel.keyboardShortcuts, id: \.key) { shortcut in
                    KeyboardShortcutRow(shortcut: shortcut)
                        .accessibilityIdentifier("aboutSection.shortcut.\(shortcut.key)")
                }
            }
        }
        .accessibilityIdentifier("aboutSection.shortcuts")
    }

    // MARK: - Technology Section

    private var technologySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Powered By")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 8) {
                // Parakeet model info
                HStack(spacing: 12) {
                    Image(systemName: "waveform.badge.mic")
                        .font(.title2)
                        .foregroundStyle(Color.amberPrimary)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("NVIDIA Parakeet TDT")
                                .font(.callout)
                                .fontWeight(.medium)

                            Text("0.6b-v3")
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.amberPrimary.opacity(0.2))
                                .foregroundStyle(Color.amberPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }

                        Text("State-of-the-art multilingual speech recognition running locally via Apple Neural Engine")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Privacy note
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .font(.caption)
                        .foregroundStyle(Color.successGreen)

                    Text("All processing happens on-device. Your voice never leaves your Mac.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
            }
        }
        .accessibilityIdentifier("aboutSection.technology")
    }

    // MARK: - Links Section

    private var linksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Help & Support")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)

            // Acknowledgments button (full width)
            Button {
                viewModel.openAcknowledgments()
            } label: {
                HStack {
                    Image(systemName: "heart")
                        .font(.caption)

                    Text("Acknowledgments")
                        .font(.callout)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("aboutSection.acknowledgementsLink")
        }
        .accessibilityIdentifier("aboutSection.links")
    }

    // MARK: - Copyright Footer

    private var copyrightFooter: some View {
        VStack(spacing: 8) {
            Divider()

            Text(viewModel.copyrightText)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)

            Text("Made with care for your privacy")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .italic()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(viewModel.copyrightText)
        .accessibilityIdentifier("aboutSection.copyright")
    }
}

// MARK: - Keyboard Shortcut Row

private struct KeyboardShortcutRow: View {
    let shortcut: KeyboardShortcutInfo

    var body: some View {
        HStack(spacing: 12) {
            // Key combination
            Text(shortcut.keyCombo)
                .font(.system(.callout, design: .monospaced))
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 4))

            // Description
            Text(shortcut.description)
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(shortcut.keyCombo): \(shortcut.description)")
    }
}

// MARK: - Link Button

private struct LinkButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(Color.warmAmber)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.warmAmber.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint("Opens in browser")
    }
}

// MARK: - Keyboard Shortcut Info

struct KeyboardShortcutInfo: Identifiable {
    let id = UUID()
    let key: String
    let keyCombo: String
    let description: String
}

// MARK: - About Section ViewModel

@Observable
@MainActor
final class AboutSectionViewModel {
    // MARK: - App Info

    var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    var copyrightText: String {
        let year = Calendar.current.component(.year, from: Date())
        return "\u{00A9} \(year) Speech to Text"
    }

    // MARK: - Keyboard Shortcuts

    let keyboardShortcuts: [KeyboardShortcutInfo] = [
        KeyboardShortcutInfo(
            key: "record",
            keyCombo: "\u{2303}\u{21E7}Space",
            description: "Hold to record"
        ),
        KeyboardShortcutInfo(
            key: "settings",
            keyCombo: "\u{2318},",
            description: "Open settings"
        ),
        KeyboardShortcutInfo(
            key: "quit",
            keyCombo: "\u{2318}Q",
            description: "Quit"
        )
    ]

    // MARK: - URLs

    private static let supportURLString = "https://speechtotext.app/support"
    private static let privacyPolicyURLString = "https://speechtotext.app/privacy"
    private static let acknowledgementsURLString = "https://claude.ai"

    // MARK: - Initialization

    init() {}

    // MARK: - Methods

    func openSupport(openURL: OpenURLAction) {
        guard let url = URL(string: Self.supportURLString) else {
            AppLogger.system.error("Invalid support URL: \(Self.supportURLString)")
            return
        }
        openURL(url) { success in
            if !success {
                AppLogger.system.error("Failed to open support URL")
            }
        }
    }

    func openPrivacyPolicy(openURL: OpenURLAction) {
        guard let url = URL(string: Self.privacyPolicyURLString) else {
            AppLogger.system.error("Invalid privacy policy URL: \(Self.privacyPolicyURLString)")
            return
        }
        openURL(url) { success in
            if !success {
                AppLogger.system.error("Failed to open privacy policy URL")
            }
        }
    }

    func openAcknowledgments() {
        guard let url = URL(string: Self.acknowledgementsURLString) else {
            AppLogger.system.error("Invalid acknowledgements URL: \(Self.acknowledgementsURLString)")
            return
        }
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Previews

#Preview("About Section") {
    AboutSection(viewModel: AboutSectionViewModel())
        .frame(width: 320, height: 600)
        .padding()
}

#Preview("About Section - Dark Mode") {
    AboutSection(viewModel: AboutSectionViewModel())
        .frame(width: 320, height: 600)
        .padding()
        .preferredColorScheme(.dark)
}
