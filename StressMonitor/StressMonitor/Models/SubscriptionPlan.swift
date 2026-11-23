import Foundation

enum SubscriptionPeriod: String, CaseIterable {
    case annual
    case monthly
}

struct SubscriptionPlan: Identifiable {
    let id: SubscriptionPeriod
    let displayName: String
    let pricePerMonth: Decimal
    let pricePerPeriod: Decimal
    let period: SubscriptionPeriod
    var savingsPercent: Int?
    let isBestValue: Bool
    let subtitle: String?

    // StoreKit-driven fields
    let productID: String?
    let displayPrice: String?
    let billingSummary: String?
    let hasIntroductoryOffer: Bool
    let introOfferPeriodUnit: String?
    /// Annual only: the per-month equivalent formatted in the product's own
    /// currency (e.g. "$2.17"). Nil for placeholders and monthly plans.
    var monthlyEquivalentDisplay: String? = nil

    /// Human-readable period unit for display (e.g. "/month", "/year").
    var periodUnitDisplay: String {
        switch period {
        case .monthly: return "/month"
        case .annual:  return "/year"
        }
    }

    /// True only when the price came from a loaded StoreKit product.
    var hasStorePrice: Bool {
        guard let displayPrice else { return false }
        return !displayPrice.isEmpty
    }

    /// StoreKit `displayPrice` (storefront currency). Placeholders have no
    /// price, so this is a dash rather than an invented amount.
    var priceDisplay: String {
        guard hasStorePrice, let displayPrice else { return "\u{2014}" }
        return displayPrice
    }

    var savingsDisplay: String? {
        guard let savings = savingsPercent, savings > 0 else { return nil }
        return "Save \(savings)%"
    }

    /// Placeholder slots for the loading skeleton: names only, no prices,
    /// savings or trial. Real values come from StoreKit products.
    static let defaultPlans: [SubscriptionPlan] = [
        SubscriptionPlan(
            id: .annual,
            displayName: "Annually",
            pricePerMonth: .zero,
            pricePerPeriod: .zero,
            period: .annual,
            savingsPercent: nil,
            isBestValue: true,
            subtitle: nil,
            productID: nil,
            displayPrice: nil,
            billingSummary: nil,
            hasIntroductoryOffer: false,
            introOfferPeriodUnit: nil
        ),
        SubscriptionPlan(
            id: .monthly,
            displayName: "Monthly",
            pricePerMonth: .zero,
            pricePerPeriod: .zero,
            period: .monthly,
            savingsPercent: nil,
            isBestValue: false,
            subtitle: nil,
            productID: nil,
            displayPrice: nil,
            billingSummary: nil,
            hasIntroductoryOffer: false,
            introOfferPeriodUnit: nil
        )
    ]
}
