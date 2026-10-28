import SwiftUI

// MARK: - Character Grid Card

/// Grid tile for a character in the collection, matching `16-characters.html`.
///
/// Renders a glow background, procedural character art, name, element label,
/// an unlock status badge (FREE / PLUS / 30-DAY STREAK), and evolution stage dots.
/// Locked characters are visually desaturated with a lock overlay.
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
            // Character art with glow background. Locked dimming is scoped to
            // the illustration block only — card text always renders at full
            // token contrast.
            ZStack {
                Circle()
                    .fill(creature.element.primaryColor.opacity(0.55))
                    .frame(width: 80, height: 80)
                    .blur(radius: 20)
                    .offset(y: -12)

                if isUnlocked {
                    StressBuddyIllustration(
                        characterId: creature.id,
                        evolution: currentStage,
                        mood: mood,
                        size: 72
                    )
                } else {
                    StressBuddyIllustration(
                        characterId: creature.id,
                        evolution: .droplet,
                        mood: mood,
                        size: 72
                    )
                    .overlay {
                        Image(systemName: AppIconSystem.System.locked.sfSymbol)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.Wellness.adaptivePrimaryText)
                            .frame(width: 32, height: 32)
                            .background(.thinMaterial, in: Circle())
                    }
                }
            }
            .frame(height: 92)
            .opacity(isUnlocked ? 1.0 : 0.65)
            .saturation(isUnlocked ? 1.0 : 0.5)

            // Name
            Text(creature.displayName)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Color.Wellness.adaptivePrimaryText)

            // Element subtitle
            Text(creature.subtitle.uppercased())
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText)

            // Status badge
            statusBadge
                .padding(.top, 2)

            // Stage / streak info
            stageLabel
                .font(.system(size: 11))
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .background(Color.Wellness.adaptiveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isActive ? creature.element.primaryColor : Color.clear, lineWidth: 2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Double tap for character details")
    }

    // MARK: - Status Badge

    @ViewBuilder
    private var statusBadge: some View {
        HStack(spacing: 5) {
            if isStreakGated {
                Image(systemName: AppIconSystem.Metric.streak.sfSymbol)
                    .font(.system(size: 9))
                Text(isUnlocked ? "UNLOCKED" : "30-DAY STREAK")
                    .font(.system(size: 10, weight: .semibold))
            } else if isPremium {
                Image(systemName: AppIconSystem.System.premium.sfSymbol)
                    .font(.system(size: 9))
                Text("PLUS")
                    .font(.system(size: 10, weight: .semibold))
            } else {
                Image(systemName: AppIconSystem.System.success.sfSymbol)
                    .font(.system(size: 9))
                Text(isActive ? "FREE · ACTIVE" : "FREE")
                    .font(.system(size: 10, weight: .semibold))
            }
        }
        .foregroundStyle(badgeColor)
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .background(badgeColor.opacity(0.14), in: Capsule())
    }

    private var badgeColor: Color {
        if isStreakGated { return Color(hex: "#7B86CB") }
        if isPremium { return Color(hex: "#FE9901") }
        return Color(hex: "#34C759")
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
