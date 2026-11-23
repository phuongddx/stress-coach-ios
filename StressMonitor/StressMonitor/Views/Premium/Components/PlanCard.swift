import SwiftUI

/// Single pricing tier in the paywall grid.
///
/// Shows a shimmering `SkeletonBlock` while prices are still resolving so the
/// layout doesn't jump when `StoreKitService.availablePlans` returns. Once a
/// plan is available the card renders name, the StoreKit price for the billing
/// period (annual adds a smaller per-month equivalent) and the savings label.
struct PlanCard: View {
    let plan: SubscriptionPlan?
    let isSelected: Bool
    let isLoading: Bool
    let onSelect: () -> Void

    init(plan: SubscriptionPlan?, isSelected: Bool, isLoading: Bool, onSelect: @escaping () -> Void) {
        self.plan = plan
        self.isSelected = isSelected
        self.isLoading = isLoading
        self.onSelect = onSelect
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 10) {
                if isLoading || plan == nil {
                    skeletonContent
                } else {
                    planContent
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .background(Color.iapCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 23))
            .overlay(
                RoundedRectangle(cornerRadius: 23)
                    .stroke(isSelected ? Color.iapAmber : Color.iapIconBorder.opacity(0.15), lineWidth: 1.4)
            )
            .shadow(
                color: isSelected
                    ? Color(hex: "FFAE3B").opacity(0.16)
                    : Color.black.opacity(0.04),
                radius: isSelected ? 12 : 8,
                y: isSelected ? 6 : 3
            )
            .overlay(alignment: .top) {
                if let plan, plan.isBestValue, isSelected {
                    Text("Best Value")
                        .font(Typography.iapBadge)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.iapAmber))
                        .shadow(color: Color(hex: "FFAE3B").opacity(0.26), radius: 6, y: 3)
                        .offset(y: -13)
                } else if let plan, plan.subtitle == "Most popular" {
                    Text("Most Popular")
                        .font(Typography.iapBadge)
                        .foregroundStyle(Color.iapHeaderTeal)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.iapPillBackground))
                        .overlay(Capsule().stroke(Color.iapHeaderTeal.opacity(0.3), lineWidth: 1))
                        .offset(y: -13)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isLoading || plan == nil)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Content

    @ViewBuilder
    private var planContent: some View {
        if let plan {
            HStack(alignment: .top) {
                // Radio
                ZStack {
                    Circle()
                        .stroke(
                            isSelected ? Color.iapAmber : Color.iapTextSecondary.opacity(0.35),
                            lineWidth: 2
                        )
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle().fill(Color.iapAmber).frame(width: 10, height: 10)
                    }
                }
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.displayName)
                        .font(Typography.iapPlanName)
                        .tracking(-0.03 * 17)
                        .foregroundStyle(Color.iapTextPrimary)

                    if let subtitle = plan.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(Typography.iapPlanSubtitle)
                            .foregroundStyle(Color.iapTextSecondary)
                    }
                }
                .padding(.leading, 10)

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(plan.priceDisplay)
                            .font(Typography.iapPrice)
                            .tracking(-0.045 * 22)
                            .foregroundStyle(Color.iapTextPrimary)
                        Text(plan.periodUnitDisplay)
                            .font(Typography.iapPerMonth)
                            .foregroundStyle(Color.iapTextSecondary)
                    }
                    if let monthly = plan.monthlyEquivalentDisplay {
                        Text("\u{2248} \(monthly)/month")
                            .font(Typography.iapPlanFooter)
                            .foregroundStyle(Color.iapTextSecondary)
                    }
                }
            }

            HStack {
                Text(leftFooter(for: plan))
                    .font(Typography.iapPlanFooter)
                    .foregroundStyle(footerColor(for: plan))
                Spacer()
                Text(plan.billingSummary ?? "")
                    .font(Typography.iapPlanFooter)
                    .foregroundStyle(footerColor(for: plan))
            }
        }
    }

    private var skeletonContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle().fill(Color.iapIconBorder.opacity(0.15)).frame(width: 22, height: 22)
                SkeletonBlock(height: 14).frame(width: 90)
                Spacer()
                SkeletonBlock(height: 22).frame(width: 70)
            }
            SkeletonBlock(height: 10).frame(width: 140)
        }
    }

    // MARK: - Derived

    private func leftFooter(for plan: SubscriptionPlan) -> String {
        switch plan.period {
        case .annual:  return plan.savingsDisplay ?? ""
        case .monthly: return "No commitment"
        }
    }

    private func footerColor(for plan: SubscriptionPlan) -> Color {
        plan.period == .annual ? Color.iapSavingsGreen : Color.iapTextSecondary
    }

    private var accessibilityLabel: String {
        if isLoading || plan == nil {
            return "Loading plan"
        }
        guard let plan else { return "Plan" }
        let selected = isSelected ? ", selected" : ""
        var label = "\(plan.displayName), \(plan.priceDisplay) \(plan.periodUnitDisplay)"
        if let monthly = plan.monthlyEquivalentDisplay {
            label += ", about \(monthly) per month"
        }
        return label + selected
    }
}

#Preview {
    VStack(spacing: 16) {
        PlanCard(plan: PlanCard.previewAnnual, isSelected: true, isLoading: false, onSelect: {})
        PlanCard(plan: PlanCard.previewMonthly, isSelected: false, isLoading: false, onSelect: {})
        PlanCard(plan: nil, isSelected: false, isLoading: true, onSelect: {})
    }
    .padding()
    .background(Color(hex: "F5F2EC"))
}

#if DEBUG
private extension PlanCard {
    // Preview-only sample matching the .storekit test configuration.
    static let previewAnnual = SubscriptionPlan(
        id: .annual, displayName: "Plus Annual", pricePerMonth: 2.17, pricePerPeriod: 25.99,
        period: .annual, savingsPercent: 56, isBestValue: true, subtitle: "Best value option",
        productID: nil, displayPrice: "25,99 US$", billingSummary: "Billed annually",
        hasIntroductoryOffer: true, introOfferPeriodUnit: "14-day", monthlyEquivalentDisplay: "2,17 US$"
    )
    static let previewMonthly = SubscriptionPlan(
        id: .monthly, displayName: "Plus Monthly", pricePerMonth: 4.99, pricePerPeriod: 4.99,
        period: .monthly, savingsPercent: nil, isBestValue: false, subtitle: nil,
        productID: nil, displayPrice: "4,99 US$", billingSummary: "Billed monthly",
        hasIntroductoryOffer: false, introOfferPeriodUnit: nil
    )
}
#endif
