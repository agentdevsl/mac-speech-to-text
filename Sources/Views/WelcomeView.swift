// WelcomeView.swift
// macOS Local Speech-to-Text Application
//
// Phase 2.2: Single-screen WelcomeView replacing 5-step onboarding wizard
// Warm Minimalism design with frosted glass, amber accents, spring animations

import SwiftUI

/// WelcomeView provides a single-screen onboarding experience
struct WelcomeView: View {
    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State var viewModel: WelcomeViewModel

    /// Entry animation state
    @State private var isVisible: Bool = false

    // MARK: - Initialization

    init(viewModel: WelcomeViewModel = WelcomeViewModel()) {
        self._viewModel = State(initialValue: viewModel)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 32) {
            headerSection
            microphoneSection
            outputPreviewSection
            footerSection
        }
        .padding(40)
        .frame(width: 520, height: 480)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        .scaleEffect(isVisible ? 1.0 : 0.9)
        .opacity(isVisible ? 1.0 : 0.0)
        .onAppear {
            // Spring animation on appear
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                isVisible = true
            }
            // Start phrase cycling animation
            viewModel.startPhraseAnimation()
        }
        .onDisappear {
            viewModel.stopPhraseAnimation()
            Task {
                await viewModel.stopMicrophoneTest()
            }
        }
        .accessibilityIdentifier("welcomeView")
    }

    // MARK: - Header Section

    /// App icon + "Speech to Text" + tagline
    private var headerSection: some View {
        VStack(spacing: 12) {
            // App icon
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color("AmberPrimary", bundle: nil))
                .symbolEffect(.pulse)
                .accessibilityIdentifier("welcomeIcon")

            // App name
            Text("Speech to Text")
                .font(.largeTitle)
                .fontWeight(.bold)
                .accessibilityIdentifier("welcomeTitle")
                .accessibilityAddTraits(.isHeader)

            // Tagline
            Text("Local, Private, Fast")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Speech to Text. Local, Private, Fast.")
    }

    // MARK: - Microphone Section

    /// Permission card or test interface based on permission state
    private var microphoneSection: some View {
        VStack(spacing: 16) {
            if viewModel.isPermissionGranted {
                // Show microphone test interface
                microphoneTestView
            } else {
                // Show permission request
                microphonePermissionView
            }
        }
        .padding(20)
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    viewModel.isPermissionGranted ? Color.green.opacity(0.3) : Color.gray.opacity(0.2),
                    lineWidth: 1
                )
        )
        .accessibilityIdentifier("microphoneSection")
    }

    /// Permission request view
    private var microphonePermissionView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color("AmberPrimary", bundle: nil))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Microphone Access")
                        .font(.headline)
                    Text("Required to capture your voice")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Button {
                Task {
                    await viewModel.requestMicrophonePermission()
                }
            } label: {
                Text("Grant Microphone Access")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color("AmberPrimary", bundle: nil))
            .accessibilityIdentifier("grantMicrophoneButton")

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    /// Microphone test view with live waveform
    private var microphoneTestView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.green)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Microphone Ready")
                        .font(.headline)
                    Text(viewModel.isTesting ? "Speak to test..." : "Tap to test your microphone")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    Task {
                        await viewModel.toggleMicrophoneTest()
                    }
                } label: {
                    Image(systemName: viewModel.isTesting ? "stop.circle.fill" : "play.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(viewModel.isTesting ? .red : Color("AmberPrimary", bundle: nil))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("testMicrophoneButton")
                .accessibilityLabel(viewModel.isTesting ? "Stop microphone test" : "Start microphone test")
            }

            // Waveform visualization
            if viewModel.isTesting {
                WaveformView(audioLevel: viewModel.audioLevel)
                    .frame(height: 50)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.isTesting)
    }

    // MARK: - Output Preview Section

    /// Sample text cycling with typing animation
    private var outputPreviewSection: some View {
        VStack(spacing: 8) {
            Text("What you'll get:")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 0) {
                Text(viewModel.displayedText)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.primary)

                // Blinking cursor
                Rectangle()
                    .fill(Color("AmberPrimary", bundle: nil))
                    .frame(width: 2, height: 16)
                    .opacity(viewModel.displayedCharacterCount < viewModel.samplePhrases[viewModel.currentPhraseIndex].count ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: true)

                Spacer()
            }
            .frame(height: 44)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .accessibilityIdentifier("outputPreviewSection")
        .accessibilityLabel("Sample output: \(viewModel.displayedText)")
    }

    // MARK: - Footer Section

    /// Keyboard shortcut hint + Get Started button
    private var footerSection: some View {
        VStack(spacing: 20) {
            // Keyboard shortcut hint
            HStack(spacing: 8) {
                Text("Press")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    KeyCapView(symbol: "\u{2318}")
                    KeyCapView(symbol: "\u{2303}")
                    KeyCapView(text: "Space")
                }

                Text("anywhere to record")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Press Command Control Space anywhere to record")

            // Get Started button
            Button {
                viewModel.complete()
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color("AmberPrimary", bundle: nil))
            .keyboardShortcut(.return)
            .accessibilityIdentifier("getStartedButton")
        }
    }
}

// MARK: - Previews

#Preview("Welcome - No Permission") {
    WelcomeViewPreview(permissionGranted: false)
}

#Preview("Welcome - Permission Granted") {
    WelcomeViewPreview(permissionGranted: true)
}

/// Preview helper with customizable permission state
private struct WelcomeViewPreview: View {
    let permissionGranted: Bool

    var body: some View {
        let mockPermissionService = MockPermissionService()
        mockPermissionService.microphoneGranted = permissionGranted

        return WelcomeView(
            viewModel: WelcomeViewModel(
                permissionService: mockPermissionService
            )
        )
        .padding(40)
        .background(Color.gray.opacity(0.2))
    }
}
