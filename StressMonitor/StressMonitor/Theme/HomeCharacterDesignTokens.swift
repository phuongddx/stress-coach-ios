import SwiftUI

/// Home-tab visual tokens derived from `docs/design/character-concept-sheet.html`.
/// Keeps the first redesign focused on Ripple / Water Otter while leaving room
/// for the full Elemental Creatures system.
enum HomeCharacterDesignTokens {
    enum Ripple {
        static let primary = Color(hex: "#4FC3F7")
        static let mid = Color(hex: "#81D4FA")
        static let light = Color(hex: "#B3E5FC")
        static let deep = Color(hex: "#0288D1")
    }

    enum Blossom {
        static let primary = Color(hex: "#A5D6A7")
        static let accent = Color(hex: "#81C784")
    }

    enum Ember {
        static let primary = Color(hex: "#FFAB91")
        static let accent = Color(hex: "#FF8A65")
    }

    enum Zephyr {
        static let primary = Color(hex: "#D1C4E9")
        static let accent = Color(hex: "#B39DDB")
    }

    enum Lumi {
        static let primary = Color(hex: "#7986CB")
        static let accent = Color(hex: "#5C6BC0")
    }

    static let ink = Color(hex: "#101223")
    static let mutedInk = Color(hex: "#777986")
    static let darkCanvas = Color(hex: "#0A0A0F")
    static let darkCard = Color(hex: "#1A1A2E")

    /// UI V2: flat paper canvas. Kept as a gradient type so call sites compile unchanged.
    static var homeBackground: LinearGradient {
        LinearGradient(colors: [Color.V2.bg, Color.V2.bg], startPoint: .top, endPoint: .bottom)
    }

    static var heroGradient: LinearGradient {
        LinearGradient(colors: [Color.V2.surface, Color.V2.surface], startPoint: .top, endPoint: .bottom)
    }
}
