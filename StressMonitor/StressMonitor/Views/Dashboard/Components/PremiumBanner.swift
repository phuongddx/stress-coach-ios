import SwiftUI

/// Premium upsell — frosted-glass banner with the premium companion team.
///
/// The gradient is built from three premium character colors (Ember / Zephyr /
/// Lumi) so it reads as narrative rather than decoration. A frost layer (iOS
/// Control Center lineage) sits over the gradient. Three companion busts
/// overlap on the right; copy + a CTA pill sit on the left. The pill offers a
/// trial only when `trialPeriodUnit` comes from an eligible StoreKit product.
///
/// Spec reference: design/screens/04-home.html — `.premium-banner`.
struct PremiumBanner: View {
    var onUpgrade: (() -> Void)? = nil
    /// Trial length from the annual product (e.g. "14-day"); nil hides trial copy.
    var trialPeriodUnit: String? = nil

    private static let benefits = "Unlimited chat · all your charts · premium companions"

    private var ctaTitle: String {
        trialPeriodUnit.map { "\($0) free trial" } ?? "See Plus"
    }

    private var accessibilityHintText: String {
        trialPeriodUnit.map { "Double tap to start a \($0) free trial" } ?? "Double tap to see StressMonitor Plus"
    }

    var body: some View {
        ZStack {
            gradientBackground
            frostLayer
            glow
            content
        }
        .frame(minHeight: 116)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("StressMonitor Plus. Meet your full companion team. \(Self.benefits.replacingOccurrences(of: " · ", with: ", ")).")
        .accessibilityHint(accessibilityHintText)
    }

    // MARK: - Background layers

    private var gradientBackground: some View {
        LinearGradient(
            colors: [
                Color(hex: "#FFAB91"),
                Color(hex: "#FE9901"),
                Color(hex: "#B39DDB"),
                Color(hex: "#7986CB")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var frostLayer: some View {
        Color.white.opacity(0.17)
            .background(.ultraThinMaterial)
    }

    private var glow: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color.white.opacity(0.30), .clear],
                    center: .center,
                    startRadius: 1,
                    endRadius: 80
                )
            )
            .frame(width: 160, height: 160)
            .offset(x: 90, y: -50)
            .accessibilityHidden(true)
    }

    // MARK: - Content

    private var content: some View {
        HStack(spacing: 12) {
            copyBlock
            Spacer(minLength: 0)
            companionStack
        }
        .padding(16)
    }

    private var copyBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("STRESSMONITOR PLUS")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(Color.white.opacity(0.92))

            Text("Meet your full companion team")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .tracking(-0.3)
                .foregroundStyle(.white)
                .padding(.top, 1)

            Text(Self.benefits)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.92))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 1)

            ctaPill
                .padding(.top, 6)
        }
    }

    private var ctaPill: some View {
        Button {
            onUpgrade?()
        } label: {
            HStack(spacing: 4) {
                Text(ctaTitle)
                    .font(.system(size: 11, weight: .bold))
                Image(systemName: AppIconSystem.Nav.forward.sfSymbol)
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(HomeCharacterDesignTokens.Lumi.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.95))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .minimumTouchTarget(DesignTokens.Layout.minTouchTarget)
    }

    // MARK: - Companion stack

    private var companionStack: some View {
        HStack(spacing: -10) {
            companionBust(symbol: "flame.fill", background: Color(hex: "#FF7043"), scale: 0.92, offsetX: 4)
            companionBust(symbol: "wind", background: Color(hex: "#9575CD"), scale: 1.0, offsetX: 0)
            companionBust(symbol: "star.fill", background: Color(hex: "#5C6BC0"), scale: 0.92, offsetX: -4)
        }
        .accessibilityHidden(true)
    }

    private func companionBust(symbol: String, background: Color, scale: CGFloat, offsetX: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(background)
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 38, height: 38)
        .overlay(Circle().stroke(Color.white.opacity(0.45), lineWidth: 1.5))
        .shadow(color: Color(red: 0.16, green: 0.08, blue: 0.24).opacity(0.22), radius: 5, y: 4)
        .scaleEffect(scale)
        .offset(x: offsetX)
    }
}

// MARK: - Preview

#Preview("PremiumBanner") {
    VStack(spacing: 16) {
        PremiumBanner(onUpgrade: {}, trialPeriodUnit: "14-day")
        PremiumBanner(onUpgrade: {})
    }
    .padding()
    .background(HomeCharacterDesignTokens.homeBackground)
}
