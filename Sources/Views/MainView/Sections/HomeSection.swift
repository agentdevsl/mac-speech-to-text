// HomeSection.swift
// macOS Local Speech-to-Text Application
//
// Main View - Home Section
// Displays recording status, permission cards, and typing animation demo
// Glassmorphism design with frosted glass effects

import SwiftUI

// MARK: - Permission Card Focus

/// Enumeration for focusable permission cards
enum PermissionCardFocus: Hashable {
    case microphone
    case accessibility
}

/// HomeSection displays the main dashboard with recording status and permission overview
/// Features glassmorphism design with frosted glass cards and glowing accents
struct HomeSection: View {
    // MARK: - Environment

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Dependencies

    let settingsService: SettingsService
    let permissionService: PermissionService

    // MARK: - Focus State

    @FocusState private var focusedCard: PermissionCardFocus?
    @Namespace private var homeFocusScope

    // MARK: - State

    @State private var isPulsing: Bool = false
    @State private var microphoneGranted: Bool = false
    @State private var accessibilityGranted: Bool = false
    @State private var currentPhraseIndex: Int = 0
    @State private var displayedText: String = ""
    @State private var typingTask: Task<Void, Never>?
    @State private var settings: UserSettings

    // MARK: - Initialization

    init(settingsService: SettingsService, permissionService: PermissionService) {
        self.settingsService = settingsService
        self.permissionService = permissionService
        self._settings = State(initialValue: settingsService.load())
    }

    // Loading & Error States
    @State private var isMicrophoneLoading: Bool = false
    @State private var isAccessibilityPolling: Bool = false
    @State private var microphoneError: String?
    @State private var accessibilityError: String?

    // Task references for cancellation
    @State private var microphonePermissionTask: Task<Void, Never>?
    @State private var accessibilityPermissionTask: Task<Void, Never>?

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
                    .padding(.top, 20)

                // Permission status cards in glass containers
                permissionCards

                // Hotkey hint (shown after permissions are set up)
                hotkeyHint

                // Typing animation preview
                typingPreview
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
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
            microphonePermissionTask?.cancel()
            microphonePermissionTask = nil
            accessibilityPermissionTask?.cancel()
            accessibilityPermissionTask = nil
        }
        .focusScope(homeFocusScope)
        .onKeyPress(.tab) {
            handleTabNavigation()
            return .handled
        }
        .onKeyPress(.return) {
            if focusedCard != nil {
                handleReturnKey()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.space) {
            if focusedCard != nil {
                handleReturnKey()
                return .handled
            }
            return .ignored
        }
        .onAppear {
            // Set initial focus to microphone card if no permissions granted
            if !microphoneGranted {
                focusedCard = .microphone
            } else if !accessibilityGranted {
                focusedCard = .accessibility
            }
        }
    }

    // MARK: - Keyboard Navigation

    private func handleTabNavigation() {
        switch focusedCard {
        case .none:
            focusedCard = .microphone
        case .microphone:
            focusedCard = .accessibility
        case .accessibility:
            focusedCard = .microphone
        }
    }

    private func handleReturnKey() {
        switch focusedCard {
        case .microphone:
            if !microphoneGranted {
                requestMicrophonePermission()
            }
        case .accessibility:
            if !accessibilityGranted {
                requestAccessibilityPermission()
            }
        case .none:
            break
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 24) {
            // Animated microphone icon with glow effect
            ZStack {
                // Outer pulse rings
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.amberPrimary.opacity(0.4),
                                    Color.amberPrimary.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                        .frame(width: CGFloat(80 + index * 24), height: CGFloat(80 + index * 24))
                        .scaleEffect(isPulsing ? 1.2 : 1.0)
                        .opacity(isPulsing ? 0.0 : 0.8 - Double(index) * 0.2)
                        .animation(
                            .easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                            value: isPulsing
                        )
                }

                // Glass card background
                Circle()
                    .fill(
                        colorScheme == .dark
                            ? Color.white.opacity(0.08)
                            : Color.white.opacity(0.9)
                    )
                    .frame(width: 90, height: 90)
                    .background(.ultraThinMaterial, in: Circle())
                    .shadow(color: Color.amberPrimary.opacity(0.3), radius: 20, x: 0, y: 5)

                // Main icon with gradient
                Image(systemName: "mic.circle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.amberLight, .amberPrimary, .amberDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolEffect(.pulse, options: .repeating, value: isPulsing)
            }
            .frame(height: 160)
            .accessibilityIdentifier("homeMicIcon")
        }
        .accessibilityIdentifier("heroSection")
    }

    // MARK: - Hotkey Hint

    private var hotkeyHint: some View {
        VStack(spacing: 10) {
            Text("Press")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                ForEach(settings.hotkey.modifiers, id: \.self) { modifier in
                    GlassKeyboardKey(symbol: modifier.displayName)
                }
                GlassKeyboardKey(symbol: hotkeyKeyName)
            }
            .accessibilityIdentifier("hotkeyDisplay")

            Text("anywhere to record")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.white.opacity(0.7))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
        .accessibilityIdentifier("hotkeyHint")
    }

    /// Display name for the configured hotkey
    private var hotkeyKeyName: String {
        switch settings.hotkey.keyCode {
        case 49: return "Space"
        case 36: return "Return"
        case 53: return "Escape"
        case 51: return "Delete"
        default: return "Key \(settings.hotkey.keyCode)"
        }
    }

    // MARK: - Permission Cards

    private var permissionCards: some View {
        VStack(spacing: 14) {
            // Section label
            HStack {
                Text("PERMISSIONS")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .tracking(1.5)

                Spacer()

                if allPermissionsGranted {
                    Label("All Ready", systemImage: "checkmark.seal.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.successGreen)
                }
            }
            .padding(.horizontal, 4)

            // Microphone permission card
            GlassPermissionCard(
                icon: "mic.fill",
                title: "Microphone",
                subtitle: "Required for voice recording",
                isGranted: microphoneGranted,
                isLoading: isMicrophoneLoading,
                errorMessage: microphoneError,
                actionLabel: "Grant Access",
                isFocused: focusedCard == .microphone,
                colorScheme: colorScheme,
                onAction: requestMicrophonePermission,
                onDismissError: { microphoneError = nil }
            )
            .focusable()
            .focused($focusedCard, equals: .microphone)
            .accessibilityIdentifier("microphonePermissionCard")

            // Accessibility permission card
            GlassPermissionCard(
                icon: "hand.raised.fill",
                title: "Accessibility",
                subtitle: "Required for text insertion",
                isGranted: accessibilityGranted,
                isLoading: isAccessibilityPolling,
                errorMessage: accessibilityError,
                actionLabel: "Enable",
                isFocused: focusedCard == .accessibility,
                colorScheme: colorScheme,
                onAction: requestAccessibilityPermission,
                onDismissError: { accessibilityError = nil }
            )
            .focusable()
            .focused($focusedCard, equals: .accessibility)
            .accessibilityIdentifier("accessibilityPermissionCard")
        }
        .accessibilityIdentifier("permissionCards")
    }

    private var allPermissionsGranted: Bool {
        microphoneGranted && accessibilityGranted
    }

    // MARK: - Typing Preview

    private var typingPreview: some View {
        VStack(spacing: 12) {
            HStack {
                Text("PREVIEW")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .tracking(1.5)
                Spacer()
            }
            .padding(.horizontal, 4)

            // Glass typing preview container
            HStack(spacing: 0) {
                Text(displayedText)
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundStyle(.primary)

                // Animated cursor
                Rectangle()
                    .fill(Color.amberPrimary)
                    .frame(width: 2, height: 20)
                    .opacity(isPulsing ? 1.0 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                        value: isPulsing
                    )
            }
            .frame(minHeight: 28)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.8))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                colorScheme == .dark
                                    ? Color.white.opacity(0.1)
                                    : Color.black.opacity(0.05),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 2)
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
        typingTask?.cancel()
        displayedText = ""
        let phrase = samplePhrases[currentPhraseIndex]

        typingTask = Task { @MainActor in
            for char in phrase {
                guard !Task.isCancelled else { return }
                displayedText.append(char)
                try? await Task.sleep(nanoseconds: 80_000_000)
            }

            guard !Task.isCancelled else { return }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            currentPhraseIndex = (currentPhraseIndex + 1) % samplePhrases.count
            startTypingAnimation()
        }
    }

    private func requestMicrophonePermission() {
        microphoneError = nil
        isMicrophoneLoading = true

        microphonePermissionTask?.cancel()
        microphonePermissionTask = Task { @MainActor in
            do {
                try await permissionService.requestMicrophonePermission()
                guard !Task.isCancelled else { return }
                await refreshPermissions()
                isMicrophoneLoading = false
            } catch {
                guard !Task.isCancelled else { return }
                isMicrophoneLoading = false
                microphoneError = "Permission denied. Please grant access in System Settings."
                AppLogger.system.warning("Microphone permission denied")
            }
        }
    }

    private func requestAccessibilityPermission() {
        accessibilityError = nil
        isAccessibilityPolling = true

        accessibilityPermissionTask?.cancel()
        accessibilityPermissionTask = Task { @MainActor in
            do {
                try permissionService.requestAccessibilityPermission()
            } catch {
                AppLogger.system.info("Opening System Settings for accessibility permission")
            }

            var callbackInvoked = false

            await permissionService.pollForAccessibilityPermission(
                interval: 1.0,
                maxDuration: 60.0
            ) {
                // Callback is already @MainActor, no nested Task needed
                callbackInvoked = true
                self.accessibilityGranted = true
                self.isAccessibilityPolling = false
            }

            guard !Task.isCancelled else { return }

            if !callbackInvoked {
                isAccessibilityPolling = false
                if !accessibilityGranted {
                    accessibilityError = "Permission not granted. Please enable in System Settings."
                }
            }
        }
    }
}

// MARK: - Glass Keyboard Key

/// A glassmorphism styled keyboard key
private struct GlassKeyboardKey: View {
    let symbol: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(symbol)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.white)
                    .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.1),
                        lineWidth: 1
                    )
            )
    }
}

// MARK: - Glass Permission Card

/// Glassmorphism permission status card
private struct GlassPermissionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let isGranted: Bool
    let isLoading: Bool
    let errorMessage: String?
    let actionLabel: String
    let isFocused: Bool
    let colorScheme: ColorScheme
    let onAction: () -> Void
    let onDismissError: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main card content
            HStack(spacing: 14) {
                // Icon with status glow
                ZStack {
                    Circle()
                        .fill(iconBackgroundColor)
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(iconColor)
                }
                .shadow(color: iconGlowColor, radius: 8, x: 0, y: 2)

                // Title and subtitle
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Status or action button
                statusContent
            }
            .padding(16)

            // Error message row (if present)
            if let errorMessage = errorMessage {
                errorRow(message: errorMessage)
            }
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(cardBorder)
        .shadow(color: shadowColor, radius: 12, x: 0, y: 4)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isGranted)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isLoading)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: errorMessage != nil)
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }

    // MARK: - Computed Properties

    private var iconColor: Color {
        if errorMessage != nil {
            return Color.errorRed
        } else if isGranted {
            return Color.successGreen
        } else {
            return Color.amberPrimary
        }
    }

    private var iconBackgroundColor: Color {
        if errorMessage != nil {
            return Color.errorRed.opacity(0.15)
        } else if isGranted {
            return Color.successGreen.opacity(0.15)
        } else {
            return Color.amberPrimary.opacity(0.15)
        }
    }

    private var iconGlowColor: Color {
        if errorMessage != nil {
            return Color.errorRed.opacity(0.2)
        } else if isGranted {
            return Color.successGreen.opacity(0.2)
        } else {
            return Color.amberPrimary.opacity(0.2)
        }
    }

    private var cardBackground: some View {
        Group {
            if isFocused {
                Color.amberPrimary.opacity(0.08)
            } else if colorScheme == .dark {
                Color.white.opacity(0.06)
            } else {
                Color.white.opacity(0.85)
            }
        }
        .background(.ultraThinMaterial)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 14)
            .stroke(borderColor, lineWidth: isFocused ? 2 : 1)
    }

    private var borderColor: Color {
        if isFocused {
            return Color.amberPrimary.opacity(0.6)
        } else if errorMessage != nil {
            return Color.errorRed.opacity(0.4)
        } else if isGranted {
            return Color.successGreen.opacity(0.3)
        } else {
            return colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05)
        }
    }

    private var shadowColor: Color {
        if isGranted {
            return Color.successGreen.opacity(0.1)
        } else if errorMessage != nil {
            return Color.errorRed.opacity(0.1)
        } else {
            return Color.black.opacity(0.05)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var statusContent: some View {
        if isLoading {
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Checking...")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Checking permission status")
        } else if isGranted {
            Label("Ready", systemImage: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.successGreen)
        } else if errorMessage != nil {
            Button(action: onAction) {
                HStack(spacing: 4) {
                    Text("Retry")
                    Image(systemName: "arrow.clockwise")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.amberPrimary)
            }
            .buttonStyle(.plain)
        } else {
            Button(action: onAction) {
                HStack(spacing: 4) {
                    Text(actionLabel)
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.amberLight, .amberPrimary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .shadow(color: Color.amberPrimary.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }
    }

    private func errorRow(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(Color.errorRed)

            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(Color.errorRed)
                .lineLimit(2)

            Spacer()

            Button {
                onDismissError()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss error")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.errorRed.opacity(0.1))
    }
}

// MARK: - Previews

#Preview("Home Section - All Granted") {
    HomeSection(
        settingsService: SettingsService(),
        permissionService: PermissionService()
    )
    .frame(width: 500, height: 650)
}

#Preview("Home Section - Dark Mode") {
    HomeSection(
        settingsService: SettingsService(),
        permissionService: PermissionService()
    )
    .frame(width: 500, height: 650)
    .preferredColorScheme(.dark)
}
