import SwiftUI

// MARK: - Color(hex:)

extension Color {
    /// Parse a `#RRGGBB` / `#RGB` / `#AARRGGBB` hex string into a Color.
    /// Mirrors the iOS app's `Color(hex:)` so token values match exactly.
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    /// Adaptive light/dark colour.  watchOS does not expose
    /// `UIColor(dynamicProvider:)`, and the watch app is dark-only (UI V2),
    /// so this resolves to the dark variant. The light argument is retained
    /// for API symmetry with the iOS app.
    init(light: Color, dark: Color) {
        self = dark
    }

    // MARK: - Stress-scale convenience accessors (UI V2 dark tiers)

    /// 5-tier stress scale — V2 dark tier colours (text == fill).
    static let stressRelaxed  = WatchV2.tierRelaxed
    static let stressMild     = WatchV2.tierMild
    static let stressModerate = WatchV2.tierElevated
    static let stressHigh     = WatchV2.tierHigh
    static let stressSevere   = WatchV2.tierSevere

    /// Resolve the stress colour for a raw 0–100+ level.
    static func stressColor(for level: Double) -> Color {
        StressCategory.category(for: level).color
    }

    /// Resolve the stress colour for a category.
    static func stressColor(for category: StressCategory) -> Color {
        category.color
    }
}
