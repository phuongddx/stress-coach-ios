import SwiftUI

/// One "What could help" row (UI V2): accent icon tile, title and a short
/// description. Rows sit inside a single grouped card on the detail screen.
///
/// Spec reference: ui-v2-design/screens.js `S.detail` "What could help".
struct RecommendationCard: View {
    let recommendation: Recommendation

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: recommendation.icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.V2.accent)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: V2Metrics.radiusXS, style: .continuous)
                        .fill(Color.V2.accentSoft)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(recommendation.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.V2.ink)
                Text(recommendation.description)
                    .font(.footnote)
                    .foregroundStyle(Color.V2.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, V2Metrics.margin)
        .padding(.vertical, 12)
        .frame(minHeight: V2Metrics.minTouchTarget)
        .accessibilityElement(children: .combine)
    }
}
