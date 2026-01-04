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

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // App identity header
            appIdentitySection

            Divider()

            // Keyboard shortcuts
            keyboardShortcutsSection

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

    // MARK: - App Identity Section

    private var appIdentitySection: some View {
        VStack(spacing: 16) {
            // App icon
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                .accessibilityHidden(true)

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

    // MARK: - Links Section

    private var linksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Help & Support")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: 12) {
                // Support button
                LinkButton(
                    title: "Support",
                    icon: "questionmark.circle",
                    action: { viewModel.openSupport(openURL: openURL) }
                )
                .accessibilityIdentifier("aboutSection.supportLink")

                // Privacy Policy button
                LinkButton(
                    title: "Privacy Policy",
                    icon: "hand.raised",
                    action: { viewModel.openPrivacyPolicy(openURL: openURL) }
                )
                .accessibilityIdentifier("aboutSection.privacyLink")
            }

            // Acknowledgments button (full width)
            Button {
                viewModel.showAcknowledgments()
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

    private let supportURL = URL(string: "https://speechtotext.app/support")!
    private let privacyPolicyURL = URL(string: "https://speechtotext.app/privacy")!

    // MARK: - Initialization

    init() {}

    // MARK: - Methods

    func openSupport(openURL: OpenURLAction) {
        openURL(supportURL)
    }

    func openPrivacyPolicy(openURL: OpenURLAction) {
        openURL(privacyPolicyURL)
    }

    func showAcknowledgments() {
        // Post notification to show acknowledgments sheet
        NotificationCenter.default.post(
            name: .showAcknowledgments,
            object: nil
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let showAcknowledgments = Notification.Name("com.speechtotext.showAcknowledgments")
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
