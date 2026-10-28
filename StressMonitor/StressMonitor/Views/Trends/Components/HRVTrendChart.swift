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

    /// HRV accent color — see `Color.hrvTrendAccent`.
    private let hrvColor = Color.hrvTrendAccent

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
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.Wellness.adaptiveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.Wellness.adaptiveSecondaryText.opacity(0.08), lineWidth: 1)
        )
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
        HStack(alignment: .firstTextBaseline) {
            Text("HRV trend")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.Wellness.adaptivePrimaryText)
            Spacer()
            Text("ms · \(periodLabel)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText.opacity(0.6))
        }
    }

    // MARK: - Summary Row

    private var summaryRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(Int(referenceValue))")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(hrvColor)
            Text("ms avg")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
            Spacer()
            if let deltaText {
                Text(deltaText)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: "#34C759"))
            }
        }
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
            .frame(height: 110)

            // Endpoint annotation (top-right)
            if let last = dataPoints.last {
                Text("\(endpointDayLabel(for: last.date)) · \(Int(last.value))ms")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(hrvColor)
                    .padding(.horizontal, 4)
                    .background(Color.Wellness.adaptiveCardBackground)
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
            Color.Wellness.adaptiveSecondaryText.opacity(0.28),
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
                    hrvColor.opacity(0.32),
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
        VStack(spacing: 10) {
            Image(systemName: AppIconSystem.Metric.hrv.sfSymbol)
                .font(.system(size: 28))
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText.opacity(0.4))
            Text("Need more data")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
            Text("Measure for 7 days to see your HRV trend")
                .font(.system(size: 12))
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 110)
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
    .background(Color.Wellness.adaptiveBackground)
}
