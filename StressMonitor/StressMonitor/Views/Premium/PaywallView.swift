import SwiftUI

/// Thin wrapper around `IAPPremiumView`.
///
/// Presented **full-screen from anywhere** via `PaywallController.present(reason:)`,
/// which drives the root `.fullScreenCover(item:)` (see `MainTabView`).
///
/// The `StoreKitServiceProtocol` instance comes from the environment —
/// `StressMonitorApp` owns exactly one for the app's process lifetime, so
/// its `Transaction.updates` listener runs continuously instead of only
/// while this view happens to be on screen. This view must never construct
/// its own instance; that was the original bug.
///
/// Above the paywall content it renders the live server credit balance
/// header (count or "Unlimited" for premium, never the raw sentinel), the
/// free-tier reset date, and — when presented because chat hit HTTP 402 —
/// the out-of-credits heading variant (DEC-2 placement-a).
struct PaywallView: View {
    let reason: PaywallReason
    @Environment(\.storeKitService) private var storeKitService
    @Environment(CreditService.self) private var creditService

    init(reason: PaywallReason = .general) {
        self.reason = reason
    }

    var body: some View {
        VStack(spacing: 0) {
            balanceHeader
            IAPPremiumView(
                storeKit: storeKitService,
                premiumState: PremiumState.shared,
                credits: CreditsViewModel(creditService: creditService, storeKit: storeKitService)
            )
        }
        .task { try? await creditService.refreshBalance() }
    }

    // MARK: - Balance Header

    private var balanceHeader: some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            if let headline = reason.headline {
                Text(headline)
                    .font(Typography.iapPlanName)
                    .foregroundStyle(Color.iapHeaderTeal)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.top, DesignTokens.Spacing.sm)
                    .accessibilityAddTraits(.isHeader)
            }

            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "circlebadge.2")
                Text(CreditBalanceFormatter.balanceText(creditService.balance))
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Credit balance: \(CreditBalanceFormatter.balanceText(creditService.balance))")

            if let resetLine = CreditBalanceFormatter.resetDateText(creditService.balance) {
                Text(resetLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if reason != .outOfCredits, CreditBalanceFormatter.isLowCredits(creditService.balance) {
                lowCreditsLine
            }
        }
        .padding(.top, reason.headline == nil ? DesignTokens.Spacing.sm : 0)
        .padding(.bottom, DesignTokens.Spacing.xs)
        .accessibleDynamicType()
    }

    /// Expectation-setting copy for the backend's token-tier shrink below 20
    /// credits (research Pitfall 5). Dual coded: color paired with icon+text.
    private var lowCreditsLine: some View {
        HStack(spacing: 6) {
            Image(systemName: "battery.25")
            Text("Low on free messages this month. Plus gives you unlimited chat.")
        }
        .font(.caption)
        .foregroundStyle(Color(hex: "B25000"))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(Color(hex: "B25000").opacity(0.10))
        )
        .accessibilityElement(children: .combine)
    }
}
