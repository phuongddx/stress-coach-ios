import SwiftUI

// MARK: - Character Detail View

/// Character detail screen (UI V2, `S.charDetail`).
///
/// Hero (companion-tinted circle, name, role, quote), moods (when unlocked),
/// evolution list, streak stat, strength/personality cards and either the
/// "set as companion" action or the unlock requirement.
struct CharacterDetailView: View {
    let creature: CharacterCreature
    let unlock: CharacterUnlock?
    var onSelect: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(PaywallController.self) private var paywall
    @State private var previewMood: RippleMood = .serene

    private var isUnlocked: Bool { unlock?.isUnlocked ?? false }
    private var isActive: Bool { unlock?.isActive ?? false }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    heroBlock

                    // Mood previews (only if unlocked)
                    if isUnlocked {
                        VStack(alignment: .leading, spacing: 8) {
                            sectionHeader("Moods")
                            MoodPreviewGrid(creature: creature, selectedMood: $previewMood)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        sectionHeader("Evolution")
                        EvolutionStageRow(creature: creature, unlock: unlock)
                    }

                    if isUnlocked, let unlock {
                        statRow(unlock: unlock)
                    }

                    sectionBlock(
                        title: "\(creature.displayName)'s strength",
                        body: strengthText
                    )

                    sectionBlock(
                        title: "\(creature.displayName)'s personality",
                        body: "\(creature.personality). \(creature.description)"
                    )

                    if isUnlocked {
                        ctaButton
                    } else {
                        unlockCTA
                    }
                }
                .padding(.horizontal, V2Metrics.margin)
                .padding(.bottom, 40)
            }
            .background(Color.V2.bg.ignoresSafeArea())
            .navigationTitle("Companion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.V2.accent)
                }
            }
        }
    }

    // MARK: - Hero Block

    private var roleText: String {
        if isUnlocked { return "\(creature.subtitle) · Unlocked" }
        switch creature.unlockType {
        case .premium: return "\(creature.subtitle) · Plus companion"
        case .streakGated: return "\(creature.subtitle) · \(creature.streakRequired)-day streak"
        default: return creature.subtitle
        }
    }

    private var heroBlock: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(creature.element.v2Tint.opacity(0.22))
                    .frame(width: 180, height: 180)

                // Ripple draws the previewed tier's level pose; other
                // companions ignore `pose`.
                StressBuddyIllustration(
                    characterId: creature.id,
                    evolution: unlock?.evolutionStage ?? .droplet,
                    mood: isUnlocked ? previewMood : .serene,
                    size: 140,
                    pose: isUnlocked ? StressMoodCell.ripplePose(for: previewMood) : .base
                )
                .opacity(isUnlocked ? 1 : 0.65)
                .saturation(isUnlocked ? 1 : 0.5)
            }
            .accessibilityHidden(true)

            Text(creature.displayName)
                .font(.title.weight(.bold))
                .foregroundStyle(Color.V2.ink)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 4)

            Text(roleText)
                .font(.subheadline)
                .foregroundStyle(Color.V2.ink2)
                .multilineTextAlignment(.center)

            Text("\"\(quoteText)\"")
                .font(.callout)
                .italic()
                .foregroundStyle(Color.V2.ink2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(Color.V2.ink)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Stat Row

    private func statRow(unlock: CharacterUnlock) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.fill")
                .font(.body)
                .foregroundStyle(Color.V2.accent)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: V2Metrics.radiusXS, style: .continuous)
                        .fill(Color.V2.accentSoft)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(unlock.streakDays) \(unlock.streakDays == 1 ? "day" : "days")")
                    .font(.v2Number(.title3, weight: .bold))
                    .foregroundStyle(Color.V2.ink)
                Text("Reading streak")
                    .font(.footnote)
                    .foregroundStyle(Color.V2.ink3)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .v2CardBackground()
        .accessibilityElement(children: .combine)
    }

    // MARK: - Section Block

    private func sectionBlock(title: String, body: String) -> some View {
        V2Card {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.V2.ink)
                Text(body)
                    .font(.callout)
                    .foregroundStyle(Color.V2.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - CTA

    private var ctaButton: some View {
        Button {
            onSelect?()
        } label: {
            Text(isActive ? "\(creature.displayName) is your companion" : "Set as companion")
        }
        .buttonStyle(.v2(.primary))
        .disabled(isActive)
        .accessibilityHint(isActive ? "Currently active character" : "Set as your active companion")
        .padding(.top, 4)
    }

    // MARK: - Unlock CTA

    @ViewBuilder
    private var unlockCTA: some View {
        // The `PurchaseAvailability.isEnabled` guard keeps the upgrade copy
        // and buy path unreachable if purchases are ever postponed again,
        // including via a stale deep link.
        if creature.unlockType == .premium, PurchaseAvailability.isEnabled {
            Button {
                paywall.present(reason: .characters)
            } label: {
                V2Card(style: .flat) {
                    VStack(alignment: .leading, spacing: 8) {
                        V2PlusPill(showsLock: true)
                        Text("Plus companion")
                            .font(.headline)
                            .foregroundStyle(Color.V2.ink)
                        Text("Unlock with StressMonitor Plus")
                            .font(.callout)
                            .foregroundStyle(Color.V2.ink2)
                        Text("Ember and Zephyr come with Plus. Lumi unlocks with a 30-day streak.")
                            .font(.footnote)
                            .foregroundStyle(Color.V2.ink3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Opens StressMonitor Plus")
        } else if creature.unlockType == .streakGated {
            let current = unlock?.streakDays ?? 0
            let progress = min(Double(current) / Double(max(creature.streakRequired, 1)), 1)
            V2Card(style: .flat) {
                VStack(alignment: .leading, spacing: 8) {
                    CharacterTag(
                        title: "\(creature.streakRequired)-day streak",
                        systemImage: AppIconSystem.Metric.streak.sfSymbol
                    )
                    Text("\(creature.streakRequired)-day streak required")
                        .font(.headline)
                        .foregroundStyle(Color.V2.ink)
                    Text("Keep logging daily to unlock \(creature.displayName). Current streak: \(current) \(current == 1 ? "day" : "days").")
                        .font(.callout)
                        .foregroundStyle(Color.V2.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.V2.surface3)
                            Capsule()
                                .fill(creature.element.v2Tint)
                                .frame(width: geo.size.width * progress)
                        }
                    }
                    .frame(height: 6)
                    .accessibilityHidden(true)
                    Text("\(min(current, creature.streakRequired)) of \(creature.streakRequired) days · not part of Plus")
                        .font(.v2Number(.footnote))
                        .foregroundStyle(Color.V2.ink3)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Character Copy

    /// Element-specific quote matching the HTML design's voice.
    private var quoteText: String {
        switch creature.element {
        case .water: return "Stress is just ripples on the surface. I'll help you find the still water underneath."
        case .earth: return "Roots grow deepest in quiet soil. Let's ground together."
        case .fire:  return "Every flame starts with a spark. Let me kindle yours."
        case .air:   return "Breathe. The wind carries what weighs you down away."
        case .moon:  return "Even in darkness, there's light. I'll help you find your rhythm."
        }
    }

    private var strengthText: String {
        switch creature.element {
        case .water:
            return "Ripple is a calm presence for night-time wind-downs and the moments after a rough conflict."
        case .earth:
            return "Blossom is a steady companion for building daily habits and grounding yourself after feeling overwhelmed."
        case .fire:
            return "Ember brings morning motivation and a bit of spark when procrastination creeps in."
        case .air:
            return "Zephyr is a light companion for anxious spikes and racing thoughts."
        case .moon:
            return "Lumi is a quiet companion for winding down and keeping a restful rhythm."
        }
    }
}
