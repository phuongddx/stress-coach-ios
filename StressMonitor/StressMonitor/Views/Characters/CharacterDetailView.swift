import SwiftUI

// MARK: - Character Detail View

/// Character detail screen matching `17-character-detail.html`.
///
/// Shows a hero block (160px character with radial glow + name + role + quote),
/// evolution stage strip (3 stages), 5-mood preview grid, stat pills,
/// personality/strength text blocks, and a primary CTA.
struct CharacterDetailView: View {
    let creature: CharacterCreature
    let unlock: CharacterUnlock?
    var onSelect: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var previewMood: RippleMood = .serene

    private var isUnlocked: Bool { unlock?.isUnlocked ?? false }
    private var isActive: Bool { unlock?.isActive ?? false }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    // Hero
                    heroBlock

                    // Evolution stages
                    VStack(alignment: .leading, spacing: 6) {
                        Text("EVOLUTION · 3 STAGES")
                            .sectionMetaLabel

                        EvolutionStageRow(creature: creature, unlock: unlock)
                    }
                    .padding(.horizontal, 4)

                    // Mood previews (only if unlocked)
                    if isUnlocked {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("5 STRESS MOODS · \(creature.displayName.uppercased()) REACTS")
                                .sectionMetaLabel

                            MoodPreviewGrid(creature: creature, selectedMood: $previewMood)
                                .padding(14)
                                .background(Color.Wellness.adaptiveCardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                        .padding(.horizontal, 4)
                    }

                    // Stat pills
                    if isUnlocked, let unlock {
                        statRow(unlock: unlock)
                    }

                    // Strength section
                    sectionBlock(
                        title: "\(creature.displayName)'s strength",
                        body: strengthText
                    )

                    // Personality section
                    sectionBlock(
                        title: "\(creature.displayName)'s personality",
                        body: "\(creature.personality). \(creature.description)"
                    )

                    // CTA
                    if isUnlocked {
                        ctaButton
                    } else {
                        unlockCTA
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .background(Color.Wellness.adaptiveBackground.ignoresSafeArea())
            .navigationTitle("Companion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Hero Block

    private var heroBlock: some View {
        VStack(spacing: 8) {
            // Character art (160px) with radial glow + bob animation
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [creature.element.primaryColor.opacity(0.20), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)

                StressBuddyIllustration(
                    characterId: creature.id,
                    evolution: unlock?.evolutionStage ?? .droplet,
                    mood: isUnlocked ? previewMood : .serene,
                    size: 160
                )
            }
            .accessibilityHidden(true)

            // Name
            Text(creature.displayName)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .tracking(-0.4)
                .foregroundStyle(Color.Wellness.adaptivePrimaryText)
                .padding(.top, 4)

            // Role
            Text("\(creature.subtitle) · Element of \(creature.element.displayName)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(creature.element.accentColor)

            // Quote
            Text("\"\(quoteText)\"")
                .font(.system(size: 14))
                .italic()
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .background(
            RadialGradient(
                colors: [creature.element.primaryColor.opacity(0.08), Color.Wellness.adaptiveCardBackground],
                center: .top,
                startRadius: 30,
                endRadius: 250
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    // MARK: - Stat Row

    private func statRow(unlock: CharacterUnlock) -> some View {
        HStack(spacing: 8) {
            statPill(
                icon: "waveform.path.ecg",
                value: "+\(Int(unlock.resilienceScore))ms",
                label: "avg HRV gain"
            )
            statPill(
                icon: "clock.fill",
                value: "\(unlock.streakDays) days",
                label: "streak with \(creature.displayName)"
            )
        }
    }

    private func statPill(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(creature.element.primaryColor.opacity(0.15))
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(creature.element.accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.Wellness.adaptivePrimaryText)

                Text(label.uppercased())
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(0.4)
                    .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.Wellness.adaptiveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Section Block

    private func sectionBlock(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.Wellness.adaptivePrimaryText)

            Text(body)
                .font(.system(size: 13))
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.Wellness.adaptiveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - CTA

    @ViewBuilder
    private var ctaButton: some View {
        Button {
            onSelect?()
        } label: {
            Text(isActive ? "\(creature.displayName) is Active" : "Set \(creature.displayName) as Active")
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundStyle(.white)
                .background(
                    isActive
                    ? AnyShapeStyle(creature.element.primaryColor.opacity(0.4))
                    : AnyShapeStyle(creature.element.primaryColor)
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .disabled(isActive)
        .accessibilityHint(isActive ? "Currently active character" : "Set as your active companion")
    }

    // MARK: - Unlock CTA

    @ViewBuilder
    private var unlockCTA: some View {
        VStack(spacing: 12) {
            // Premium creatures are filtered out of the collection while
            // purchases are postponed; the guard keeps the price and the
            // upgrade CTA unreachable even via a stale deep link.
            if creature.unlockType == .premium, PurchaseAvailability.isEnabled {
                Image(systemName: AppIconSystem.System.premium.sfSymbol)
                    .font(.system(size: 36))
                    .foregroundStyle(.orange)

                Text("Premium Character")
                    .font(.system(size: 17, weight: .semibold))

                Text("Unlock with StressMonitor Plus — $4.99/mo")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.Wellness.adaptiveSecondaryText)

                Button("Get StressMonitor Plus") {
                    // Handled by parent navigation
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                .background(creature.element.primaryColor)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else if creature.unlockType == .streakGated {
                Image(systemName: AppIconSystem.Metric.streak.sfSymbol)
                    .font(.system(size: 36))
                    .foregroundStyle(Color(hex: "#7B86CB"))

                Text("\(creature.streakRequired)-Day Streak Required")
                    .font(.system(size: 17, weight: .semibold))

                let current = unlock?.streakDays ?? 0
                Text("Keep logging daily to unlock \(creature.displayName). Current streak: \(current) days.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.Wellness.adaptiveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .multilineTextAlignment(.center)
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
            return "Best for night-time wind-downs and post-conflict recovery. Breathing animations are 4-7-8 biased — slower exhales help activate the parasympathetic vagal response."
        case .earth:
            return "Best for building consistent habits and grounding after overwhelm. Blossom's prompts focus on nature connection and body-awareness check-ins."
        case .fire:
            return "Best for morning motivation and overcoming procrastination. Ember's energy peaks with your activity, nudging you toward movement when stress runs low."
        case .air:
            return "Best for anxiety spikes and racing thoughts. Zephyr's breathing patterns emphasize extended exhales to quickly down-regulate your nervous system."
        case .moon:
            return "Best for sleep optimization and recovery tracking. Lumi glows brighter with consistent sleep, helping you build a sustainable rest rhythm."
        }
    }
}

// MARK: - Section Meta Label Modifier

private struct SectionMetaLabel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .tracking(0.6)
            .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
            .padding(.leading, 4)
            .padding(.bottom, 2)
    }
}

private extension View {
    var sectionMetaLabel: some View { modifier(SectionMetaLabel()) }
}
