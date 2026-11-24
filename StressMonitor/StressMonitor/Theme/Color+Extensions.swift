import SwiftUI

extension Color {
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

    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }

    // MARK: - Stress Level Colors

    static let stressRelaxed = StressCategory.relaxed.color
    static let stressMild = StressCategory.mild.color
    static let stressModerate = StressCategory.moderate.color
    static let stressHigh = StressCategory.high.color
    static let stressSevere = StressCategory.severe.color

    // MARK: - Chart Accents

    /// HRV trend chart accent (green per HTML `--hrv-color: #34D399`). The
    /// color is also used as `.foregroundStyle` for the average numeral and
    /// "today · NNms" annotation text in `HRVTrendChart`, so the light
    /// variant must clear the 4.5:1 text bar, not just the 3:1 UI bar the
    /// line/fill/halo need. The base `#34D399` measures 1.92:1 on the white
    /// light-mode card; an earlier `#0F9D6E` retune only reached 3.46:1
    /// (clears 3:1, fails 4.5:1). Retuned to `#0C7A55`, which measures
    /// 5.34:1 on the white card.
    static let hrvTrendAccent = Color(light: Color(hex: "#0C7A55"), dark: Color(hex: "#34D399"))

    // MARK: - Semantic Colors

    static let primaryBlue = Color(light: Color(hex: "#007AFF"), dark: Color(hex: "#0A84FF"))
    static let primaryGreen = Color(light: Color(hex: "#34C759"), dark: Color(hex: "#30D158"))
    static let success = Color(light: Color(hex: "#34C759"), dark: Color(hex: "#30D158"))
    static let warning = Color(hex: "#FFB00A")
    static let error = Color(light: Color(hex: "#FF3B30"), dark: Color(hex: "#FF453A"))

    // MARK: - Light Mode Colors

    static let backgroundLight = Color(hex: "#F2F2F7")
    static let surfaceLight = Color.white
    static let cardLight = Color.white
    static let textPrimaryLight = Color.black
    static let textSecondaryLight = Color(hex: "#8E8E93")
    static let dividerLight = Color(hex: "#C6C6C8")

    // MARK: - Dark Mode Colors

    static let backgroundDark = Color.black
    static let surfaceDark = Color(hex: "#1C1C1E")
    static let cardDark = Color(hex: "#1C1C1E")
    static let textPrimaryDark = Color.white
    static let textSecondaryDark = Color(hex: "#EBEBF5")
    static let dividerDark = Color(hex: "#38383A")

    // MARK: - OLED Dark Mode Colors

    /// Deep dark background for OLED displays - #121212
    static let oledBackground = Color(hex: "#121212")
    /// Card background for OLED dark theme - #1E1E1E
    static let oledCardBackground = Color(hex: "#1E1E1E")
    /// Secondary card background for OLED - #2A2A2A
    static let oledCardSecondary = Color(hex: "#2A2A2A")
    /// Secondary text color for OLED - #9CA3AF
    static let oledTextSecondary = Color(hex: "#9CA3AF")

    // MARK: - Tab Bar Colors

    /// Unselected tab bar icon color (adaptive: system gray for both modes)
    static let tabBarUnselected = Color(light: Color(hex: "#8E8E93"), dark: Color(hex: "#636366"))

    // MARK: - Accent Colors

    /// HRV accent color (green-teal)
    static let hrvAccent = Color(hex: "#34D399")
    /// Heart rate accent color (red-pink)
    static let heartRateAccent = Color(hex: "#F87171")

    // MARK: - Figma Design Colors (Action Demo Screen)

    /// Positive green - #52B923
    static let positive = Color(hex: "52B923")
    /// Accents orange - #FF8D28
    static let accentOrange = Color(hex: "FF8D28")
    /// Light grey - #D2D4DA
    static let lightGrey = Color(hex: "D2D4DA")

    // MARK: - Settings Screen Colors

    /// App-wide grouped-list background (#F2F2F7 in light, system black in dark).
    /// Matches iOS Settings canvas.
    static let appBackground = Color.V2.bg

    /// Settings background (light: warm cream #FFFDF6, dark canvas #121212 —
    /// unified with the adaptive canvas)
    static let settingsBackground = Color.V2.bg
    /// Ripple blue accent - #0891B2. Fill-safe: white text on this value
    /// passes 3:1 in both appearances. The legacy fixed #4FC3F7 must never
    /// carry white text as a fill in either appearance (2.00:1).
    static let settingsRippleBlue = Color(hex: "0891B2")
    /// Accent teal compatibility alias now aligned to Ripple blue.
    static let accentTeal = Color(hex: "0891B2")
    /// Settings icon accents.
    static let settingsIconYellow = Color(hex: "FFD166")
    static let settingsIconPurple = Color(hex: "A78BFA")
    /// Amber info banner background for privacy / HRV guidance.
    static let settingsAmberInfo = Color(light: Color(hex: "FFF4D6"), dark: Color(hex: "3A2A05"))
    /// Premium gold - #FE9901
    static let premiumGold = Color(hex: "FE9901")
    /// Tertiary text — alias of the adaptive secondary text token
    static var textTertiary: Color { Color.Wellness.adaptiveSecondaryText }
    /// Descriptive text — alias of the adaptive secondary text token
    static var textDescriptive: Color { Color.Wellness.adaptiveSecondaryText }
    /// Light border - #DBDBDB
    static let borderLight = Color.V2.line2
    /// Widget border - #C0C0C0
    static let widgetBorder = Color(light: Color(hex: "C0C0C0"), dark: Color(hex: "48484A"))
    /// Settings card shadow color - #18274B
    static let settingsCardShadowColor = Color(hex: "18274B")
    /// Info banner yellow background — alias of settingsAmberInfo
    static var bannerYellow: Color { settingsAmberInfo }

    // MARK: - Adaptive Colors for Settings

    /// Adaptive background for settings screen
    static var adaptiveSettingsBackground: Color {
        settingsBackground
    }

        // MARK: - Paywall Redesign Colors

    /// IAP purple accent (benefit icon) - #8B5CF6
    static let iapPurple = Color(hex: "8B5CF6")
    /// IAP warm background - #FFFD6
    static let iapWarmBackground = Color(hex: "FFFDF6")
    /// IAP card background (white)
    static let iapCardBackground = Color.white
    /// IAP pill background
    static let iapPillBackground = Color(light: Color.white.opacity(0.66), dark: Color.white.opacity(0.06))
    /// IAP trust item background
    static let iapTrustBackground = Color(light: Color.white.opacity(0.58), dark: Color.white.opacity(0.05))

// MARK: - IAP Screen Colors (Figma)

    /// IAP section header teal - #158B8B
    static let iapHeaderTeal = Color(hex: "158B8B")
    /// IAP CTA button - Ripple blue #0891B2. Retuned from the legacy
    /// #4FC3F7 (2.00:1 with white text, failing the 3:1 fill-safe bar);
    /// matches `settingsRippleBlue` (3.68:1 with white text).
    static let iapCTATeal = Color(hex: "0891B2")
    /// IAP plan selected border amber - #FFAE3B
    static let iapAmber = Color(hex: "FFAE3B")
    /// IAP savings green - #4FC01B
    static let iapSavingsGreen = Color(hex: "4FC01B")
    /// IAP primary text - #111827
    static let iapTextPrimary = Color(hex: "111827")
    /// IAP secondary text - #6B7280
    static let iapTextSecondary = Color(hex: "6B7280")
    /// IAP muted text (nav title) — alias of textTertiary
    static var iapTextMuted: Color { textTertiary }
    /// IAP chevron/icon gray - #9CA3AF
    static let iapChevronGray = Color(hex: "9CA3AF")
    /// IAP icon border - #9EA7B8
    static let iapIconBorder = Color(hex: "9EA7B8")
    /// IAP restore icon blue - #3B82F6
    static let iapRestoreBlue = Color(hex: "3B82F6")
    /// IAP manage icon dark - #374151
    static let iapManageDark = Color(hex: "374151")
    /// IAP tagline gradient start - #00D9FF
    static let iapGradientStart = Color(hex: "00D9FF")
    /// IAP tagline gradient end - #24B9CC
    static let iapGradientEnd = Color(hex: "24B9CC")

    // MARK: - Color Helpers

    static func stressColor(for category: StressCategory) -> Color {
        // Delegate to StressCategory as single source of truth
        return category.color
    }

    static func stressIcon(for category: StressCategory) -> String {
        // Delegate to StressCategory as single source of truth
        return category.icon
    }
}
