import SwiftUI

// MARK: - Circular Stress View
/// Reusable circular stress display (UI V2): the shared 240° gauge with the
/// score in the centre and the tier shown as colour + shape + name.
struct CircularStressView: View {
    let stressLevel: Double
    let category: StressCategory
    let showLabel: Bool
    let size: CGFloat

    init(
        stressLevel: Double,
        category: StressCategory,
        showLabel: Bool = true,
        size: CGFloat = 120
    ) {
        self.stressLevel = stressLevel
        self.category = category
        self.showLabel = showLabel
        self.size = size
    }

    var body: some View {
        WatchStressGauge(score: stressLevel, lineWidth: max(4, size * 0.08)) {
            VStack(spacing: 2) {
                Text("\(Int(stressLevel.rounded()))")
                    .font(.v2Number(.title3, weight: .bold))
                    .foregroundStyle(WatchV2.ink)
                    .contentTransition(.numericText(value: stressLevel))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                if showLabel {
                    WatchTierBadge(category: category, font: .caption2.weight(.semibold))
                } else {
                    Image(systemName: category.icon)
                        .font(.caption2)
                        .imageScale(.small)
                        .foregroundStyle(category.color)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Stress Category Extension
extension StressCategory {
    /// Human-readable label for the category.
    var label: String { displayName }
}

// MARK: - Preview
#Preview("Relaxed") {
    CircularStressView(
        stressLevel: 15,
        category: .relaxed
    )
    .previewLayout(.sizeThatFits)
    .padding()
}

#Preview("Mild") {
    CircularStressView(
        stressLevel: 35,
        category: .mild
    )
    .previewLayout(.sizeThatFits)
    .padding()
}

#Preview("Moderate") {
    CircularStressView(
        stressLevel: 60,
        category: .moderate
    )
    .previewLayout(.sizeThatFits)
    .padding()
}

#Preview("High") {
    CircularStressView(
        stressLevel: 85,
        category: .high
    )
    .previewLayout(.sizeThatFits)
    .padding()
}

#Preview("Compact") {
    CircularStressView(
        stressLevel: 45,
        category: .mild,
        showLabel: false,
        size: 60
    )
    .previewLayout(.sizeThatFits)
    .padding()
}

#Preview("Watch Size") {
    HStack(spacing: 20) {
        CircularStressView(
            stressLevel: 25,
            category: .relaxed,
            size: 80
        )

        CircularStressView(
            stressLevel: 50,
            category: .moderate,
            size: 80
        )

        CircularStressView(
            stressLevel: 75,
            category: .high,
            size: 80
        )
    }
    .padding()
    .previewLayout(.sizeThatFits)
}
