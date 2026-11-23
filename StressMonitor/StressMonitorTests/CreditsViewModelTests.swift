import Foundation
import Testing
@testable import StressMonitor

// MARK: - Test doubles

/// StoreKit seam double for the packs-era purchase flow. Mirrors the
/// `FakeStoreKitService` convention from PremiumViewModelTests.
private final class CreditsFakeStoreKitService: StoreKitServiceProtocol {
    var stubbedPacks: [CreditPack] = CreditPack.defaultPacks
    var stubbedPlans: [SubscriptionPlan] = SubscriptionPlan.defaultPlans
    var packPurchaseStub: (() async throws -> Void)?
    private(set) var purchasedPackIDs: [CreditPackID] = []

    var availablePlans: [SubscriptionPlan] {
        get async { stubbedPlans }
    }

    var availablePacks: [CreditPack] {
        get async { stubbedPacks }
    }

    var isPremiumUser: Bool {
        get async { false }
    }

    func purchase(_ plan: SubscriptionPlan) async throws {}

    func purchase(pack: CreditPack) async throws {
        purchasedPackIDs.append(pack.id)
        try await packPurchaseStub?()
    }

    func restorePurchases() async throws {}

    func fetchPurchaseHistory() async -> [String] { [] }

    func refreshEntitlements() async {}

    func isEligibleForIntroOffer(for period: SubscriptionPeriod) async -> Bool { false }
}

// MARK: - Purchase state machine

@MainActor
struct CreditsViewModelTests {

    private func makeBalance(
        total: Int = 50,
        used: Int = 7,
        planType: CreditBalance.PlanType = .free,
        freeResetAt: String? = "2026-09-01T00:00:00Z"
    ) -> CreditBalance {
        CreditBalance(
            total: total,
            used: used,
            remaining: total - used,
            planType: planType,
            freeResetAt: freeResetAt
        )
    }

    private func makeViewModel(
        balance: CreditBalance? = nil,
        storeKit: CreditsFakeStoreKitService = CreditsFakeStoreKitService()
    ) -> (CreditsViewModel, MockCreditService, CreditsFakeStoreKitService) {
        let creditService = MockCreditService(balance: balance)
        let viewModel = CreditsViewModel(creditService: creditService, storeKit: storeKit)
        return (viewModel, creditService, storeKit)
    }

    // MARK: - loadPacks

    @Test("loadPacks loads the catalog packs without preselecting one")
    func loadPacksLoadsCatalogPacks() async {
        let (viewModel, _, _) = makeViewModel()

        await viewModel.loadPacks()

        #expect(viewModel.packs.count == 2)
        #expect(viewModel.packs.map(\.id) == [.small, .large])
        #expect(viewModel.selectedPack == nil)
    }

    // MARK: - purchaseSelectedPack

    @Test("purchaseSelectedPack derives success from the observed balance change")
    func purchaseSuccessDerivedFromBalanceChange() async {
        let (viewModel, creditService, storeKit) = makeViewModel(balance: makeBalance())
        await viewModel.loadPacks()
        viewModel.selectedPack = .small

        storeKit.packPurchaseStub = { [weak creditService] in
            creditService?.apply(
                CreditBalance(total: 60, used: 7, remaining: 53, planType: .free, freeResetAt: nil)
            )
        }

        await viewModel.purchaseSelectedPack()

        #expect(storeKit.purchasedPackIDs == [.small])
        #expect(viewModel.showSuccess)
        #expect(viewModel.purchasedPack?.credits == 10)
        #expect(!viewModel.showError)
        #expect(!viewModel.isLoading)
    }

    @Test("purchase that returns without a balance change shows no success and no error")
    func purchaseWithoutBalanceChangeIsSilent() async {
        let (viewModel, _, storeKit) = makeViewModel(balance: makeBalance())
        await viewModel.loadPacks()
        viewModel.selectedPack = .small

        storeKit.packPurchaseStub = {}

        await viewModel.purchaseSelectedPack()

        #expect(!viewModel.showSuccess)
        #expect(!viewModel.showError)
        #expect(viewModel.errorMessage == nil)
        #expect(!viewModel.isLoading)
    }

    @Test("purchaseSelectedPack with no selection sets an error message")
    func purchaseWithoutSelectionSetsError() async {
        let (viewModel, _, _) = makeViewModel(balance: makeBalance())
        await viewModel.loadPacks()

        await viewModel.purchaseSelectedPack()

        #expect(viewModel.showError)
        #expect(viewModel.errorMessage != nil)
    }

    @Test("purchase cancellation is silent")
    func purchaseCancellationIsSilent() async {
        let (viewModel, _, storeKit) = makeViewModel(balance: makeBalance())
        await viewModel.loadPacks()
        viewModel.selectedPack = .large

        storeKit.packPurchaseStub = {
            throw StoreKitError.purchaseCancelled
        }

        await viewModel.purchaseSelectedPack()

        #expect(!viewModel.showSuccess)
        #expect(!viewModel.showError)
        #expect(viewModel.errorMessage == nil)
        #expect(!viewModel.isLoading)
    }

    @Test("pending purchase sets a message")
    func pendingPurchaseSetsMessage() async {
        let (viewModel, _, storeKit) = makeViewModel(balance: makeBalance())
        await viewModel.loadPacks()
        viewModel.selectedPack = .small

        storeKit.packPurchaseStub = {
            throw StoreKitError.purchasePending
        }

        await viewModel.purchaseSelectedPack()

        #expect(viewModel.showError)
        #expect(viewModel.errorMessage == StoreKitError.purchasePending.errorDescription)
        #expect(!viewModel.isLoading)
    }

    @Test("purchase failure sets a message and resets loading")
    func purchaseFailureSetsMessageAndResetsLoading() async {
        let (viewModel, _, storeKit) = makeViewModel(balance: makeBalance())
        await viewModel.loadPacks()
        viewModel.selectedPack = .small

        storeKit.packPurchaseStub = {
            throw StoreKitError.purchaseFailed
        }

        await viewModel.purchaseSelectedPack()

        #expect(viewModel.showError)
        #expect(viewModel.errorMessage != nil)
        #expect(!viewModel.isLoading)
        #expect(!viewModel.showSuccess)
    }

    // MARK: - Balance display rules (shared formatter)

    @Test("premium balance renders as Unlimited, never the raw sentinel count")
    func premiumRendersAsUnlimited() {
        var premium = makeBalance(
            total: 999_999,
            used: 0,
            planType: .premium,
            freeResetAt: nil
        )
        premium.remaining = 999_999

        let text = CreditBalanceFormatter.balanceText(premium)

        #expect(text == "Unlimited")
        #expect(!text.contains("999"))
    }

    @Test("free-tier balance renders as a count")
    func freeTierRendersAsCount() {
        let text = CreditBalanceFormatter.balanceText(makeBalance(total: 50, used: 7))

        #expect(text == "43 credits")
    }

    @Test("unavailable balance renders a neutral placeholder, never a zero")
    func nilBalanceRendersNeutralPlaceholder() {
        let text = CreditBalanceFormatter.balanceText(nil)

        #expect(text == CreditBalanceFormatter.unavailableText)
        #expect(!text.contains("0"))
        #expect(text != "0 credits")
    }

    @Test("fewer than 5 free messages left flags the low-messages warning")
    func lowRemainingFlagsShortResponses() {
        #expect(CreditBalanceFormatter.shortResponseThreshold == 5)
        #expect(CreditBalanceFormatter.isLowCredits(makeBalance(total: 20, used: 16)))
        #expect(!CreditBalanceFormatter.isLowCredits(makeBalance(total: 20, used: 15)))

        let premium = makeBalance(total: 999_999, used: 0, planType: .premium, freeResetAt: nil)
        #expect(!CreditBalanceFormatter.isLowCredits(premium))
        #expect(!CreditBalanceFormatter.isLowCredits(nil))
    }

    @Test("reset date renders for the free tier and hides for premium")
    func resetDateRendering() {
        let freeText = CreditBalanceFormatter.resetDateText(makeBalance())
        #expect(freeText != nil)
        #expect(freeText?.hasPrefix("Resets ") == true)

        let noResetDate = CreditBalanceFormatter.resetDateText(makeBalance(freeResetAt: nil))
        #expect(noResetDate == nil)

        let premium = makeBalance(total: 999_999, used: 0, planType: .premium, freeResetAt: nil)
        #expect(CreditBalanceFormatter.resetDateText(premium) == nil)
    }

    // MARK: - DEC-2 placement surfaces (chat row + Plus row)

    @Test("chat row value combines availability with the shared balance string")
    func chatRowValueCombinesAvailabilityAndBalance() {
        #expect(
            CreditBalanceFormatter.chatRowValue(
                available: true,
                balance: makeBalance(total: 50, used: 7)
            ) == "Active · 43 credits"
        )

        var premium = makeBalance(total: 999_999, used: 0, planType: .premium, freeResetAt: nil)
        premium.remaining = 999_999
        #expect(
            CreditBalanceFormatter.chatRowValue(available: true, balance: premium)
                == "Active · Unlimited"
        )

        #expect(
            CreditBalanceFormatter.chatRowValue(available: true, balance: nil) == "Active"
        )

        #expect(
            CreditBalanceFormatter.chatRowValue(
                available: false,
                balance: makeBalance()
            ) == "Coming soon"
        )
    }

    @Test("plus row value reflects live state instead of the static teaser")
    func plusRowValueReflectsLiveState() {
        var premium = makeBalance(total: 999_999, used: 0, planType: .premium, freeResetAt: nil)
        premium.remaining = 999_999
        #expect(CreditBalanceFormatter.plusRowValue(premium) == "Active")

        #expect(CreditBalanceFormatter.plusRowValue(makeBalance(total: 50, used: 7)) == "43 credits left")

        #expect(CreditBalanceFormatter.plusRowValue(nil) == "Try free")
    }
}
