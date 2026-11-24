import SwiftUI

/// HRV trend line chart matching `06-trends.html` section 5.
///
/// Draws a Path-based line chart with:
/// - A dashed reference line at the personal average
/// - An area fill gradient below the line
/// - A glowing endpoint halo dot
/// - A summary header showing the average + week-over-week delta
struct HRVTrendChart: View {
    let dataPoints: [ChartDataPoint]
    var referenceValue: Double = 0
    var deltaText: String? = nil
    /// Window the points span (e.g. "7 days"), shown in the header and used
    /// for VoiceOver.
    var periodLabel: String = "7 days"

    /// HRV line colour: the V2 accent.
    private let hrvColor = Color.V2.accent

    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 110

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if dataPoints.isEmpty {
                emptyState
            } else {
                summaryRow
                chart
            }
        }
        .padding(V2Metrics.margin)
        .frame(maxWidth: .infinity, alignment: .leading)
        .v2CardBackground()
        .accessibilityChart(
            description: dataPoints.isEmpty
                ? "HRV trend chart. No data yet."
                : "HRV trend chart. Average \(Int(referenceValue)) milliseconds. Reference line at \(Int(referenceValue)) milliseconds.",
            summary: accessibilityTrendSummary,
            points: accessibilityPoints
        )
    }

    // MARK: - Accessibility Series (D-09)

    private static let pointDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    private var accessibilityTrendSummary: String {
        guard !dataPoints.isEmpty else { return "Need more data" }
        return VoiceOverLabels.trendSummary(
            metric: "HRV",
            values: dataPoints.map(\.value),
            period: periodLabel
        )
    }

    private var accessibilityPoints: [String] {
        dataPoints.map { point in
            VoiceOverLabels.chartPoint(
                dateText: Self.pointDateFormatter.string(from: point.date),
                valueText: "\(Int(point.value))",
                unit: "ms"
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                headerTitle
                Spacer(minLength: 8)
                headerCaption
            }
            VStack(alignment: .leading, spacing: 2) {
                headerTitle
                headerCaption
            }
        }
    }

    private var headerTitle: some View {
        Text("HRV trend")
            .font(.headline)
            .foregroundStyle(Color.V2.ink)
            .accessibilityAddTraits(.isHeader)
    }

    private var headerCaption: some View {
        Text("ms · \(periodLabel)")
            .font(.footnote)
            .foregroundStyle(Color.V2.ink3)
    }

    // MARK: - Summary Row

    private var summaryRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                averageValue
                Spacer(minLength: 8)
                deltaLabel
            }
            VStack(alignment: .leading, spacing: 4) {
                averageValue
                deltaLabel
            }
        }
    }

    private var averageValue: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(Int(referenceValue))")
                .font(.v2Number(.title2, weight: .semibold))
                .foregroundStyle(Color.V2.ink)
            Text("ms avg")
                .font(.footnote)
                .foregroundStyle(Color.V2.ink2)
        }
    }

    @ViewBuilder
    private var deltaLabel: some View {
        if let deltaText {
            Text(deltaText)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(deltaColor(for: deltaText))
        }
    }

    /// Higher HRV is better: a rise reads in the Relaxed text colour, a drop in
    /// the High text colour, anything else stays neutral.
    private func deltaColor(for text: String) -> Color {
        if text.hasPrefix("+") { return StressCategory.relaxed.color }
        if text.hasPrefix("-") || text.hasPrefix("\u{2212}") { return StressCategory.high.color }
        return Color.V2.ink2
    }

    // MARK: - Chart

    private var chart: some View {
        ZStack(alignment: .topTrailing) {
            GeometryReader { proxy in
                let layout = ChartLayout(
                    points: dataPoints,
                    reference: referenceValue,
                    size: proxy.size
                )
                ZStack {
                    referenceLine(layout: layout)
                    areaFill(layout: layout)
                    trendLine(layout: layout)
                    if let endpoint = layout.endpoint {
                        endpointHalo(at: endpoint)
                    }
                }
            }
            .frame(height: chartHeight)

            // Endpoint annotation (top-right)
            if let last = dataPoints.last {
                Text("\(endpointDayLabel(for: last.date)) · \(Int(last.value))ms")
                    .font(.v2Number(.caption2, weight: .medium))
                    .foregroundStyle(Color.V2.ink2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.V2.surface, in: Capsule())
                    .zIndex(2)
            }
        }
    }

    /// "today" only when the last point falls on today; otherwise its date.
    private func endpointDayLabel(for date: Date) -> String {
        Calendar.current.isDateInToday(date) ? "today" : Self.pointDateFormatter.string(from: date)
    }

    // MARK: - Chart Layers

    private func referenceLine(layout: ChartLayout) -> some View {
        Path { path in
            let y = layout.y(for: referenceValue)
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: layout.size.width, y: y))
        }
        .stroke(
            Color.V2.ink3.opacity(0.6),
            style: StrokeStyle(lineWidth: 1, dash: [3, 3])
        )
    }

    private func areaFill(layout: ChartLayout) -> some View {
        Path { path in
            let pts = layout.pointCoordinates
            guard let first = pts.first else { return }
            let bottom = layout.size.height
            path.move(to: CGPoint(x: first.x, y: bottom))
            path.addLine(to: first)
            for point in pts.dropFirst() {
                path.addLine(to: point)
            }
            if let last = pts.last {
                path.addLine(to: CGPoint(x: last.x, y: bottom))
            }
            path.closeSubpath()
        }
        .fill(
            LinearGradient(
                colors: [
                    hrvColor.opacity(0.24),
                    hrvColor.opacity(0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func trendLine(layout: ChartLayout) -> some View {
        Path { path in
            let pts = layout.pointCoordinates
            guard let first = pts.first else { return }
            path.move(to: first)
            for point in pts.dropFirst() {
                path.addLine(to: point)
            }
        }
        .stroke(hrvColor, lineWidth: 2.4)
    }

    private func endpointHalo(at point: CGPoint) -> some View {
        ZStack {
            Circle()
                .fill(hrvColor.opacity(0.2))
                .frame(width: 16, height: 16)
            Circle()
                .fill(hrvColor)
                .frame(width: 8, height: 8)
        }
        .position(point)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        V2StateView(
            systemImage: AppIconSystem.Metric.hrv.sfSymbol,
            title: "Need more data",
            message: "Measure for 7 days to see your HRV trend",
            tint: Color.V2.ink3
        )
        .frame(maxWidth: .infinity, minHeight: 110)
    }
}

// MARK: - Chart Layout

private struct ChartLayout {
    let points: [ChartDataPoint]
    let reference: Double
    let size: CGSize

    private var yDomain: ClosedRange<Double> {
        guard let minVal = points.map({ $0.value }).min(),
              let maxVal = points.map({ $0.value }).max() else {
            return 0...100
        }
        let lower = min(minVal, reference) - 5
        let upper = max(maxVal, reference) + 5
        return lower...upper
    }

    private var xStep: CGFloat {
        guard points.count > 1 else { return size.width }
        return size.width / CGFloat(points.count - 1)
    }

    func y(for value: Double) -> CGFloat {
        let domain = yDomain
        let span = max(domain.upperBound - domain.lowerBound, 1)
        let normalized = (value - domain.lowerBound) / span
        return size.height - CGFloat(normalized) * size.height
    }

    var pointCoordinates: [CGPoint] {
        points.enumerated().map { index, point in
            CGPoint(x: CGFloat(index) * xStep, y: y(for: point.value))
        }
    }

    var endpoint: CGPoint? {
        pointCoordinates.last
    }
}

#Preview("HRVTrendChart") {
    let now = Date()
    let cal = Calendar.current
    let values: [Double] = [48, 52, 49, 55, 60, 58, 62]
    let points = values.enumerated().map { index, value in
        ChartDataPoint(date: cal.date(byAdding: .day, value: -(6 - index), to: now) ?? now, value: value)
    }
    return VStack {
        HRVTrendChart(dataPoints: points, referenceValue: 52, deltaText: "+8% vs prior 7 days")
        Spacer()
    }
    .padding()
    .background(Color.V2.bg)
}
