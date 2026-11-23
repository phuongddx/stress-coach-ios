import Foundation
import Testing
@testable import StressMonitor

// MARK: - Fake StoreKit Service

private final class FakeStoreKitService: StoreKitServiceProtocol {
    var stubbedPlans: [SubscriptionPlan] = SubscriptionPlan.defaultPlans
    var stubbedIsPremiumUser: Bool = false
    var purchaseStub: (() async throws -> Void)?
    var packPurchaseStub: (() async throws -> Void)?
    var restoreStub: (() async throws -> Void)?
    var didCallRefresh = false
    /// Overrides intro-offer eligibility; nil derives it from the stubbed plan.
    var stubbedTrialEligibility: Bool?
    private(set) var eligibilityQueries: [SubscriptionPeriod] = []

    var availablePlans: [SubscriptionPlan] {
        get async { stubbedPlans }
    }

    var availablePacks: [CreditPack] {
        get async { CreditPack.defaultPacks }
    }

    var isPremiumUser: Bool {
        get async { stubbedIsPremiumUser }
    }

    func purchase(_ plan: SubscriptionPlan) async throws {
        try await purchaseStub?()
    }

    func purchase(pack: CreditPack) async throws {
        try await packPurchaseStub?()
    }

    func restorePurchases() async throws {
        try await restoreStub?()
    }

    func fetchPurchaseHistory() async -> [String] {
        return []
    }

    func refreshEntitlements() async {
        didCallRefresh = true
    }

    func isEligibleForIntroOffer(for period: SubscriptionPeriod) async -> Bool {
        eligibilityQueries.append(period)
        if let stubbedTrialEligibility { return stubbedTrialEligibility }
        return stubbedPlans.first(where: { $0.period == period })?.hasIntroductoryOffer ?? false
    }
}

// MARK: - Tests

@MainActor
struct PremiumViewModelTests {

    /// Helper to create an isolated PremiumState that doesn't pollute real UserDefaults.
    private func makeIsolatedState(isPremium: Bool = false) -> PremiumState {
        let defaults = UserDefaults(suiteName: "PremiumViewModelTests_\(UUID().uuidString)")!
        let state = PremiumState(defaults: defaults, key: "isPremiumUser")
        state.isPremiumUser = isPremium
        return state
    }

    // MARK: - loadInitialData

    @Test("loadInitialData loads plans")
    func loadInitialDataLoadsPlans() async {
        let service = FakeStoreKitService()
        let state = makeIsolatedState()
        let vm = PremiumViewModel(storeKit: service, premiumState: state)

        await vm.loadInitialData()

        #expect(vm.plans.count == 2)
    }

    @Test("loadInitialData selects annual when present")
    func loadInitialDataSelectsAnnual() async {
        let service = FakeStoreKitService()
        let state = makeIsolatedState()
        let vm = PremiumViewModel(storeKit: service, premiumState: state)

        await vm.loadInitialData()

        #expect(vm.selectedPlan == .annual)
    }

    @Test("loadInitialData selects first plan when annual not present")
    func loadInitialDataSelectsFirstWhenNoAnnual() async {
        let service = FakeStoreKitService()
        service.stubbedPlans = [
            SubscriptionPlan(
                id: .monthly,
                displayName: "Monthly",
                pricePerMonth: 9.99,
                pricePerPeriod: 9.99,
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
        let state = makeIsolatedState()
        let vm = PremiumViewModel(storeKit: service, premiumState: state)

        await vm.loadInitialData()

        #expect(vm.selectedPlan == .monthly)
    }

    // MARK: - Purchase

    @Test("purchaseSelectedPlan calls purchase and sets success only if Premium state becomes true")
    func purchaseSuccessSetsSuccessOnlyIfPremium() async {
        let service = FakeStoreKitService()
        let state = makeIsolatedState()
        let vm = PremiumViewModel(storeKit: service, premiumState: state)

        await vm.loadInitialData()

        // Simulate purchase succeeding but Premium not yet verified
        service.purchaseStub = { /* no-op, Premium stays false */ }

        await vm.purchaseSelectedPlan()

        #expect(!vm.showSuccess)
        #expect(!vm.showError)
    }

    @Test("purchaseSelectedPlan sets success when Premium state is true after purchase")
    func purchaseSuccessSetsSuccessWhenPremiumTrue() async {
        let service = FakeStoreKitService()
        let state = makeIsolatedState()
        let vm = PremiumViewModel(storeKit: service, premiumState: state)

        await vm.loadInitialData()

        service.purchaseStub = { [weak state] in
            state?.isPremiumUser = true
        }

        await vm.purchaseSelectedPlan()

        #expect(vm.showSuccess)
    }

    @Test("Purchase cancellation does not set showError")
    func purchaseCancellationSilent() async {
        let service = FakeStoreKitService()
        let state = makeIsolatedState()
        let vm = PremiumViewModel(storeKit: service, premiumState: state)

        await vm.loadInitialData()

        service.purchaseStub = {
            throw StoreKitError.purchaseCancelled
        }

        await vm.purchaseSelectedPlan()

        #expect(!vm.showError)
        #expect(!vm.showSuccess)
    }

    @Test("Purchase failure sets showError and errorMessage")
    func purchaseFailureSetsError() async {
        let service = FakeStoreKitService()
        let state = makeIsolatedState()
        let vm = PremiumViewModel(storeKit: service, premiumState: state)

        await vm.loadInitialData()

        service.purchaseStub = {
            throw StoreKitError.purchaseFailed
        }

        await vm.purchaseSelectedPlan()

        #expect(vm.showError)
        #expect(vm.errorMessage != nil)
    }

    @Test("Pending purchase shows friendly alert but does not mark Premium active")
    func pendingPurchaseShowsAlert() async {
        let service = FakeStoreKitService()
        let state = makeIsolatedState()
        let vm = PremiumViewModel(storeKit: service, premiumState: state)

        await vm.loadInitialData()

        service.purchaseStub = {
            throw StoreKitError.purchasePending
        }

        await vm.purchaseSelectedPlan()

        #expect(vm.showError)
        #expect(vm.errorMessage == StoreKitError.purchasePending.errorDescription)
        #expect(!state.isPremiumUser)
    }

    @Test("Missing product configuration shows error")
    func missingConfigShowsError() async {
        let service = FakeStoreKitService()
        let state = makeIsolatedState()
        let vm = PremiumViewModel(storeKit: service, premiumState: state)

        await vm.loadInitialData()

        service.purchaseStub = {
            throw StoreKitError.missingProductConfiguration
        }

        await vm.purchaseSelectedPlan()

        #expect(vm.showError)
        #expect(!state.isPremiumUser)
    }

    // MARK: - Restore

    @Test("Restore success sets success when Premium state is true")
    func restoreSuccessSetsSuccess() async {
        let service = FakeStoreKitService()
        let state = makeIsolatedState()
        let vm = PremiumViewModel(storeKit: service, premiumState: state)

        service.restoreStub = { [weak state] in
            state?.isPremiumUser = true
        }

        await vm.restorePurchases()

        #expect(vm.showSuccess)
    }

    @Test("Restore with no active subscription sets showError")
    func restoreNoActiveSubscriptionSetsError() async {
        let service = FakeStoreKitService()
        let state = makeIsolatedState()
        let vm = PremiumViewModel(storeKit: service, premiumState: state)

        service.restoreStub = {
            throw StoreKitError.noActiveSubscription
        }

        await vm.restorePurchases()

        #expect(vm.showError)
        #expect(vm.errorMessage == StoreKitError.noActiveSubscription.errorDescription)
        #expect(!state.isPremiumUser)
    }

    @Test("Restore failure sets showError")
    func restoreFailureSetsError() async {
        let service = FakeStoreKitService()
        let state = makeIsolatedState()
        let vm = PremiumViewModel(storeKit: service, premiumState: state)

        service.restoreStub = {
            throw StoreKitError.restoreFailed
        }

        await vm.restorePurchases()

        #expect(vm.showError)
    }

    // MARK: - dismissError

    @Test("dismissError clears error state")
    func dismissErrorClearsState() async {
        let service = FakeStoreKitService()
        let state = makeIsolatedState()
        let vm = PremiumViewModel(storeKit: service, premiumState: state)

        vm.showError = true
        vm.errorMessage = "test error"

        vm.dismissError()

        #expect(!vm.showError)
        #expect(vm.errorMessage == nil)
    }

    // MARK: - Trial copy and CTA (prices and trial length come from StoreKit)

    private static func storePlans(annualTrialUnit: String? = "14-day") -> [SubscriptionPlan] {
        [
            SubscriptionPlan(
                id: .annual, displayName: "Plus Annual", pricePerMonth: 2.1658, pricePerPeriod: 25.99,
                period: .annual, savingsPercent: 56, isBestValue: true, subtitle: nil,
                productID: "com.stressmonitor.app.plus.annual", displayPrice: "25,99 US$",
                billingSummary: "Billed annually", hasIntroductoryOffer: annualTrialUnit != nil,
                introOfferPeriodUnit: annualTrialUnit, monthlyEquivalentDisplay: "2,17 US$"
            ),
            SubscriptionPlan(
                id: .monthly, displayName: "Plus Monthly", pricePerMonth: 4.99, pricePerPeriod: 4.99,
                period: .monthly, savingsPercent: nil, isBestValue: false, subtitle: nil,
                productID: "com.stressmonitor.app.plus.monthly", displayPrice: "4,99 US$",
                billingSummary: "Billed monthly", hasIntroductoryOffer: false, introOfferPeriodUnit: nil
            )
        ]
    }

    @Test("Eligible + annual selected: CTA offers the trial with the product's length")
    func ctaTitleOffersTrialWhenEligible() async {
        let service = FakeStoreKitService()
        service.stubbedPlans = Self.storePlans()
        service.stubbedTrialEligibility = true
        let vm = PremiumViewModel(storeKit: service, premiumState: makeIsolatedState())

        await vm.loadInitialData()

        #expect(vm.selectedPlan == .annual)
        #expect(vm.annualTrialEligible)
        #expect(vm.showsTrialOffer)
        #expect(vm.ctaTitle.contains("free trial"))
        #expect(vm.ctaTitle == "Start 14-day free trial")
        #expect(vm.renewalTerms.contains("14-day free trial, then 25,99 US$/year"))
    }

    @Test("Not eligible (trial already used): CTA is Subscribe and no trial copy")
    func ctaTitleSubscribeWhenIneligible() async {
        let service = FakeStoreKitService()
        service.stubbedPlans = Self.storePlans()
        service.stubbedTrialEligibility = false
        let vm = PremiumViewModel(storeKit: service, premiumState: makeIsolatedState())

        await vm.loadInitialData()

        #expect(!vm.showsTrialOffer)
        #expect(vm.trialPeriodUnit == nil)
        #expect(vm.ctaTitle == "Subscribe")
        #expect(!vm.renewalTerms.contains("trial"))
        #expect(vm.renewalTerms.hasPrefix("25,99 US$/year."))
    }

    @Test("Monthly selected: CTA is Subscribe even when the annual trial is available")
    func ctaTitleSubscribeForMonthly() async {
        let service = FakeStoreKitService()
        service.stubbedPlans = Self.storePlans()
        service.stubbedTrialEligibility = true
        let vm = PremiumViewModel(storeKit: service, premiumState: makeIsolatedState())

        await vm.loadInitialData()
        vm.selectedPlan = .monthly

        #expect(!vm.showsTrialOffer)
        #expect(vm.ctaTitle == "Subscribe")
        #expect(vm.renewalTerms.hasPrefix("4,99 US$/month."))
    }

    @Test("Eligibility is asked for the annual product, whatever is selected")
    func eligibilityQueriedForAnnual() async {
        let service = FakeStoreKitService()
        service.stubbedPlans = Self.storePlans()
        service.stubbedTrialEligibility = true
        let vm = PremiumViewModel(storeKit: service, premiumState: makeIsolatedState())

        await vm.loadInitialData()

        #expect(service.eligibilityQueries == [.annual])
    }

    @Test("Annual product without an intro offer never shows trial copy")
    func noTrialCopyWithoutIntroOffer() async {
        let service = FakeStoreKitService()
        service.stubbedPlans = Self.storePlans(annualTrialUnit: nil)
        service.stubbedTrialEligibility = true
        let vm = PremiumViewModel(storeKit: service, premiumState: makeIsolatedState())

        await vm.loadInitialData()

        #expect(!vm.annualTrialEligible)
        #expect(!vm.showsTrialOffer)
        #expect(vm.ctaTitle == "Subscribe")
    }

    @Test("Placeholder plans carry no price, savings or trial")
    func placeholderPlansHaveNoPrices() {
        for plan in SubscriptionPlan.defaultPlans {
            #expect(!plan.hasStorePrice)
            #expect(plan.pricePerPeriod == .zero)
            #expect(plan.savingsPercent == nil)
            #expect(!plan.hasIntroductoryOffer)
            #expect(plan.priceDisplay == "\u{2014}")
        }
    }

    @Test("Savings label is computed from real prices and rounded down")
    func savingsFromRealPrices() {
        #expect(StoreKitService.savingsPercent(monthlyPrice: 4.99, annualPrice: 25.99) == 56)
        #expect(StoreKitService.savingsPercent(monthlyPrice: 0, annualPrice: 25.99) == nil)
        #expect(StoreKitService.savingsPercent(monthlyPrice: 1.99, annualPrice: 25.99) == nil)
    }

    // MARK: - Paywall states (SPEC ST5–ST7)

    @Test("No product loads: state is failed and buying is disabled")
    func loadFailureDisablesPurchase() async {
        let service = FakeStoreKitService()
        service.stubbedPlans = []
        let vm = PremiumViewModel(storeKit: service, premiumState: makeIsolatedState())

        await vm.loadInitialData()

        #expect(vm.loadState == .failed)
        #expect(!vm.canPurchase)
        #expect(!vm.showsTrialOffer)
        #expect(vm.ctaTitle == "Subscribe")
    }

    @Test("Retry after a failed load reaches loaded with real prices")
    func retryRecoversFromFailure() async {
        let service = FakeStoreKitService()
        service.stubbedPlans = []
        let vm = PremiumViewModel(storeKit: service, premiumState: makeIsolatedState())
        await vm.loadInitialData()
        #expect(vm.loadState == .failed)

        service.stubbedPlans = Self.storePlans()
        await vm.retryLoading()

        #expect(vm.loadState == .loaded)
        #expect(vm.canPurchase)
    }

    @Test("Placeholder plans without a store price cannot be bought")
    func placeholderPlansCannotBeBought() async {
        let service = FakeStoreKitService()
        service.stubbedPlans = SubscriptionPlan.defaultPlans
        let vm = PremiumViewModel(storeKit: service, premiumState: makeIsolatedState())

        await vm.loadInitialData()

        #expect(!vm.canPurchase)
    }

    @Test("Cancelled purchase leaves no error message")
    func cancelledPurchaseHasNoErrorMessage() async {
        let service = FakeStoreKitService()
        service.stubbedPlans = Self.storePlans()
        service.purchaseStub = { throw StoreKitError.purchaseCancelled }
        let vm = PremiumViewModel(storeKit: service, premiumState: makeIsolatedState())
        await vm.loadInitialData()

        await vm.purchaseSelectedPlan()

        #expect(vm.errorMessage == nil)
        #expect(!vm.showError)
    }

    @Test("Pending purchase shows Waiting for approval")
    func pendingPurchaseShowsWaitingForApproval() async {
        let service = FakeStoreKitService()
        service.stubbedPlans = Self.storePlans()
        service.purchaseStub = { throw StoreKitError.purchasePending }
        let vm = PremiumViewModel(storeKit: service, premiumState: makeIsolatedState())
        await vm.loadInitialData()

        await vm.purchaseSelectedPlan()

        #expect(vm.showError)
        #expect(vm.alertTitle == "Waiting for Approval")
        #expect(vm.errorMessage?.contains("Waiting for approval") == true)
    }

    @Test("Restore with nothing to restore says so")
    func restoreNothingToRestore() async {
        let service = FakeStoreKitService()
        service.restoreStub = { throw StoreKitError.noActiveSubscription }
        let vm = PremiumViewModel(storeKit: service, premiumState: makeIsolatedState())

        await vm.restorePurchases()

        #expect(vm.alertTitle == "Nothing to Restore")
        #expect(vm.errorMessage?.contains("Nothing to restore") == true)
        #expect(!vm.didRestore)
    }

    @Test("Successful restore marks the success sheet as a restore")
    func restoreSuccessMarksRestore() async {
        let service = FakeStoreKitService()
        let state = makeIsolatedState()
        service.restoreStub = { state.isPremiumUser = true }
        let vm = PremiumViewModel(storeKit: service, premiumState: state)

        await vm.restorePurchases()

        #expect(vm.showSuccess)
        #expect(vm.didRestore)
    }
}
