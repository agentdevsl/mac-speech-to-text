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

    // MARK: - Liquid Glass Palette

    /// Deep glass tint - rich blue-violet undertone
    /// Hex: #1a1a2e
    static let liquidGlassDeep = Color(hex: "1a1a2e")

    /// Mid glass tint - subtle blue-gray
    /// Hex: #2d2d44
    static let liquidGlassMid = Color(hex: "2d2d44")

    /// Light glass tint - frosted white-blue
    /// Hex: #e8eaf6
    static let liquidGlassLight = Color(hex: "e8eaf6")

    /// Glass shadow - deep blue-black for depth
    /// Hex: #0d0d1a
    static let liquidGlassShadow = Color(hex: "0d0d1a")

    // MARK: - Refined Glass Palette (Apple Liquid Glass Inspired)

    /// Primary glass color - soft ice blue (barely perceptible)
    /// Hex: #E8F4FC
    static let liquidGlassPrimary = Color(hex: "E8F4FC")

    /// Secondary glass color - cool silver
    /// Hex: #F0F2F5
    static let liquidGlassSecondary = Color(hex: "F0F2F5")

    /// Glass accent - single blue accent for highlights
    /// Hex: #667eea
    static let liquidGlassAccent = Color(hex: "667eea")

    // MARK: - Legacy Prismatic (Mapped to Refined Palette)

    /// @deprecated Use liquidGlassAccent or white with opacity
    static let liquidPrismaticPink = liquidGlassAccent.opacity(0.8)

    /// @deprecated Use liquidGlassAccent
    static let liquidPrismaticPurple = liquidGlassAccent

    /// @deprecated Use liquidGlassAccent
    static let liquidPrismaticBlue = liquidGlassAccent

    /// @deprecated Use liquidGlassPrimary
    static let liquidPrismaticCyan = liquidGlassPrimary

    /// @deprecated Use liquidGlassPrimary
    static let liquidPrismaticGreen = liquidGlassPrimary

    /// @deprecated Use amberPrimary
    static let liquidPrismaticYellow = amberPrimary

    /// @deprecated Use amberBright
    static let liquidPrismaticOrange = amberBright

    // MARK: - Liquid Recording States

    /// Recording core - intense warm red
    /// Hex: #ff4757
    static let liquidRecordingCore = Color(hex: "ff4757")

    /// Recording mid - soft coral
    /// Hex: #ff6b81
    static let liquidRecordingMid = Color(hex: "ff6b81")

    /// Recording outer - pale rose glow
    /// Hex: #ff8a9b
    static let liquidRecordingOuter = Color(hex: "ff8a9b")

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

    // MARK: - Refined Light Mode Palette ("Warm Burnished")
    // Designed for WCAG AA contrast compliance while maintaining warmth

    // MARK: Light Mode - Burnished Amber (High Contrast Icons)

    /// Rich honey amber for light mode icons - 4.5:1 contrast on white
    /// Hex: #8B6914 (burnished gold)
    static let burnishedAmber = Color(hex: "8B6914")

    /// Darker honey for hover/pressed states in light mode
    /// Hex: #705410
    static let burnishedAmberDark = Color(hex: "705410")

    /// Warm bronze for secondary icons in light mode
    /// Hex: #7A6B52
    static let warmBronze = Color(hex: "7A6B52")

    // MARK: Light Mode - Enhanced Borders & Surfaces

    /// Visible card border for light mode - warm taupe
    /// Hex: #C9C3BA
    static let lightCardBorder = Color(hex: "C9C3BA")

    /// Subtle inner shadow border for depth
    /// Hex: #E8E4DE
    static let lightInnerBorder = Color(hex: "E8E4DE")

    /// Card shadow color for light mode - warm brown tint
    static let lightCardShadow = Color(hex: "8B7355").opacity(0.12)

    /// Elevated card background with subtle warmth
    /// Hex: #FFFFFE
    static let lightCardSurface = Color(hex: "FFFFFE")

    /// Recessed background for contrast with cards
    /// Hex: #F7F4F0
    static let lightRecessedBg = Color(hex: "F7F4F0")

    // MARK: Light Mode - Enhanced Text

    /// Secondary text with better contrast for light mode
    /// Hex: #5A5754 (4.7:1 contrast on white)
    static let lightTextSecondary = Color(hex: "5A5754")

    /// Tertiary text, still readable in light mode
    /// Hex: #6E6B67 (3.5:1 contrast - passes for large text)
    static let lightTextTertiary = Color(hex: "6E6B67")

    /// Muted but visible placeholder text
    /// Hex: #8A8682
    static let lightTextMuted = Color(hex: "8A8682")

    // MARK: - Adaptive UI Colors (Light/Dark Mode Aware)

    /// Adaptive card background - pure white in light, dark gray in dark
    static let cardBackgroundAdaptive = adaptive(
        light: lightCardSurface,
        dark: Color(white: 0.15)
    )

    /// Adaptive card border - clearly visible in both modes
    static let cardBorderAdaptive = adaptive(
        light: lightCardBorder,
        dark: Color.white.opacity(0.12)
    )

    /// Adaptive subtle border - inner borders and dividers
    static let subtleBorderAdaptive = adaptive(
        light: lightInnerBorder,
        dark: Color.white.opacity(0.08)
    )

    /// Adaptive icon color - burnished amber in light, bright amber in dark
    static let iconPrimaryAdaptive = adaptive(
        light: burnishedAmber,
        dark: amberPrimary
    )

    /// Adaptive secondary icon - bronze in light, muted amber in dark
    static let iconSecondaryAdaptive = adaptive(
        light: warmBronze,
        dark: amberDark
    )

    /// Adaptive secondary background - recessed surfaces
    static let secondaryBackgroundAdaptive = adaptive(
        light: lightRecessedBg,
        dark: Color(white: 0.12)
    )

    /// Adaptive tertiary text - readable in both modes
    static let textTertiaryAdaptive = adaptive(
        light: lightTextTertiary,
        dark: Color(hex: "9C9A97")
    )

    /// Adaptive secondary text - clear in both modes
    static let textSecondaryAdaptive = adaptive(
        light: lightTextSecondary,
        dark: Color(hex: "A8A5A2")
    )

    /// Adaptive muted text for hints and placeholders
    static let textMutedAdaptive = adaptive(
        light: lightTextMuted,
        dark: Color(hex: "A0A0A0")
    )

    /// Adaptive card shadow
    static let cardShadowAdaptive = adaptive(
        light: lightCardShadow,
        dark: Color.black.opacity(0.3)
    )

    /// Adaptive selection/focus background
    static let selectionBackgroundAdaptive = adaptive(
        light: Color(hex: "FFF8E7"),  // Warm cream highlight
        dark: amberPrimary.opacity(0.15)
    )

    /// Adaptive selection border
    static let selectionBorderAdaptive = adaptive(
        light: burnishedAmber.opacity(0.4),
        dark: amberPrimary.opacity(0.5)
    )
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
