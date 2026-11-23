import SwiftUI

// MARK: - Rectangular Stress View
/// Reusable rectangular stress display (UI V2): tier shape chip, "Stress N"
/// with the tier name, and HRV / heart rate. "—" when there is no reading.
struct RectangularStressView: View {
    let stressLevel: Double
    let category: StressCategory
    let hrv: Double
    let heartRate: Double
    let width: CGFloat
    let height: CGFloat

    init(
        stressLevel: Double,
        category: StressCategory,
        hrv: Double,
        heartRate: Double,
        width: CGFloat = 160,
        height: CGFloat = 80
    ) {
        self.stressLevel = stressLevel
        self.category = category
        self.hrv = hrv
        self.heartRate = heartRate
        self.width = width
        self.height = height
    }

    var body: some View {
        HStack(spacing: 8) {
            stressIndicator

            VStack(alignment: .leading, spacing: 2) {
                Text("Stress")
                    .font(.caption2)
                    .foregroundStyle(WatchV2.ink2)
                Text(stressLevelText)
                    .font(.v2Number(.title3, weight: .bold))
                    .foregroundStyle(hasData ? WatchV2.ink : WatchV2.ink3)
                if hasData {
                    WatchTierBadge(category: category, font: .caption2.weight(.semibold))
                }
            }

            Spacer(minLength: 4)

            healthMetrics
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(width: width, height: height)
    }

    // MARK: - View Components
    /// Tier shape on a tinted chip.
    private var stressIndicator: some View {
        ZStack {
            Circle()
                .fill(hasData ? category.color.opacity(0.18) : WatchV2.surface2)
            Image(systemName: hasData ? category.icon : "minus")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(hasData ? category.color : WatchV2.ink3)
        }
        .frame(width: 28, height: 28)
        .accessibilityHidden(true)
    }

    /// HRV and (space permitting) heart rate.
    private var healthMetrics: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("HRV")
                .font(.caption2)
                .foregroundStyle(WatchV2.ink3)
            metric(hrvText, unit: "ms")
            if height >= 70 {
                metric(heartRateText, unit: "bpm")
            }
        }
    }

    private func metric(_ value: String, unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(value)
                .font(.v2Number(.footnote, weight: .semibold))
                .foregroundStyle(WatchV2.ink)
            Text(unit)
                .font(.caption2)
                .foregroundStyle(WatchV2.ink3)
        }
    }

    // MARK: - Computed Properties
    private var stressLevelText: String {
        hasData ? "\(Int(stressLevel.rounded()))" : "—"
    }

    private var hrvText: String {
        hasData ? String(format: "%.0f", hrv) : "—"
    }

    private var heartRateText: String {
        hasData ? String(format: "%.0f", heartRate) : "—"
    }

    private var hasData: Bool {
        stressLevel > 0 || hrv > 0
    }
}

// MARK: - Preview
#Preview("Mild Stress") {
    RectangularStressView(
        stressLevel: 32,
        category: .mild,
        hrv: 48,
        heartRate: 72
    )
    .previewLayout(.sizeThatFits)
    .padding()
}

#Preview("High Stress") {
    RectangularStressView(
        stressLevel: 85,
        category: .high,
        hrv: 22,
        heartRate: 95
    )
    .previewLayout(.sizeThatFits)
    .padding()
}

#Preview("Relaxed") {
    RectangularStressView(
        stressLevel: 18,
        category: .relaxed,
        hrv: 65,
        heartRate: 58
    )
    .previewLayout(.sizeThatFits)
    .padding()
}

#Preview("No Data") {
    RectangularStressView(
        stressLevel: 0,
        category: .relaxed,
        hrv: 0,
        heartRate: 0
    )
    .previewLayout(.sizeThatFits)
    .padding()
}

#Preview("Compact") {
    RectangularStressView(
        stressLevel: 45,
        category: .moderate,
        hrv: 38,
        heartRate: 78,
        width: 140,
        height: 60
    )
    .previewLayout(.sizeThatFits)
    .padding()
}

#Preview("Large") {
    RectangularStressView(
        stressLevel: 62,
        category: .moderate,
        hrv: 35,
        heartRate: 82,
        width: 200,
        height: 100
    )
    .previewLayout(.sizeThatFits)
    .padding()
}
