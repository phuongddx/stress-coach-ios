import SwiftUI

/// Single pricing tier in the paywall list (UI V2 plan card).
///
/// Shows a `V2Skeleton` while prices are still resolving so the layout
/// doesn't jump when `StoreKitService.availablePlans` returns. Once a plan is
/// available the card renders a radio, the plan name with its savings tag, a
/// one-line summary and the StoreKit price for the billing period.
struct PlanCard: View {
    let plan: SubscriptionPlan?
    let isSelected: Bool
    let isLoading: Bool
    /// Trial length label from StoreKit (e.g. the annual intro offer); nil
    /// when no trial is on offer for this plan.
    let trialPeriodUnit: String?
    let onSelect: () -> Void

    init(
        plan: SubscriptionPlan?,
        isSelected: Bool,
        isLoading: Bool,
        trialPeriodUnit: String? = nil,
        onSelect: @escaping () -> Void
    ) {
        self.plan = plan
        self.isSelected = isSelected
        self.isLoading = isLoading
        self.trialPeriodUnit = trialPeriodUnit
        self.onSelect = onSelect
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: V2Metrics.radiusLG, style: .continuous)
    }

    var body: some View {
        Button(action: onSelect) {
            Group {
                if isLoading || plan == nil {
                    skeletonContent
                } else {
                    planContent
                }
            }
            .padding(.horizontal, V2Metrics.margin)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(shape.fill(Color.V2.surface))
            .overlay(
                shape.strokeBorder(
                    isSelected ? Color.V2.accent : Color.V2.line2,
                    lineWidth: isSelected ? 2 : 1
                )
            )
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .disabled(isLoading || plan == nil)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Content

    @ViewBuilder
    private var planContent: some View {
        if let plan {
            HStack(alignment: .center, spacing: 12) {
                radio

                VStack(alignment: .leading, spacing: 2) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) { nameText(plan); badge(plan) }
                        VStack(alignment: .leading, spacing: 4) { nameText(plan); badge(plan) }
                    }
                    Text(summary(for: plan))
                        .font(.footnote)
                        .foregroundStyle(Color.V2.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 0) {
                    Text(plan.priceDisplay)
                        .font(.v2Number(.headline))
                        .foregroundStyle(Color.V2.ink)
                    Text(plan.periodUnitDisplay)
                        .font(.caption)
                        .foregroundStyle(Color.V2.ink3)
                }
                .fixedSize()
            }
        }
    }

    private func nameText(_ plan: SubscriptionPlan) -> some View {
        Text(plan.displayName)
            .font(.headline)
            .foregroundStyle(Color.V2.ink)
    }

    @ViewBuilder
    private func badge(_ plan: SubscriptionPlan) -> some View {
        if let tag = plan.savingsDisplay ?? (plan.isBestValue ? "Best value" : nil) {
            Text(tag)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.V2.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.V2.accentSoft))
                .fixedSize()
        }
    }

    private var radio: some View {
        ZStack {
            Circle()
                .strokeBorder(isSelected ? Color.V2.accent : Color.V2.ink3, lineWidth: 2)
                .frame(width: 22, height: 22)
            if isSelected {
                Circle().fill(Color.V2.accent).frame(width: 12, height: 12)
            }
        }
        .accessibilityHidden(true)
    }

    private var skeletonContent: some View {
        HStack(spacing: 12) {
            Circle().fill(Color.V2.surface2).frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 8) {
                V2Skeleton(width: 110, height: 16)
                V2Skeleton(width: 170, height: 12)
            }
            Spacer(minLength: 0)
            V2Skeleton(width: 64, height: 20)
        }
        .frame(minHeight: 44)
    }

    // MARK: - Derived

    /// One line under the plan name, built only from StoreKit-derived values.
    private func summary(for plan: SubscriptionPlan) -> String {
        var parts: [String] = []
        if let trialPeriodUnit {
            parts.append("\(trialPeriodUnit) free trial")
        }
        if let monthly = plan.monthlyEquivalentDisplay {
            parts.append("\u{2248}\u{00A0}\(monthly)/month")
        } else if let billing = plan.billingSummary {
            parts.append(billing)
        }
        if plan.period == .monthly {
            parts.append("No commitment")
        }
        return parts.joined(separator: " \u{00B7} ")
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
        if let trialPeriodUnit {
            label += ", \(trialPeriodUnit) free trial"
        }
        return label + selected
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 12) {
        PlanCard(plan: PlanCard.previewAnnual, isSelected: true, isLoading: false,
                 trialPeriodUnit: PlanCard.previewAnnual.introOfferPeriodUnit, onSelect: {})
        PlanCard(plan: PlanCard.previewMonthly, isSelected: false, isLoading: false, onSelect: {})
        PlanCard(plan: nil, isSelected: false, isLoading: true, onSelect: {})
    }
    .padding()
    .background(Color.V2.bg)
}

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
