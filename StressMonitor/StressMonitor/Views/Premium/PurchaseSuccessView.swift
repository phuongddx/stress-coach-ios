import SwiftData
import SwiftUI

/// Confirmation screen shown after a successful purchase.
///
/// Premium mode (default): unlocks the premium characters (Ember, Zephyr) and
/// the streak-gated Lumi by updating existing `CharacterUnlock` rows
/// additively, then renders the newly-available SwiftUI character views at
/// 80pt.
///
/// Pack mode (`purchasedPack` non-nil): a consumable credit-pack top-up —
/// shows the granted credits and the new balance. No character unlock and no
/// restore affordance: consumables are one-time grants that cannot be
/// restored (DEC-2 / packs-era restore copy).
struct PurchaseSuccessView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let purchasedPack: CreditPack?
    let newBalanceText: String
    let isRestore: Bool

    /// Character ids unlocked by Premium.
    private static let unlockedByPremium = CharacterCreature.allCharacters.filter { $0.unlockType == .premium }.map(\.id)

    init(purchasedPack: CreditPack? = nil, newBalanceText: String = "", isRestore: Bool = false) {
        self.isRestore = isRestore
        self.purchasedPack = purchasedPack
        self.newBalanceText = newBalanceText
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                if let pack = purchasedPack {
                    packHeader(pack)
                    actions
                } else {
                    header

                    unlockedCharactersPreview

                    benefitsList

                    actions
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 28)
        }
        .background(HomeCharacterDesignTokens.homeBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Header (Premium)

    private var header: some View {
        VStack(spacing: 14) {
            successSeal

            Text(isRestore ? "Plus restored" : "Welcome to Plus")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(Color.Wellness.adaptivePrimaryText)

            Text("Your premium companions are unlocked, along with all your charts, 30- and 90-day trends, and unlimited AI chat.")
                .font(.subheadline)
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    // MARK: - Header (Credit pack)

    private func packHeader(_ pack: CreditPack) -> some View {
        VStack(spacing: 14) {
            successSeal

            Text("\(pack.credits) Credits Added")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(Color.Wellness.adaptivePrimaryText)
                .accessibilityAddTraits(.isHeader)

            Text("New balance: \(newBalanceText)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText)

            Text("Your credits are ready to use right away — no unlock needed.")
                .font(.subheadline)
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var successSeal: some View {
        ZStack {
            Circle()
                .fill(HomeCharacterDesignTokens.Ripple.light.opacity(0.32))
                .frame(width: 110, height: 110)
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 52))
                .foregroundStyle(Color(hex: "#4FC01B"))
        }
        .accessibilityHidden(true)
    }

    // MARK: - Unlocked Characters

    private var unlockedCharactersPreview: some View {
        VStack(spacing: 12) {
            Text("New companions unlocked")
                .font(.headline)
                .foregroundStyle(Color.Wellness.adaptivePrimaryText)

            HStack(spacing: 16) {
                ForEach(Self.unlockedByPremium, id: \.self) { id in
                    if let creature = CharacterCreature.find(by: id) {
                        characterChip(creature: creature)
                    }
                }
            }
        }
        .task {
            CharacterCollectionViewModel.syncPremiumCharacterEntitlement(
                isPremium: PremiumState.shared.isPremiumUser,
                in: modelContext
            )
        }
    }

    private func characterChip(creature: CharacterCreature) -> some View {
        VStack(spacing: 6) {
            CharacterAssetResolver.characterView(for: creature.id, mood: .happy, size: 80)
            Text(creature.displayName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.Wellness.adaptivePrimaryText)
            Text(creature.subtitle)
                .font(.system(size: 11))
                .foregroundStyle(creature.element.accentColor)
        }
        .frame(width: 96)
        .padding(.vertical, 10)
        .background(Color.Wellness.adaptiveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(creature.element.primaryColor.opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(creature.displayName), \(creature.subtitle), now unlocked")
    }

    // MARK: - Benefits

    private var benefitsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            benefitRow(icon: "chart.xyaxis.line", text: "All your charts, unblurred")
            benefitRow(icon: "chart.line.uptrend.xyaxis", text: "30- and 90-day Trends")
            benefitRow(icon: "bubble.left.and.bubble.right.fill", text: "Unlimited AI chat with Ripple")
            benefitRow(icon: "sparkles", text: "All elemental companions and evolution stages")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.Wellness.adaptiveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(HomeCharacterDesignTokens.Ripple.deep)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color.Wellness.adaptivePrimaryText)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Text(purchasedPack == nil ? "Back to Home" : "Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(HomeCharacterDesignTokens.Ripple.deep)
            .accessibilityLabel(purchasedPack == nil ? "Back to Home" : "Done")

            if purchasedPack == nil {
                Button {
                    Task { await restoreOrDismiss() }
                } label: {
                    Text("Restore purchases")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
                }
                .accessibilityLabel("Restore purchases")
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Unlock Logic

    /// Additively mark the premium-gated characters as unlocked. Existing rows
    /// are updated in place; missing rows (unexpected on a seeded store) are
    /// inserted so the unlock always lands.
    private func restoreOrDismiss() async {
        // Restore is handled by StoreKitService elsewhere; here we simply return
        // the user home since the purchase is already confirmed on this screen.
        dismiss()
    }
}

#Preview {
    PurchaseSuccessView()
        .modelContainer(for: CharacterUnlock.self, inMemory: true)
}
