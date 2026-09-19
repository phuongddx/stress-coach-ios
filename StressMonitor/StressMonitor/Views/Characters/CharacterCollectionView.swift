import SwiftData
import SwiftUI

// MARK: - Character Collection View

/// Character collection screen matching `16-characters.html`.
///
/// Displays a 2-column grid of all 5 characters with unlock status badges,
/// an evolution explainer banner, and a "why elemental companions" legend card.
struct CharacterCollectionView: View {
    @Environment(\.modelContext) private var modelContext
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
            VStack(alignment: .leading, spacing: 14) {
                // Header
                headerSection
                    .padding(.horizontal, 16)
                        .padding(.top, 4)

                // Character grid (2 columns)
                characterGrid
                    .padding(.horizontal, 16)

                // Lumi streak card (full-width)
                lumiStreakCard
                    .padding(.horizontal, 16)

                // Evolution banner
                evolutionBanner
                    .padding(.horizontal, 16)

                // Legend card
                legendCard
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
            }
            .padding(.bottom, 40)
        }
        .background(Color.Wellness.adaptiveBackground.ignoresSafeArea())
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
            Text("\(unlockedCount) of \(totalCount) unlocked".uppercased())
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText)

            Text("Elemental companions")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.Wellness.adaptivePrimaryText)
        }
    }

    // MARK: - Character Grid

    private var characterGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
            ],
            spacing: 12
        ) {
            // Show all characters except Lumi (Lumi gets full-width card below)
            ForEach(CharacterCreature.offeredCharacters.filter { $0.id != "lumi" }) { creature in
                CharacterGridCard(
                    creature: creature,
                    unlock: viewModel.unlockStatus(for: creature.id),
                    isActive: viewModel.activeCharacterId == creature.id,
                    mood: viewModel.currentMood
                )
                .contentShape(RoundedRectangle(cornerRadius: 18))
                .onTapGesture {
                    selectedCharacter = creature
                    HapticManager.shared.buttonPress()
                }
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
            let progress = min(Double(currentStreak) / Double(lumi.streakRequired), 1.0)
            let daysToGo = max(lumi.streakRequired - currentStreak, 0)

            HStack(spacing: 16) {
                // Lumi art
                ZStack {
                    Circle()
                        .fill(lumi.element.primaryColor.opacity(0.55))
                        .frame(width: 70, height: 70)
                        .blur(radius: 16)

                    StressBuddyIllustration(
                        characterId: lumi.id,
                        evolution: unlock?.evolutionStage ?? .droplet,
                        mood: viewModel.currentMood,
                        size: 72
                    )
                    .opacity(isUnlocked ? 1 : 0.65)
                    .saturation(isUnlocked ? 1 : 0.5)
                }
                .frame(width: 92, height: 92)

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(lumi.displayName)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.Wellness.adaptivePrimaryText)

                    Text(lumi.subtitle.uppercased())
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .tracking(0.6)
                        .foregroundStyle(Color.Wellness.adaptiveSecondaryText)

                    // Streak badge
                    HStack(spacing: 4) {
                        Image(systemName: AppIconSystem.Metric.streak.sfSymbol)
                            .font(.system(size: 9))
                        Text("30-DAY STREAK")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(Color(hex: "#7B86CB"))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(Color(hex: "#7B86CB").opacity(0.14), in: Capsule())
                    .padding(.top, 2)

                    Text("\(daysToGo) days to go · current \(currentStreak)d")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
                        .padding(.top, 2)

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(hex: "#7B86CB").opacity(0.18))
                                .frame(height: 6)

                            Capsule()
                                .fill(Color(hex: "#7B86CB"))
                                .frame(width: geo.size.width * progress, height: 6)
                        }
                    }
                    .frame(height: 6)
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(Color.Wellness.adaptiveCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 18))
            .onTapGesture {
                selectedCharacter = lumi
                HapticManager.shared.buttonPress()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(lumiAccessibilityLabel(lumi: lumi, isUnlocked: isUnlocked))
            .accessibilityValue("Evolution stage \((unlock?.evolutionStage ?? .droplet).sortOrder + 1) of \(EvolutionStage.allCases.count)")
            .accessibilityHint("Double tap for character details")
        }
    }

    // MARK: - Evolution Banner

    private var evolutionBanner: some View {
        HStack(spacing: 14) {
            stageProgressionViz
            evolutionBannerText
            Spacer()
        }
        .padding(16)
        .background(evolutionBannerGradient)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(bannerBorder)
    }

    private var stageProgressionViz: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color(hex: "#7B86CB").opacity(0.18 + Double(i) * 0.12))
                    .frame(width: 36, height: 36 + CGFloat(i) * 6)
                    .overlay {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: "#7B86CB"))
                    }
            }
        }
    }

    private var evolutionBannerText: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Each character evolves 3 stages")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.Wellness.adaptivePrimaryText)

            Text("Stay consistent — forms change, new animations unlock at 30, 90, 180 days.")
                .font(.system(size: 12))
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
                .lineSpacing(3)
        }
    }

    private var evolutionBannerGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: "#7B86CB").opacity(0.14),
                Color(hex: "#4FC3F7").opacity(0.10),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var bannerBorder: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(Color.Wellness.adaptiveSecondaryText.opacity(0.15), lineWidth: 1)
    }

    // MARK: - Legend Card

    private var legendCard: some View {
        HStack(spacing: 12) {
            // Gradient icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#4FC3F7"), // Ripple
                                Color(hex: "#A5D6A7"), // Blossom
                                Color(hex: "#FFAB91"), // Ember
                                Color(hex: "#D1C4E9"), // Zephyr
                                Color(hex: "#7986CB"), // Lumi
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)

                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Why elemental companions?")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.Wellness.adaptivePrimaryText)

                Text("Each maps to a stress-recovery archetype — water for calm, forest for grounding, fire for energy, wind for lightness, stars for rest.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
                    .lineSpacing(3)
            }
        }
        .padding(14)
        .background(Color.Wellness.adaptiveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
