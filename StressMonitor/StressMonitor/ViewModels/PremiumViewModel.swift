import Foundation

@MainActor
@Observable
final class PremiumViewModel {
    /// Price loading for the paywall. `.failed` means no StoreKit product
    /// loaded, so the paywall shows a retry instead of any price.
    enum LoadState: Equatable {
        case loading
        case loaded
        case failed
    }

    let storeKit: StoreKitServiceProtocol
    let premiumState: PremiumState

    var selectedPlan: SubscriptionPeriod = .annual
    var plans: [SubscriptionPlan] = []
    private(set) var loadState: LoadState = .loading
    var isLoading = false
    var showError = false
    var alertTitle = "Purchase Error"
    var errorMessage: String?
    /// True when the success sheet follows a restore rather than a purchase.
    private(set) var didRestore = false
    var showSuccess = false
    /// Whether this Apple ID can still start the annual plan's free trial.
    /// Apple allows one intro offer per subscription group, so this is asked
    /// for the annual product regardless of which card is selected.
    var annualTrialEligible = false

    init(storeKit: StoreKitServiceProtocol, premiumState: PremiumState) {
        self.storeKit = storeKit
        self.premiumState = premiumState
    }

    var selectedPlanDetails: SubscriptionPlan? {
        plans.first { $0.period == selectedPlan }
    }

    var annualPlan: SubscriptionPlan? {
        plans.first { $0.period == .annual }
    }

    /// Trial length label from the annual product (e.g. "14-day"); nil when
    /// the user is not eligible or the product has no intro offer.
    var trialPeriodUnit: String? {
        guard annualTrialEligible, let annualPlan, annualPlan.hasIntroductoryOffer else { return nil }
        return annualPlan.introOfferPeriodUnit
    }

    /// Trial copy shows only with the annual card selected and a trial on offer.
    var showsTrialOffer: Bool {
        selectedPlan == .annual && annualTrialEligible && annualPlan?.hasIntroductoryOffer == true
    }

    var ctaTitle: String {
        guard showsTrialOffer else { return "Subscribe" }
        if let unit = trialPeriodUnit {
            return "Start \(unit) free trial"
        }
        return "Start free trial"
    }

    /// Renewal terms under the CTA, built from the selected product's price.
    var renewalTerms: String {
        guard let plan = selectedPlanDetails, plan.hasStorePrice else {
            return "Subscription auto-renews until cancelled. Cancel anytime in Settings."
        }
        let price = "\(plan.priceDisplay)\(plan.periodUnitDisplay)"
        if showsTrialOffer, let unit = trialPeriodUnit {
            return "Includes a \(unit) free trial, then \(price). Auto-renews until cancelled. Cancel anytime in Settings."
        }
        return "\(price). Auto-renews until cancelled. Cancel anytime in Settings."
    }

    /// Buying needs a loaded product for the selected card.
    var canPurchase: Bool {
        loadState == .loaded && selectedPlanDetails?.hasStorePrice == true && !isLoading
    }

    func loadInitialData() async {
        loadState = .loading
        plans = await storeKit.availablePlans
        guard !plans.isEmpty else {
            annualTrialEligible = false
            loadState = .failed
            return
        }

        // Select annual when present, otherwise first available plan
        if plans.contains(where: { $0.period == .annual }) {
            selectedPlan = .annual
        } else if let first = plans.first {
            selectedPlan = first.period
        }

        if annualPlan?.hasIntroductoryOffer == true {
            annualTrialEligible = await storeKit.isEligibleForIntroOffer(for: .annual)
        } else {
            annualTrialEligible = false
        }
        loadState = .loaded
    }

    func retryLoading() async {
        await loadInitialData()
    }

    func purchaseSelectedPlan() async {
        isLoading = true
        defer { isLoading = false }

        do {
            guard let plan = selectedPlanDetails else {
                presentAlert(title: "Purchase Error", message: "Plan not available. Please try again.")
                return
            }
            try await storeKit.purchase(plan)
            // Derive success from premium state, not from purchase call alone
            showSuccess = premiumState.isPremiumUser
        } catch StoreKitError.purchaseCancelled {
            // User cancelled — silent
        } catch StoreKitError.purchasePending {
            presentAlert(title: "Waiting for Approval", message: StoreKitError.purchasePending.errorDescription)
        } catch {
            presentAlert(title: "Purchase Error", message: error.localizedDescription)
        }
    }

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await storeKit.restorePurchases()
            if premiumState.isPremiumUser {
                didRestore = true
                showSuccess = true
            } else {
                presentAlert(title: "Nothing to Restore", message: StoreKitError.noActiveSubscription.errorDescription)
            }
        } catch StoreKitError.noActiveSubscription {
            presentAlert(title: "Nothing to Restore", message: StoreKitError.noActiveSubscription.errorDescription)
        } catch {
            presentAlert(title: "Restore Failed", message: error.localizedDescription)
        }
    }

    func dismissError() {
        showError = false
        errorMessage = nil
        alertTitle = "Purchase Error"
    }

    private func presentAlert(title: String, message: String?) {
        alertTitle = title
        errorMessage = message
        showError = true
    }
}
