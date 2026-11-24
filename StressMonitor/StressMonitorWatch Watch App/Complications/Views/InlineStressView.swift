import SwiftUI

// MARK: - Inline Stress View
/// Compact single-line stress display (UI V2): tier shape + score in the
/// tier colour, "—" when there is no reading.
struct InlineStressView: View {
    let stressLevel: Double
    let category: StressCategory
    let showIcon: Bool
    let showLabel: Bool

    init(
        stressLevel: Double,
        category: StressCategory,
        showIcon: Bool = true,
        showLabel: Bool = true
    ) {
        self.stressLevel = stressLevel
        self.category = category
        self.showIcon = showIcon
        self.showLabel = showLabel
    }

    var body: some View {
        HStack(spacing: 4) {
            if showIcon && hasData {
                Image(systemName: category.icon)
                    .foregroundStyle(category.color)
            }

            if showLabel {
                Text("Stress")
                    .foregroundStyle(WatchV2.ink2)
            }

            Text(hasData ? stressLevelText : "—")
                .font(.v2Number(.footnote, weight: .semibold))
                .foregroundStyle(hasData ? category.color : WatchV2.ink3)
        }
        .font(.footnote.weight(.medium))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    // MARK: - Computed Properties
    private var stressLevelText: String {
        "\(Int(stressLevel.rounded()))"
    }

    private var hasData: Bool {
        stressLevel > 0
    }
}

// MARK: - Stress Label Component
/// Alternative component showing the tier (shape + name) instead of a number.
struct StressLabelInlineView: View {
    let category: StressCategory
    let showIcon: Bool

    init(category: StressCategory, showIcon: Bool = true) {
        self.category = category
        self.showIcon = showIcon
    }

    var body: some View {
        HStack(spacing: 4) {
            if showIcon {
                Image(systemName: category.icon)
            }
            Text(category.label)
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(category.color)
        .lineLimit(1)
    }
}

// MARK: - Preview
#Preview("Mild Stress") {
    InlineStressView(
        stressLevel: 35,
        category: .mild
    )
    .previewLayout(.sizeThatFits)
    .padding()
}

#Preview("High Stress") {
    InlineStressView(
        stressLevel: 88,
        category: .high
    )
    .previewLayout(.sizeThatFits)
    .padding()
}

#Preview("Relaxed") {
    InlineStressView(
        stressLevel: 15,
        category: .relaxed
    )
    .previewLayout(.sizeThatFits)
    .padding()
}

#Preview("Moderate") {
    InlineStressView(
        stressLevel: 62,
        category: .moderate
    )
    .previewLayout(.sizeThatFits)
    .padding()
}

#Preview("No Icon") {
    InlineStressView(
        stressLevel: 45,
        category: .moderate,
        showIcon: false
    )
    .previewLayout(.sizeThatFits)
    .padding()
}

#Preview("Number Only") {
    InlineStressView(
        stressLevel: 50,
        category: .moderate,
        showIcon: false,
        showLabel: false
    )
    .previewLayout(.sizeThatFits)
    .padding()
}

#Preview("No Data") {
    InlineStressView(
        stressLevel: 0,
        category: .relaxed
    )
    .previewLayout(.sizeThatFits)
    .padding()
}

#Preview("Category Label") {
    StressLabelInlineView(
        category: .high
    )
    .previewLayout(.sizeThatFits)
    .padding()
}

#Preview("All Categories") {
    VStack(alignment: .leading, spacing: 8) {
        InlineStressView(stressLevel: 12, category: .relaxed)
        InlineStressView(stressLevel: 35, category: .mild)
        InlineStressView(stressLevel: 58, category: .moderate)
        InlineStressView(stressLevel: 82, category: .high)
    }
    .padding()
    .previewLayout(.sizeThatFits)
}
