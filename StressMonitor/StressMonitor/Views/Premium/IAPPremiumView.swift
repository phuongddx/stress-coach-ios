import SwiftUI

/// Plus paywall body (UI V2 `S.paywall`).
///
/// Layout: a pinned nav row (Restore, Close), then the companion hero, the
/// caller's `header` (reason headline and credit balance), what Plus unlocks
/// and the plans. The CTA, the auto-renew sentence and the legal links sit in
/// a footer pinned above the home indicator (inside the safe area). At
/// accessibility text sizes the footer moves to the end of the scroll so it
/// never covers the content.
///
/// Prices, periods and the trial length come only from the StoreKit-backed
/// `SubscriptionPlan` values on `PremiumViewModel`.
struct IAPPremiumView<Header: View>: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var viewModel: PremiumViewModel
    @State private var creditsViewModel: CreditsViewModel
    @State private var showPurchaseSuccess = false
    @State private var showPackSuccess = false

    private let header: Header

    init(
        storeKit: StoreKitServiceProtocol,
        premiumState: PremiumState,
        credits: CreditsViewModel,
        @ViewBuilder header: () -> Header
    ) {
        _viewModel = State(initialValue: PremiumViewModel(storeKit: storeKit, premiumState: premiumState))
        _creditsViewModel = State(initialValue: credits)
        self.header = header()
    }

    private var isLoadingPlans: Bool { viewModel.loadState == .loading }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                hero
                header
                IAPBenefitsCard()
                plansSection

                if dynamicTypeSize.isAccessibilitySize {
                    purchaseFooter
                        .padding(.top, 4)
                }

                paymentNote
            }
            .padding(.horizontal, V2Metrics.margin)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            IAPNavBar(
                isRestoreDisabled: viewModel.isLoading,
                onRestore: { Task { await viewModel.restorePurchases() } },
                onClose: { dismiss() }
            )
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !dynamicTypeSize.isAccessibilitySize {
                purchaseFooter
                    .padding(.horizontal, V2Metrics.margin)
                    .padding(.top, 12)
                    .padding(.bottom, 4)
                    .background(Color.V2.bg.ignoresSafeArea(edges: .bottom))
                    .overlay(alignment: .top) {
                        Rectangle().fill(Color.V2.line).frame(height: 0.5)
                    }
            }
        }
        .background(Color.V2.bg.ignoresSafeArea())
        .navigationBarHidden(true)
        .task {
            await viewModel.loadInitialData()
        }
        .onChange(of: viewModel.showSuccess) {
            if viewModel.showSuccess {
                showPurchaseSuccess = true
            }
        }
        .onChange(of: creditsViewModel.showSuccess) {
            if creditsViewModel.showSuccess {
                showPackSuccess = true
            }
        }
        .sheet(isPresented: $showPurchaseSuccess) {
            PurchaseSuccessView(isRestore: viewModel.didRestore)
                .onDisappear {
                    viewModel.showSuccess = false
                    dismiss()
                }
        }
        .sheet(isPresented: $showPackSuccess) {
            PurchaseSuccessView(
                purchasedPack: creditsViewModel.purchasedPack,
                newBalanceText: creditsViewModel.currentBalanceText
            )
            .onDisappear {
                creditsViewModel.showSuccess = false
                dismiss()
            }
        }
        .alert(viewModel.alertTitle, isPresented: $viewModel.showError) {
            Button("OK") { viewModel.dismissError() }
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred.")
        }
        .alert("Purchase Error", isPresented: $creditsViewModel.showError) {
            Button("OK") { creditsViewModel.dismissError() }
        } message: {
            Text(creditsViewModel.errorMessage ?? "An error occurred.")
        }
    }

    // MARK: - Hero

    /// Ripple with the two Plus companions, then the Plus pill.
    private var hero: some View {
        VStack(spacing: 10) {
            HStack(alignment: .bottom, spacing: 0) {
                CharacterAssetResolver.characterView(for: "zephyr", mood: .serene, size: 52)
                CharacterAssetResolver.characterView(for: "ripple", mood: .happy, size: 76)
                CharacterAssetResolver.characterView(for: "ember", mood: .serene, size: 52)
            }
            .accessibilityHidden(true)

            Text("StressMonitor Plus")
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .tracking(0.4)
                .foregroundStyle(Color.V2.plus)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.V2.plusBg))
                .overlay(Capsule().strokeBorder(Color.V2.plusLine, lineWidth: 0.5))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Plans

    private var plansSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Choose your plan")
                .v2Eyebrow()
                .padding(.horizontal, 4)
                .accessibilityAddTraits(.isHeader)

            switch viewModel.loadState {
            case .failed:
                loadFailedCard
            case .loading:
                loadingPlans
            case .loaded:
                if orderedPlans.isEmpty {
                    loadingPlans
                } else {
                    planList
                }
            }
        }
    }

    private var planList: some View {
        VStack(spacing: 10) {
            ForEach(orderedPlans) { plan in
                PlanCard(
                    plan: plan,
                    isSelected: viewModel.selectedPlan == plan.period,
                    isLoading: false,
                    trialPeriodUnit: plan.period == .annual ? viewModel.trialPeriodUnit : nil,
                    onSelect: {
                        viewModel.selectedPlan = plan.period
                        HapticManager.shared.buttonPress()
                    }
                )
            }
        }
    }

    /// Two plan-shaped skeletons while StoreKit resolves the products.
    private var loadingPlans: some View {
        VStack(spacing: 10) {
            PlanCard(plan: nil, isSelected: false, isLoading: true, onSelect: {})
            PlanCard(plan: nil, isSelected: false, isLoading: true, onSelect: {})
            Text("Loading prices from the App Store…")
                .font(.footnote)
                .foregroundStyle(Color.V2.ink3)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
    }

    /// SPEC ST7: no price could be loaded, so no plan is shown at all.
    private var loadFailedCard: some View {
        V2StateView(
            systemImage: "wifi.exclamationmark",
            title: "Couldn't load plans",
            message: "Couldn't load prices. Check your connection and try again. You won't be charged.",
            actionTitle: "Retry"
        ) {
            HapticManager.shared.buttonPress()
            Task { await viewModel.retryLoading() }
        }
        .v2CardBackground()
    }

    // MARK: - Purchase footer

    /// CTA, the auto-renew sentence for the selected product, and the Terms,
    /// Privacy and Manage subscription links next to the purchase button.
    private var purchaseFooter: some View {
        VStack(spacing: 10) {
            Button {
                Task { await viewModel.purchaseSelectedPlan() }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(Color.V2.onAccent)
                        .accessibilityLabel("Purchasing")
                } else {
                    Text(viewModel.ctaTitle)
                }
            }
            .buttonStyle(.v2(.primary))
            // Full strength while purchasing (spinner shows), dimmed only
            // when no product is ready to buy; taps are ignored while busy.
            .disabled(!(viewModel.canPurchase || viewModel.isLoading))
            .allowsHitTesting(!viewModel.isLoading)

            Text(autoRenewSentence)
                .font(.caption)
                .foregroundStyle(Color.V2.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            IAPFooterLinks()
        }
    }

    private var paymentNote: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "lock.fill")
                .imageScale(.small)
                .accessibilityHidden(true)
            Text("Payment is handled securely by Apple. Cancel anytime in Settings.")
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.footnote)
        .foregroundStyle(Color.V2.ink3)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Derived

    /// Loaded plans ordered annual -> monthly.
    private var orderedPlans: [SubscriptionPlan] {
        let order: [SubscriptionPeriod] = [.annual, .monthly]
        return order.compactMap { period in
            viewModel.plans.first(where: { $0.period == period })
        }
    }

    /// Auto-renew terms built from the selected StoreKit product: price,
    /// period and, when offered, the trial length.
    private var autoRenewSentence: String {
        let renewal = "Renews automatically unless cancelled at least 24 hours before the end of the period; manage or cancel in Settings \u{203A} Apple ID \u{203A} Subscriptions."
        guard let plan = viewModel.selectedPlanDetails, plan.hasStorePrice else {
            return "Subscriptions renew automatically unless cancelled at least 24 hours before the end of the period; manage or cancel in Settings \u{203A} Apple ID \u{203A} Subscriptions."
        }
        let price = "\(plan.priceDisplay)\(plan.periodUnitDisplay)"
        if viewModel.showsTrialOffer, let unit = viewModel.trialPeriodUnit {
            return "Includes a \(unit) free trial, then \(price). \(renewal)"
        }
        return "\(price). \(renewal)"
    }
}
