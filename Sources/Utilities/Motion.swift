import SwiftUI

/// Animation tokens for consistent motion throughout the app.
///
/// Motion follows the "Warm Minimalism" design language with spring-based
/// animations that feel natural and responsive. All animations are designed
/// to be fast enough to feel immediate while maintaining visual polish.
///
/// Usage:
/// ```swift
/// withAnimation(Motion.standard) {
///     isExpanded.toggle()
/// }
/// ```
enum Motion {
    // MARK: - Core Animations

    /// Quick animation for micro-interactions (0.2s)
    ///
    /// Use for small state changes like button presses, toggles, and hover effects.
    static let quick = Animation.spring(response: 0.2, dampingFraction: 0.8)

    /// Standard animation for most UI transitions (0.35s)
    ///
    /// The default choice for view transitions, modal presentations, and content changes.
    static let standard = Animation.spring(response: 0.35, dampingFraction: 0.75)

    /// Gentle animation for larger elements (0.5s)
    ///
    /// Use for significant layout changes or when you want a more relaxed feel.
    static let gentle = Animation.spring(response: 0.5, dampingFraction: 0.7)

    /// Bouncy animation for playful feedback (0.4s)
    ///
    /// Use sparingly for celebratory moments or to draw attention to important changes.
    static let bouncy = Animation.spring(response: 0.4, dampingFraction: 0.6)

    // MARK: - Glass Overlay Animations

    /// Glass overlay appear animation
    ///
    /// Matches the quick timing for responsive modal presentation.
    static let glassAppear = Animation.spring(response: 0.2, dampingFraction: 0.8)

    /// Glass overlay disappear - simple fade
    ///
    /// Uses ease-out for a natural deceleration as the overlay fades away.
    static let glassDisappear = Animation.easeOut(duration: 0.15)

    // MARK: - Specialized Animations

    /// Waveform bar animation - smooth and continuous
    ///
    /// Very fast linear animation for real-time audio visualization updates.
    static let waveform = Animation.linear(duration: 0.05)
}
