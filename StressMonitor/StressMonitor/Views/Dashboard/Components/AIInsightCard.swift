import SwiftUI

/// Ripple's voice (UI V2): the companion on the left, a "Ripple" label in the
/// accent colour with the age of the reading, the insight message, and an
/// optional "Ask Ripple" button.
///
/// Spec reference: ui-v2-design/screens.js `rippleCard`.
struct RippleInsightCard: View {
    let insight: AIInsight
    var onAskRipple: (() -> Void)?
    /// When the reading behind this insight was taken; nil omits the age from the label.
    var generatedAt: Date?

    var body: some View {
        V2Card {
            HStack(alignment: .top, spacing: 12) {
                StressBuddyIllustration(mood: .happy, size: 44, pose: .thinking, crop: .head, lightChip: true)
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.V2.accent)

                    Text(insight.message)
                        .font(.callout)
                        .foregroundStyle(Color.V2.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    if let onAskRipple {
                        Button("Ask Ripple", action: onAskRipple)
                            .buttonStyle(.v2(.secondary, compact: true, fullWidth: false))
                            .padding(.top, 8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Ripple insight. \(insight.message)")
    }

    private var label: String {
        guard let generatedAt else { return "Ripple" }
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        formatter.unitsStyle = .abbreviated
        return "Ripple · \(formatter.localizedString(for: generatedAt, relativeTo: Date()))"
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
    .background(Color.V2.bg)
}
