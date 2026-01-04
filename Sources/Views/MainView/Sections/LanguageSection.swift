// LanguageSection.swift
// macOS Local Speech-to-Text Application
//
// Part 2: Unified Main View - Language Settings Section
// Provides language selection with searchable list, recent languages, and model status

import SwiftUI

/// Language section for the Main View sidebar
/// Displays current language, searchable picker, and model download status
struct LanguageSection: View {
    // MARK: - Dependencies

    @Bindable var viewModel: LanguageSectionViewModel

    // MARK: - State

    @State private var searchText = ""
    @State private var isExpanded = false

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Section header
            sectionHeader

            // Current language display
            currentLanguageCard

            // Auto-detect toggle
            autoDetectToggle

            Divider()
                .padding(.vertical, 4)

            // Recent languages
            if !viewModel.recentLanguages.isEmpty {
                recentLanguagesSection
            }

            // Language picker
            languagePickerSection

            // Downloaded models indicator
            downloadedModelsSection
        }
        .padding(20)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("languageSection")
    }

    // MARK: - Section Header

    private var sectionHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Language")
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)

            Text("Select your transcription language")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .accessibilityIdentifier("languageSection.header")
    }

    // MARK: - Current Language Card

    private var currentLanguageCard: some View {
        HStack(spacing: 16) {
            // Flag
            Text(viewModel.currentLanguageFlag)
                .font(.system(size: 32))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Current Language")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(viewModel.currentLanguageName)
                    .font(.headline)
            }

            Spacer()

            // Download status badge
            if viewModel.isCurrentLanguageDownloaded {
                Label("Ready", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(Color.successGreen)
            } else {
                Label("Download needed", systemImage: "arrow.down.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color.warmAmber.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Current language: \(viewModel.currentLanguageName)")
        .accessibilityIdentifier("languageSection.currentLanguage")
    }

    // MARK: - Auto-Detect Toggle

    private var autoDetectToggle: some View {
        Toggle(isOn: $viewModel.autoDetectEnabled) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Auto-detect language")
                    .font(.body)

                Text("Let the app detect the spoken language automatically")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch)
        .tint(Color.warmAmber)
        .accessibilityIdentifier("languageSection.autoDetectToggle")
    }

    // MARK: - Recent Languages Section

    private var recentLanguagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(viewModel.recentLanguages.prefix(4), id: \.code) { language in
                    Button {
                        viewModel.selectLanguage(language)
                    } label: {
                        HStack(spacing: 6) {
                            Text(language.flag)
                                .font(.body)
                            Text(language.code.uppercased())
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            language.code == viewModel.selectedLanguageCode
                                ? Color.warmAmber.opacity(0.2)
                                : Color(nsColor: .controlBackgroundColor)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    language.code == viewModel.selectedLanguageCode
                                        ? Color.warmAmber
                                        : Color.clear,
                                    lineWidth: 1.5
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(language.name)")
                    .accessibilityHint(
                        language.code == viewModel.selectedLanguageCode
                            ? "Currently selected"
                            : "Double tap to select"
                    )
                    .accessibilityIdentifier("languageSection.recent.\(language.code)")
                }
            }
        }
        .accessibilityIdentifier("languageSection.recentLanguages")
    }

    // MARK: - Language Picker Section

    private var languagePickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Expand/collapse header
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("All Languages")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("languageSection.allLanguagesToggle")

            if isExpanded {
                // Search field
                searchField

                // Language list
                languageList
            }
        }
        .accessibilityIdentifier("languageSection.picker")
    }

    // MARK: - Search Field

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.caption)

            TextField("Search languages...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.callout)
                .accessibilityLabel("Search languages")
                .accessibilityIdentifier("languageSection.searchField")

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
                .accessibilityIdentifier("languageSection.clearSearch")
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Language List

    private var languageList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(filteredLanguages, id: \.code) { language in
                    LanguageRowView(
                        language: language,
                        isSelected: language.code == viewModel.selectedLanguageCode,
                        onSelect: {
                            viewModel.selectLanguage(language)
                        }
                    )
                    .accessibilityIdentifier("languageSection.language.\(language.code)")
                }
            }
        }
        .frame(maxHeight: 200)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Filtered Languages

    private var filteredLanguages: [LanguageModel] {
        let allLanguages = LanguageModel.supportedLanguages

        if searchText.isEmpty {
            return allLanguages
        }

        return allLanguages.filter { language in
            language.name.localizedCaseInsensitiveContains(searchText) ||
            language.nativeName.localizedCaseInsensitiveContains(searchText) ||
            language.code.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Downloaded Models Section

    private var downloadedModelsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .padding(.vertical, 4)

            HStack {
                Image(systemName: "internaldrive")
                    .foregroundStyle(.secondary)
                    .font(.caption)

                Text("\(viewModel.downloadedModelsCount) models downloaded")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if viewModel.downloadedModelsCount > 0 {
                    Text(viewModel.downloadedModelsSize)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(viewModel.downloadedModelsCount) language models downloaded, using \(viewModel.downloadedModelsSize)")
        .accessibilityIdentifier("languageSection.downloadedModels")
    }
}

// MARK: - Language Row View

private struct LanguageRowView: View {
    let language: LanguageModel
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Flag
                Text(language.flag)
                    .font(.title3)

                // Language info
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.name)
                        .font(.callout)
                        .foregroundStyle(.primary)

                    Text(language.nativeName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.warmAmber)
                        .font(.body)
                }

                // Download status
                downloadStatusBadge
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? Color.warmAmber.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(language.name), \(isSelected ? "selected" : "not selected")")
        .accessibilityHint(isSelected ? "Currently selected" : "Double tap to select")
    }

    @ViewBuilder
    private var downloadStatusBadge: some View {
        switch language.downloadStatus {
        case .downloaded:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.successGreen)
                .font(.caption)
                .accessibilityLabel("Downloaded")

        case .downloading:
            ProgressView()
                .scaleEffect(0.6)
                .accessibilityLabel("Downloading")

        case .notDownloaded:
            Image(systemName: "arrow.down.circle")
                .foregroundStyle(.secondary)
                .font(.caption)
                .accessibilityLabel("Not downloaded")

        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.warningOrange)
                .font(.caption)
                .accessibilityLabel("Download error")
        }
    }
}

// MARK: - Language Section ViewModel

@Observable
@MainActor
final class LanguageSectionViewModel {
    // MARK: - State

    var selectedLanguageCode: String
    var autoDetectEnabled: Bool
    var recentLanguages: [LanguageModel]
    var downloadedModels: [String]

    // MARK: - Dependencies

    @ObservationIgnored
    private let settingsService: SettingsService

    // MARK: - Computed Properties

    var currentLanguageName: String {
        SupportedLanguage.from(code: selectedLanguageCode)?.displayName ?? "Unknown"
    }

    var currentLanguageFlag: String {
        SupportedLanguage.from(code: selectedLanguageCode)?.flag ?? "🌐"
    }

    var isCurrentLanguageDownloaded: Bool {
        downloadedModels.contains(selectedLanguageCode)
    }

    var downloadedModelsCount: Int {
        downloadedModels.count
    }

    var downloadedModelsSize: String {
        // Approximate size per model (500MB each)
        let totalMB = downloadedModels.count * 500
        if totalMB >= 1000 {
            return String(format: "%.1f GB", Double(totalMB) / 1000.0)
        }
        return "\(totalMB) MB"
    }

    // MARK: - Initialization

    init(settingsService: SettingsService = SettingsService()) {
        self.settingsService = settingsService

        let settings = settingsService.load()
        self.selectedLanguageCode = settings.language.defaultLanguage
        self.autoDetectEnabled = settings.language.autoDetectEnabled
        self.downloadedModels = settings.language.downloadedModels

        // Build recent languages from codes
        self.recentLanguages = settings.language.recentLanguages.compactMap { code in
            LanguageModel.supportedLanguages.first { $0.code == code }
        }
    }

    // MARK: - Methods

    func selectLanguage(_ language: LanguageModel) {
        selectedLanguageCode = language.code

        // Update recent languages
        var recent = recentLanguages.filter { $0.code != language.code }
        recent.insert(language, at: 0)
        recentLanguages = Array(recent.prefix(4))

        // Persist changes
        Task {
            await saveLanguageSettings()
        }
    }

    private func saveLanguageSettings() async {
        var settings = settingsService.load()
        settings.language.defaultLanguage = selectedLanguageCode
        settings.language.autoDetectEnabled = autoDetectEnabled
        settings.language.recentLanguages = recentLanguages.map { $0.code }

        do {
            try settingsService.save(settings)
        } catch {
            // Log error but don't crash
            print("Failed to save language settings: \(error)")
        }
    }
}

// MARK: - Previews

#Preview("Language Section") {
    LanguageSection(viewModel: LanguageSectionViewModel())
        .frame(width: 320)
        .padding()
}

#Preview("Language Section - Expanded") {
    LanguageSection(viewModel: LanguageSectionViewModel())
        .frame(width: 320)
        .padding()
}
