import SwiftUI

// MARK: - WatchV2

/// UI V2 token layer for the watch (spec §3, dark values).
///
/// The watch is dark-only on a true-black canvas, so every token here is the
/// V2 *dark* value. This file is the only place in the watch target that may
/// spell a hex colour; views read these tokens (directly or through the
/// re-pointed `WatchDesignTokens` / `StressCategory` accessors).
enum WatchV2 {

    // MARK: Canvas + surfaces

    /// True black — the watch display background.
    static let canvas    = Color.black
    /// Card / row platter.
    static let surface   = Color(hex: "#14201B")
    /// Gauge track, inactive bars, secondary wells.
    static let surface2  = Color(hex: "#1C2A24")
    /// Pressed / tertiary well.
    static let surface3  = Color(hex: "#26362F")
    /// Hairline divider (ink at 9 %).
    static let line      = Color(hex: "#EEF1E6").opacity(0.09)

    // MARK: Ink

    static let ink   = Color(hex: "#EEF1E6")
    static let ink2  = Color(hex: "#B9C5B8")
    static let ink3  = Color(hex: "#8F9D94")

    // MARK: Accent

    static let accent      = Color(hex: "#5FBFA9")
    static let accentSoft  = Color(hex: "#1F3830")
    static let accentTint  = Color(hex: "#2C6B5C")
    /// Text / glyphs drawn on an `accent` (or any tier) fill.
    static let onAccent    = Color(hex: "#062A22")
    static let lime        = Color(hex: "#9CCB3A")
    static let onLime      = Color(hex: "#142605")
    static let danger      = Color(hex: "#FF7A6E")

    // MARK: Stress tiers (text colour == fill colour in dark)

    static let tierRelaxed  = Color(hex: "#9CCB3A")
    static let tierMild     = Color(hex: "#74C3CE")
    static let tierElevated = Color(hex: "#F2C46A")
    static let tierHigh     = Color(hex: "#EE7448")
    static let tierSevere   = Color(hex: "#F0788C")

    // MARK: Companion tints (background wash + halo only — art unchanged)

    enum Companion {
        static let rippleDark   = Color(hex: "#5FB3B9")
        static let blossomDark  = Color(hex: "#A6CF78")
        static let emberDark    = Color(hex: "#F2A984")
        static let zephyrDark   = Color(hex: "#BDB7E3")
        static let lumiDark     = Color(hex: "#7E9BD0")

        static let rippleLight  = Color(hex: "#4E9FA6")
        static let blossomLight = Color(hex: "#9CC56B")
        static let emberLight   = Color(hex: "#EE9F78")
        static let zephyrLight  = Color(hex: "#B4AEDB")
        static let lumiLight    = Color(hex: "#5E7FB8")
    }

    // MARK: Feature hues (menu tiles / cycle ring)

    /// Cycle phase ring + menu tile (prototype `#D78AE0`).
    static let cycle = Color(hex: "#D78AE0")

    // MARK: Metrics

    /// Minimum visible size for a tappable control.
    static let minVisibleTarget: CGFloat = 32
    /// Minimum hit area for a tappable control.
    static let minHitTarget: CGFloat = 44
    /// Platter corner radius for rows / cards.
    static let radiusCard: CGFloat = 16
}

// MARK: - V2 type helpers (parity with the iPhone `V2Tokens`)

extension Font {
    /// Rounded, monospaced-digit number style that scales with Dynamic Type.
    static func v2Number(_ style: Font.TextStyle, weight: Font.Weight = .semibold) -> Font {
        .system(style, design: .rounded).weight(weight).monospacedDigit()
    }
}

extension View {
    /// Small uppercase label above a value (footnote · semibold · ink3).
    func v2Eyebrow() -> some View {
        self
            .font(.footnote.weight(.semibold))
            .textCase(.uppercase)
            .tracking(0.2)
            .foregroundStyle(WatchV2.ink3)
    }
}

// MARK: - Tier badge (shape + name, colour-coded)

/// The tier shown three ways at once: colour, SF Symbol shape and name.
struct WatchTierBadge: View {
    let category: StressCategory
    var font: Font = .footnote.weight(.semibold)

    var body: some View {
        HStack(spacing: 4) {
            // Default (not small) scale so the octagon / circle / square
            // silhouettes stay distinguishable at caption sizes.
            Image(systemName: category.icon)
                .accessibilityHidden(true)
            Text(category.displayName)
        }
        .font(font)
        .foregroundStyle(category.color)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}
