import SwiftUI

// MARK: - Evolution Stage Row

/// Evolution stages as a grouped list (UI V2, `S.charDetail` "Evolution").
///
/// Each row shows a status tile, the element-specific stage name and its
/// requirement. The current stage of an unlocked companion carries a "Now" tag.
struct EvolutionStageRow: View {
    let creature: CharacterCreature
    let unlock: CharacterUnlock?

    private var currentStage: EvolutionStage { unlock?.evolutionStage ?? .droplet }
    private var isUnlocked: Bool { unlock?.isUnlocked ?? false }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(EvolutionStage.allCases.enumerated()), id: \.element) { index, stage in
                if index > 0 {
                    Rectangle()
                        .fill(Color.V2.line)
                        .frame(height: 0.5)
                        .padding(.leading, 60)
                }
                stageRow(stage: stage, index: index)
            }
        }
        .v2CardBackground()
    }

    @ViewBuilder
    private func stageRow(stage: EvolutionStage, index: Int) -> some View {
        let isThisUnlocked = isUnlocked && currentStage.sortOrder >= stage.sortOrder
        let isCurrent = isUnlocked && currentStage == stage
        let requirement = creature.evolutionRequirement(for: stage)

        HStack(spacing: 12) {
            Image(systemName: isThisUnlocked ? "checkmark" : AppIconSystem.System.locked.sfSymbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isThisUnlocked ? Color.V2.onAccent : Color.V2.ink2)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: V2Metrics.radiusXS, style: .continuous)
                        .fill(isThisUnlocked ? Color.V2.accent : Color.V2.surface3)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(stageName(for: stage, index: index))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.V2.ink)
                Text(stageRequirementText(stage: stage, requirement: requirement, isThisUnlocked: isThisUnlocked))
                    .font(.footnote)
                    .foregroundStyle(Color.V2.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isCurrent {
                CharacterTag(title: "Now", style: .accent)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: V2Metrics.minTouchTarget)
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
            case .droplet: return "Where every companion starts"
            case .ripple:  return "Reached on day 30"
            case .tidal:   return "Reached on day 90"
            }
        }
        switch stage {
        case .droplet: return "Where every companion starts"
        case .ripple:  return "\(requirement.streakDays)-day streak + \(requirement.sessionsCompleted) breathing sessions"
        case .tidal:   return "\(requirement.streakDays)-day streak"
        }
    }
}
