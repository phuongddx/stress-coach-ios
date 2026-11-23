import SwiftUI

/// Compact trust indicators shown beneath the plan grid on the paywall.
/// Only statements that are always true for a StoreKit subscription.
struct TrustRow: View {
    var body: some View {
        VStack(spacing: 10) {
            trustItem(icon: "xmark.circle.fill", tint: Color.iapHeaderTeal, text: "Cancel anytime in Settings")
            trustItem(icon: "lock.fill", tint: Color.iapSavingsGreen, text: "Payment handled securely by Apple")
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(Color.iapCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.iapIconBorder.opacity(0.12), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Cancel anytime in Settings. Payment handled securely by Apple.")
    }

    private func trustItem(icon: String, tint: Color, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 22)
            Text(text)
                .font(Typography.iapPlanFooter)
                .foregroundStyle(Color.iapTextSecondary)
            Spacer()
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    TrustRow()
        .padding()
        .background(Color.iapWarmBackground)
}
