// KeywordEditorSheet.swift
// macOS Local Speech-to-Text Application
//
// Sheet/modal component for editing or creating a TriggerKeyword.
// Part of the voice trigger feature for hands-free activation.

import SwiftUI

/// A sheet for creating or editing a voice trigger keyword.
/// Pass `nil` for `keyword` to create a new keyword, or an existing keyword to edit it.
struct KeywordEditorSheet: View {
    // MARK: - Supported Keywords

    /// Keywords that have BPE token mappings and will work with wake word detection
    /// To add more, the WakeWordService.bpeTokenMappings dictionary must also be updated
    static let supportedKeywords: Set<String> = [
        // Assistant-style
        "hey siri", "hi google", "ok google", "alexa",
        "hey claude", "claude", "jarvis", "hey jarvis",
        "computer", "hey computer",
        // Action-style
        "start listening", "stop listening", "take note", "take notes",
        "start recording", "stop recording", "go home", "play music",
        "open mail", "open browser", "open calendar", "open settings",
        "open notes", "search", "send message", "new email", "call",
        "remind me", "set timer", "what time",
        // Short triggers
        "hey", "hello", "hello world", "okay", "listen", "record",
        "start", "stop", "opus", "sonnet", "transcribe",
        // Microsoft suite
        "open word", "open excel", "open powerpoint", "open outlook",
        "open teams", "open onenote", "open onedrive", "open sharepoint",
        "new document", "save document", "new spreadsheet", "new presentation"
    ]

    // MARK: - Properties

    /// Binding to the keyword being edited. Nil means creating a new keyword.
    @Binding var keyword: TriggerKeyword?

    /// Callback invoked when the user saves the keyword
    let onSave: (TriggerKeyword) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    // Local editing state
    @State private var phrase: String = ""
    @State private var boostingScore: Float = 1.5
    @State private var triggerThreshold: Float = 0.35
    @State private var isEnabled: Bool = true

    // MARK: - Computed Properties

    /// Whether this is editing an existing keyword or creating a new one
    private var isEditing: Bool {
        keyword != nil
    }

    /// Title for the sheet
    private var sheetTitle: String {
        isEditing ? "Edit Keyword" : "New Keyword"
    }

    /// Normalized phrase for validation
    private var normalizedPhrase: String {
        phrase.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Whether the entered phrase is a supported keyword
    private var isPhraseSupported: Bool {
        Self.supportedKeywords.contains(normalizedPhrase)
    }

    /// Whether the current input is valid for saving
    private var canSave: Bool {
        !normalizedPhrase.isEmpty && isPhraseSupported
    }

    /// Description for boosting score
    private var boostingDescription: String {
        if boostingScore < 1.3 {
            return "Standard sensitivity"
        } else if boostingScore < 1.7 {
            return "Balanced detection"
        } else {
            return "Easier to trigger"
        }
    }

    /// Description for trigger threshold
    private var thresholdDescription: String {
        if triggerThreshold < 0.25 {
            return "Very sensitive (may false trigger)"
        } else if triggerThreshold < 0.5 {
            return "Balanced accuracy"
        } else if triggerThreshold < 0.75 {
            return "Strict matching"
        } else {
            return "Very strict (may miss triggers)"
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()
                .padding(.horizontal, 20)

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    phraseSection
                    boostingScoreSection
                    thresholdSection
                    enabledSection
                }
                .padding(24)
            }

            Divider()
                .padding(.horizontal, 20)

            // Footer buttons
            footerView
        }
        .frame(width: 580, height: 680)
        .background(sheetBackground)
        .onAppear {
            loadKeywordData()
        }
        .onChange(of: keyword) { _, _ in
            // Reload data when the keyword binding changes (e.g., switching from one keyword to another)
            loadKeywordData()
        }
    }

    // MARK: - View Components

    private var headerView: some View {
        HStack {
            Text(sheetTitle)
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close")
            .accessibilityIdentifier("keywordEditorCloseButton")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var phraseSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Trigger Phrase", systemImage: "waveform")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)

            TextField("Enter trigger phrase...", text: $phrase)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 15))
                .accessibilityIdentifier("keywordPhraseTextField")

            // Validation feedback
            if !normalizedPhrase.isEmpty {
                if isPhraseSupported {
                    Label("Supported keyword", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Label("Unsupported - choose from the list below", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            // Supported keywords list
            VStack(alignment: .leading, spacing: 6) {
                Text("Supported keywords:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                FlowLayout(spacing: 6) {
                    ForEach(Self.supportedKeywords.sorted(), id: \.self) { keyword in
                        Button {
                            phrase = keyword
                        } label: {
                            Text(keyword)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    normalizedPhrase == keyword
                                        ? Color.warmAmber
                                        : Color.warmGray.opacity(0.5)
                                )
                                .foregroundStyle(
                                    normalizedPhrase == keyword ? .white : .primary
                                )
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    /// Flow layout for keyword chips
    private struct FlowLayout: Layout {
        var spacing: CGFloat = 8

        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
            let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
            return result.size
        }

        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
            let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
            for (index, subview) in subviews.enumerated() {
                subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                          y: bounds.minY + result.positions[index].y),
                              proposal: .unspecified)
            }
        }

        struct FlowResult {
            var size: CGSize = .zero
            var positions: [CGPoint] = []

            init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
                var currentX: CGFloat = 0
                var currentY: CGFloat = 0
                var lineHeight: CGFloat = 0

                for subview in subviews {
                    let size = subview.sizeThatFits(.unspecified)

                    if currentX + size.width > maxWidth && currentX > 0 {
                        currentX = 0
                        currentY += lineHeight + spacing
                        lineHeight = 0
                    }

                    positions.append(CGPoint(x: currentX, y: currentY))
                    lineHeight = max(lineHeight, size.height)
                    currentX += size.width + spacing
                    self.size.width = max(self.size.width, currentX)
                }

                self.size.height = currentY + lineHeight
            }
        }
    }

    private var boostingScoreSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Boosting Score", systemImage: "speaker.wave.3")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                Spacer()

                Text(String(format: "%.1f", boostingScore))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.amberPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.amberPrimary.opacity(0.1))
                    )
            }

            Slider(value: $boostingScore, in: 1.0...2.0, step: 0.1)
                .tint(Color.amberPrimary)
                .accessibilityIdentifier("keywordBoostingScoreSlider")

            HStack {
                Text("1.0")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text(boostingDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("2.0")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var thresholdSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Trigger Threshold", systemImage: "slider.horizontal.below.rectangle")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                Spacer()

                Text(String(format: "%.0f%%", triggerThreshold * 100))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.amberPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.amberPrimary.opacity(0.1))
                    )
            }

            Slider(value: $triggerThreshold, in: 0.0...1.0, step: 0.05)
                .tint(Color.amberPrimary)
                .accessibilityIdentifier("keywordThresholdSlider")

            HStack {
                Text("0%")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text(thresholdDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("100%")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var enabledSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Label("Enabled", systemImage: "power")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                Text("Enable this keyword for voice trigger detection")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: $isEnabled)
                .toggleStyle(.switch)
                .tint(Color.amberPrimary)
                .accessibilityIdentifier("keywordEnabledToggle")
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
        )
    }

    private var footerView: some View {
        HStack(spacing: 12) {
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .accessibilityIdentifier("keywordEditorCancelButton")

            Spacer()

            Button {
                saveKeyword()
            } label: {
                Text("Save")
                    .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.amberPrimary)
            .disabled(!canSave)
            .accessibilityIdentifier("keywordEditorSaveButton")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Styling Helpers

    private var sheetBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(colorScheme == .dark ? Color.modalBackgroundDark : Color.modalBackground)
    }

    private var textFieldBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white)
    }

    private var textFieldBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.1)
    }

    // MARK: - Actions

    private func loadKeywordData() {
        if let existingKeyword = keyword {
            phrase = existingKeyword.phrase
            boostingScore = existingKeyword.boostingScore
            triggerThreshold = existingKeyword.triggerThreshold
            isEnabled = existingKeyword.isEnabled
        } else {
            // Default values for new keyword
            phrase = ""
            boostingScore = 1.5
            triggerThreshold = 0.35
            isEnabled = true
        }
    }

    private func saveKeyword() {
        let trimmedPhrase = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPhrase.isEmpty else { return }

        let savedKeyword = TriggerKeyword(
            id: keyword?.id ?? UUID(),
            phrase: trimmedPhrase,
            boostingScore: boostingScore,
            triggerThreshold: triggerThreshold,
            isEnabled: isEnabled
        )

        onSave(savedKeyword)
        dismiss()
    }
}

// MARK: - Previews

#Preview("New Keyword") {
    KeywordEditorSheet(keyword: .constant(nil)) { keyword in
        print("Saved new keyword: \(keyword.phrase)")
    }
}

#Preview("Edit Keyword") {
    KeywordEditorSheet(keyword: .constant(.heyClaudeDefault)) { keyword in
        print("Updated keyword: \(keyword.phrase)")
    }
}

#Preview("Dark Mode") {
    KeywordEditorSheet(keyword: .constant(nil)) { keyword in
        print("Saved: \(keyword.phrase)")
    }
    .preferredColorScheme(.dark)
}
