// MainView.swift
// macOS Local Speech-to-Text Application
//
// Phase 2: Unified Main View
// NavigationSplitView container serving as both Welcome (first launch) and Settings (subsequent)

import SwiftUI

/// MainView provides a unified interface for both first-launch welcome and subsequent settings access
struct MainView: View {
    // MARK: - Environment

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - State

    @State var viewModel: MainViewModel

    // MARK: - Dependencies

    /// Settings service for persisting user preferences
    private let settingsService: SettingsService

    /// Permission service for checking/requesting system permissions
    private let permissionService: PermissionService

    // MARK: - Section ViewModels (lazy initialized)

    @State private var languageViewModel: LanguageSectionViewModel?
    @State private var privacyViewModel: PrivacySectionViewModel?
    @State private var aboutViewModel: AboutSectionViewModel?

    // MARK: - Initialization

    init(
        viewModel: MainViewModel = MainViewModel(),
        settingsService: SettingsService = SettingsService(),
        permissionService: PermissionService = PermissionService()
    ) {
        self._viewModel = State(initialValue: viewModel)
        self.settingsService = settingsService
        self.permissionService = permissionService
    }

    // MARK: - Body

    var body: some View {
        NavigationSplitView {
            sidebarContent
        } detail: {
            detailContent
        }
        .frame(minWidth: 600, minHeight: 500)
        .frame(width: 600, height: 500)
        .accessibilityIdentifier("mainView")
        .onAppear {
            initializeViewModels()
        }
    }

    // MARK: - ViewModel Initialization

    /// Initialize section ViewModels on first appear
    private func initializeViewModels() {
        // ViewModels use default initializers - they manage their own dependencies internally
        if languageViewModel == nil {
            languageViewModel = LanguageSectionViewModel()
        }
        if privacyViewModel == nil {
            privacyViewModel = PrivacySectionViewModel()
        }
        if aboutViewModel == nil {
            aboutViewModel = AboutSectionViewModel()
        }
    }

    // MARK: - Sidebar

    /// Sidebar navigation content
    private var sidebarContent: some View {
        VStack(spacing: 0) {
            // Main navigation sections
            List(selection: $viewModel.selectedSection) {
                // Home section (default on first launch)
                sidebarItem(for: .home)
                    .accessibilityIdentifier("sidebarHome")

                Divider()
                    .padding(.vertical, 8)

                // Settings sections
                Section {
                    sidebarItem(for: .general)
                        .accessibilityIdentifier("sidebarGeneral")
                    sidebarItem(for: .audio)
                        .accessibilityIdentifier("sidebarAudio")
                    sidebarItem(for: .language)
                        .accessibilityIdentifier("sidebarLanguage")
                    sidebarItem(for: .privacy)
                        .accessibilityIdentifier("sidebarPrivacy")
                }

                Divider()
                    .padding(.vertical, 8)

                // About section
                sidebarItem(for: .about)
                    .accessibilityIdentifier("sidebarAbout")
            }
            .listStyle(.sidebar)

            Spacer()

            // Quit button at bottom
            quitButton
        }
        .frame(minWidth: 160, idealWidth: 180, maxWidth: 200)
        .accessibilityIdentifier("mainViewSidebar")
    }

    /// Sidebar navigation item
    private func sidebarItem(for section: SidebarSection) -> some View {
        Label {
            Text(section.title)
        } icon: {
            Image(systemName: section.icon)
                .foregroundStyle(
                    viewModel.selectedSection == section
                    ? Color("AmberPrimary", bundle: nil)
                    : .secondary
                )
        }
        .tag(section)
        .accessibilityLabel(section.accessibilityLabel)
    }

    /// Quit button at bottom of sidebar
    private var quitButton: some View {
        Button {
            viewModel.quitApplication()
        } label: {
            HStack {
                Image(systemName: "power")
                Text("Quit")
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .background(Color.gray.opacity(0.1))
        .accessibilityIdentifier("quitButton")
        .accessibilityLabel("Quit Speech to Text")
    }

    // MARK: - Detail Content

    /// Main content area based on selected section
    @ViewBuilder
    private var detailContent: some View {
        switch viewModel.selectedSection {
        case .home:
            HomeSection(
                settingsService: settingsService,
                permissionService: permissionService
            )
        case .general:
            GeneralSection(settingsService: settingsService)
        case .audio:
            AudioSection(settingsService: settingsService)
        case .language:
            if let vm = languageViewModel {
                LanguageSection(viewModel: vm)
            } else {
                LanguageSectionPlaceholder()
            }
        case .privacy:
            if let vm = privacyViewModel {
                PrivacySection(viewModel: vm)
            } else {
                PrivacySectionPlaceholder()
            }
        case .about:
            if let vm = aboutViewModel {
                AboutSection(viewModel: vm)
            } else {
                AboutSectionPlaceholder()
            }
        }
    }
}

// MARK: - Placeholder Views (fallback until ViewModels initialize)

/// Placeholder for Language section
private struct LanguageSectionPlaceholder: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "globe")
                .font(.system(size: 48))
                .foregroundStyle(Color("AmberPrimary", bundle: nil))

            Text("Language Section")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Loading...")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("languageSectionContent")
    }
}

/// Placeholder for Privacy section
private struct PrivacySectionPlaceholder: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 48))
                .foregroundStyle(Color("AmberPrimary", bundle: nil))

            Text("Privacy Section")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Loading...")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("privacySectionContent")
    }
}

/// Placeholder for About section
private struct AboutSectionPlaceholder: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "info.circle")
                .font(.system(size: 48))
                .foregroundStyle(Color("AmberPrimary", bundle: nil))

            Text("About Section")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Loading...")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("aboutSectionContent")
    }
}

// MARK: - Previews

#Preview("Main View - Home") {
    MainViewPreview(section: .home)
}

#Preview("Main View - General") {
    MainViewPreview(section: .general)
}

#Preview("Main View - Audio") {
    MainViewPreview(section: .audio)
}

/// Preview helper with customizable section
private struct MainViewPreview: View {
    let section: SidebarSection

    var body: some View {
        let viewModel = MainViewModel()
        viewModel.selectedSection = section
        return MainView(viewModel: viewModel)
    }
}
