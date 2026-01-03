// LanguagePicker.swift
// macOS Local Speech-to-Text Application
//
// User Story 4: Customizable Settings
// Task T053: LanguagePicker component with searchable list of 25 languages

import SwiftUI

/// LanguagePicker provides searchable language selection with download status
struct LanguagePicker: View {
    // MARK: - Bindings

    @Binding var selectedLanguageCode: String

    // MARK: - State

    @State private var searchText = ""
    @State private var isDownloading = false
    @State private var downloadProgress = 0.0

    // MARK: - Properties

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

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search languages...", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Language list
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(filteredLanguages, id: \.code) { language in
                        LanguageRow(
                            language: language,
                            isSelected: language.code == selectedLanguageCode,
                            onSelect: {
                                selectedLanguageCode = language.code
                                Task {
                                    await onLanguageSelected(language)
                                }
                            }
                        )
                    }
                }
            }
            .frame(maxHeight: 300)

            // Download progress (T061)
            if isDownloading {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Downloading model...")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text("\(Int(downloadProgress * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ProgressView(value: downloadProgress)
                }
                .padding(.top, 8)
            }
        }
    }
}

// MARK: - Helper Views

/// Individual language row
private struct LanguageRow: View {
    let language: LanguageModel
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color("AmberPrimary", bundle: nil) : .secondary)
                    .font(.title3)

                // Language info
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.name)
                        .font(.callout)

                    Text(language.nativeName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Download status
                downloadStatusBadge
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color("AmberPrimary", bundle: nil).opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Download status badge
    @ViewBuilder
    private var downloadStatusBadge: some View {
        switch language.downloadStatus {
        case .downloaded:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)

        case .downloading:
            ProgressView()
                .scaleEffect(0.7)

        case .notDownloaded:
            Image(systemName: "arrow.down.circle")
                .foregroundStyle(.secondary)
                .font(.caption)

        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.caption)
        }
    }
}

// MARK: - Previews

#Preview("Language Picker") {
    LanguagePicker(
        selectedLanguageCode: .constant("en"),
        onLanguageSelected: { _ in }
    )
    .padding()
    .frame(width: 400)
}

#Preview("Language Picker - French Selected") {
    LanguagePicker(
        selectedLanguageCode: .constant("fr"),
        onLanguageSelected: { _ in }
    )
    .padding()
    .frame(width: 400)
}
