import SwiftUI

// MARK: - Hex Color Initializer

extension Color {
    /// Initialize a Color from a hex string (e.g., "#FAC061" or "FAC061")
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let alpha, red, green, blue: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (alpha, red, green, blue) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (alpha, red, green, blue) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (alpha, red, green, blue) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (alpha, red, green, blue) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: Double(alpha) / 255
        )
    }
}

// MARK: - Warm Minimalism Color Palette

/// Warm Minimalism color palette extensions for the Speech-to-Text app.
/// This design system uses warm amber accents with neutral backgrounds
/// to create a friendly, accessible interface.
extension Color {

    // MARK: - Brand Amber Palette

    /// Primary amber accent color - used for main interactive elements
    /// Hex: #FAC061
    static let amberPrimary = Color(hex: "FAC061")

    /// Light amber for hover states and subtle fills
    /// Hex: #FFD98C
    static let amberLight = Color(hex: "FFD98C")

    /// Bright amber for glow effects and active states
    /// Hex: #FFAE42
    static let amberBright = Color(hex: "FFAE42")

    /// Dark amber for pressed/active states
    /// Hex: #D99E40
    static let amberDark = Color(hex: "D99E40")

    // MARK: - Legacy Amber (Deprecated - Use amberPrimary, amberLight, amberDark)

    /// @deprecated Use `amberPrimary` instead
    static let warmAmber = amberPrimary

    /// @deprecated Use `amberLight` instead
    static let warmAmberLight = amberLight

    /// @deprecated Use `amberDark` instead
    static let warmAmberDark = amberDark

    // MARK: - Semantic Colors

    /// Warm red for active recording state - not harsh, approachable
    /// Hex: #E85D5D
    static let recordingActive = Color(hex: "E85D5D")

    /// Recording pulse glow effect - recordingActive at 40% opacity
    /// Use for animated pulsing effects during recording
    static let recordingGlow = Color(hex: "E85D5D").opacity(0.4)

    /// Success green for permission granted, completed actions
    /// Hex: #5CB85C
    static let successGreen = Color(hex: "5CB85C")

    /// Soft blue for informational messages and hints
    /// Hex: #5B9BD5
    static let info = Color(hex: "5B9BD5")

    /// Error red for error states and critical alerts
    /// Hex: #E85D5D (same as recordingActive for palette consistency)
    static let errorRed = Color(hex: "E85D5D")

    /// Warning orange for caution states
    /// Hex: #FAC061 (uses amber primary for warmth)
    static let warningOrange = amberPrimary

    // MARK: - Warm Neutrals

    /// Warm white background - primary app background
    /// Hex: #FDFBF9
    static let backgroundPrimary = Color(hex: "FDFBF9")

    /// Warm off-white for cards and secondary surfaces
    /// Hex: #F5F3F1
    static let backgroundSecondary = Color(hex: "F5F3F1")

    /// Warm black for primary text - softer than pure black
    /// Hex: #1C1B1A
    static let textPrimary = Color(hex: "1C1B1A")

    /// Medium warm gray for secondary text and descriptions
    /// Hex: #6B6966
    static let textSecondary = Color(hex: "6B6966")

    /// Light warm gray for hints and tertiary text
    /// Hex: #9C9A97
    static let textTertiary = Color(hex: "9C9A97")

    // MARK: - Legacy Neutral Colors (For Compatibility)

    /// Light warm gray - use for subtle backgrounds
    static let warmGray = backgroundSecondary

    /// Medium warm gray - use for borders and dividers
    static let warmGrayMedium = Color(hex: "D4D2D0")

    /// Dark warm gray - use for secondary icons
    static let warmGrayDark = textSecondary

    // MARK: - Waveform Colors

    /// Active waveform color when recording
    static let waveformActive = amberPrimary

    /// Inactive waveform color when idle
    static let waveformInactive = warmGrayMedium

    /// Subtle waveform background
    static let waveformBackground = Color.black.opacity(0.02)

    // MARK: - UI Element Colors

    /// Modal background with frosted glass effect
    static let modalBackground = backgroundPrimary.opacity(0.95)

    /// Dark mode modal background
    static let modalBackgroundDark = Color(white: 0.1).opacity(0.95)

    /// Card surface color
    static let cardBackground = Color.white

    /// Dark mode card surface
    static let cardBackgroundDark = Color(white: 0.15)
}

// MARK: - Adaptive Colors

/// Dynamic color that adapts to light/dark mode
extension Color {
    /// Creates a color that automatically switches between light and dark variants
    /// - Parameters:
    ///   - light: Color to use in light mode
    ///   - dark: Color to use in dark mode
    /// - Returns: An adaptive color
    static func adaptive(light: Color, dark: Color) -> Color {
        #if os(macOS)
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ?
                NSColor(dark) : NSColor(light)
        })
        #else
        Color(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ?
                UIColor(dark) : UIColor(light)
        })
        #endif
    }
}

// MARK: - Gradients

/// Gradients for UI elements following the Warm Minimalism aesthetic
extension LinearGradient {
    /// Primary amber gradient for buttons and highlights
    static let warmAmberGradient = LinearGradient(
        colors: [.amberLight, .amberPrimary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Bright amber gradient for active/glowing states
    static let amberGlowGradient = LinearGradient(
        colors: [.amberBright, .amberPrimary],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Neutral gradient for subtle backgrounds
    static let neutralGradient = LinearGradient(
        colors: [.backgroundPrimary, .backgroundSecondary],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Recording state gradient
    static let recordingGradient = LinearGradient(
        colors: [.recordingActive, .recordingActive.opacity(0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
