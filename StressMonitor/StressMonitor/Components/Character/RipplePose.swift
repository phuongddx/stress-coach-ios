import SwiftUI

// MARK: - Ripple v2 Pose

/// The drawn states of Ripple v2 (docs/superpowers/specs/2026-11-24-ripple-v2-rollout-design.md §4.1).
///
/// This is the single place that decides which Ripple drawing is shown.
/// Level poses go through ``StressCategory`` so the phone, watch and widget
/// always agree. Each pose has a full-body and a head-crop asset.
enum RipplePose: String, CaseIterable, Sendable {
    case base, relaxed, mild, elevated, high, severe
    case breathing, walking, celebrating, sleeping, thinking

    /// Level → pose table. No score bands: score → category stays in
    /// `StressResult.category(for:)`.
    static func from(category: StressCategory) -> RipplePose {
        switch category {
        case .relaxed:  return .relaxed
        case .mild:     return .mild
        case .moderate: return .elevated
        case .high:     return .high
        case .severe:   return .severe
        }
    }

    /// Pose for an optional category. No data → `.base`.
    static func from(category: StressCategory?) -> RipplePose {
        category.map { from(category: $0) } ?? .base
    }

    /// Full-body asset name in `Assets.xcassets/RippleV2`.
    var assetName: String { "ripple-v2-\(rawValue)" }

    /// Head-crop asset name in `Assets.xcassets/RippleV2`.
    var headAssetName: String { "ripple-v2-\(rawValue)-head" }

    /// VoiceOver label for the drawing.
    var accessibilityLabel: String {
        switch self {
        case .base:        return "Ripple, smiling"
        case .relaxed:     return "Ripple, relaxed and floating"
        case .mild:        return "Ripple, waving"
        case .elevated:    return "Ripple, a little worried"
        case .high:        return "Ripple, worried and dizzy"
        case .severe:      return "Ripple, upset and holding a heart"
        case .breathing:   return "Ripple, breathing slowly"
        case .walking:     return "Ripple, walking"
        case .celebrating: return "Ripple, celebrating"
        case .sleeping:    return "Ripple, asleep"
        case .thinking:    return "Ripple, thinking"
        }
    }
}

/// Which crop of a Ripple v2 drawing to show.
enum RippleCrop: Sendable {
    case full
    case head
}
