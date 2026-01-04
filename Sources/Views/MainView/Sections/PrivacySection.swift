// PrivacySection.swift
// macOS Local Speech-to-Text Application
//
// Part 2: Unified Main View - Privacy Settings Section
// Provides privacy controls for data collection, storage policy, and retention

import SwiftUI

/// Privacy section for the Main View sidebar
/// Displays data collection, storage policy, and local processing assurance
struct PrivacySection: View {
    // MARK: - Dependencies

    @Bindable var viewModel: PrivacySectionViewModel

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Section header
            sectionHeader

            // Local processing assurance
            localProcessingCard

            Divider()
                .padding(.vertical, 4)

            // Anonymous stats toggle
            anonymousStatsToggle

            // Storage policy picker
            storagePolicySection

            // Data retention slider (conditional)
            if viewModel.storagePolicy == .persistent {
                dataRetentionSection
            }

            Spacer(minLength: 20)

            // Privacy info footer
            privacyInfoFooter
        }
        .padding(20)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("privacySection")
    }

    // MARK: - Section Header

    private var sectionHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Privacy")
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)

            Text("Control your data and privacy settings")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .accessibilityIdentifier("privacySection.header")
    }

    // MARK: - Local Processing Card

    private var localProcessingCard: some View {
        HStack(spacing: 16) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 28))
                .foregroundStyle(Color.warmAmber)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("100% Local Processing")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("All speech recognition happens on your device. No data is ever sent to external servers.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.warmAmber.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("100% Local Processing. All speech recognition happens on your device. No data is ever sent to external servers.")
        .accessibilityIdentifier("privacySection.localProcessing")
    }

    // MARK: - Anonymous Stats Toggle

    private var anonymousStatsToggle: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $viewModel.collectAnonymousStats) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Collect anonymous statistics")
                        .font(.body)

                    Text("Help improve the app with anonymous usage data")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .tint(Color.warmAmber)
            .accessibilityIdentifier("privacySection.statsToggle")

            // Info about what's collected
            if viewModel.collectAnonymousStats {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Only word count and session duration are tracked. No actual transcriptions are stored.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, 4)
                .accessibilityIdentifier("privacySection.statsInfo")
            }
        }
    }

    // MARK: - Storage Policy Section

    private var storagePolicySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Storage Policy")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            // Storage policy options
            VStack(spacing: 8) {
                ForEach(StoragePolicy.allCases, id: \.self) { policy in
                    StoragePolicyRow(
                        policy: policy,
                        isSelected: viewModel.storagePolicy == policy,
                        onSelect: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                viewModel.storagePolicy = policy
                            }
                        }
                    )
                    .accessibilityIdentifier("privacySection.storage.\(policy.rawValue)")
                }
            }
        }
        .accessibilityIdentifier("privacySection.storagePolicy")
    }

    // MARK: - Data Retention Section

    private var dataRetentionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data Retention")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                HStack {
                    Text("Keep history for")
                        .font(.callout)

                    Spacer()

                    Text("\(viewModel.dataRetentionDays) days")
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.warmAmber)
                }

                Slider(
                    value: Binding(
                        get: { Double(viewModel.dataRetentionDays) },
                        set: { viewModel.dataRetentionDays = Int($0) }
                    ),
                    in: 1...30,
                    step: 1
                )
                .tint(Color.warmAmber)
                .accessibilityLabel("Data retention period")
                .accessibilityValue("\(viewModel.dataRetentionDays) days")
                .accessibilityIdentifier("privacySection.retentionSlider")

                HStack {
                    Text("1 day")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Spacer()

                    Text("30 days")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
        .accessibilityIdentifier("privacySection.dataRetention")
    }

    // MARK: - Privacy Info Footer

    private var privacyInfoFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            HStack(spacing: 4) {
                Image(systemName: "checkmark.shield")
                    .font(.caption)
                    .foregroundStyle(Color.successGreen)

                Text("Your privacy is protected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("All processing happens locally on your device using Apple's Neural Engine. Your voice data never leaves your Mac.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Your privacy is protected. All processing happens locally on your device.")
        .accessibilityIdentifier("privacySection.footer")
    }
}

// MARK: - Storage Policy Row

private struct StoragePolicyRow: View {
    let policy: StoragePolicy
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.warmAmber : Color.secondary)
                    .font(.body)

                // Policy info
                VStack(alignment: .leading, spacing: 2) {
                    Text(policy.displayName)
                        .font(.callout)
                        .foregroundStyle(.primary)

                    Text(policy.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Icon
                Image(systemName: policy.icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(
                isSelected
                    ? Color.warmAmber.opacity(0.1)
                    : Color(nsColor: .controlBackgroundColor)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected ? Color.warmAmber : Color.clear,
                        lineWidth: 1.5
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(policy.displayName), \(policy.description)")
        .accessibilityHint(isSelected ? "Currently selected" : "Double tap to select")
    }
}

// MARK: - Storage Policy Extension

extension StoragePolicy: CaseIterable {
    static let allCases: [StoragePolicy] = [.none, .sessionOnly, .persistent]

    var description: String {
        switch self {
        case .none:
            return "Transcriptions are discarded immediately"
        case .sessionOnly:
            return "Kept until you quit the app"
        case .persistent:
            return "Saved locally for quick access"
        }
    }

    var icon: String {
        switch self {
        case .none:
            return "trash"
        case .sessionOnly:
            return "clock"
        case .persistent:
            return "internaldrive"
        }
    }
}

// MARK: - Privacy Section ViewModel

@Observable
@MainActor
final class PrivacySectionViewModel {
    // MARK: - State

    var collectAnonymousStats: Bool {
        didSet {
            scheduleSave()
        }
    }

    var storagePolicy: StoragePolicy {
        didSet {
            // Keep storeHistory in sync with storagePolicy
            storeHistory = (storagePolicy == .persistent)
            scheduleSave()
        }
    }

    var dataRetentionDays: Int {
        didSet {
            scheduleSave()
        }
    }

    /// Derived from storagePolicy - kept in sync for settings persistence
    private(set) var storeHistory: Bool

    // MARK: - Dependencies

    @ObservationIgnored
    private let settingsService: SettingsService

    @ObservationIgnored
    private var saveTask: Task<Void, Never>?

    /// Debounce interval for save operations
    @ObservationIgnored
    private let saveDebounceInterval: Duration = .milliseconds(300)

    // MARK: - Initialization

    init(settingsService: SettingsService = SettingsService()) {
        self.settingsService = settingsService

        let settings = settingsService.load()
        self.collectAnonymousStats = settings.privacy.collectAnonymousStats
        self.storagePolicy = settings.privacy.storagePolicy
        self.dataRetentionDays = settings.privacy.dataRetentionDays
        // Initialize storeHistory from storagePolicy to ensure consistency
        self.storeHistory = (settings.privacy.storagePolicy == .persistent)
    }

    // MARK: - Methods

    /// Schedules a debounced save operation, canceling any pending save
    private func scheduleSave() {
        // Cancel any pending save task
        saveTask?.cancel()

        // Schedule a new save after debounce interval
        saveTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: self?.saveDebounceInterval ?? .milliseconds(300))
            } catch {
                // Task was cancelled, don't save
                return
            }

            // Perform the save if not cancelled
            guard !Task.isCancelled else { return }
            self?.performSave()
        }
    }

    private func performSave() {
        var settings = settingsService.load()
        settings.privacy.collectAnonymousStats = collectAnonymousStats
        settings.privacy.storagePolicy = storagePolicy
        settings.privacy.dataRetentionDays = dataRetentionDays
        settings.privacy.storeHistory = storeHistory

        do {
            try settingsService.save(settings)
        } catch {
            // Log error but don't crash
            AppLogger.service.error("Failed to save privacy settings: \(error.localizedDescription)")
        }
    }
}

// MARK: - Previews

#Preview("Privacy Section") {
    PrivacySection(viewModel: PrivacySectionViewModel())
        .frame(width: 320)
        .padding()
}

#Preview("Privacy Section - Keep History") {
    let vm = PrivacySectionViewModel()
    vm.storagePolicy = .persistent
    return PrivacySection(viewModel: vm)
        .frame(width: 320)
        .padding()
}
