import Foundation
import Testing
@testable import StressMonitor

@MainActor
struct StoreKitProductCatalogTests {

    // MARK: - Missing values

    @Test("Missing values produce empty allProductIDs")
    func missingValuesProduceEmptyIDs() {
        let catalog = StoreKitProductCatalog(
            monthlyProductID: nil,
            annualProductID: nil,
            subscriptionGroupID: nil
        )
        #expect(catalog.allProductIDs.isEmpty)
        #expect(catalog.monthlyProductID == nil)
        #expect(catalog.annualProductID == nil)
    }

    // MARK: - Empty strings

    @Test("Empty strings are ignored")
    func emptyStringsAreIgnored() {
        let catalog = StoreKitProductCatalog(
            monthlyProductID: "",
            annualProductID: "",
            subscriptionGroupID: ""
        )
        #expect(catalog.allProductIDs.isEmpty)
        #expect(catalog.monthlyProductID == nil)
        #expect(catalog.annualProductID == nil)
    }

    // MARK: - Placeholder values

    @Test("Placeholder build-setting values are ignored")
    func placeholderValuesAreIgnored() {
        let catalog = StoreKitProductCatalog(
            monthlyProductID: "$(STOREKIT_PREMIUM_MONTHLY_PRODUCT_ID)",
            annualProductID: "$(STOREKIT_PREMIUM_ANNUAL_PRODUCT_ID)",
            subscriptionGroupID: "$(STOREKIT_PREMIUM_SUBSCRIPTION_GROUP_ID)"
        )
        #expect(catalog.allProductIDs.isEmpty)
    }

    // MARK: - Explicit values

    @Test("Explicit monthly/annual/group values are returned")
    func explicitValuesAreReturned() {
        let catalog = StoreKitProductCatalog(
            monthlyProductID: "com.example.app.plus.monthly",
            annualProductID: "com.example.app.plus.annual",
            subscriptionGroupID: "plus"
        )
        #expect(catalog.monthlyProductID == "com.example.app.plus.monthly")
        #expect(catalog.annualProductID == "com.example.app.plus.annual")
        #expect(catalog.subscriptionGroupID == "plus")
        #expect(catalog.allProductIDs.count == 2)
        #expect(catalog.allProductIDs.contains("com.example.app.plus.monthly"))
        #expect(catalog.allProductIDs.contains("com.example.app.plus.annual"))
    }

    // MARK: - productID(for:) mapping

    @Test("productID(for:) maps periods correctly")
    func productIDForPeriod() {
        let catalog = StoreKitProductCatalog(
            monthlyProductID: "monthly.id",
            annualProductID: "annual.id",
            subscriptionGroupID: nil
        )
        #expect(catalog.productID(for: .monthly) == "monthly.id")
        #expect(catalog.productID(for: .annual) == "annual.id")
    }

    @Test("Only monthly and annual periods exist (weekly removed in 1.1)")
    func onlyTwoPeriodsExist() {
        #expect(SubscriptionPeriod.allCases == [.annual, .monthly])
        #expect(SubscriptionPlan.defaultPlans.map(\.period) == [.annual, .monthly])
    }

    // MARK: - period(for:) mapping

    @Test("period(for:) maps product IDs back to periods")
    func periodForProductID() {
        let catalog = StoreKitProductCatalog(
            monthlyProductID: "monthly.id",
            annualProductID: "annual.id",
            subscriptionGroupID: nil
        )
        #expect(catalog.period(for: "monthly.id") == .monthly)
        #expect(catalog.period(for: "annual.id") == .annual)
        #expect(catalog.period(for: "legacy.weekly.id") == nil)
        #expect(catalog.period(for: "unknown.id") == nil)
    }

    // MARK: - Injectable sources

    @Test("Catalog resolves from injected environment dictionary")
    func resolvesFromInjectedEnvironment() {
        let catalog = StoreKitProductCatalog(
            bundle: Bundle.main,
            infoDictionary: [:],
            environment: [
                "STOREKIT_PREMIUM_MONTHLY_PRODUCT_ID": "env.monthly",
                "STOREKIT_PREMIUM_ANNUAL_PRODUCT_ID": "env.annual",
                "STOREKIT_PREMIUM_SUBSCRIPTION_GROUP_ID": "env.group"
            ],
            defaults: nil
        )
        #expect(catalog.monthlyProductID == "env.monthly")
        #expect(catalog.annualProductID == "env.annual")
        #expect(catalog.subscriptionGroupID == "env.group")
    }

    @Test("Catalog resolves from injected UserDefaults")
    func resolvesFromInjectedDefaults() {
        let defaults = UserDefaults(suiteName: "StoreKitProductCatalogTests")!
        defaults.set("defaults.monthly", forKey: "storeKitPremiumMonthlyProductID")
        defaults.set("defaults.annual", forKey: "storeKitPremiumAnnualProductID")
        defaults.set("defaults.group", forKey: "storeKitPremiumSubscriptionGroupID")

        defer {
            defaults.removeSuite(named: "StoreKitProductCatalogTests")
        }

        let catalog = StoreKitProductCatalog(
            bundle: Bundle.main,
            infoDictionary: [:],
            environment: [:],
            defaults: defaults
        )
        #expect(catalog.monthlyProductID == "defaults.monthly")
        #expect(catalog.annualProductID == "defaults.annual")
        #expect(catalog.subscriptionGroupID == "defaults.group")
    }

    // MARK: - Annual-only edge case

    @Test("Catalog with only annual product still works")
    func annualOnlyCatalog() {
        let catalog = StoreKitProductCatalog(
            monthlyProductID: nil,
            annualProductID: "annual.only",
            subscriptionGroupID: nil
        )
        #expect(catalog.allProductIDs.count == 1)
        #expect(catalog.productID(for: .annual) == "annual.only")
        #expect(catalog.productID(for: .monthly) == nil)
        #expect(catalog.period(for: "annual.only") == .annual)
    }

    // MARK: - Bundle Info.plist takes priority over environment

    @Test("Bundle Info.plist key takes priority over environment")
    func bundlePriorityOverEnvironment() {
        let catalog = StoreKitProductCatalog(
            bundle: Bundle.main,
            infoDictionary: [
                "STOREKIT_PREMIUM_MONTHLY_PRODUCT_ID": "info.monthly"
            ],
            environment: [
                "STOREKIT_PREMIUM_MONTHLY_PRODUCT_ID": "env.monthly"
            ],
            defaults: nil
        )
        #expect(catalog.monthlyProductID == "info.monthly")
    }

    // MARK: - Credit pack resolution (DEC-2)

    @Test("Pack product IDs resolve from the injected environment dictionary")
    func packIDsResolveFromInjectedEnvironment() {
        let catalog = StoreKitProductCatalog(
            bundle: Bundle.main,
            infoDictionary: [:],
            environment: [
                "STOREKIT_CREDITS_SMALL_PRODUCT_ID": "env.credits.small",
                "STOREKIT_CREDITS_LARGE_PRODUCT_ID": "env.credits.large"
            ],
            defaults: nil
        )
        #expect(catalog.smallPackProductID == "env.credits.small")
        #expect(catalog.largePackProductID == "env.credits.large")
    }

    @Test("Pack product IDs resolve from injected UserDefaults")
    func packIDsResolveFromInjectedDefaults() {
        let defaults = UserDefaults(suiteName: "StoreKitProductCatalogPackTests")!
        defaults.set("defaults.credits.small", forKey: "storeKitCreditsSmallProductID")
        defaults.set("defaults.credits.large", forKey: "storeKitCreditsLargeProductID")

        defer {
            defaults.removeSuite(named: "StoreKitProductCatalogPackTests")
        }

        let catalog = StoreKitProductCatalog(
            bundle: Bundle.main,
            infoDictionary: [:],
            environment: [:],
            defaults: defaults
        )
        #expect(catalog.smallPackProductID == "defaults.credits.small")
        #expect(catalog.largePackProductID == "defaults.credits.large")
    }

    @Test("Pack environment key takes priority over the defaults key")
    func packEnvironmentBeatsDefaults() {
        let defaults = UserDefaults(suiteName: "StoreKitProductCatalogPackPrecedenceTests")!
        defaults.set("defaults.credits.small", forKey: "storeKitCreditsSmallProductID")

        defer {
            defaults.removeSuite(named: "StoreKitProductCatalogPackPrecedenceTests")
        }

        let catalog = StoreKitProductCatalog(
            bundle: Bundle.main,
            infoDictionary: [:],
            environment: [
                "STOREKIT_CREDITS_SMALL_PRODUCT_ID": "env.credits.small"
            ],
            defaults: defaults
        )
        #expect(catalog.smallPackProductID == "env.credits.small")
    }

    @Test("Pack IDs stay additive — subscription resolution is unchanged by pack keys")
    func packKeysDoNotAffectSubscriptionResolution() {
        let catalog = StoreKitProductCatalog(
            monthlyProductID: "monthly.id",
            annualProductID: "annual.id",
            subscriptionGroupID: nil,
            smallPackProductID: "credits.small",
            largePackProductID: "credits.large"
        )
        #expect(catalog.productID(for: .monthly) == "monthly.id")
        #expect(catalog.period(for: "monthly.id") == .monthly)
        #expect(catalog.allProductIDs.count == 2)
    }

    // MARK: - CreditPack model (DEC-2)

    @Test("defaultPacks match DEC-2 — small 10 credits, large 150 credits")
    func defaultPacksMatchDEC2() {
        let packs = CreditPack.defaultPacks
        #expect(packs.count == 2)

        let small = packs.first(where: { $0.id == .small })
        #expect(small?.credits == 10)
        #expect(small?.productID == nil)
        #expect(small?.displayPrice == "$1.99")

        let large = packs.first(where: { $0.id == .large })
        #expect(large?.credits == 150)
        #expect(large?.productID == nil)
        #expect(large?.displayPrice == "$19.99")
    }

    @Test("pack(for:) and packID(for:) round-trip every configured pack")
    func packLookupRoundTrips() {
        let catalog = StoreKitProductCatalog(
            smallPackProductID: "com.stressmonitor.app.credits.small",
            largePackProductID: "com.stressmonitor.app.credits.large"
        )
        #expect(catalog.packID(for: .small) == "com.stressmonitor.app.credits.small")
        #expect(catalog.packID(for: .large) == "com.stressmonitor.app.credits.large")
        #expect(catalog.pack(for: "com.stressmonitor.app.credits.small") == .small)
        #expect(catalog.pack(for: "com.stressmonitor.app.credits.large") == .large)
        #expect(catalog.pack(for: "com.stressmonitor.app.plus.monthly") == nil)
        #expect(catalog.pack(for: "unknown.id") == nil)
    }
}
