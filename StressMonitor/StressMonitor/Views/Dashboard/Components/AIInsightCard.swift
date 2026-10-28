import SwiftUI

/// Ripple's voice — the AI insight card that sits right under the hero.
///
/// Per the 04-home spec the status → AI summary flow: a Ripple avatar on the
/// left, a "Ripple · <age of the reading>" eyebrow, the insight message (which may
/// emphasize a fragment), and an optional "Ask Ripple" link.
///
/// Spec reference: design/screens/04-home.html — `.ai-insight`.
struct RippleInsightCard: View {
    let insight: AIInsight
    var onAskRipple: (() -> Void)?
    /// When the reading behind this insight was taken; nil omits the age from the eyebrow.
    var generatedAt: Date?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            avatar

            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrow)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(HomeCharacterDesignTokens.Ripple.deep)

                Text(insight.message)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color.Wellness.adaptivePrimaryText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                if onAskRipple != nil {
                    Button {
                        onAskRipple?()
                    } label: {
                        HStack(spacing: 4) {
                            Text("Ask Ripple")
                                .font(.system(size: 13, weight: .semibold))
                            Image(systemName: AppIconSystem.Nav.forward.sfSymbol)
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(HomeCharacterDesignTokens.Ripple.deep)
                        .padding(.top, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.Wellness.adaptiveCardBackground.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Ripple insight. \(insight.message)")
    }

    private var eyebrow: String {
        guard let generatedAt else { return "RIPPLE" }
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        formatter.unitsStyle = .abbreviated
        return "RIPPLE · \(formatter.localizedString(for: generatedAt, relativeTo: Date()).uppercased())"
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(HomeCharacterDesignTokens.Ripple.primary.opacity(0.14))
            StressBuddyIllustration(mood: .happy, size: 28)
        }
        .frame(width: 36, height: 36)
        .accessibilityHidden(true)
    }
}

// MARK: - AIInsight model

struct AIInsight: Sendable {
    let title: String
    let message: String
    let actionTitle: String?
    let trendData: [Double]?
}

// MARK: - Preview

#Preview("RippleInsightCard") {
    VStack(spacing: 12) {
        RippleInsightCard(
            insight: AIInsight(
                title: "Recovery",
                message: "Calm morning. HRV is 52 ms — your highest all week. An early wind-down tonight locks in the streak.",
                actionTitle: "Ask Ripple",
                trendData: nil
            ),
            onAskRipple: {}
        )
        RippleInsightCard(
            insight: AIInsight(
                title: "High Stress",
                message: "Stress is elevated. A 3-minute box breathing reset will bring it down.",
                actionTitle: nil,
                trendData: nil
            )
        )
    }
    .padding()
    .background(HomeCharacterDesignTokens.homeBackground)
}
