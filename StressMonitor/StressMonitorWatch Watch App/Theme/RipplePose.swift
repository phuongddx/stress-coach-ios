import Foundation

// MARK: - Ripple v2 Pose (watch)

/// Watch copy of the Ripple v2 level table
/// (docs/superpowers/specs/2026-11-24-ripple-v2-rollout-design.md §4.1, §4.4).
///
/// `StressCategory` is duplicated per target, so the watch keeps its own
/// mapping. Keep `from(category:)` identical to the phone's
/// `StressMonitor/Components/Character/RipplePose.swift`. The watch catalog
/// holds only head crops (`Assets.xcassets/RippleV2`), so only the level
/// poses plus `base` and `sleeping` exist here.
enum RipplePose: String, CaseIterable, Sendable {
    case base, relaxed, mild, elevated, high, severe, sleeping

    /// Level → pose table. Must match the phone table exactly.
    static func from(category: StressCategory) -> RipplePose {
        switch category {
        case .relaxed:  return .relaxed
        case .mild:     return .mild
        case .moderate: return .elevated
        case .high:     return .high
        case .severe:   return .severe
        }
    }

    /// Pose for an optional category. On the watch, no reading → `.sleeping`
    /// (spec §4.2: watch empty state shows Ripple asleep).
    static func from(category: StressCategory?) -> RipplePose {
        category.map { from(category: $0) } ?? .sleeping
    }

    /// Head-crop asset name in the watch `Assets.xcassets/RippleV2`.
    var headAssetName: String { "ripple-v2-\(rawValue)-head" }

    /// VoiceOver label for the drawing. Same strings as the phone.
    var accessibilityLabel: String {
        switch self {
        case .base:     return "Ripple, smiling"
        case .relaxed:  return "Ripple, relaxed and floating"
        case .mild:     return "Ripple, waving"
        case .elevated: return "Ripple, a little worried"
        case .high:     return "Ripple, worried and dizzy"
        case .severe:   return "Ripple, upset and holding a heart"
        case .sleeping: return "Ripple, asleep"
        }
    }
}
