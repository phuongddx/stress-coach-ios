import SwiftUI

// MARK: - WatchDesignTokens

/// Watch theme tokens, re-pointed at the UI V2 dark palette (`WatchV2`).
///
/// The watch is dark-only on a true-black canvas. The token *names* are kept
/// so every existing call site picks up the V2 palette; the values now come
/// from `WatchV2` (the only place hex colours live).
enum WatchDesignTokens {

    // MARK: - Surfaces (V2 dark)

    /// True-black watch canvas.
    static let canvas          = WatchV2.canvas
    /// Cards, reading rows, picker items.
    static let surface         = WatchV2.surface
    /// Secondary elevated surface / tracks.
    static let surfaceSecondary = WatchV2.surface2
    /// Settings canvas — same true black as every other watch screen.
    static let settingsCanvas  = WatchV2.canvas

    // MARK: - Ink

    /// Primary text/ink.
    static let ink             = WatchV2.ink
    /// Secondary text.
    static let inkSecondary    = WatchV2.ink2
    /// Meta / caption text.
    static let muted           = WatchV2.ink3
    /// Quiet glyphs, inactive marks.
    static let mutedSystem     = WatchV2.ink3

    /// Hairline divider colour.
    static let separator       = WatchV2.line
    /// Inactive phase dots / control borders.
    static let separatorStrong = WatchV2.surface3

    // MARK: - Accent

    /// V2 accent (teal).
    static let accent          = WatchV2.accent
    /// Borders / selected states — same teal in dark.
    static let accentStrong    = WatchV2.accent
    /// Accent tint wash (callouts, selected wells).
    static let accentSoft      = WatchV2.accentSoft

    // MARK: - Radii (from app.css)

    static let radiusControl: CGFloat   = 12   // `--radius-control`
    static let radiusCard: CGFloat      = 14   // stat cards, reading rows
    static let radiusCardLarge: CGFloat = 18   // `--radius-card`
    static let radiusHero: CGFloat      = 22   // `--radius-card-lg`
    static let radiusPill: CGFloat      = 999  // `--radius-pill`

    // MARK: - Spacing scale (4/8/12/16/20/24/32)

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat  = 8
        static let sm: CGFloat  = 12
        static let md: CGFloat  = 16
        static let lg: CGFloat  = 20
        static let xl: CGFloat  = 24
        static let xxl: CGFloat = 32
    }

    // MARK: - Motion (iOS-aligned: ease, not spring-everything)

    enum Motion {
        /// Snappy state transitions (selection, tier swap).
        static let fast: Animation = .easeInOut(duration: 0.15)
        /// Default content transitions (score, ring fill).
        static let `default`: Animation = .easeInOut(duration: 0.20)
        /// Hero / breathing ring expansions.
        static let slow: Animation = .easeInOut(duration: 0.45)
        /// Ambient character halo (very slow, autoreverses).
        static let ambient: Animation = .easeInOut(duration: 2.4).repeatForever(autoreverses: true)
    }

    /// Resolve the motion to use, honoring `accessibilityReduceMotion`.
    /// Returns `nil` when motion should be disabled (callers pass `nil`
    /// to `.animation(_:value:)` to opt out of animation entirely).
    static func motion(_ baseline: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : baseline
    }

    // MARK: - Watch canvas metrics

    /// Apple Watch Series 10 45mm display — 216×264pt.
    static let screenCornerRadius: CGFloat = 52
    static let contentSidePadding: CGFloat = 14
    static let hairlineThickness: CGFloat = 0.5
}
