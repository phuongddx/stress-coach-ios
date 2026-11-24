import SwiftUI

/// Daily average bar chart (UI V2, ui-v2-design/screens.js `weekBars`).
///
/// Up to seven vertical bars, each filled with its tier fill colour, the
/// day's average above it and the weekday + date below. Today's bar gets an
/// `ink` outline. Days without data show an empty track.
struct StressBarChartView: View {
    let dailyStress: [DailyStressData]
    var averageValue: Int = 0
    /// Window shown in the header (e.g. "7 days"); nil shows the scale only.
    var windowLabel: String? = nil

    @ScaledMetric(relativeTo: .body) private var trackHeight: CGFloat = 112

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
        .padding(V2Metrics.margin)
        .frame(maxWidth: .infinity, alignment: .leading)
        .v2CardBackground()
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
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                title
                Spacer(minLength: 8)
                caption
            }
            VStack(alignment: .leading, spacing: 2) {
                title
                caption
            }
        }
    }

    private var title: some View {
        Text("Daily average")
            .font(.headline)
            .foregroundStyle(Color.V2.ink)
            .accessibilityAddTraits(.isHeader)
    }

    private var caption: some View {
        Text(windowLabel.map { "avg \(averageValue) · \($0)" } ?? "avg \(averageValue) of 100")
            .font(.footnote)
            .monospacedDigit()
            .foregroundStyle(Color.V2.ink3)
    }

    // MARK: - Bars

    private var bars: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(dailyStress.enumerated()), id: \.element.id) { index, item in
                barColumn(item: item, isToday: index == dailyStress.count - 1)
            }
        }
    }

    @ViewBuilder
    private func barColumn(item: DailyStressData, isToday: Bool) -> some View {
        let tier = stressCategory(for: item.averageStress)
        let hasData = item.averageStress > 0
        let fillFraction = CGFloat(min(item.averageStress, 100)) / 100.0

        VStack(spacing: 4) {
            Text(hasData ? "\(Int(item.averageStress.rounded()))" : "–")
                .font(.v2Number(.caption2))
                .foregroundStyle(hasData ? Color.V2.ink2 : Color.V2.ink3)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            // Track + fill
            GeometryReader { proxy in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.V2.surface2)
                    if hasData {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(tier.fillColor)
                            .frame(height: max(6, proxy.size.height * fillFraction))
                    }
                }
                .padding(isToday ? 3 : 0)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(isToday ? Color.V2.ink : Color.clear, lineWidth: 2)
                )
            }
            .frame(height: trackHeight)

            Text(item.dayLabel)
                .font(.caption2.weight(isToday ? .bold : .medium))
                .foregroundStyle(isToday ? Color.V2.ink : Color.V2.ink3)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let dateNum = item.dateNumber {
                Text("\(dateNum)")
                    .font(.v2Number(.caption2, weight: .regular))
                    .foregroundStyle(Color.V2.ink3)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
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
        V2StateView(
            systemImage: "chart.bar.xaxis",
            title: "No data yet",
            message: "Daily averages appear after your first readings.",
            tint: Color.V2.ink3
        )
        .frame(minHeight: 120)
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
            averageValue: 41,
            windowLabel: "7 days"
        )
        StressBarChartView(dailyStress: [], averageValue: 0)
        Spacer()
    }
    .padding()
    .background(Color.V2.bg)
}
