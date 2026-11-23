import Foundation
import StoreKitTest
import Testing
@testable import StressMonitor

// MARK: - Helpers

@MainActor
private func isolatedDefaults() -> UserDefaults {
    let name = "PaywallPriceMathTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name) ?? .standard
    defaults.removePersistentDomain(forName: name)
    return defaults
}

private func plan(_ period: StressMonitor.SubscriptionPeriod, price: Decimal) -> SubscriptionPlan {
    SubscriptionPlan(
        id: period, displayName: period == .annual ? "Plus Annual" : "Plus Monthly",
        pricePerMonth: period == .annual ? price / 12 : price, pricePerPeriod: price,
        period: period, savingsPercent: nil, isBestValue: period == .annual, subtitle: nil,
        productID: nil, displayPrice: "x", billingSummary: nil,
        hasIntroductoryOffer: false, introOfferPeriodUnit: nil
    )
}

private let usd = Decimal.FormatStyle.Currency(code: "USD", locale: Locale(identifier: "en_US"))

// MARK: - PaywallPriceMathTests

/// The annual card's "Save N%" and "≈ X/month" come from the prices StoreKit
/// returns, never from constants.
@MainActor
@Suite(.serialized)
struct PaywallPriceMathTests {

    @Test("25.99 a year against 4.99 a month saves 56%, rounded down")
    func savingsFromLaunchPrices() {
        #expect(StoreKitService.savingsPercent(monthlyPrice: 4.99, annualPrice: 25.99) == 56)
        // 59.88 - 29.94 = exactly half: rounding down must not drop it to 49.
        #expect(StoreKitService.savingsPercent(monthlyPrice: 4.99, annualPrice: 29.94) == 50)
    }

    @Test("25.99 a year is about $2.17 a month")
    func monthlyEquivalentFromLaunchPrice() {
        #expect(StoreKitService.monthlyEquivalent(annualPrice: 25.99, format: usd) == "$2.17")
    }

    @Test("The shown price wins over a truncated Decimal price")
    func resolvedPriceUsesDisplayPrice() {
        #expect(StoreKitService.resolvedPrice(price: 25, displayPrice: "$25.99", format: usd) == Decimal(string: "25.99"))
        #expect(StoreKitService.resolvedPrice(price: 4, displayPrice: "$4.99", format: usd) == Decimal(string: "4.99"))
        #expect(StoreKitService.resolvedPrice(price: 7, displayPrice: "not a price", format: usd) == 7)
    }

    @Test("Prices resolve in other currencies and locales", arguments: [
        ("EUR", "de_DE", "25.99"),
        ("VND", "vi_VN", "649000"),
        ("JPY", "ja_JP", "3000"),
        ("GBP", "en_GB", "24.99"),
    ])
    func resolvedPriceAcrossCurrencies(code: String, locale: String, amount: String) throws {
        let format = Decimal.FormatStyle.Currency(code: code, locale: Locale(identifier: locale))
        let value = try #require(Decimal(string: amount))
        let shown = format.format(value)
        #expect(StoreKitService.resolvedPrice(price: 1, displayPrice: shown, format: format) == value)
    }

    @Test("Both plans loaded: the annual card says Save 56%")
    func savingsAppliedWithBothPlans() {
        var plans = [plan(.annual, price: 25.99), plan(.monthly, price: 4.99)]
        StoreKitService.applySavings(to: &plans)
        #expect(plans[0].savingsPercent == 56)
        #expect(plans[0].savingsDisplay == "Save 56%")
        #expect(plans[1].savingsDisplay == nil)
    }

    @Test("No monthly price: the Save line is hidden")
    func savingsHiddenWithoutMonthly() {
        var plans = [plan(.annual, price: 25.99)]
        StoreKitService.applySavings(to: &plans)
        #expect(plans[0].savingsPercent == nil)
        #expect(plans[0].savingsDisplay == nil)
    }

    @Test("Products from the .storekit file give Save 56% and ≈ $2.17/month")
    func liveStoreKitProductsGiveRightFigures() async throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("StressMonitorProducts.storekit")
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.disableDialogs = true
        defer { withExtendedLifetime(session) {} }

        let defaults = isolatedDefaults()
        let premium = PremiumState(defaults: defaults, key: "isPremiumUser")
        let service = StoreKitService(
            premiumState: premium,
            plusAccess: PlusAccess(premiumState: premium, availability: .enabled, defaults: defaults),
            availability: .enabled
        )

        let plans = await service.availablePlans
        let annual = try #require(plans.first { $0.period == .annual })
        let monthly = try #require(plans.first { $0.period == .monthly })
        #expect(annual.pricePerPeriod == Decimal(string: "25.99"))
        #expect(monthly.pricePerPeriod == Decimal(string: "4.99"))
        #expect(annual.savingsDisplay == "Save 56%")
        #expect(annual.monthlyEquivalentDisplay == "$2.17")
    }
}
