import SwiftUI

/// What Plus unlocks (UI V2): one card, an accent icon per row, a bold line
/// and a one-sentence description.
struct IAPBenefitsCard: View {
    private struct Benefit: Identifiable {
        let icon: String
        let title: String
        let description: String
        var id: String { title }
    }

    private let benefits: [Benefit] = [
        Benefit(
            icon: "bubble.left.and.bubble.right.fill",
            title: "Unlimited AI chat",
            description: "Talk with Ripple as often as you like. Free accounts get 20 messages a month."
        ),
        Benefit(
            icon: "chart.xyaxis.line",
            title: "All your charts",
            description: "See every chart in full: stress over time, HRV trends, monthly heatmap, biological age and breathing results."
        ),
        Benefit(
            icon: "calendar",
            title: "30- and 90-day Trends",
            description: "Look past the last week and spot how your stress changes over months."
        ),
        Benefit(
            icon: "face.smiling",
            title: "Plus companions",
            description: "Unlock Ember and Zephyr to join Ripple on your home screen. Lumi unlocks with a 30-day streak."
        )
    ]

    var body: some View {
        V2Card {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(benefits) { benefit in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: benefit.icon)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.V2.accent)
                            .frame(width: 24)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(benefit.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.V2.ink)
                            Text(benefit.description)
                                .font(.footnote)
                                .foregroundStyle(Color.V2.ink3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

#Preview {
    IAPBenefitsCard()
        .padding()
        .background(Color.V2.bg)
}
