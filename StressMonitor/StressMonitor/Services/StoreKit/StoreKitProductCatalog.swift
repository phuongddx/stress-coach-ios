import Foundation

/// Configurable product-ID catalog for StoreKit subscriptions and credit packs.
///
/// Product IDs are resolved in this order:
/// 1. `Bundle.main` Info.plist keys (`STOREKIT_PREMIUM_MONTHLY_PRODUCT_ID`,
///    `STOREKIT_CREDITS_SMALL_PRODUCT_ID`, etc.)
/// 2. `ProcessInfo.processInfo.environment` (same keys, useful for CI)
/// 3. `UserDefaults.standard` (`storeKitPremiumMonthlyProductID` etc. —
///    one camelCase key per resolvable product)
///
/// Empty strings and unresolved build-setting placeholders (e.g. `$(…)` ) are treated as nil.
struct StoreKitProductCatalog: Sendable {

    // MARK: - Public API

    let monthlyProductID: String?
    let annualProductID: String?
    let subscriptionGroupID: String?
    let smallPackProductID: String?
    let largePackProductID: String?

    /// All non-nil product IDs.
    var allProductIDs: Set<String> {
        Set([monthlyProductID, annualProductID].compactMap { $0 })
    }

    /// Returns the product ID for a given subscription period.
    func productID(for period: SubscriptionPeriod) -> String? {
        switch period {
        case .monthly: monthlyProductID
        case .annual:  annualProductID
        }
    }

    /// Returns the period for a given product ID, or nil if unknown.
    func period(for productID: String) -> SubscriptionPeriod? {
        if productID == monthlyProductID { return .monthly }
        if productID == annualProductID  { return .annual }
        return nil
    }

    /// Returns the product ID for a given credit pack.
    func packID(for pack: CreditPackID) -> String? {
        switch pack {
        case .small: smallPackProductID
        case .large: largePackProductID
        }
    }

    /// Returns the pack identity for a given product ID, or nil if unknown.
    /// Non-nil means the product ID is a consumable credit pack.
    func pack(for productID: String) -> CreditPackID? {
        if productID == smallPackProductID { return .small }
        if productID == largePackProductID { return .large }
        return nil
    }

    // MARK: - Live (production) initializer

    /// Creates a catalog that resolves IDs from Bundle → Environment → UserDefaults.
    static let live = StoreKitProductCatalog(bundle: .main)

    init(
        bundle: Bundle = .main,
        infoDictionary: [String: String]? = nil,
        environment: [String: String]? = nil,
        defaults: UserDefaults? = nil
    ) {
        let env = environment ?? ProcessInfo.processInfo.environment
        let defs = defaults ?? .standard

        self.monthlyProductID = Self.resolve(
            infoKey: "STOREKIT_PREMIUM_MONTHLY_PRODUCT_ID",
            envKey: "STOREKIT_PREMIUM_MONTHLY_PRODUCT_ID",
            defaultsKey: "storeKitPremiumMonthlyProductID",
            infoDictionary: infoDictionary,
            bundle: bundle,
            environment: env,
            defaults: defs
        )

        self.annualProductID = Self.resolve(
            infoKey: "STOREKIT_PREMIUM_ANNUAL_PRODUCT_ID",
            envKey: "STOREKIT_PREMIUM_ANNUAL_PRODUCT_ID",
            defaultsKey: "storeKitPremiumAnnualProductID",
            infoDictionary: infoDictionary,
            bundle: bundle,
            environment: env,
            defaults: defs
        )

        self.subscriptionGroupID = Self.resolve(
            infoKey: "STOREKIT_PREMIUM_SUBSCRIPTION_GROUP_ID",
            envKey: "STOREKIT_PREMIUM_SUBSCRIPTION_GROUP_ID",
            defaultsKey: "storeKitPremiumSubscriptionGroupID",
            infoDictionary: infoDictionary,
            bundle: bundle,
            environment: env,
            defaults: defs
        )

        self.smallPackProductID = Self.resolve(
            infoKey: "STOREKIT_CREDITS_SMALL_PRODUCT_ID",
            envKey: "STOREKIT_CREDITS_SMALL_PRODUCT_ID",
            defaultsKey: "storeKitCreditsSmallProductID",
            infoDictionary: infoDictionary,
            bundle: bundle,
            environment: env,
            defaults: defs
        )

        self.largePackProductID = Self.resolve(
            infoKey: "STOREKIT_CREDITS_LARGE_PRODUCT_ID",
            envKey: "STOREKIT_CREDITS_LARGE_PRODUCT_ID",
            defaultsKey: "storeKitCreditsLargeProductID",
            infoDictionary: infoDictionary,
            bundle: bundle,
            environment: env,
            defaults: defs
        )
    }

    /// Direct initializer for tests that already have resolved values.
    init(monthlyProductID: String? = nil,
         annualProductID: String? = nil,
         subscriptionGroupID: String? = nil,
         smallPackProductID: String? = nil,
         largePackProductID: String? = nil) {
        self.monthlyProductID = Self.clean(monthlyProductID)
        self.annualProductID = Self.clean(annualProductID)
        self.subscriptionGroupID = Self.clean(subscriptionGroupID)
        self.smallPackProductID = Self.clean(smallPackProductID)
        self.largePackProductID = Self.clean(largePackProductID)
    }

    // MARK: - Resolution helpers

    private static func resolve(
        infoKey: String,
        envKey: String,
        defaultsKey: String,
        infoDictionary: [String: String]?,
        bundle: Bundle,
        environment: [String: String],
        defaults: UserDefaults
    ) -> String? {
        let infoValue: String?
        if let infoDictionary {
            infoValue = infoDictionary[infoKey]
        } else {
            infoValue = bundle.object(forInfoDictionaryKey: infoKey) as? String
        }

        // 1. Bundle Info.plist
        if let value = infoValue, clean(value) != nil {
            return clean(value)
        }

        // 2. Process environment
        if let value = environment[envKey],
           clean(value) != nil {
            return clean(value)
        }

        // 3. UserDefaults
        if let value = defaults.string(forKey: defaultsKey),
           clean(value) != nil {
            return clean(value)
        }

        return nil
    }

    /// Returns nil for empty strings or unresolved Xcode build-setting placeholders like `$(FOO)`.
    private static func clean(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        if value.hasPrefix("$(") && value.hasSuffix(")") { return nil }
        return value
    }
}
