import SwiftUI

struct RecommendationCard: View {
    let recommendation: Recommendation

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: recommendation.icon)
                .font(.title2)
                .foregroundColor(.primaryBlue)
                .frame(width: 44, height: 44)
                .background(Color.primaryBlue.opacity(0.1))
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.title)
                    .font(Typography.subheadline)
                    .fontWeight(.semibold)

                Text(recommendation.description)
                    .font(Typography.caption1)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }
}
