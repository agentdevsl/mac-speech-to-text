// MenuBarView.swift
// macOS Local Speech-to-Text Application
//
// User Story 3: Menu Bar Quick Access and Stats
// Task T044: MenuBarView - Menu bar content with quick stats display
// and menu options (Start Recording, Open Settings, Quit)

import SwiftUI

/// MenuBarView provides the menu bar dropdown content
struct MenuBarView: View {
    // MARK: - State

    @State private var viewModel = MenuBarViewModel()

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with app name
            headerSection

            Divider()

            // Quick stats section
            statsSection

            Divider()

            // Menu actions
            actionsSection

            Divider()

            // Quit button
            quitSection
        }
        .frame(width: 250)
        .onAppear {
            Task {
                await viewModel.refreshStatistics()
            }
        }
    }

    // MARK: - Sections

    /// Header section with app name and icon
    private var headerSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "mic.circle.fill")
                .font(.title2)
                .foregroundStyle(Color("AmberPrimary", bundle: nil))

            VStack(alignment: .leading, spacing: 2) {
                Text("Speech-to-Text")
                    .font(.headline)

                Text("Version \(Constants.App.version)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    /// Quick stats section
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                HStack {
                    Text("Words Today")
                    Spacer()
                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.6)
                    } else {
                        Text("\(viewModel.wordsToday)")
                            .fontWeight(.semibold)
                            .foregroundStyle(Color("AmberPrimary", bundle: nil))
                    }
                }
            } icon: {
                Image(systemName: "text.alignleft")
                    .foregroundStyle(.blue)
            }

            Label {
                HStack {
                    Text("Sessions Today")
                    Spacer()
                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.6)
                    } else {
                        Text("\(viewModel.sessionsToday)")
                            .fontWeight(.semibold)
                            .foregroundStyle(Color("AmberPrimary", bundle: nil))
                    }
                }
            } icon: {
                Image(systemName: "mic.fill")
                    .foregroundStyle(.green)
            }

            // Last updated
            Text("Updated: \(formattedUpdateTime)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .font(.callout)
    }

    /// Actions section with main menu items
    private var actionsSection: some View {
        VStack(spacing: 0) {
            MenuButton(
                icon: "mic.fill",
                title: "Start Recording",
                subtitle: "⌘⌃Space",
                action: viewModel.startRecording
            )

            MenuButton(
                icon: "gear",
                title: "Open Settings",
                subtitle: "Configure app",
                action: viewModel.openSettings
            )

            // Language quick-switch (T063)
            languageQuickSwitchMenu

            MenuButton(
                icon: "arrow.clockwise",
                title: "Refresh Stats",
                subtitle: "Update statistics",
                action: {
                    Task {
                        await viewModel.refreshStatistics()
                    }
                }
            )
        }
    }

    /// Language quick-switch menu (T063)
    private var languageQuickSwitchMenu: some View {
        Menu {
            ForEach(viewModel.recentLanguages, id: \.code) { language in
                Button {
                    Task {
                        await viewModel.switchLanguage(to: language)
                    }
                } label: {
                    HStack {
                        Text(language.flag)
                        Text(language.name)
                        if language.code == viewModel.currentLanguage {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            Divider()

            Button("More Languages...") {
                viewModel.openSettings()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "globe")
                    .font(.title3)
                    .foregroundStyle(Color("AmberPrimary", bundle: nil))
                    .frame(width: 24, alignment: .center)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Language")
                        .font(.callout)

                    if let currentLang = viewModel.currentLanguageModel {
                        Text("\(currentLang.flag) \(currentLang.name)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("English")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .buttonStyle(.plain)
    }

    /// Quit section
    private var quitSection: some View {
        Button(action: viewModel.quit) {
            HStack(spacing: 8) {
                Image(systemName: "power")
                    .foregroundStyle(.red)
                Text("Quit Speech-to-Text")
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut("q", modifiers: .command)
    }

    // MARK: - Computed Properties

    /// Cached DateFormatter for performance (avoid creating on every render)
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    /// Formatted update time
    private var formattedUpdateTime: String {
        Self.timeFormatter.string(from: viewModel.lastUpdated)
    }
}

// MARK: - Helper Views

/// Reusable menu button component
private struct MenuButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(Color("AmberPrimary", bundle: nil))
                    .frame(width: 24, alignment: .center)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout)

                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("Menu Bar View") {
    MenuBarView()
}

#Preview("With Stats") {
    MenuBarViewPreview(wordsToday: 1234, sessionsToday: 42)
}

private struct MenuBarViewPreview: View {
    let wordsToday: Int
    let sessionsToday: Int

    var body: some View {
        MenuBarView()
    }
}
