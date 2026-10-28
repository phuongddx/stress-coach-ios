import SwiftUI

/// Daily stress bar chart matching `06-trends.html` section 2.
///
/// Seven vertical bars in a 7-column grid, each colored by its stress tier
/// (Relaxed/Mild/Moderate/High). Today's bar gets an accent outline ring.
/// Below each bar: weekday abbreviation + date number.
struct StressBarChartView: View {
    let dailyStress: [DailyStressData]
    var averageValue: Int = 0

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if dailyStress.isEmpty {
                emptyState
            } else {
                bars
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.Wellness.adaptiveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.Wellness.adaptiveSecondaryText.opacity(0.08), lineWidth: 1)
        )
        .accessibilityChart(
            description: "Daily stress bar chart. Average \(averageValue) on a 0 to 100 scale.",
            summary: accessibilityTrendSummary,
            points: accessibilityPoints
        )
    }

    // MARK: - Accessibility Series (D-09)

    /// Bars with a zero average render as "no data" tracks — the trend
    /// series covers only days with data.
    private var daysWithData: [DailyStressData] {
        dailyStress.filter { $0.averageStress > 0 }
    }

    private var accessibilityTrendSummary: String {
        let values = daysWithData.map(\.averageStress)
        guard !values.isEmpty else { return "No data yet" }
        return VoiceOverLabels.trendSummary(metric: "Daily stress", values: values, period: dailyStress.count == 1 ? "1 day" : "\(dailyStress.count) days")
    }

    private var accessibilityPoints: [String] {
        daysWithData.map { item in
            let day = item.dateNumber.map { "\(item.dayLabel) \($0)" } ?? item.dayLabel
            return VoiceOverLabels.chartPoint(dateText: day, valueText: "\(Int(item.averageStress))%")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Daily stress")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.Wellness.adaptivePrimaryText)
            Spacer()
            Text("avg \(averageValue) · 0-100")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText.opacity(0.6))
        }
    }

    // MARK: - Bars

    private var bars: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(dailyStress.enumerated()), id: \.element.id) { index, item in
                barColumn(item: item, isToday: index == dailyStress.count - 1)
            }
        }
    }

    @ViewBuilder
    private func barColumn(item: DailyStressData, isToday: Bool) -> some View {
        let tier = stressCategory(for: item.averageStress)
        let hasData = item.averageStress > 0
        let fillHeight = CGFloat(hasData ? item.averageStress : 3) / 100.0

        VStack(spacing: 5) {
            // Track + fill
            GeometryReader { proxy in
                let trackHeight = proxy.size.height
                let fillPx = trackHeight * fillHeight
                ZStack(alignment: .bottom) {
                    // Track background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.Wellness.adaptiveSecondaryText.opacity(0.05))
                    // Fill
                    if hasData {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(tier.color)
                            .frame(height: max(2, fillPx))
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(
                            isToday ? Color(hex: "#0288D1") : Color.clear,
                            lineWidth: 2
                        )
                )
            }
            .frame(height: 104)

            // Weekday label
            Text(item.dayLabel.uppercased())
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(
                    isToday
                        ? Color(hex: "#0288D1")
                        : Color.Wellness.adaptiveSecondaryText.opacity(0.55)
                )

            // Date number
            if let dateNum = item.dateNumber {
                Text("\(dateNum)")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.Wellness.adaptiveSecondaryText.opacity(0.3))
            }
        }
        .accessibilityLabel(
            "\(item.dayLabel) \(item.dateNumber.map { "\($0)" } ?? ""), " +
            (hasData ? "stress level \(Int(item.averageStress)), \(tier.displayName)" : "no data")
        )
    }

    // MARK: - Helpers

    /// Maps 0–100 stress level to the 5-tier StressCategory system, matching
    /// the canonical `StressResult.category(for:)` boundaries (the local
    /// 4-tier mapper this replaced never resolved `.severe`).
    private func stressCategory(for level: Double) -> StressCategory {
        StressCategory(from: level)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 32))
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText.opacity(0.25))
            Text("No data yet")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText.opacity(0.45))
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
    }
}

#Preview("StressBarChartView") {
    VStack(spacing: 16) {
        StressBarChartView(
            dailyStress: [
                DailyStressData(dayLabel: "Wed", averageStress: 58, dateNumber: 16),
                DailyStressData(dayLabel: "Thu", averageStress: 48, dateNumber: 17),
                DailyStressData(dayLabel: "Fri", averageStress: 36, dateNumber: 18),
                DailyStressData(dayLabel: "Sat", averageStress: 62, dateNumber: 19),
                DailyStressData(dayLabel: "Sun", averageStress: 24, dateNumber: 20),
                DailyStressData(dayLabel: "Mon", averageStress: 18, dateNumber: 21),
                DailyStressData(dayLabel: "Tue", averageStress: 42, dateNumber: 22)
            ],
            averageValue: 41
        )
        Spacer()
    }
    .padding()
    .background(Color.Wellness.adaptiveBackground)
}
