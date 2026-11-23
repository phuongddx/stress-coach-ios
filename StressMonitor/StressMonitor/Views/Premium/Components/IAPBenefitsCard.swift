import SwiftUI

struct IAPBenefitsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section label
            Text("WHAT PLUS UNLOCKS")
                .font(Typography.iapSectionHeader)
                .kerning(0.10 * 12)
                .foregroundStyle(Color.iapHeaderTeal)
                .padding(.horizontal, 4)
                .padding(.bottom, 10)

            // Benefits card
            VStack(spacing: 0) {
                benefitRow(
                    icon: "sparkles",
                    accentColor: Color.iapPurple,
                    title: "Unlimited AI chat",
                    description: "Talk with Ripple as often as you like. Free accounts get 20 messages a month."
                )

                Divider()
                    .background(Color.iapIconBorder.opacity(0.15))
                    .padding(.horizontal, 2)

                benefitRow(
                    icon: "chart.xyaxis.line",
                    accentColor: Color.iapHeaderTeal,
                    title: "All your charts",
                    description: "See every chart in full: stress over time, HRV trends, monthly heatmap, biological age and breathing results."
                )

                Divider()
                    .background(Color.iapIconBorder.opacity(0.15))
                    .padding(.horizontal, 2)

                benefitRow(
                    icon: "chart.line.uptrend.xyaxis",
                    accentColor: Color.iapSavingsGreen,
                    title: "30- and 90-day Trends",
                    description: "Look past the last week and spot how your stress changes over months."
                )

                Divider()
                    .background(Color.iapIconBorder.opacity(0.15))
                    .padding(.horizontal, 2)

                benefitRow(
                    icon: "flame.fill",
                    accentColor: Color.iapAmber,
                    title: "Plus companions",
                    description: "Unlock Ember, Zephyr and Lumi to join Ripple on your home screen."
                )
            }
            .padding(15)
            .background(
                RoundedRectangle(cornerRadius: 32)
                    .fill(Color.iapCardBackground)
                    .shadow(color: Color.black.opacity(0.08), radius: 18, y: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 32)
                    .stroke(Color.iapIconBorder.opacity(0.09), lineWidth: 1)
            )
        }
    }

    // MARK: - Subcomponents

    private func benefitRow(icon: String, accentColor: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(accentColor)
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(accentColor.opacity(0.12))
                )

            // Text
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Typography.iapBenefitTitle)
                    .tracking(-0.025 * 15)
                    .foregroundStyle(Color.iapTextPrimary)

                Text(description)
                    .font(Typography.iapBenefitDescription)
                    .foregroundStyle(Color.iapTextSecondary)
                    .lineSpacing(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 2)
    }
}

#Preview {
    ScrollView {
        IAPBenefitsCard()
            .padding(16)
    }
    .background(Color(hex: "F5F2EC"))
}
