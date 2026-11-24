import SwiftUI
import WidgetKit

// MARK: - UI V2 Colour Tokens (widget target)

/// UI V2 palette for the widget extension (docs/superpowers/specs/2026-11-24-ui-v2-redesign-design.md §3).
///
/// Each token is a colour set in this target's `Assets.xcassets/V2` with Any and
/// Dark appearances, copied from the app's catalog. The widget is a separate
/// compile target, so it cannot read the app's `Color.V2`; names match so the two
/// stay easy to compare.
extension Color {
    enum V2 {
        static let bg = Color("V2Bg")
        static let surface = Color("V2Surface")
        static let surface2 = Color("V2Surface2")
        static let surface3 = Color("V2Surface3")

        static let ink = Color("V2Ink")
        static let ink2 = Color("V2Ink2")
        static let ink3 = Color("V2Ink3")
        static let line = Color("V2Line")

        static let accent = Color("V2Accent")
        static let accentSoft = Color("V2AccentSoft")

        /// Companion tints: backgrounds only, never text.
        enum Companion {
            static let ripple = Color("V2Ripple")
            static let blossom = Color("V2Blossom")
            static let ember = Color("V2Ember")
            static let zephyr = Color("V2Zephyr")
            static let lumi = Color("V2Lumi")
        }
    }
}

// MARK: - Tier Colours

extension StressCategory {
    /// Tier text colour: passes 4.5:1 on `surface` in both appearances.
    var color: Color {
        switch self {
        case .relaxed: return Color("V2TierRelaxed")
        case .mild: return Color("V2TierMild")
        case .moderate: return Color("V2TierElevated")
        case .high: return Color("V2TierHigh")
        case .severe: return Color("V2TierSevere")
        }
    }

    /// Fill colour for shapes, arcs and bars. Text uses `color`.
    var fillColor: Color {
        switch self {
        case .relaxed: return Color("V2TierRelaxedFill")
        case .mild: return Color("V2TierMildFill")
        case .moderate: return Color("V2TierElevatedFill")
        case .high: return Color("V2TierHighFill")
        case .severe: return Color("V2TierSevereFill")
        }
    }
}

// MARK: - Rendering Mode

extension WidgetRenderingMode {
    /// Colour carries meaning only in full colour. In the tinted (accented) and
    /// vibrant (Lock Screen) modes the system flattens colour, so tier shape and
    /// name carry the tier and text falls back to `.primary` / `.secondary`.
    var showsTierColor: Bool { self == .fullColor }
}

// MARK: - Type

extension Font {
    /// Rounded, tabular numerals for scores (same as the app's `Font.v2Number`).
    static func v2Number(_ style: Font.TextStyle, weight: Font.Weight = .bold) -> Font {
        .system(style, design: .rounded).weight(weight).monospacedDigit()
    }
}
