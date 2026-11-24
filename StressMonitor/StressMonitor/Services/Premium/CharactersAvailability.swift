import Foundation

// MARK: - Characters Availability

/// Single source of truth for whether the Characters / companions feature is
/// shown in this build.
///
/// Mirrors `PurchaseAvailability`: every companion entry point and every
/// line of Plus copy that mentions companions reads `current`, so flipping
/// the single case below brings the feature back without touching call sites.
///
/// Hidden for 1.1: picking a companion only changed the Settings banner, while
/// Home, the widget and the Watch always showed Ripple, so the feature (and the
/// Plus copy that promised it) over-promised. It returns in 1.2 with the v2
/// character set and the companion colour theme. Ripple stays the only mascot
/// everywhere. `CharacterUnlock` rows and their CloudKit schema are untouched,
/// so a user's earlier pick and unlocks come back when the feature does.
enum CharactersAvailability: Sendable, Equatable {
    case enabled
    case hidden(reason: HiddenReason)

    static var current: CharactersAvailability { .hidden(reason: .unfinishedForRelease) }

    static var isEnabled: Bool { current == .enabled }

    enum HiddenReason: String, Sendable {
        case unfinishedForRelease
    }

    /// The paywall hero: Ripple alone, or Ripple flanked by the two Plus
    /// companions while the feature is on.
    var paywallHeroCharacterIds: [String] {
        self == .enabled ? ["zephyr", "ripple", "ember"] : ["ripple"]
    }
}
