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
/// Below the paywall hero it renders the reason headline, the live server
/// credit balance header (count or "Unlimited" for premium, never the raw sentinel), the
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
        IAPPremiumView(
            storeKit: storeKitService,
            premiumState: PremiumState.shared,
            credits: CreditsViewModel(creditService: creditService, storeKit: storeKitService)
        ) {
            balanceHeader
        }
        .task { try? await creditService.refreshBalance() }
    }

    // MARK: - Balance Header

    private var balanceHeader: some View {
        VStack(spacing: 8) {
            // Reason headline keeps its logic; reasons without one get the
            // default title.
            Text(reason.headline ?? "Get more from your stress data")
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.V2.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: 6) {
                Image(systemName: "circlebadge.2")
                Text(CreditBalanceFormatter.balanceText(creditService.balance))
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.V2.ink2)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Credit balance: \(CreditBalanceFormatter.balanceText(creditService.balance))")

            if let resetLine = CreditBalanceFormatter.resetDateText(creditService.balance) {
                Text(resetLine)
                    .font(.caption)
                    .foregroundStyle(Color.V2.ink3)
            }

            if reason != .outOfCredits, CreditBalanceFormatter.isLowCredits(creditService.balance) {
                lowCreditsLine
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Expectation-setting copy for the backend's token-tier shrink below 20
    /// credits (research Pitfall 5). Dual coded: color paired with icon+text.
    private var lowCreditsLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "battery.25")
                .foregroundStyle(StressCategory.moderate.color)
            Text("Low on free messages this month. Plus gives you unlimited chat.")
                .foregroundStyle(Color.V2.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: V2Metrics.radiusSM, style: .continuous).fill(Color.V2.warnSoft)
        )
        .accessibilityElement(children: .combine)
    }
}
