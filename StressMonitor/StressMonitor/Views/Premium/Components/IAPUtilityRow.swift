import SwiftUI

// MARK: - Trust Indicators (3-column grid)

struct IAPTrustIndicators: View {
    var body: some View {
        HStack(spacing: 8) {
            trustItem(icon: "apple.logo", title: "Apple secure purchase")
            trustItem(icon: "arrow.triangle.2.circlepath", title: "Restore purchases")
            trustItem(icon: "xmark.circle", title: "Cancel anytime")
        }
    }

    private func trustItem(icon: String, title: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(Typography.iapTrustIcon)
                .foregroundStyle(Color.iapTextPrimary)

            Text(title)
                .font(Typography.iapTrustLabel)
                .foregroundStyle(Color.iapTextSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 64)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.iapTrustBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.iapIconBorder.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Footer Utility Links

/// Paywall legal and account links (UI V2): Terms of Use, Privacy Policy and
/// Manage subscription. Restore lives in the pinned nav row, so it is always
/// on screen. One line when it fits, two lines otherwise, one per line at the
/// largest text sizes.
struct IAPFooterLinks: View {
    private static let manageSubscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions")!

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) { terms; dot; privacy; dot; manage }
            VStack(spacing: 0) {
                HStack(spacing: 0) { terms; dot; privacy }
                manage
            }
            VStack(spacing: 0) { terms; privacy; manage }
        }
        .font(.footnote.weight(.semibold))
        .frame(maxWidth: .infinity)
    }

    private var terms: some View {
        Link("Terms of Use", destination: DocsURL.terms).modifier(FooterLinkStyle())
    }

    private var privacy: some View {
        Link("Privacy Policy", destination: DocsURL.privacy).modifier(FooterLinkStyle())
    }

    private var manage: some View {
        Link("Manage subscription", destination: Self.manageSubscriptionsURL).modifier(FooterLinkStyle())
    }

    private var dot: some View {
        Text("\u{00B7}")
            .foregroundStyle(Color.V2.ink3)
            .padding(.horizontal, 4)
            .accessibilityHidden(true)
    }
}

private struct FooterLinkStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(Color.V2.accent)
            .lineLimit(1)
            .fixedSize()
            .frame(minHeight: V2Metrics.minTouchTarget)
            .contentShape(Rectangle())
    }
}

// MARK: - Legacy alias for backward compatibility
struct IAPUtilityRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(iconColor)
                    .frame(width: 20, height: 20)

                Text(title)
                    .font(Typography.iapUtilityLabel)
                    .foregroundStyle(Color.iapTextPrimary)

                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(Color.Wellness.adaptiveCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }
}
