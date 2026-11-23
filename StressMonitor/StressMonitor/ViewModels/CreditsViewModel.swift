import Foundation
import Observation

// MARK: - Credit Balance Formatter

/// The single source of balance display strings. Every surface (paywall
/// header, chat pill, Settings rows, purchase success) routes through here so
/// the strings cannot diverge, the premium sentinel is never formatted, and a
/// missing balance renders a neutral placeholder instead of an
/// authoritative-looking zero.
enum CreditBalanceFormatter {
    /// Neutral placeholder while no balance has converged. Deliberately not
    /// "0 credits" — a zero would read as server-authoritative depletion.
    static let unavailableText = "—"

    /// Below this remaining count the chat warns that free messages are
    /// running out (SPEC Q4: 5 of the 20 monthly free messages).
    static let shortResponseThreshold = 5

    /// Shown when chat is refused because the monthly free messages are used
    /// up. 1.1 sells only Plus, so the copy never offers credit top-ups.
    static let outOfFreeMessagesText = "You've used your 20 free messages this month. Plus gives you unlimited chat."

    static func balanceText(_ balance: CreditBalance?) -> String {
        guard let balance else { return unavailableText }
        return balance.displayDescription
    }

    static func resetDateText(_ balance: CreditBalance?) -> String? {
        guard let balance, !balance.isUnlimited, let iso = balance.freeResetAt else { return nil }
        guard let date = isoParser.date(from: iso) else { return nil }
        return "Resets \(date.formatted(date: .abbreviated, time: .omitted))"
    }

    /// True when the remaining count has crossed the backend's token-tier
    /// threshold — the surface should set the expectation that AI responses
    /// get shorter until the user tops up (research Pitfall 5).
    static func isLowCredits(_ balance: CreditBalance?) -> Bool {
        guard let balance, !balance.isUnlimited else { return false }
        return balance.remaining < shortResponseThreshold
    }

    /// Settings chat-row value: availability beside the shared balance
    /// string. A not-yet-converged balance keeps the plain availability
    /// label rather than inventing a count.
    static func chatRowValue(available: Bool, balance: CreditBalance?) -> String {
        guard available else { return "Coming soon" }
        guard let balance else { return "Active" }
        return "Active · \(balanceText(balance))"
    }

    /// Settings "StressMonitor Plus" row value: live subscription state
    /// instead of the static teaser — premium is active, a free tier shows
    /// the remaining count, and an unknown balance falls back to the teaser.
    static func plusRowValue(_ balance: CreditBalance?) -> String {
        guard let balance else { return "Try free" }
        if balance.isUnlimited { return "Active" }
        return "\(balance.remaining) credits left"
    }

    private static let isoParser = ISO8601DateFormatter()
}

// MARK: - Credits View Model

/// Packs-era purchase state machine — the `PremiumViewModel` analog for
/// consumable credit packs.
///
/// Success is derived from the observed `CreditService` balance change after
/// the purchase call returns, never from the call returning alone: the server
/// is the sole credit authority, and the service layer applies the redeemed
/// balance during the purchase flow.
@MainActor
@Observable
final class CreditsViewModel {
    let creditService: CreditServiceProtocol
    let storeKit: StoreKitServiceProtocol

    var selectedPack: CreditPackID?
    var packs: [CreditPack] = []
    var isLoading = false
    var showError = false
    var errorMessage: String?
    var showSuccess = false

    /// Pack granted by the last successful purchase — feeds the success view.
    private(set) var purchasedPack: CreditPack?

    init(creditService: CreditServiceProtocol, storeKit: StoreKitServiceProtocol) {
        self.creditService = creditService
        self.storeKit = storeKit
    }

    var selectedPackDetails: CreditPack? {
        packs.first { $0.id == selectedPack }
    }

    var currentBalanceText: String {
        CreditBalanceFormatter.balanceText(creditService.balance)
    }

    func loadPacks() async {
        packs = await storeKit.availablePacks
    }

    func purchaseSelectedPack() async {
        isLoading = true
        defer { isLoading = false }

        guard let pack = selectedPackDetails else {
            errorMessage = "Pack not available. Please try again."
            showError = true
            return
        }

        let balanceBefore = creditService.balance
        do {
            try await storeKit.purchase(pack: pack)
            // Derive success from the post-purchase server balance, not from
            // the purchase call's return alone.
            if creditService.balance != balanceBefore {
                purchasedPack = pack
                showSuccess = true
            }
        } catch StoreKitError.purchaseCancelled {
            // User cancelled — silent
        } catch StoreKitError.purchasePending {
            errorMessage = StoreKitError.purchasePending.errorDescription
            showError = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func dismissError() {
        showError = false
        errorMessage = nil
    }
}
