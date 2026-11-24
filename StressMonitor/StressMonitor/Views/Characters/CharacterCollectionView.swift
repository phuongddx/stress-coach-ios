import SwiftData
import SwiftUI

// MARK: - Character Collection View

/// Character collection screen (UI V2, `S.characters`).
///
/// Displays a 2-column grid of the companions with status tags, a full-width
/// Lumi streak card, an evolution explainer and a "why elemental companions"
/// note. Companion art is unchanged; everything around it uses V2 tokens.
struct CharacterCollectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var viewModel = CharacterCollectionViewModel()
    @State private var selectedCharacter: CharacterCreature?

    // MARK: - Computed

    private var unlockedCount: Int {
        CharacterCreature.offeredCharacters.filter { isUnlocked($0.id) }.count
    }
    private var totalCount: Int { CharacterCreature.offeredCharacters.count }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                headerSection
                    .padding(.top, 4)

                characterGrid

                lumiStreakCard

                evolutionBanner

                legendCard

                Text("Companions change Ripple's look across the app, widgets and Apple Watch.")
                    .font(.footnote)
                    .foregroundStyle(Color.V2.ink3)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
            .padding(.horizontal, V2Metrics.margin)
            .padding(.bottom, 40)
        }
        .background(Color.V2.bg.ignoresSafeArea())
        .accessibleDynamicType()
        .navigationTitle("Characters")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedCharacter) { creature in
            CharacterDetailView(
                creature: creature,
                unlock: viewModel.unlockStatus(for: creature.id),
                onSelect: {
                    viewModel.selectCharacter(creature.id)
                    selectedCharacter = nil
                }
            )
        }
        .onAppear {
            viewModel.configure(modelContext: modelContext)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(unlockedCount) of \(totalCount) unlocked")
                .v2Eyebrow()

            Text("Elemental companions")
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.V2.ink)
                .accessibilityAddTraits(.isHeader)
        }
    }

    // MARK: - Character Grid

    private var characterGrid: some View {
        let columnCount = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: columnCount),
            spacing: 12
        ) {
            // Show all characters except Lumi (Lumi gets full-width card below)
            ForEach(CharacterCreature.offeredCharacters.filter { $0.id != "lumi" }) { creature in
                Button {
                    selectedCharacter = creature
                    HapticManager.shared.buttonPress()
                } label: {
                    CharacterGridCard(
                        creature: creature,
                        unlock: viewModel.unlockStatus(for: creature.id),
                        isActive: viewModel.activeCharacterId == creature.id,
                        mood: viewModel.currentMood
                    )
                    .contentShape(RoundedRectangle(cornerRadius: V2Metrics.radiusLG))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Lumi Streak Card (full-width)

    @ViewBuilder
    private var lumiStreakCard: some View {
        if let lumi = CharacterCreature.find(by: "lumi") {
            let unlock = viewModel.unlockStatus(for: lumi.id)
            let isUnlocked = unlock?.isUnlocked ?? false
            let currentStreak = unlock?.streakDays ?? 0
            let progress = min(Double(currentStreak) / Double(max(lumi.streakRequired, 1)), 1.0)

            Button {
                selectedCharacter = lumi
                HapticManager.shared.buttonPress()
            } label: {
                lumiCardContent(
                    lumi: lumi,
                    unlock: unlock,
                    isUnlocked: isUnlocked,
                    currentStreak: currentStreak,
                    progress: progress
                )
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(lumiAccessibilityLabel(lumi: lumi, isUnlocked: isUnlocked))
            .accessibilityValue("Evolution stage \((unlock?.evolutionStage ?? .droplet).sortOrder + 1) of \(EvolutionStage.allCases.count)")
            .accessibilityHint("Double tap for character details")
        }
    }

    private func lumiCardContent(
        lumi: CharacterCreature,
        unlock: CharacterUnlock?,
        isUnlocked: Bool,
        currentStreak: Int,
        progress: Double
    ) -> some View {
        let art = ZStack {
            Circle()
                .fill(lumi.element.v2Tint.opacity(0.22))
                .frame(width: 76, height: 76)

            StressBuddyIllustration(
                characterId: lumi.id,
                evolution: unlock?.evolutionStage ?? .droplet,
                mood: viewModel.currentMood,
                size: 64
            )
            .opacity(isUnlocked ? 1 : 0.65)
            .saturation(isUnlocked ? 1 : 0.5)
        }
        .frame(width: 80, height: 80)

        let info = VStack(alignment: .leading, spacing: 4) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    lumiTitle(lumi)
                    Spacer(minLength: 8)
                    lumiTag(lumi, isUnlocked: isUnlocked)
                }
                VStack(alignment: .leading, spacing: 4) {
                    lumiTitle(lumi)
                    lumiTag(lumi, isUnlocked: isUnlocked)
                }
            }

            Text(lumi.subtitle)
                .font(.caption)
                .foregroundStyle(Color.V2.ink3)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.V2.surface2)
                    Capsule()
                        .fill(lumi.element.v2Tint)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 6)
            .padding(.top, 6)
            .accessibilityHidden(true)

            Text("\(min(currentStreak, lumi.streakRequired)) of \(lumi.streakRequired) days · not part of Plus")
                .font(.footnote)
                .foregroundStyle(Color.V2.ink2)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) { art; info }
            } else {
                HStack(spacing: 14) { art; info }
            }
        }
        .padding(V2Metrics.margin)
        .frame(maxWidth: .infinity, alignment: .leading)
        .v2CardBackground()
        .contentShape(RoundedRectangle(cornerRadius: V2Metrics.radiusLG))
    }

    private func lumiTitle(_ lumi: CharacterCreature) -> some View {
        Text(lumi.displayName)
            .font(.headline)
            .foregroundStyle(Color.V2.ink)
    }

    private func lumiTag(_ lumi: CharacterCreature, isUnlocked: Bool) -> some View {
        CharacterTag(
            title: isUnlocked ? "Unlocked" : "\(lumi.streakRequired)-day streak",
            systemImage: AppIconSystem.Metric.streak.sfSymbol
        )
    }

    // MARK: - Evolution Banner

    private var evolutionBanner: some View {
        HStack(spacing: 14) {
            stageProgressionViz
            evolutionBannerText
            Spacer(minLength: 0)
        }
        .padding(V2Metrics.margin)
        .frame(maxWidth: .infinity, alignment: .leading)
        .v2CardBackground(.tint)
    }

    private var stageProgressionViz: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.V2.accent.opacity(0.14 + Double(i) * 0.1))
                    .frame(width: 30, height: 30 + CGFloat(i) * 6)
                    .overlay {
                        Image(systemName: "circle.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.V2.accent)
                    }
            }
        }
        .accessibilityHidden(true)
    }

    private var evolutionBannerText: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Each character evolves 3 stages")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.V2.ink)

            Text("Take a reading every day — forms change after a 30-day and a 90-day streak.")
                .font(.footnote)
                .foregroundStyle(Color.V2.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Legend Card

    private var legendCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.V2.accent)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.V2.accentSoft))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Why elemental companions?")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.V2.ink)

                Text("Each maps to a stress-recovery archetype — water for calm, forest for grounding, fire for energy, wind for lightness, stars for rest.")
                    .font(.footnote)
                    .foregroundStyle(Color.V2.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .v2CardBackground(.flat)
    }

    // MARK: - Helpers

    private func isUnlocked(_ characterId: String) -> Bool {
        viewModel.unlockStatus(for: characterId)?.isUnlocked ?? false
    }

    private func lumiAccessibilityLabel(lumi: CharacterCreature, isUnlocked: Bool) -> String {
        let stage = viewModel.unlockStatus(for: lumi.id)?.evolutionStage ?? .droplet
        if isUnlocked {
            return "\(lumi.displayName), \(stage.displayName.lowercased()) stage"
        }
        return "\(lumi.displayName), locked"
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CharacterCollectionView()
    }
    .modelContainer(for: CharacterUnlock.self, inMemory: true)
}
