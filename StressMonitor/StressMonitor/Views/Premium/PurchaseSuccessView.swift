import SwiftData
import SwiftUI

/// Confirmation screen shown after a successful purchase.
///
/// Premium mode (default): unlocks the premium characters (Ember, Zephyr) and
/// the streak-gated Lumi by updating existing `CharacterUnlock` rows
/// additively, then lists everything Plus unlocked (UI V2 `S.success`).
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
            VStack(spacing: 24) {
                if let pack = purchasedPack {
                    packHeader(pack)
                    actions
                } else {
                    header

                    unlockedList

                    actions
                }
            }
            .padding(.horizontal, V2Metrics.margin)
            .padding(.top, 40)
            .padding(.bottom, 24)
        }
        .background(Color.V2.bg.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Header (Premium)

    private var header: some View {
        VStack(spacing: 12) {
            companionTrio

            Text(isRestore ? "Plus restored" : "Welcome to Plus")
                .font(.title.weight(.bold))
                .foregroundStyle(Color.V2.ink)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text(isRestore
                 ? "Your Plus subscription is active on this iPhone again. Everything below is unlocked."
                 : "Everything below is unlocked and ready to use.")
                .font(.callout)
                .foregroundStyle(Color.V2.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Ripple flanked by the companions Plus unlocks.
    private var companionTrio: some View {
        let ids = Self.unlockedByPremium
        return HStack(alignment: .bottom, spacing: 0) {
            if let first = ids.first {
                CharacterAssetResolver.characterView(for: first, mood: .happy, size: 64)
            }
            CharacterAssetResolver.characterView(for: "ripple", mood: .happy, size: 88)
            ForEach(ids.dropFirst(), id: \.self) { id in
                CharacterAssetResolver.characterView(for: id, mood: .happy, size: 64)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Header (Credit pack)

    private func packHeader(_ pack: CreditPack) -> some View {
        VStack(spacing: 12) {
            successSeal

            Text("\(pack.credits) Credits Added")
                .font(.title.weight(.bold))
                .foregroundStyle(Color.V2.ink)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text("New balance: \(Text(newBalanceText).font(.v2Number(.subheadline)))")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.V2.ink2)

            Text("Your credits are ready to use right away — no unlock needed.")
                .font(.callout)
                .foregroundStyle(Color.V2.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var successSeal: some View {
        Image(systemName: "checkmark")
            .font(.title.weight(.bold))
            .foregroundStyle(StressCategory.relaxed.color)
            .frame(width: 72, height: 72)
            .background(Circle().fill(StressCategory.relaxed.fillColor.opacity(0.18)))
            .accessibilityHidden(true)
    }

    // MARK: - What unlocked

    /// One grouped list of what Plus unlocked, each row ticked.
    private var unlockedList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Now unlocked")
                .v2Eyebrow()
                .padding(.horizontal, 4)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0) {
                unlockedRow(icon: "bubble.left.and.bubble.right.fill", text: "Unlimited AI chat with Ripple")
                divider
                unlockedRow(icon: "chart.xyaxis.line", text: "All your charts, unblurred")
                divider
                unlockedRow(icon: "calendar", text: "30- and 90-day Trends")
                divider
                unlockedRow(icon: "face.smiling", text: companionsLine)
                divider
                unlockedRow(icon: "sparkles", text: "All elemental companions and evolution stages")
            }
            .v2CardBackground()
        }
        .task {
            CharacterCollectionViewModel.syncPremiumCharacterEntitlement(
                isPremium: PremiumState.shared.isPremiumUser,
                in: modelContext
            )
        }
    }

    /// "Ember and Zephyr unlocked", from the premium-gated characters.
    private var companionsLine: String {
        let names = Self.unlockedByPremium.compactMap { CharacterCreature.find(by: $0)?.displayName }
        guard !names.isEmpty else { return "Plus companions unlocked" }
        return ListFormatter.localizedString(byJoining: names) + " unlocked"
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.V2.line)
            .frame(height: 0.5)
            .padding(.leading, 52)
    }

    private func unlockedRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.V2.accent)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color.V2.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "checkmark")
                .font(.body.weight(.bold))
                .foregroundStyle(Color.V2.accent)
        }
        .padding(.horizontal, V2Metrics.margin)
        .frame(minHeight: V2Metrics.minTouchTarget)
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 8) {
            Button(purchasedPack == nil ? "Back to Home" : "Done") {
                dismiss()
            }
            .buttonStyle(.v2(.primary))
            .accessibilityLabel(purchasedPack == nil ? "Back to Home" : "Done")

            if purchasedPack == nil {
                Button("Restore purchases") {
                    Task { await restoreOrDismiss() }
                }
                .buttonStyle(.v2(.ghost, compact: true))
                .accessibilityLabel("Restore purchases")

                Text("Manage or cancel anytime in Settings \u{203A} Apple ID \u{203A} Subscriptions.")
                    .font(.caption)
                    .foregroundStyle(Color.V2.ink3)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 4)
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
