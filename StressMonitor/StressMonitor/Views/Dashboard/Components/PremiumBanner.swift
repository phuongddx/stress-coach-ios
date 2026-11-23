import SwiftUI

/// Premium upsell row on Home (UI V2): a Plus-tinted card with a spark icon,
/// the product name, the benefits, and a chevron. The trial line appears only
/// when `trialPeriodUnit` comes from an eligible StoreKit product; no price or
/// trial length is ever hardcoded here.
///
/// Spec reference: ui-v2-design/screens.js `S.home` Plus row.
struct PremiumBanner: View {
    var onUpgrade: (() -> Void)? = nil
    /// Trial length from the annual product (e.g. "14-day"); nil hides trial copy.
    var trialPeriodUnit: String? = nil

    private static let benefits = "Unlimited chat · all your charts · premium companions"

    private var trialLine: String? {
        trialPeriodUnit.map { "\($0) free trial" }
    }

    private var accessibilityHintText: String {
        trialPeriodUnit.map { "Double tap to start a \($0) free trial" } ?? "Double tap to see StressMonitor Plus"
    }

    var body: some View {
        Group {
            if let onUpgrade {
                Button(action: onUpgrade) { content }
                    .buttonStyle(.plain)
            } else {
                content
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("StressMonitor Plus. Meet your full companion team. \(Self.benefits.replacingOccurrences(of: " · ", with: ", ")).")
        .accessibilityHint(accessibilityHintText)
    }

    private var content: some View {
        let shape = RoundedRectangle(cornerRadius: V2Metrics.radiusLG, style: .continuous)
        return HStack(alignment: .center, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.V2.plus)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("StressMonitor Plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.V2.ink)
                Text(Self.benefits)
                    .font(.footnote)
                    .foregroundStyle(Color.V2.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                if let trialLine {
                    Text(trialLine)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.V2.plus)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.V2.ink3)
                .accessibilityHidden(true)
        }
        .padding(V2Metrics.margin)
        .frame(minHeight: V2Metrics.minTouchTarget)
        .background(shape.fill(Color.V2.plusBg))
        .overlay(shape.strokeBorder(Color.V2.plusLine, lineWidth: 1))
        .contentShape(shape)
    }
}

// MARK: - Preview

#Preview("PremiumBanner") {
    VStack(spacing: 16) {
        PremiumBanner(onUpgrade: {}, trialPeriodUnit: "14-day")
        PremiumBanner(onUpgrade: {})
    }
    .padding()
    .background(Color.V2.bg)
}
