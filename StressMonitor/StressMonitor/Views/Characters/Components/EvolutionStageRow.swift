import SwiftUI

// MARK: - Evolution Stage Row

/// Horizontal strip of 3 evolution stage cards, matching `17-character-detail.html`.
///
/// Each card shows a small character glyph, stage name, and requirement text.
/// Unlocked stages get a colored border; locked stages are faded.
struct EvolutionStageRow: View {
    let creature: CharacterCreature
    let unlock: CharacterUnlock?

    private var currentStage: EvolutionStage { unlock?.evolutionStage ?? .droplet }
    private var isUnlocked: Bool { unlock?.isUnlocked ?? false }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(EvolutionStage.allCases.enumerated()), id: \.element) { index, stage in
                stageCard(stage: stage, index: index)
            }
        }
    }

    @ViewBuilder
    private func stageCard(stage: EvolutionStage, index: Int) -> some View {
        let isThisUnlocked = isUnlocked && currentStage.sortOrder >= stage.sortOrder
        let requirement = creature.evolutionRequirement(for: stage)

        VStack(spacing: 6) {
            // Mini character circle
            ZStack {
                Circle()
                    .fill(isThisUnlocked
                          ? creature.element.primaryColor
                          : creature.element.primaryColor.opacity(0.18))
                    .frame(width: 40, height: 40)

                if isThisUnlocked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: AppIconSystem.System.locked.sfSymbol)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
                }
            }
            .accessibilityHidden(true)

            // Stage name
            Text(stageName(for: stage, index: index))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.Wellness.adaptivePrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7) // dated exception 2026-09-05: N-across stage name cannot wrap; fixed font

            // Requirement
            Text(stageRequirementText(stage: stage, requirement: requirement, isThisUnlocked: isThisUnlocked))
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .tracking(0.4)
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7) // dated exception 2026-09-05: last-resort clamp after 2-line wrap; fixed font
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(Color.Wellness.adaptiveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isThisUnlocked ? creature.element.primaryColor : Color.clear, lineWidth: 2)
        }
        .opacity(isThisUnlocked ? 1.0 : 0.5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(stageName(for: stage, index: index)), \(isThisUnlocked ? "unlocked" : "locked")")
    }

    // MARK: - Stage Names

    /// Element-specific stage names matching the HTML (Ripple: Tadpole/River/Ocean).
    private func stageName(for stage: EvolutionStage, index: Int) -> String {
        // Each element has its own thematic names for the 3 stages
        let names: [CharacterElement: [String]] = [
            .water: ["Tadpole", "River", "Ocean"],
            .earth: ["Sprout", "Sapling", "Elder"],
            .fire:  ["Spark", "Ember", "Blaze"],
            .air:   ["Breeze", "Gust", "Tempest"],
            .moon:  ["Moonlet", "Crescent", "Full Moon"],
        ]
        return names[creature.element]?[index] ?? stage.displayName
    }

    private func stageRequirementText(
        stage: EvolutionStage,
        requirement: EvolutionRequirement,
        isThisUnlocked: Bool
    ) -> String {
        if isThisUnlocked {
            switch stage {
            case .droplet: return "DAY 1 · ACTIVE"
            case .ripple:  return "DAY 30"
            case .tidal:   return "DAY 90"
            }
        }
        switch stage {
        case .droplet: return "DAY 1"
        case .ripple:  return "\(requirement.streakDays) DAYS + \(requirement.sessionsCompleted) BREATHING SESSIONS"
        case .tidal:   return "\(requirement.streakDays) DAYS"
        }
    }
}
