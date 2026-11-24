import SwiftUI

// MARK: - UI V2 Colour Tokens

/// UI V2 palette (docs/superpowers/specs/2026-11-24-ui-v2-redesign-design.md §3).
/// Each token is a colour set in `Assets.xcassets/V2` with Any and Dark
/// appearances, so the values live in one place.
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
        static let line2 = Color("V2Line2")

        static let accent = Color("V2Accent")
        static let onAccent = Color("V2OnAccent")
        static let accentSoft = Color("V2AccentSoft")
        static let accentTint = Color("V2AccentTint")

        static let lime = Color("V2Lime")
        static let onLime = Color("V2OnLime")
        static let limeInk = Color("V2LimeInk")

        static let plus = Color("V2Plus")
        static let plusBg = Color("V2PlusBg")
        static let plusLine = Color("V2PlusLine")

        static let danger = Color("V2Danger")
        static let dangerSoft = Color("V2DangerSoft")
        static let warnSoft = Color("V2WarnSoft")

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

// MARK: - Tier Fill + Shape

extension StressCategory {
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

    /// Text drawn on top of `fillColor` (bar labels, filled badges).
    var onFillColor: Color {
        let darkInk = Color(hex: "#0B1411")
        switch self {
        case .relaxed, .moderate: return Color.V2.onLime
        case .mild: return Color(light: .black, dark: darkInk)
        case .high, .severe: return Color(light: .white, dark: darkInk)
        }
    }
}

// MARK: - Metrics

enum V2Metrics {
    static let margin: CGFloat = 16
    static let radiusXS: CGFloat = 8
    static let radiusSM: CGFloat = 12
    static let radiusMD: CGFloat = 16
    static let radiusLG: CGFloat = 22
    static let radiusXL: CGFloat = 28
    static let buttonHeight: CGFloat = 50
    static let compactButtonHeight: CGFloat = 44
    static let minTouchTarget: CGFloat = 44
}

// MARK: - Type

extension Font {
    /// Rounded, tabular numerals for scores, vitals and timers.
    static func v2Number(_ style: Font.TextStyle, weight: Font.Weight = .semibold) -> Font {
        .system(style, design: .rounded).weight(weight).monospacedDigit()
    }
}

extension View {
    /// Uppercase section eyebrow: footnote semibold in `ink3`.
    func v2Eyebrow() -> some View {
        font(.footnote.weight(.semibold))
            .textCase(.uppercase)
            .tracking(0.2)
            .foregroundStyle(Color.V2.ink3)
    }
}
