import SwiftUI

/// Warm Minimalism color palette extensions
extension Color {
    // MARK: - Primary Colors
    static let warmAmber = Color(red: 0.98, green: 0.75, blue: 0.38)
    static let warmAmberLight = Color(red: 1.0, green: 0.85, blue: 0.55)
    static let warmAmberDark = Color(red: 0.85, green: 0.62, blue: 0.25)

    // MARK: - Neutral Colors
    static let warmGray = Color(red: 0.95, green: 0.94, blue: 0.93)
    static let warmGrayMedium = Color(red: 0.85, green: 0.84, blue: 0.83)
    static let warmGrayDark = Color(red: 0.45, green: 0.44, blue: 0.43)

    // MARK: - Semantic Colors
    static let successGreen = Color(red: 0.42, green: 0.78, blue: 0.46)
    static let errorRed = Color(red: 0.95, green: 0.36, blue: 0.36)
    static let warningOrange = Color(red: 0.98, green: 0.65, blue: 0.25)

    // MARK: - Waveform Colors
    static let waveformActive = warmAmber
    static let waveformInactive = warmGrayMedium
    static let waveformBackground = Color.black.opacity(0.02)

    // MARK: - UI Elements
    static let modalBackground = Color(white: 1.0).opacity(0.95)
    static let modalBackgroundDark = Color(white: 0.1).opacity(0.95)
    static let cardBackground = Color.white
    static let cardBackgroundDark = Color(white: 0.15)

    // MARK: - Text Colors
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color.gray.opacity(0.6)
}

/// Dynamic color that adapts to light/dark mode
extension Color {
    static func adaptive(light: Color, dark: Color) -> Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ?
                UIColor(dark) : UIColor(light)
        })
    }
}

/// Gradients for UI elements
extension LinearGradient {
    static let warmAmberGradient = LinearGradient(
        colors: [.warmAmberLight, .warmAmber],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let neutralGradient = LinearGradient(
        colors: [.warmGray, .warmGrayMedium],
        startPoint: .top,
        endPoint: .bottom
    )
}
