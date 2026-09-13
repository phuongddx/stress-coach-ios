import SwiftUI

/// Bar chart of per-day biological-age estimates with a dashed
/// chronological-age reference line (`design/screens/18-bio-age.html`,
/// "7-day range" / "Day-by-day estimate"). Only bars at or below the
/// chronological line use the younger tint; no fabricated reference bands.
struct BioAgeDailyChart: View {
    let estimates: [DailyBioAgeEstimate]
    let chronologicalAge: Int

    private let chartHeight: CGFloat = 120
    private let barSpacing: CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            chart
            legend
        }
        .accessibilityChart(
            description: "Daily biological age estimates for the last week",
            summary: Self.accessibilitySummary(for: estimates) ?? "No estimates",
            points: accessibilityPoints
        )
    }

    /// Pure formatter for the VoiceOver one-line summary. Re-states exactly
    /// what the chart renders — never invents young/older bands.
    static func accessibilitySummary(for estimates: [DailyBioAgeEstimate]) -> String? {
        let ages = estimates.map(\.estimatedAge)
        guard let youngest = ages.min(), let oldest = ages.max() else {
            return nil
        }
        if youngest == oldest {
            return "Bio age held at \(youngest) over the last 7 days"
        }
        return "Bio age ranged \(youngest) to \(oldest) over the last 7 days"
    }

    // MARK: - Chart

    private var chart: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                bars(size: proxy.size)
                referenceLine(size: proxy.size)
            }
        }
        .frame(height: chartHeight)
    }

    private func bars(size: CGSize) -> some View {
        HStack(alignment: .bottom, spacing: barSpacing) {
            ForEach(estimates) { estimate in
                Capsule()
                    .fill(barTint(for: estimate.estimatedAge))
                    .frame(height: barHeight(for: estimate.estimatedAge, in: size.height))
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .bottom)
    }

    private func referenceLine(size: CGSize) -> some View {
        Path { path in
            let y = size.height - barHeight(for: chronologicalAge, in: size.height)
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
        }
        .stroke(
            Color.Wellness.adaptiveSecondaryText.opacity(0.4),
            style: StrokeStyle(lineWidth: 1, dash: [3, 3])
        )
        .allowsHitTesting(false)
    }

    private func barTint(for estimatedAge: Int) -> Color {
        estimatedAge <= chronologicalAge
            ? Color.primaryGreen.opacity(0.85)
            : Color.stressColor(for: .high).opacity(0.85)
    }

    private func barHeight(for age: Int, in chartHeight: CGFloat) -> CGFloat {
        let bounds = valueDomain
        let span = max(bounds.upperBound - bounds.lowerBound, 1)
        let normalized = (Double(age) - bounds.lowerBound) / span
        return max(CGFloat(normalized) * chartHeight, 2)
    }

    private var valueDomain: ClosedRange<Double> {
        let values = estimates.map { Double($0.estimatedAge) } + [Double(chronologicalAge)]
        guard let lower = values.min(), let upper = values.max(), upper > lower else {
            return 0...1
        }
        let padding = (upper - lower) * 0.2
        return (lower - padding)...(upper + padding)
    }

    // MARK: - Legend

    private var legend: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(legendText(for: estimates.first?.day, fallback: "start"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(legendText(for: middleEstimate?.day, fallback: ""))
                    .frame(maxWidth: .infinity, alignment: .center)
                Text("today · \(estimates.last?.estimatedAge ?? chronologicalAge) yrs")
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            HStack(spacing: 6) {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0.5))
                    path.addLine(to: CGPoint(x: 14, y: 0.5))
                }
                .stroke(
                    Color.Wellness.adaptiveSecondaryText.opacity(0.4),
                    style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                )
                .frame(width: 14, height: 1)
                .accessibilityHidden(true)

                Text("chronological \(chronologicalAge)")
            }
        }
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .tracking(0.4)
        .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
    }

    private var middleEstimate: DailyBioAgeEstimate? {
        guard !estimates.isEmpty else { return nil }
        return estimates[estimates.count / 2]
    }

    private func legendText(for day: Date?, fallback: String) -> String {
        day?.formatted(.dateTime.month(.abbreviated).day()) ?? fallback
    }

    private var accessibilityPoints: [String] {
        estimates.map { estimate in
            VoiceOverLabels.chartPoint(
                dateText: estimate.day.formatted(.dateTime.month(.abbreviated).day()),
                valueText: "\(estimate.estimatedAge)",
                unit: "yrs"
            )
        }
    }
}

#Preview("BioAgeDailyChart") {
    let now = Date()
    let calendar = Calendar.current
    let ages = [28, 30, 29, 31, 27, 30, 26]
    let estimates = ages.enumerated().map { index, age in
        DailyBioAgeEstimate(
            day: calendar.date(byAdding: .day, value: -(6 - index), to: now) ?? now,
            estimatedAge: age
        )
    }
    return BioAgeDailyChart(estimates: estimates, chronologicalAge: 28)
        .padding()
        .background(Color.Wellness.adaptiveBackground)
}
