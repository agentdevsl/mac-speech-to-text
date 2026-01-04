// HomeSection.swift
// macOS Local Speech-to-Text Application
//
// Main View - Home Section
// Displays recording status, permission cards, and typing animation demo

import SwiftUI

/// HomeSection displays the main dashboard with recording status and permission overview
struct HomeSection: View {
    // MARK: - Dependencies

    let settingsService: SettingsService
    let permissionService: PermissionService

    // MARK: - State

    @State private var isPulsing: Bool = false
    @State private var microphoneGranted: Bool = false
    @State private var accessibilityGranted: Bool = false
    @State private var currentPhraseIndex: Int = 0
    @State private var displayedText: String = ""
    @State private var typingTask: Task<Void, Never>?

    // MARK: - Constants

    private let samplePhrases: [String] = [
        "Hello, this is a test...",
        "Meeting notes from today...",
        "Reminder: call the team...",
        "Quick note to self..."
    ]

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Hero section with animated mic icon
                heroSection

                // Permission status cards
                permissionCards

                // Typing animation preview
                typingPreview
            }
            .padding(24)
        }
        .accessibilityIdentifier("homeSection")
        .task {
            await refreshPermissions()
            startPulseAnimation()
            startTypingAnimation()
        }
        .onDisappear {
            typingTask?.cancel()
            typingTask = nil
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 20) {
            // Animated microphone icon with pulse effect
            ZStack {
                // Outer pulse rings
                Circle()
                    .stroke(Color.warmAmber.opacity(0.3), lineWidth: 2)
                    .frame(width: 120, height: 120)
                    .scaleEffect(isPulsing ? 1.3 : 1.0)
                    .opacity(isPulsing ? 0.0 : 0.6)

                Circle()
                    .stroke(Color.warmAmber.opacity(0.5), lineWidth: 2)
                    .frame(width: 100, height: 100)
                    .scaleEffect(isPulsing ? 1.2 : 1.0)
                    .opacity(isPulsing ? 0.0 : 0.8)

                // Main icon circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.warmAmberLight, Color.warmAmber],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.warmAmber.opacity(0.4), radius: 12, x: 0, y: 4)

                Image(systemName: "mic.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, options: .repeating, value: isPulsing)
            }
            .accessibilityIdentifier("homeMicIcon")

            // Hotkey hint
            VStack(spacing: 8) {
                Text("Press")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    KeyboardKey(symbol: "^")
                    KeyboardKey(symbol: "Shift")
                    KeyboardKey(symbol: "Space")
                }
                .accessibilityIdentifier("hotkeyDisplay")

                Text("anywhere to record")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 16)
        .accessibilityIdentifier("heroSection")
    }

    // MARK: - Permission Cards

    private var permissionCards: some View {
        VStack(spacing: 12) {
            // Microphone permission card
            PermissionStatusCard(
                icon: "mic.fill",
                title: "Microphone",
                isGranted: microphoneGranted,
                actionLabel: "Grant Access",
                onAction: requestMicrophonePermission
            )
            .accessibilityIdentifier("microphonePermissionCard")

            // Accessibility permission card
            PermissionStatusCard(
                icon: "hand.raised.fill",
                title: "Accessibility",
                isGranted: accessibilityGranted,
                actionLabel: "Enable",
                onAction: requestAccessibilityPermission
            )
            .accessibilityIdentifier("accessibilityPermissionCard")
        }
        .padding(.horizontal, 4)
        .accessibilityIdentifier("permissionCards")
    }

    // MARK: - Typing Preview

    private var typingPreview: some View {
        VStack(spacing: 12) {
            Text("Preview")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(1)

            HStack(spacing: 0) {
                Text(displayedText)
                    .font(.system(.body, design: .default))
                    .foregroundStyle(.primary)

                // Typing cursor
                Rectangle()
                    .fill(Color.warmAmber)
                    .frame(width: 2, height: 18)
                    .opacity(isPulsing ? 1.0 : 0.3)
            }
            .frame(minHeight: 24)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.warmGray.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .accessibilityIdentifier("typingPreview")
    }

    // MARK: - Private Methods

    private func refreshPermissions() async {
        microphoneGranted = await permissionService.checkMicrophonePermission()
        accessibilityGranted = permissionService.checkAccessibilityPermission()
    }

    private func startPulseAnimation() {
        withAnimation(
            .easeInOut(duration: 1.5)
            .repeatForever(autoreverses: true)
        ) {
            isPulsing = true
        }
    }

    private func startTypingAnimation() {
        // Cancel any existing typing task
        typingTask?.cancel()
        displayedText = ""
        let phrase = samplePhrases[currentPhraseIndex]

        // Use cancellable Task for animation loop
        typingTask = Task { @MainActor in
            for char in phrase {
                guard !Task.isCancelled else { return }
                displayedText.append(char)
                try? await Task.sleep(nanoseconds: 80_000_000) // 80ms per character
            }

            // Pause at the end, then move to next phrase
            guard !Task.isCancelled else { return }
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 second pause
            guard !Task.isCancelled else { return }
            currentPhraseIndex = (currentPhraseIndex + 1) % samplePhrases.count
            startTypingAnimation()
        }
    }

    private func requestMicrophonePermission() {
        Task {
            do {
                try await permissionService.requestMicrophonePermission()
                await refreshPermissions()
            } catch {
                // Permission denied - user needs to grant in System Settings
                AppLogger.system.warning("Microphone permission denied")
            }
        }
    }

    private func requestAccessibilityPermission() {
        Task {
            do {
                try permissionService.requestAccessibilityPermission()
            } catch {
                // Opens System Settings for user to grant permission
                AppLogger.system.info("Opening System Settings for accessibility permission")
            }
            // Start polling for permission grant
            await permissionService.pollForAccessibilityPermission(
                interval: 1.0,
                maxDuration: 60.0
            ) {
                Task { @MainActor in
                    accessibilityGranted = true
                }
            }
        }
    }
}

// MARK: - Keyboard Key View

/// A styled keyboard key for hotkey display
private struct KeyboardKey: View {
    let symbol: String

    var body: some View {
        Text(symbol)
            .font(.system(.caption, design: .rounded, weight: .medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.warmGray)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.warmGrayMedium, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
    }
}

// MARK: - Permission Status Card

/// Compact permission status card for the home section
private struct PermissionStatusCard: View {
    let icon: String
    let title: String
    let isGranted: Bool
    let actionLabel: String
    let onAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(isGranted ? Color.successGreen : Color.warmAmber)
                .frame(width: 32)

            // Title
            Text(title)
                .font(.body)
                .foregroundStyle(.primary)

            Spacer()

            // Status or action button
            if isGranted {
                Label("Ready", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(Color.successGreen)
            } else {
                Button(action: onAction) {
                    HStack(spacing: 4) {
                        Text(actionLabel)
                        Image(systemName: "arrow.right")
                    }
                    .font(.caption)
                    .foregroundStyle(Color.warmAmber)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isGranted ? Color.successGreen.opacity(0.3) : Color.warmGrayMedium.opacity(0.5),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Previews

#Preview("Home Section - All Granted") {
    HomeSection(
        settingsService: SettingsService(),
        permissionService: PermissionService()
    )
    .frame(width: 380, height: 600)
}

#Preview("Home Section - Dark Mode") {
    HomeSection(
        settingsService: SettingsService(),
        permissionService: PermissionService()
    )
    .frame(width: 380, height: 600)
    .preferredColorScheme(.dark)
}
