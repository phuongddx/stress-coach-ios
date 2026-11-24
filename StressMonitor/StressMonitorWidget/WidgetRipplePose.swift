import Foundation

// MARK: - Ripple v2 Pose (Widget)

/// The Ripple v2 head shown by the widget (spec §4.4 "Widget").
///
/// The widget target does not compile the app's `RipplePose`, so this is the
/// widget-side copy of its level table: category → pose, no data → `.base`.
/// Keep it in step with `StressMonitor/Components/Character/RipplePose.swift`.
enum WidgetRipplePose: String, CaseIterable, Sendable {
    case base, relaxed, mild, elevated, high, severe

    /// Level → pose table (same as `RipplePose.from(category:)`).
    static func from(category: StressCategory) -> WidgetRipplePose {
        switch category {
        case .relaxed:  return .relaxed
        case .mild:     return .mild
        case .moderate: return .elevated
        case .high:     return .high
        case .severe:   return .severe
        }
    }

    /// Pose for an optional category. No data → `.base`.
    static func from(category: StressCategory?) -> WidgetRipplePose {
        category.map { from(category: $0) } ?? .base
    }

    /// Head-crop asset name in the widget's `Assets.xcassets/RippleV2`.
    var headAssetName: String { "ripple-v2-\(rawValue)-head" }

    /// VoiceOver label for the drawing (same copy as `RipplePose`).
    var accessibilityLabel: String {
        switch self {
        case .base:     return "Ripple, smiling"
        case .relaxed:  return "Ripple, relaxed and floating"
        case .mild:     return "Ripple, waving"
        case .elevated: return "Ripple, a little worried"
        case .high:     return "Ripple, worried and dizzy"
        case .severe:   return "Ripple, upset and holding a heart"
        }
    }
}
