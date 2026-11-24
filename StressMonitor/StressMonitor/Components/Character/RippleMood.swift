import SwiftUI

/// Mood states for the Ripple water-droplet character used in Action subscreens.
/// Each mood drives visibly different eyes/mouth and an associated body tint.
///
/// Canonical mood type for the StressMonitor character system. All five
/// elemental creatures (Ripple, Blossom, Ember, Zephyr, Lumi) share this type.
public enum RippleMood: String, CaseIterable, Sendable {
    case serene
    case focused
    case relaxed
    case happy
    case celebrating
    case worried
    case determined
    case tired

    // MARK: - Stress Level Mapping

    /// Map a stress level (0–100) to the closest character mood.
    static func from(stressLevel: Double) -> RippleMood {
        switch stressLevel {
        case ..<10:
            return .relaxed
        case 10..<25:
            return .serene
        case 25..<50:
            return .focused
        case 50..<75:
            return .worried
        case 75..<90:
            return .tired
        default:
            return .determined
        }
    }

    // MARK: - Ripple v2 Pose

    /// The Ripple v2 drawing for this mood (spec §4.1 table).
    var pose: RipplePose {
        switch self {
        case .serene:       return .base
        case .relaxed:      return .relaxed
        case .focused:      return .mild
        case .happy:        return .mild
        case .celebrating:  return .celebrating
        case .worried:      return .elevated
        case .determined:   return .high
        case .tired:        return .sleeping
        }
    }

    /// VoiceOver-friendly description of the character's state.
    var accessibilityLabel: String {
        switch self {
        case .serene:       return "Ripple is serene and calm"
        case .focused:      return "Ripple is focused and attentive"
        case .relaxed:      return "Ripple is relaxed and at ease"
        case .happy:        return "Ripple is happy and content"
        case .celebrating:  return "Ripple is celebrating joyfully"
        case .worried:      return "Ripple is feeling worried"
        case .determined:   return "Ripple is determined and strong"
        case .tired:        return "Ripple is tired and sleepy"
        }
    }

    /// VoiceOver description (alias used by migrated call sites).
    var accessibilityDescription: String { accessibilityLabel }

    /// Base body tint — slightly shifts the water-droplet fill per mood.
    var bodyTint: Color {
        switch self {
        case .serene:       return HomeCharacterDesignTokens.Ripple.primary
        case .focused:      return HomeCharacterDesignTokens.Ripple.deep
        case .relaxed:      return HomeCharacterDesignTokens.Ripple.mid
        case .happy:        return HomeCharacterDesignTokens.Ripple.primary
        case .celebrating:  return HomeCharacterDesignTokens.Ripple.light
        case .worried:      return Color(hex: "#42A5F5")   // slightly muted blue
        case .determined:   return HomeCharacterDesignTokens.Ripple.deep
        case .tired:        return Color(hex: "#64B5F6")   // faded blue
        }
    }

    /// SF Symbol representative of this mood (for legend/icon UI).
    var symbol: String {
        switch self {
        case .serene:       return "figure.mind.and.body"
        case .focused:      return "figure.walk.circle"
        case .relaxed:      return "moon.zzz.fill"
        case .happy:        return "face.smiling.fill"
        case .celebrating:  return "sparkles"
        case .worried:      return "exclamationmark.triangle.fill"
        case .determined:   return "flame.fill"
        case .tired:        return "tortoise.fill"
        }
    }

    /// Display name for legends and labels.
    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - Character Display Context

/// Context in which the character is rendered, used to pick a size.
public enum CharacterDisplayContext: Sendable {
    case dashboard
    case widget
    case watchOS
}
