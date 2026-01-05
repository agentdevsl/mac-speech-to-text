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
            // Glassmorphic sidebar
            VStack(alignment: .leading, spacing: 4) {
                // App branding header with amber accent
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.amberPrimary.opacity(0.15))
                            .frame(width: 44, height: 44)

                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.amberLight, .amberPrimary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .shadow(color: .amberPrimary.opacity(0.3), radius: 6, x: 0, y: 2)

                    Text("Speech to Text")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                .padding(.bottom, 16)

                // Navigation items with amber selection
                ForEach(SidebarSection.allCases, id: \.self) { section in
                    sidebarButton(for: section)
                }

                Spacer()

                // Quit button
                Button {
                    viewModel.quitApplication()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "power")
                            .font(.system(size: 11, weight: .medium))
                        Text("Quit")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("quitButton")
            }
            .frame(width: 180)
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
            .background(sidebarBackground)

            // Subtle divider
            Rectangle()
                .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.lightCardBorder)
                .frame(width: 1)

            // Detail content area
            detailContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(detailBackground)
        }
        .background(backgroundGradient)
        .frame(minWidth: 900, minHeight: 820)
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

    // MARK: - Sidebar Button

    private func sidebarButton(for section: SidebarSection) -> some View {
        let isSelected = viewModel.selectedSection == section

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.selectedSection = section
            }
        } label: {
            HStack(spacing: 10) {
                // Icon with amber glow when selected
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(Color.selectionBackgroundAdaptive)
                            .frame(width: 24, height: 24)
                    }

                    Image(systemName: section.icon)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Color.iconPrimaryAdaptive : Color.textTertiaryAdaptive)
                }
                .frame(width: 24)

                Text(section.title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : Color.textSecondaryAdaptive)

                Spacer()

                // Selection indicator bar
                if isSelected {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.iconPrimaryAdaptive)
                        .frame(width: 3, height: 14)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.selectionBackgroundAdaptive)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.selectionBorderAdaptive, lineWidth: 1)
                            )
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("sidebar\(section.title.replacingOccurrences(of: " ", with: ""))")
    }

    // MARK: - Background Components

    /// Subtle gradient background that spans the entire window
    private var backgroundGradient: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(white: 0.08), Color(white: 0.05)]
                : [Color.lightRecessedBg, Color(hex: "EDE8E2")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    /// Frosted glass background for sidebar - subtle translucent effect
    private var sidebarBackground: some View {
        colorScheme == .dark
            ? Color(white: 0.12)
            : Color(hex: "FAF8F5")
    }

    /// Clean background for detail area
    private var detailBackground: some View {
        colorScheme == .dark
            ? Color(white: 0.08)
            : Color(hex: "FDFCFB")
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

    /// Initialize section ViewModels lazily on first appear
    /// Note: This method is idempotent - nil checks prevent duplicate creation
    /// even if onAppear fires multiple times (MED-2, MED-3 documented)
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
        case .voiceTrigger:
            VoiceTriggerSection(settingsService: settingsService)
        case .language:
            if let languageVM = languageViewModel {
                LanguageSection(viewModel: languageVM)
            } else {
                LanguageSectionPlaceholder()
            }
        case .theme:
            ThemeSection(settingsService: settingsService)
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
