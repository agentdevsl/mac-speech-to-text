// InlineLanguagePicker.swift
// macOS Local Speech-to-Text Application
//
// Phase 3: UI Simplification
// Compact language selector for inline menu bar settings

import SwiftUI

/// Compact inline language picker for menu bar settings
struct InlineLanguagePicker: View {
    // MARK: - Bindings

    @Binding var selectedLanguageCode: String

    // MARK: - State

    @State private var searchText = ""
    @State private var isExpanded = false

    // MARK: - Properties

    let recentLanguages: [LanguageModel]
    let onLanguageSelected: (LanguageModel) async -> Void

    // MARK: - Computed Properties

    /// Filtered languages based on search text
    private var filteredLanguages: [LanguageModel] {
        if searchText.isEmpty {
            return LanguageModel.supportedLanguages
        }

        return LanguageModel.supportedLanguages.filter { language in
            language.name.localizedCaseInsensitiveContains(searchText) ||
            language.nativeName.localizedCaseInsensitiveContains(searchText) ||
            language.code.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// Current selected language model
    private var currentLanguage: LanguageModel? {
        LanguageModel.supportedLanguages.first { $0.code == selectedLanguageCode }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Recent languages (quick access)
            if !recentLanguages.isEmpty {
                Text("Recent")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)

                ForEach(recentLanguages.prefix(3), id: \.code) { language in
                    languageButton(language)
                }

                Divider()
                    .padding(.vertical, 4)
            }

            // Search field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("Search...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.callout)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Language list (scrollable)
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(filteredLanguages, id: \.code) { language in
                        languageButton(language)
                    }
                }
            }
            .frame(maxHeight: 200)
        }
    }

    // MARK: - Helper Views

    private func languageButton(_ language: LanguageModel) -> some View {
        Button {
            selectedLanguageCode = language.code
            Task {
                await onLanguageSelected(language)
            }
        } label: {
            HStack(spacing: 8) {
                Text(language.flag)
                    .font(.callout)

                VStack(alignment: .leading, spacing: 1) {
                    Text(language.name)
                        .font(.callout)

                    if language.name != language.nativeName {
                        Text(language.nativeName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if language.code == selectedLanguageCode {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .foregroundStyle(Color("AmberPrimary", bundle: nil))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                language.code == selectedLanguageCode
                    ? Color("AmberPrimary", bundle: nil).opacity(0.1)
                    : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("Inline Language Picker") {
    InlineLanguagePicker(
        selectedLanguageCode: .constant("en"),
        recentLanguages: Array(LanguageModel.supportedLanguages.prefix(3)),
        onLanguageSelected: { _ in }
    )
    .frame(width: 220)
    .padding()
}

#Preview("With French Selected") {
    InlineLanguagePicker(
        selectedLanguageCode: .constant("fr"),
        recentLanguages: [],
        onLanguageSelected: { _ in }
    )
    .frame(width: 220)
    .padding()
}
