import SwiftUI

// MARK: - Character Grid Card

/// Grid tile for a character in the collection (UI V2, `S.characters`).
///
/// Renders a companion-tinted halo, the character art (unchanged), name,
/// element subtitle, a status tag (Active / Free / PLUS / 30-day streak) and
/// the stage or streak line. Locked characters dim only the art block.
struct CharacterGridCard: View {
    let creature: CharacterCreature
    let unlock: CharacterUnlock?
    let isActive: Bool
    var mood: RippleMood = .serene

    private var isUnlocked: Bool { unlock?.isUnlocked ?? false }
    private var isPremium: Bool { creature.unlockType == .premium }
    private var isStreakGated: Bool { creature.unlockType == .streakGated }
    private var currentStage: EvolutionStage { unlock?.evolutionStage ?? .droplet }

    var body: some View {
        VStack(spacing: 6) {
            // Character art on a companion tint. Locked dimming is scoped to
            // the illustration block only; card text keeps full token contrast.
            ZStack {
                Circle()
                    .fill(creature.element.v2Tint.opacity(0.22))
                    .frame(width: 88, height: 88)

                StressBuddyIllustration(
                    characterId: creature.id,
                    evolution: isUnlocked ? currentStage : .droplet,
                    mood: mood,
                    size: 72
                )
                .opacity(isUnlocked ? 1.0 : 0.65)
                .saturation(isUnlocked ? 1.0 : 0.5)
            }
            .frame(height: 92)
            .overlay(alignment: .bottomTrailing) {
                if !isUnlocked {
                    Image(systemName: AppIconSystem.System.locked.sfSymbol)
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Color.V2.ink2)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.V2.surface2))
                        .overlay(Circle().strokeBorder(Color.V2.line, lineWidth: 0.5))
                        .offset(x: -8, y: -2)
                }
            }

            Text(creature.displayName)
                .font(.headline)
                .foregroundStyle(Color.V2.ink)
                .multilineTextAlignment(.center)

            Text(creature.subtitle)
                .font(.caption)
                .foregroundStyle(Color.V2.ink3)
                .multilineTextAlignment(.center)

            statusBadge
                .padding(.top, 2)

            stageLabel
                .font(.caption)
                .foregroundStyle(Color.V2.ink2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .v2CardBackground()
        .overlay {
            RoundedRectangle(cornerRadius: V2Metrics.radiusLG, style: .continuous)
                .strokeBorder(isActive ? Color.V2.accent : Color.clear, lineWidth: 2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Double tap for character details")
    }

    // MARK: - Status Badge

    @ViewBuilder
    private var statusBadge: some View {
        if isActive {
            CharacterTag(title: "Active", style: .accent)
        } else if isStreakGated {
            CharacterTag(
                title: isUnlocked ? "Unlocked" : "\(creature.streakRequired)-day streak",
                systemImage: AppIconSystem.Metric.streak.sfSymbol
            )
        } else if isPremium {
            V2PlusPill(showsLock: !isUnlocked)
        } else {
            CharacterTag(title: "Free")
        }
    }

    // MARK: - Stage Label

    @ViewBuilder
    private var stageLabel: some View {
        if isUnlocked {
            if let unlock {
                Text("Stage \(currentStage.sortOrder + 1) · \(unlock.streakDays)d streak")
            } else {
                Text("Stage \(currentStage.sortOrder + 1)")
            }
        } else if isStreakGated {
            let current = unlock?.streakDays ?? 0
            Text("Locked · \(max(creature.streakRequired - current, 0))d to go")
        } else {
            Text("Locked · Plus")
        }
    }

    private var accessibilityLabel: String {
        let active = isActive ? ", active" : ""
        if isUnlocked {
            return "\(creature.displayName), \(currentStage.displayName.lowercased()) stage\(active)"
        }
        return "\(creature.displayName), locked\(active)"
    }

    private var accessibilityValue: String {
        "Evolution stage \(currentStage.sortOrder + 1) of \(EvolutionStage.allCases.count)"
    }
}

// MARK: - Character Tag

/// Small status tag used on companion cards (prototype `.tag` / `.tag.acc`).
struct CharacterTag: View {
    enum Style { case neutral, accent }

    let title: String
    var systemImage: String? = nil
    var style: Style = .neutral

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .imageScale(.small)
            }
            Text(title)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(style == .accent ? Color.V2.accent : Color.V2.ink2)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(style == .accent ? Color.V2.accentSoft : Color.V2.surface2))
    }
}

// MARK: - Companion Tint

extension CharacterElement {
    /// V2 companion tint for halos and progress (backgrounds only, never text).
    var v2Tint: Color {
        switch self {
        case .water: return Color.V2.Companion.ripple
        case .earth: return Color.V2.Companion.blossom
        case .fire: return Color.V2.Companion.ember
        case .air: return Color.V2.Companion.zephyr
        case .moon: return Color.V2.Companion.lumi
        }
    }
}
