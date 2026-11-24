import SwiftUI

/// Tier shape + name in the tier text colour. `compact` shows the shape only
/// and keeps the name as the accessibility label.
struct V2TierBadge: View {
    let category: StressCategory
    var compact: Bool = false
    var font: Font = .subheadline.weight(.semibold)

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: category.icon)
                .imageScale(.small)
                .accessibilityHidden(true)
            if !compact {
                Text(category.displayName)
            }
        }
        .font(font)
        .foregroundStyle(category.color)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(category.displayName)
    }
}

#Preview("Tier badges") {
    VStack(alignment: .leading, spacing: 12) {
        ForEach(StressCategory.allCases, id: \.self) { tier in
            HStack {
                V2TierBadge(category: tier)
                Spacer()
                V2TierBadge(category: tier, compact: true)
            }
        }
    }
    .padding()
    .background(Color.V2.surface)
}
