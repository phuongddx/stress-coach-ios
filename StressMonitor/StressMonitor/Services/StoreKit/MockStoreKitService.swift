import Foundation

#if DEBUG
final class MockStoreKitService: StoreKitServiceProtocol {
    private let premiumState: PremiumState

    /// `-mock-iap` sample mirroring StressMonitorProducts.storekit, so the
    /// paywall is purchasable in this double. Never used in Release.
    let availablePlans: [SubscriptionPlan] = {
        let format = Decimal.FormatStyle.Currency(code: "USD")
        let annual: Decimal = 25.99
        let monthly: Decimal = 4.99
        return [
            SubscriptionPlan(
                id: .annual, displayName: "Plus Annual", pricePerMonth: annual / 12, pricePerPeriod: annual,
                period: .annual,
                savingsPercent: StoreKitService.savingsPercent(monthlyPrice: monthly, annualPrice: annual),
                isBestValue: true, subtitle: "Best value option", productID: nil,
                displayPrice: format.format(annual), billingSummary: "Billed annually",
                hasIntroductoryOffer: true, introOfferPeriodUnit: "14-day",
                monthlyEquivalentDisplay: format.format(annual / 12)
            ),
            SubscriptionPlan(
                id: .monthly, displayName: "Plus Monthly", pricePerMonth: monthly, pricePerPeriod: monthly,
                period: .monthly, savingsPercent: nil, isBestValue: false, subtitle: nil, productID: nil,
                displayPrice: format.format(monthly), billingSummary: "Billed monthly",
                hasIntroductoryOffer: false, introOfferPeriodUnit: nil
            )
        ]
    }()

    var availablePacks: [CreditPack] {
        get async { CreditPack.defaultPacks }
    }

    var isPremiumUser: Bool { premiumState.isPremiumUser }

    init(premiumState: PremiumState) {
        self.premiumState = premiumState
    }

    func purchase(_ plan: SubscriptionPlan) async throws {
        try await Task.sleep(for: .seconds(1))
        premiumState.isPremiumUser = true
    }

    func purchase(pack: CreditPack) async throws {
        // Packs never flip premium — they grant credits, and this DEBUG
        // double has no backend to redeem against.
        try await Task.sleep(for: .seconds(1))
    }

    func restorePurchases() async throws {
        try await Task.sleep(for: .seconds(1))
        premiumState.isPremiumUser = true
    }

    func fetchPurchaseHistory() async -> [String] {
        return []
    }

    func refreshEntitlements() async {
        // No-op for mock
    }

    func isEligibleForIntroOffer(for period: SubscriptionPeriod) async -> Bool {
        availablePlans.first(where: { $0.period == period })?.hasIntroductoryOffer ?? false
    }
}
#endif
