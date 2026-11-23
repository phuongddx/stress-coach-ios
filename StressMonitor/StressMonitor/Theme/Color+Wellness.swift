import SwiftUI

// MARK: - Wellness Color Palette
extension Color {
    /// Wellness color palette based on calm blues and health greens
    struct Wellness {
        // MARK: - Primary Colors

        /// Calm Blue - Healthcare trust color
        static let calmBlue = Color(
            light: Color(hex: "#0891B2"), // Cyan-600
            dark: Color(hex: "#22D3EE")   // Cyan-400
        )

        /// Health Green - Wellness/growth
        static let healthGreen = Color(
            light: Color(hex: "#10B981"), // Emerald-500
            dark: Color(hex: "#34D399")   // Emerald-400
        )

        /// Gentle Purple - Mindfulness
        static let gentlePurple = Color(
            light: Color(hex: "#8B5CF6"), // Violet-500
            dark: Color(hex: "#A78BFA")   // Violet-400
        )

        // MARK: - Background Colors

        /// Pure black for OLED dark mode
        static let backgroundDark = Color(hex: "#000000")

        /// Light mode background
        static let backgroundLight = Color(hex: "#F2F2F7")

        /// Card surface in dark mode
        static let surfaceDark = Color(hex: "#1C1C1E")

        /// Card surface in light mode
        static let surfaceLight = Color.white

        // MARK: - Adaptive Colors

        /// Primary background that adapts to color scheme
        static let background = Color.V2.bg

        /// Surface color that adapts to color scheme
        static let surface = Color.V2.surface

        // MARK: - Adaptive UI Colors (Dashboard Redesign)

        /// Adaptive background — UI V2 canvas (`Color.V2.bg`)
        static let adaptiveBackground = Color.V2.bg

        /// Adaptive card background
        static let adaptiveCardBackground = Color.V2.surface

        /// Adaptive primary text
        static let adaptivePrimaryText = Color.V2.ink

        /// Adaptive secondary text
        static let adaptiveSecondaryText = Color.V2.ink2

        // MARK: - Fixed Accent Colors

        /// Elevated badge accent (yellow-gold)
        static let elevatedBadge = Color(hex: "#FDD57A")

        /// Ripple blue card accent
        static let tealCard = Color(hex: "#4FC3F7")

        /// Exercise cyan accent
        static let exerciseCyan = Color(hex: "#86CECD")

        /// Sleep purple accent
        static let sleepPurple = Color(hex: "#BE8BE5")

        /// Daylight yellow accent
        static let daylightYellow = Color(hex: "#FFBD42")

        /// Icon gray (from Figma)
        static let figmaIconGray = Color(hex: "#717171")

        // MARK: - Timer Colors

        /// Timer track ring color (adaptive)
        static let timerTrack = Color.V2.surface2

        // MARK: - Quick Action Colors

        /// Gratitude purple
        static let gratitudePurple = Color(hex: "#9E85C9")

        /// Mini walk blue
        static let miniWalkBlue = Color(hex: "#859DC9")

        /// Box breathing purple
        static let boxBreathingPurple = Color(hex: "#A58FC7")

        // MARK: - Insight Colors

        /// AI insight title color
        static let insightTitle = Color(hex: "#FFBF00")

        /// AI insight text color
        static let insightText = Color(hex: "#5E5E5E")
    }
}

// MARK: - Stress Level Colors with Dual Coding
extension Color {
    /// Get stress color with dual coding support (color + icon)
    /// - Parameters:
    ///   - category: The stress category
    ///   - highContrast: Whether to use high contrast variant
    /// - Returns: Color for the stress level
    static func accessibleStressColor(for category: StressCategory, highContrast: Bool = false) -> Color {
        if highContrast {
            // Increased-contrast indicator variants — each passes WCAG AA
            // (>= 3:1) on the light cream canvas
            switch category {
            case .relaxed:
                return Color(hex: "#00A000") // Darker green
            case .mild:
                return Color(hex: "#0050FF") // Darker blue
            case .moderate:
                return Color(hex: "#8A5A00") // Dark amber (matches the standard light variant)
            case .high:
                return Color(hex: "#CC0000") // Dark red
            case .severe:
                return Color(hex: "#FF3B30") // Severe tier (canonical app red)
            }
        }

        // Standard colors with WCAG AA compliance (4.5:1 ratio)
        // Delegate to StressCategory as single source of truth
        return category.color
    }
}

// MARK: - Accessibility-Aware View Modifier
struct AccessibilityContrastModifier: ViewModifier {
    @Environment(\.colorSchemeContrast) var colorSchemeContrast
    let category: StressCategory

    func body(content: Content) -> some View {
        content
            .foregroundStyle(
                Color.accessibleStressColor(
                    for: category,
                    highContrast: colorSchemeContrast == .increased
                )
            )
    }
}

extension View {
    /// Apply accessible stress color based on system contrast setting
    /// - Parameter category: The stress category
    /// - Returns: View with accessible color applied
    func accessibleStressColor(for category: StressCategory) -> some View {
        modifier(AccessibilityContrastModifier(category: category))
    }
}
