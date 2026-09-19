import Foundation
import SwiftUI

// MARK: - Character Element Type

/// The elemental type of each character creature
enum CharacterElement: String, Codable, CaseIterable, Sendable {
    case water   // Ripple — Water Otter
    case earth   // Blossom — Forest Fox
    case fire    // Ember — Fire Phoenix
    case air     // Zephyr — Cloud Rabbit
    case moon    // Lumi — Moon Owl

    var displayName: String {
        switch self {
        case .water: return "Water"
        case .earth: return "Earth"
        case .fire:  return "Fire"
        case .air:   return "Air"
        case .moon:  return "Moon"
        }
    }

    var emoji: String {
        switch self {
        case .water: return "💧"
        case .earth: return "🌿"
        case .fire:  return "🔥"
        case .air:   return "🌬️"
        case .moon:  return "🌙"
        }
    }

    /// Primary color for this element
    var primaryColor: Color {
        switch self {
        case .water: return Color(hex: "#4FC3F7")
        case .earth: return Color(hex: "#A5D6A7")
        case .fire:  return Color(hex: "#FFAB91")
        case .air:   return Color(hex: "#D1C4E9")
        case .moon:  return Color(hex: "#7986CB")
        }
    }

    /// Secondary/lighter color
    var secondaryColor: Color {
        switch self {
        case .water: return Color(hex: "#B3E5FC")
        case .earth: return Color(hex: "#C8E6C9")
        case .fire:  return Color(hex: "#FBE9E7")
        case .air:   return Color(hex: "#EDE7F6")
        case .moon:  return Color(hex: "#C5CAE9")
        }
    }

    /// Accent/dark color
    var accentColor: Color {
        switch self {
        case .water: return Color(hex: "#0288D1")
        case .earth: return Color(hex: "#2E7D32")
        case .fire:  return Color(hex: "#E65100")
        case .air:   return Color(hex: "#7E57C2")
        case .moon:  return Color(hex: "#3949AB")
        }
    }

    /// Background glow color
    var glowColor: Color {
        primaryColor.opacity(0.3)
    }
}

// MARK: - Evolution Stage

/// Evolution stages for characters (Tamagotchi-style growth)
enum EvolutionStage: String, Codable, CaseIterable, Sendable {
    case droplet  // Stage 1: Baby form
    case ripple   // Stage 2: Teen form
    case tidal    // Stage 3: Majestic adult form

    var displayName: String { rawValue.capitalized }

    var sortOrder: Int {
        switch self {
        case .droplet: return 0
        case .ripple:  return 1
        case .tidal:   return 2
        }
    }

    /// Scale factor for rendering character at this evolution stage
    var scaleFactor: CGFloat {
        switch self {
        case .droplet: return 0.6
        case .ripple:  return 0.85
        case .tidal:   return 1.0
        }
    }

    /// Evolution trigger description
    func triggerDescription(for element: CharacterElement) -> String {
        switch self {
        case .droplet:
            return "🌱 Start: 7-day streak"
        case .ripple:
            switch element {
            case .water: return "🌊 30-day streak + 5 breathing sessions"
            case .earth: return "🌿 30-day streak + 10 journal entries"
            case .fire:  return "🔥 30-day streak + 20 workouts"
            case .air:   return "🌬️ 30-day streak + 15 mindfulness sessions"
            case .moon:  return "🌙 30-day streak + 20 good sleep nights"
            }
        case .tidal:
            return "⚡ 90-day streak + Resilience Score 80+"
        }
    }
}

// MARK: - Character Unlock Type

/// How a character can be unlocked
enum CharacterUnlockType: String, Codable, Sendable {
    case free         // Available from start
    case premium      // Requires premium subscription
    case streakGated  // Requires a streak milestone
}

// MARK: - Character Creature (Static Definition)

/// Static definition of a character creature (not persisted — acts as catalog)
struct CharacterCreature: Identifiable, Equatable, Sendable {
    let id: String           // "ripple", "blossom", etc.
    let displayName: String
    let subtitle: String     // "Water Otter", "Forest Fox", etc.
    let element: CharacterElement
    let personality: String
    let unlockType: CharacterUnlockType
    let streakRequired: Int  // Days of streak needed (0 for free/premium)
    let description: String

    /// All available characters in the collection
    static let allCharacters: [CharacterCreature] = [
        CharacterCreature(
            id: "ripple",
            displayName: "Ripple",
            subtitle: "Water Otter",
            element: .water,
            personality: "Gentle, playful, shy",
            unlockType: .free,
            streakRequired: 0,
            description: "Relaxation & calm. Floats on waves when you're at peace, hides in shell when stressed."
        ),
        CharacterCreature(
            id: "blossom",
            displayName: "Blossom",
            subtitle: "Forest Fox",
            element: .earth,
            personality: "Curious, nurturing, warm",
            unlockType: .free,
            streakRequired: 0,
            description: "Growth & resilience. Leaves perk up with good habits, wilts when you need rest."
        ),
        CharacterCreature(
            id: "ember",
            displayName: "Ember",
            subtitle: "Fire Phoenix",
            element: .fire,
            personality: "Bold, motivating, fierce",
            unlockType: .premium,
            streakRequired: 0,
            description: "Energy & motivation. Flames grow with activity, dims when you need recovery."
        ),
        CharacterCreature(
            id: "zephyr",
            displayName: "Zephyr",
            subtitle: "Cloud Rabbit",
            element: .air,
            personality: "Calm, dreamy, soft",
            unlockType: .premium,
            streakRequired: 0,
            description: "Breathing & mindfulness. Clouds drift gently when calm, storms when stressed."
        ),
        CharacterCreature(
            id: "lumi",
            displayName: "Lumi",
            subtitle: "Moon Owl",
            element: .moon,
            personality: "Wise, serene, mystical",
            unlockType: .streakGated,
            streakRequired: 30,
            description: "Sleep & wisdom. Glows bright with good sleep, dims when sleep-deprived."
        ),
    ]

    /// Find character by ID
    static func find(by id: String) -> CharacterCreature? {
        allCharacters.first { $0.id == id }
    }

    /// Characters offered to the user in this build.
    ///
    /// Premium creatures are withheld while `PurchaseAvailability` is
    /// postponed: the app must surface no purchasable content while the
    /// products are absent from App Store Connect. Lookups and persistence
    /// keep using `allCharacters` so existing unlock rows stay resolvable.
    static var offeredCharacters: [CharacterCreature] {
        guard !PurchaseAvailability.isEnabled else { return allCharacters }
        return allCharacters.filter { $0.unlockType != .premium }
    }
}

// MARK: - Evolution Requirements

/// Structured requirements for reaching an evolution stage.
struct EvolutionRequirement: Sendable {
    let streakDays: Int
    let sessionsCompleted: Int
    let description: String

    static func forStage(_ stage: EvolutionStage, element: CharacterElement) -> EvolutionRequirement {
        switch stage {
        case .droplet:
            return EvolutionRequirement(
                streakDays: 0,
                sessionsCompleted: 0,
                description: "🌱 Starter form"
            )
        case .ripple:
            let sessions: Int
            let desc: String
            switch element {
            case .water:
                sessions = 5
                desc = "🌊 30-day streak + 5 breathing sessions"
            case .earth:
                sessions = 10
                desc = "🌿 30-day streak + 10 journal entries"
            case .fire:
                sessions = 20
                desc = "🔥 30-day streak + 20 workouts"
            case .air:
                sessions = 15
                desc = "🌬️ 30-day streak + 15 mindfulness sessions"
            case .moon:
                sessions = 20
                desc = "🌙 30-day streak + 20 good sleep nights"
            }

            return EvolutionRequirement(
                streakDays: 30,
                sessionsCompleted: sessions,
                description: desc
            )
        case .tidal:
            return EvolutionRequirement(
                streakDays: 90,
                sessionsCompleted: 0,
                description: "⚡ 90-day streak + Resilience Score 80+"
            )
        }
    }
}

extension CharacterCreature {
    /// Evolution requirement for reaching the supplied stage.
    func evolutionRequirement(for stage: EvolutionStage) -> EvolutionRequirement {
        .forStage(stage, element: element)
    }

    /// Display emoji for the character's element.
    var emoji: String { element.emoji }
}
