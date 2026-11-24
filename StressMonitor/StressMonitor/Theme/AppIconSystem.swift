import SwiftUI

// MARK: - AppIconSystem

/// Centralized icon system mapping the StressMonitor design spec to SF Symbols.
///
/// Single source of truth for every icon in the app. Extracted from
/// `design/icon-system.html` and `design/icon-asset-mapping.md`.
/// Use `AppIconSystem.Icon.xxxx.sfSymbol` to get the canonical SF Symbol name.
///
/// ## Categories
/// - Tab bar (4 tabs, active/inactive variants)
/// - Navigation (back, forward, close)
/// - Action quick-start (6 exercises)
/// - Health metrics (8 factor icons)
/// - Mood faces (5-level stress scale — use `MoodFaceIcon`)
/// - Settings list (17 rows with colored square backgrounds)
/// - System / semantic (11 status icons)
enum AppIconSystem {

    // MARK: - Tab Bar

    enum Tab {
        case home
        case action
        case trends
        case settings

        /// SF Symbol for unselected state.
        var sfSymbol: String {
            switch self {
            case .home:     return "house"
            case .action:   return "plus.circle"
            case .trends:   return "chart.bar"
            case .settings: return "gearshape"
            }
        }

        /// SF Symbol for selected (active) state — uses `.fill` variant.
        var sfSymbolActive: String {
            switch self {
            case .home:     return "house.fill"
            case .action:   return "plus.circle.fill"
            case .trends:   return "chart.bar.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }

    // MARK: - Navigation

    enum Nav {
        case back
        case forward
        case close

        var sfSymbol: String {
            switch self {
            case .back:    return "chevron.left"
            case .forward: return "chevron.right"
            case .close:   return "xmark"
            }
        }
    }

    // MARK: - Action Quick-Start (6 exercises)

    enum Action {
        case breathing      // Box Breathing
        case bodyScan       // Body Scan
        case miniWalk       // Mini Walk
        case coldSplash     // Cold Splash
        case gratitude      // Gratitude
        case chat           // Talk to Companion

        var sfSymbol: String {
            switch self {
            case .breathing:  return "wind"
            case .bodyScan:   return "figure.mind.and.body"
            case .miniWalk:   return "figure.walk"
            case .coldSplash: return "snowflake"
            case .gratitude:  return "face.smiling"
            case .chat:       return "bubble.left"
            }
        }
    }

    // MARK: - Health Metrics (8 factor icons)

    enum Metric {
        case heartRate       // heart.fill
        case hrv             // waveform.path.ecg
        case sleep           // moon
        case activity        // sun.max
        case streak          // flame.fill
        case time            // clock
        case date            // calendar
        case achievement     // star.fill

        var sfSymbol: String {
            switch self {
            case .heartRate:   return "heart.fill"
            case .hrv:         return "waveform.path.ecg"
            case .sleep:       return "moon"
            case .activity:    return "sun.max"
            case .streak:      return "flame.fill"
            case .time:        return "clock"
            case .date:        return "calendar"
            case .achievement: return "star.fill"
            }
        }
    }

    // MARK: - Settings List (17 rows)

    enum Setting {
        case characters          // person.2.crop.square.stack
        case rippleCoach         // bubble.left.fill
        case appleHealth         // heart.fill
        case appleWatch          // applewatch
        case biologicalAge       // circle.dashed
        case hydration           // drop.fill
        case caffeine            // cup.and.saucer.fill
        case lightExposure       // sun.max.fill
        case stressAlerts        // bell.badge.fill
        case waterReminder       // drop.fill
        case dailySummary        // clock.badge.checkmark
        case stressMonitorPlus   // star.fill
        case appearance          // circle.lefthalf.filled
        case haptics             // speaker.wave.2.fill
        case exportData          // square.and.arrow.up
        case manageData          // trash
        case helpPrivacy         // questionmark.circle

        /// SF Symbol name (fallback when no custom SVG asset is available).
        var sfSymbol: String {
            switch self {
            case .characters:        return "person.2.crop.square.stack"
            case .rippleCoach:       return "bubble.left.fill"
            case .appleHealth:       return "heart.fill"
            case .appleWatch:        return "applewatch"
            case .biologicalAge:     return "circle.dashed"
            case .hydration:         return "drop.fill"
            case .caffeine:          return "cup.and.saucer.fill"
            case .lightExposure:     return "sun.max.fill"
            case .stressAlerts:      return "bell.badge.fill"
            case .waterReminder:     return "drop.fill"
            case .dailySummary:      return "clock.badge.checkmark"
            case .stressMonitorPlus: return "star.fill"
            case .appearance:        return "circle.lefthalf.filled"
            case .haptics:           return "speaker.wave.2.fill"
            case .exportData:        return "square.and.arrow.up"
            case .manageData:        return "trash"
            case .helpPrivacy:       return "questionmark.circle"
            }
        }

        /// Custom SVG asset name in Assets.xcassets/Settings/ (nil = use SF Symbol fallback).
        /// Each asset is a single-color template SVG (24x24, stroke-based 1.75pt) generated by
        /// the Open Design `stressmonitor-settings-redesign` project (2026-06-28).
        var assetName: String? {
            switch self {
            case .characters:        return "settings-icon-characters"
            case .rippleCoach:       return "settings-icon-ripple-coach"
            case .appleHealth:       return "settings-icon-apple-health"
            case .appleWatch:        return "settings-icon-apple-watch"
            case .biologicalAge:     return "settings-icon-biological-age"
            case .hydration:         return "settings-icon-hydration"
            case .caffeine:          return "settings-icon-caffeine"
            case .lightExposure:     return "settings-icon-light-exposure"
            case .stressAlerts:      return "settings-icon-stress-alerts"
            case .waterReminder:     return "settings-icon-water-reminder"
            case .dailySummary:      return "settings-icon-daily-summary"
            case .stressMonitorPlus: return "settings-icon-stressmonitor-plus"
            case .appearance:        return "settings-icon-appearance"
            case .haptics:           return "settings-icon-haptics"
            case .exportData:        return "settings-icon-export-data"
            case .manageData:        return "settings-icon-manage-data"
            case .helpPrivacy:       return "settings-icon-help-privacy"
            }
        }

        /// Small decorative sparkle (12x12) for the Plus upsell pill.
        static let plusPillSparkleAsset = "settings-icon-plus-pill-sparkle"
    }

    // MARK: - System / Semantic (11 icons)

    enum System {
        case success       // checkmark.circle.fill
        case warning       // exclamationmark.triangle
        case info          // info.circle
        case locked        // lock.fill
        case privacy       // shield.lefthalf.filled
        case delete        // trash
        case export_       // square.and.arrow.up
        case download      // arrow.down.square
        case send          // arrow.up
        case voiceInput    // mic.fill
        case premium       // crown.fill

        var sfSymbol: String {
            switch self {
            case .success:     return "checkmark.circle.fill"
            case .warning:     return "exclamationmark.triangle"
            case .info:        return "info.circle"
            case .locked:      return "lock.fill"
            case .privacy:     return "shield.lefthalf.filled"
            case .delete:      return "trash"
            case .export_:     return "square.and.arrow.up"
            case .download:    return "arrow.down.square"
            case .send:        return "arrow.up"
            case .voiceInput:  return "mic.fill"
            case .premium:     return "crown.fill"
            }
        }
    }
}

// MARK: - MoodFaceIcon (5-Level Stress Scale)

/// Maps the 5-level stress scale to SF Symbols and stress colors.
///
/// **CRITICAL (WCAG):** Always pair the face icon with its color.
/// The color is the primary signal; the face shape is secondary reinforcement.
/// Never show stress color without an accompanying icon or text label.
enum MoodFaceIcon: String, CaseIterable, Identifiable {
    case relaxed    // 0–25
    case mild       // 26–50
    case moderate   // 51–75
    case high       // 76–90
    case severe     // 91+

    var id: String { rawValue }

    // MARK: - SF Symbol

    var sfSymbol: String {
        switch self {
        case .relaxed:  return "face.smiling"
        case .mild:     return "face.smiling"
        case .moderate: return "face.neutral"
        case .high:     return "face.dashed"
        case .severe:   return "face.frowning"
        }
    }

    // MARK: - Stress Color (WCAG dual-coding)

    /// Stress-level color token. Must always accompany the face icon.
    var color: Color {
        switch self {
        case .relaxed:  return Color(hex: "#34C759")
        case .mild:     return Color(hex: "#007AFF")
        case .moderate: return Color(hex: "#FFD60A")
        case .high:     return Color(hex: "#FF9500")
        case .severe:   return Color(hex: "#FF3B30")
        }
    }

    // MARK: - Numeric Range

    var rangeText: String {
        switch self {
        case .relaxed:  return "0–25"
        case .mild:     return "26–50"
        case .moderate: return "51–75"
        case .high:     return "76–90"
        case .severe:   return "91+"
        }
    }

    var label: String {
        switch self {
        case .relaxed:  return "Relaxed"
        case .mild:     return "Mild"
        case .moderate: return "Moderate"
        case .high:     return "High"
        case .severe:   return "Severe"
        }
    }

    // MARK: - Stress Level → MoodFaceIcon

    /// Map a numeric stress level (0–100) to the closest mood face.
    static func from(stressLevel: Double) -> MoodFaceIcon {
        switch stressLevel {
        case ..<26:     return .relaxed
        case 26..<51:   return .mild
        case 51..<76:   return .moderate
        case 76..<91:   return .high
        default:        return .severe
        }
    }

    /// Bridge from `RippleMood` (procedural character mood) to the 5-level scale.
    static func from(mood: RippleMood) -> MoodFaceIcon {
        switch mood {
        case .relaxed, .serene, .happy, .celebrating: return .relaxed
        case .focused:                                 return .mild
        case .worried:                                 return .moderate
        case .determined:                              return .high
        case .tired:                                   return .severe
        }
    }
}

// MARK: - SettingsIconView

/// Renders a settings-row icon inside a UI V2 rounded tile (30 pt by
/// default, `V2Metrics.radiusXS`).
///
/// Resolution order (per `AppIconSystem.Setting`):
/// 1. If `setting.assetName` is non-nil AND the asset exists in the bundle,
///    render the custom SVG (single-color template image).
/// 2. Otherwise fall back to the SF Symbol defined by `setting.sfSymbol`.
///
/// Direct callers can still pass an arbitrary SF Symbol name via
/// `SettingsIconView(systemName:color:)` for icons outside the Settings enum.
struct SettingsIconView: View {
    let symbolName: String?
    let assetName: String?
    /// Tile fill.
    var color: Color = Color.V2.accent
    /// Glyph colour on the tile.
    var foreground: Color = Color.V2.onAccent
    var size: CGFloat = 30

    var body: some View {
        Group {
            if let assetName, UIImage(named: assetName) != nil {
                Image(assetName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.56, height: size * 0.56)
            } else if let symbolName {
                Image(systemName: symbolName)
                    .font(.callout.weight(.semibold))
            }
        }
        .foregroundStyle(foreground)
        .frame(width: size, height: size)
        .background(color, in: RoundedRectangle(cornerRadius: V2Metrics.radiusXS, style: .continuous))
        .accessibilityHidden(true)
    }
}

// MARK: - Convenience initializers

extension SettingsIconView {
    /// Icon from the Settings enum (preferred entry point).
    init(
        _ setting: AppIconSystem.Setting,
        color: Color = Color.V2.accent,
        foreground: Color = Color.V2.onAccent,
        size: CGFloat = 30
    ) {
        self.init(symbolName: setting.sfSymbol, assetName: setting.assetName, color: color, foreground: foreground, size: size)
    }

    /// Direct SF Symbol bypass (rare; use the enum case when one exists).
    init(
        systemName: String,
        color: Color = Color.V2.accent,
        foreground: Color = Color.V2.onAccent,
        size: CGFloat = 30
    ) {
        self.init(symbolName: systemName, assetName: nil, color: color, foreground: foreground, size: size)
    }

    /// Direct asset-name bypass (e.g. for the Plus pill sparkle).
    init(assetName: String, color: Color = Color.V2.accent) {
        self.init(symbolName: nil, assetName: assetName, color: color)
    }
}

// MARK: - MoodFaceView

/// Self-contained mood face icon with WCAG-compliant color background.
/// Renders as a colored circle with white SF Symbol face — matches the
/// `mood-style` CSS class from the icon system design.
struct MoodFaceView: View {
    let mood: MoodFaceIcon
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: mood.sfSymbol)
            .font(.system(size: size * 0.6, weight: .regular))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(mood.color, in: Circle())
            .accessibilityLabel("\(mood.label) stress, range \(mood.rangeText)")
    }
}
