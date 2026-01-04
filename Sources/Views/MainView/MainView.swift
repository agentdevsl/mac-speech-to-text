// MainView.swift
// macOS Local Speech-to-Text Application
//
// Phase 2: Unified Main View
// NavigationSplitView container with glassmorphism design

import SwiftUI

/// MainView provides a unified interface for both first-launch welcome and subsequent settings access
/// Features a glassmorphism design with frosted glass effects and warm amber accents
struct MainView: View {
    // MARK: - Environment

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Focus State

    /// Focus state for keyboard navigation in sidebar
    @FocusState private var focusedSection: SidebarSection?

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
        HStack(spacing: 0) {
            // Simple sidebar
            VStack(alignment: .leading, spacing: 8) {
                Text("Speech to Text")
                    .font(.headline)
                    .padding(.bottom, 10)

                ForEach(SidebarSection.allCases, id: \.self) { section in
                    Button {
                        viewModel.selectedSection = section
                    } label: {
                        HStack {
                            Image(systemName: section.icon)
                            Text(section.title)
                            Spacer()
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(viewModel.selectedSection == section ? Color.accentColor.opacity(0.2) : Color.clear)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .frame(width: 180)
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Detail content
            detailContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 600, minHeight: 500)
        .accessibilityIdentifier("mainView")
        .onAppear {
            initializeViewModels()
            focusedSection = viewModel.selectedSection
        }
        .onChange(of: focusedSection) { _, newValue in
            if let newValue = newValue {
                viewModel.selectedSection = newValue
            }
        }
        .onKeyPress(.upArrow) {
            navigateToPreviousSection()
            return .handled
        }
        .onKeyPress(.downArrow) {
            navigateToNextSection()
            return .handled
        }
    }

    // MARK: - Background Components

    /// Subtle gradient background that spans the entire window
    private var backgroundGradient: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(white: 0.08), Color(white: 0.05)]
                : [Color(hex: "FDFBF9"), Color(hex: "F5F0EB")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    /// Frosted glass background for sidebar
    private var sidebarBackground: some View {
        ZStack {
            if colorScheme == .dark {
                Color.black.opacity(0.3)
            } else {
                Color.white.opacity(0.6)
            }
        }
        .background(.ultraThinMaterial)
    }

    /// Clean background for detail area
    private var detailBackground: some View {
        ZStack {
            if colorScheme == .dark {
                Color.black.opacity(0.2)
            } else {
                Color.white.opacity(0.8)
            }
        }
        .background(.regularMaterial)
    }

    // MARK: - Keyboard Navigation

    private func navigateToPreviousSection() {
        let allSections = SidebarSection.allCases
        guard let currentIndex = allSections.firstIndex(of: viewModel.selectedSection),
              currentIndex > 0 else { return }
        let previousSection = allSections[currentIndex - 1]
        viewModel.selectedSection = previousSection
        focusedSection = previousSection
    }

    private func navigateToNextSection() {
        let allSections = SidebarSection.allCases
        guard let currentIndex = allSections.firstIndex(of: viewModel.selectedSection),
              currentIndex < allSections.count - 1 else { return }
        let nextSection = allSections[currentIndex + 1]
        viewModel.selectedSection = nextSection
        focusedSection = nextSection
    }

    // MARK: - ViewModel Initialization

    private func initializeViewModels() {
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

    private var sidebarContent: some View {
        VStack(spacing: 0) {
            // App branding header
            sidebarHeader
                .padding(.top, 16)
                .padding(.bottom, 20)

            // Main navigation sections
            VStack(spacing: 4) {
                sidebarItem(for: .home)
                    .accessibilityIdentifier("sidebarHome")
            }

            // Divider with subtle styling
            sidebarDivider

            // Settings sections
            VStack(spacing: 4) {
                sidebarItem(for: .general)
                    .accessibilityIdentifier("sidebarGeneral")
                sidebarItem(for: .audio)
                    .accessibilityIdentifier("sidebarAudio")
                sidebarItem(for: .language)
                    .accessibilityIdentifier("sidebarLanguage")
                sidebarItem(for: .privacy)
                    .accessibilityIdentifier("sidebarPrivacy")
            }

            // Divider with subtle styling
            sidebarDivider

            // About section
            sidebarItem(for: .about)
                .accessibilityIdentifier("sidebarAbout")

            Spacer()

            // Quit button at bottom
            quitButton
                .padding(.bottom, 16)
        }
        .padding(.horizontal, 12)
        .frame(minWidth: 180, idealWidth: 200, maxWidth: 220)
        .accessibilityIdentifier("mainViewSidebar")
    }

    /// App branding in sidebar header
    private var sidebarHeader: some View {
        VStack(spacing: 8) {
            // Glowing amber icon
            ZStack {
                Circle()
                    .fill(Color.amberPrimary.opacity(0.15))
                    .frame(width: 50, height: 50)

                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.amberLight, .amberPrimary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .shadow(color: .amberPrimary.opacity(0.3), radius: 8, x: 0, y: 2)

            Text("Speech to Text")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
        }
    }

    /// Styled divider for sidebar
    private var sidebarDivider: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.clear,
                        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
    }

    /// Sidebar navigation item with keyboard focus support and glassmorphism
    private func sidebarItem(for section: SidebarSection) -> some View {
        let isSelected = viewModel.selectedSection == section
        let isFocused = focusedSection == section

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.selectedSection = section
            }
        } label: {
            HStack(spacing: 12) {
                // Icon with glow when selected
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(Color.amberPrimary.opacity(0.2))
                            .frame(width: 28, height: 28)
                    }

                    Image(systemName: section.icon)
                        .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Color.amberPrimary : .secondary)
                }
                .frame(width: 28)

                Text(section.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)

                Spacer()

                // Selection indicator
                if isSelected {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.amberPrimary)
                        .frame(width: 3, height: 16)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                colorScheme == .dark
                                    ? Color.amberPrimary.opacity(0.15)
                                    : Color.amberPrimary.opacity(0.12)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.amberPrimary.opacity(0.3), lineWidth: 1)
                            )
                    } else if isFocused {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
                    }
                }
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable()
        .focused($focusedSection, equals: section)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .animation(.easeInOut(duration: 0.15), value: isFocused)
        .accessibilityLabel(section.accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Quit button at bottom of sidebar
    private var quitButton: some View {
        Button {
            viewModel.quitApplication()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "power")
                    .font(.system(size: 12, weight: .medium))
                Text("Quit")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("quitButton")
        .accessibilityLabel("Quit Speech to Text")
    }

    // MARK: - Detail Content

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
            if let languageVM = languageViewModel {
                LanguageSection(viewModel: languageVM)
            } else {
                LanguageSectionPlaceholder()
            }
        case .privacy:
            if let privacyVM = privacyViewModel {
                PrivacySection(viewModel: privacyVM)
            } else {
                PrivacySectionPlaceholder()
            }
        case .about:
            if let aboutVM = aboutViewModel {
                AboutSection(viewModel: aboutVM)
            } else {
                AboutSectionPlaceholder()
            }
        }
    }
}

// MARK: - Placeholder Views

private struct LanguageSectionPlaceholder: View {
    var body: some View {
        GlassPlaceholder(icon: "globe", title: "Language Section")
    }
}

private struct PrivacySectionPlaceholder: View {
    var body: some View {
        GlassPlaceholder(icon: "lock.shield", title: "Privacy Section")
    }
}

private struct AboutSectionPlaceholder: View {
    var body: some View {
        GlassPlaceholder(icon: "info.circle", title: "About Section")
    }
}

/// Reusable glass-styled placeholder
private struct GlassPlaceholder: View {
    let icon: String
    let title: String

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.amberPrimary.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: icon)
                    .font(.system(size: 36))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.amberLight, .amberPrimary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .shadow(color: .amberPrimary.opacity(0.2), radius: 12, x: 0, y: 4)

            Text(title)
                .font(.title3)
                .fontWeight(.semibold)

            ProgressView()
                .scaleEffect(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

#Preview("Main View - Dark Mode") {
    MainViewPreview(section: .home)
        .preferredColorScheme(.dark)
}

private struct MainViewPreview: View {
    let section: SidebarSection

    var body: some View {
        let viewModel = MainViewModel()
        viewModel.selectedSection = section
        return MainView(viewModel: viewModel)
    }
}
