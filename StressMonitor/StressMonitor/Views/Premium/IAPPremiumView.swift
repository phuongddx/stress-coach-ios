import SwiftUI

struct IAPPremiumView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: PremiumViewModel
    @State private var creditsViewModel: CreditsViewModel
    @State private var showPurchaseSuccess = false
    @State private var showPackSuccess = false

    init(
        storeKit: StoreKitServiceProtocol,
        premiumState: PremiumState,
        credits: CreditsViewModel
    ) {
        _viewModel = State(initialValue: PremiumViewModel(storeKit: storeKit, premiumState: premiumState))
        _creditsViewModel = State(initialValue: credits)
    }

    private var isLoadingPlans: Bool { viewModel.loadState == .loading }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    IAPNavBar(onBack: { dismiss() }, onClose: { dismiss() })

                    // Section 1 — Transformation hero
                    RippleTransformationHero()
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    // Section 2 — Features (lead with Trends)
                    IAPBenefitsCard()
                        .padding(.horizontal, 16)
                        .padding(.top, 20)

                    // Section 3 — Plan grid (with loading skeleton)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("CHOOSE YOUR PLAN")
                            .font(Typography.iapSectionHeader)
                            .kerning(0.10 * 12)
                            .foregroundStyle(Color.iapHeaderTeal)
                            .padding(.horizontal, 4)

                        if viewModel.loadState == .failed {
                            loadFailedCard
                        } else {
                            planGrid
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 24)

                    if viewModel.showsTrialOffer {
                        trialBanner
                            .padding(.horizontal, 16)
                            .padding(.top, 18)
                    }

                    // Section 5 — Trust indicators
                    TrustRow()
                        .padding(.horizontal, 16)
                        .padding(.top, 14)

                    // Spacer for sticky bottom bar
                    Color.clear.frame(height: 150)
                }
                .padding(.bottom, 20)
            }
            .background(
                ZStack {
                    Color.iapWarmBackground
                    RadialGradient(
                        colors: [Color.iapGradientStart.opacity(0.12), .clear],
                        center: .top,
                        startRadius: 0,
                        endRadius: 350
                    )
                }
            )
            .accessibleDynamicType()

            // Sticky bottom CTA bar
            VStack(spacing: 0) {
                IAPCTAButton(title: viewModel.ctaTitle, isLoading: viewModel.isLoading) {
                    Task { await viewModel.purchaseSelectedPlan() }
                }
                .disabled(!viewModel.canPurchase)
                .opacity(viewModel.canPurchase || viewModel.isLoading ? 1 : 0.45)

                VStack(spacing: 4) {
                    Text(viewModel.renewalTerms)
                        .font(Typography.iapFinePrint)
                        .foregroundStyle(Color.iapTextSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 4) {
                        Link("Terms", destination: DocsURL.terms)
                            .foregroundStyle(Color.iapHeaderTeal)
                        Text("\u{00B7}")
                            .foregroundStyle(Color.iapTextSecondary)
                        Link("Privacy", destination: DocsURL.privacy)
                            .foregroundStyle(Color.iapHeaderTeal)
                    }
                    .font(Typography.iapFinePrint)
                }
                .padding(.top, 9)

                IAPFooterLinks {
                    Task { await viewModel.restorePurchases() }
                }
                .disabled(viewModel.isLoading)
                .padding(.top, 8)
            }
            .padding(.horizontal, 17)
            .padding(.top, 12)
            .padding(.bottom, 18)
            .background(
                Color.iapWarmBackground.opacity(0.88)
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea()
            )
            .overlay(alignment: .top) {
                Divider().background(Color.iapIconBorder.opacity(0.15))
            }
        }
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

    // MARK: - Plan grid

    private var planGrid: some View {
        VStack(spacing: 10) {
            ForEach(Array(orderedPlans.enumerated()), id: \.offset) { _, plan in
                PlanCard(
                    plan: plan,
                    isSelected: viewModel.selectedPlan == plan?.period,
                    isLoading: isLoadingPlans,
                    onSelect: {
                        if let period = plan?.period {
                            viewModel.selectedPlan = period
                            HapticManager.shared.buttonPress()
                        }
                    }
                )
            }
        }
    }

    /// SPEC ST7: no price could be loaded, so no plan is shown at all.
    private var loadFailedCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.iapHeaderTeal)
                .accessibilityHidden(true)
            Text("Couldn't load prices. Check your connection and try again.")
                .font(Typography.iapPlanFooter)
                .foregroundStyle(Color.iapTextPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                HapticManager.shared.buttonPress()
                Task { await viewModel.retryLoading() }
            } label: {
                Text("Retry")
                    .font(Typography.iapPlanName)
                    .foregroundStyle(Color.iapHeaderTeal)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 8)
                    .background(Capsule().stroke(Color.iapHeaderTeal.opacity(0.4), lineWidth: 1.2))
            }
            .buttonStyle(.plain)
            .minimumTouchTarget(DesignTokens.Layout.minTouchTarget)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Color.iapCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 23))
        .overlay(
            RoundedRectangle(cornerRadius: 23)
                .stroke(Color.iapIconBorder.opacity(0.15), lineWidth: 1.4)
        )
    }

    // MARK: - Trial banner

    private var trialBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "gift.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.iapAmber)
            VStack(alignment: .leading, spacing: 2) {
                Text(trialHeadline)
                    .font(Typography.iapPlanName)
                    .foregroundStyle(Color.iapTextPrimary)
                Text("Then \(selectedPlanPriceDisplay). Cancel anytime during the trial.")
                    .font(Typography.iapPlanFooter)
                    .foregroundStyle(Color.iapTextSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [Color.iapAmber.opacity(0.14), Color.iapCardBackground.opacity(0.6)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.iapAmber.opacity(0.25), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(trialHeadline), then \(selectedPlanPriceDisplay). Cancel anytime during the trial.")
    }

    // MARK: - Derived

    /// Plans ordered annual -> monthly. While loading, returns two
    /// `nil` placeholders so the grid renders two skeleton cards.
    private var orderedPlans: [SubscriptionPlan?] {
        if isLoadingPlans || viewModel.plans.isEmpty {
            // Two skeleton slots matching the expected plan count
            return [nil, nil]
        }
        let order: [SubscriptionPeriod] = [.annual, .monthly]
        return order.compactMap { period in
            viewModel.plans.first(where: { $0.period == period })
        }
    }

    /// Price with its period ("$25.99/year") so the post-trial charge is explicit.
    private var selectedPlanPriceDisplay: String {
        guard let plan = viewModel.selectedPlanDetails, plan.hasStorePrice else { return "\u{2014}" }
        return "\(plan.priceDisplay)\(plan.periodUnitDisplay)"
    }

    private var trialHeadline: String {
        if let unit = viewModel.trialPeriodUnit {
            return "\(unit) free trial"
        }
        return "Free trial"
    }
}
