import SwiftUI

/// 7-day stress bar chart (UI V2).
///
/// Each bar's height encodes the peak stress for that day; the bar's fill
/// encodes the stress tier. Subtle gridlines at 25 / 50 / 75 imply the 0–100
/// scale. Today's bar gets a thin outline. Days without a reading stay empty.
/// A tier legend summarizes the distribution across the days with readings.
///
/// Spec reference: ui-v2-design/screens.js `S.home` "Stress over time".
struct StressOverTimeChart: View {
    let data: [StressDataPoint]
    var onOpenHistory: (() -> Void)?

    init(
        data: [StressDataPoint],
        onOpenHistory: (() -> Void)? = nil
    ) {
        self.data = data
        self.onOpenHistory = onOpenHistory
    }

    var body: some View {
        V2Card {
            VStack(alignment: .leading, spacing: 16) {
                header
                chartArea
                legend
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Stress over time, last 7 days. \(legendVoiceover)")
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("This week")
                .font(.headline)
                .foregroundStyle(Color.V2.ink)
            Spacer(minLength: 8)
            if let averageSummary {
                Text(averageSummary)
                    .font(.footnote)
                    .foregroundStyle(Color.V2.ink3)
            }
            if let onOpenHistory {
                Button {
                    HapticManager.shared.buttonPress()
                    onOpenHistory()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.V2.accent)
                        .frame(minWidth: V2Metrics.minTouchTarget, minHeight: V2Metrics.minTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("All history")
            }
        }
    }

    // MARK: - Bars

    private var chartArea: some View {
        ZStack(alignment: .top) {
            gridlines
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(displayData, id: \.date) { point in
                    barColumn(for: point)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private var gridlines: some View {
        VStack(spacing: 0) {
            ForEach([0.75, 0.5, 0.25, 0.0], id: \.self) { _ in
                Spacer(minLength: 0)
                Rectangle()
                    .fill(Color.V2.line)
                    .frame(height: 0.5)
            }
        }
        .frame(height: barHeight)
    }

    private let barHeight: CGFloat = 100

    private func barColumn(for point: StressDataPoint) -> some View {
        let isToday = Calendar.current.isDateInToday(point.date)
        return VStack(spacing: 6) {
            GeometryReader { geo in
                if let value = point.value, let category = point.category {
                    let height = max(3, CGFloat(value) / 100.0 * geo.size.height)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(category.fillColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .strokeBorder(Color.V2.ink, lineWidth: isToday ? 1.5 : 0)
                        )
                        .frame(height: height)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
            .frame(height: barHeight)

            Text(dayLabel(for: point.date, isToday: isToday))
                .font(.caption2.weight(isToday ? .bold : .regular))
                .foregroundStyle(isToday ? Color.V2.ink : Color.V2.ink3)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Legend

    private var legend: some View {
        let distribution = tierDistribution
        return Group {
            if distribution.isEmpty {
                Text("No readings in the last 7 days")
                    .font(.footnote)
                    .foregroundStyle(Color.V2.ink3)
            } else {
                FlowLayout(spacing: 12, lineSpacing: 6) {
                    ForEach(StressCategory.allCases, id: \.self) { tier in
                        legendPill(tier: tier, percent: distribution[tier] ?? 0)
                    }
                }
            }
        }
    }

    private func legendPill(tier: StressCategory, percent: Int) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(tier.fillColor)
                .frame(width: 8, height: 8)
            Text(tier.displayName)
                .font(.caption)
                .foregroundStyle(Color.V2.ink2)
            Text("\(percent)%")
                .font(.v2Number(.caption))
                .foregroundStyle(Color.V2.ink)
        }
    }

    /// "avg 40 · Mild" across the days with a reading; nil when none.
    private var averageSummary: String? {
        let values = displayData.compactMap(\.value)
        guard !values.isEmpty else { return nil }
        let average = Double(values.reduce(0, +)) / Double(values.count)
        return "avg \(Int(average.rounded())) · \(StressCategory(from: average).displayName)"
    }

    // MARK: - Data shaping

    private var displayData: [StressDataPoint] {
        Array(data.suffix(7))
    }

    private func dayLabel(for date: Date, isToday: Bool) -> String {
        guard !isToday else { return "Today" }
        let calendar = Calendar.current
        return calendar.veryShortWeekdaySymbols[calendar.component(.weekday, from: date) - 1]
    }

    /// Share of days with a reading per tier. Empty when no day has a reading.
    private var tierDistribution: [StressCategory: Int] {
        let categories = displayData.compactMap(\.category)
        guard !categories.isEmpty else { return [:] }
        var counts: [StressCategory: Int] = [:]
        for category in categories { counts[category, default: 0] += 1 }
        let total = categories.count
        return StressCategory.allCases.reduce(into: [:]) { result, tier in
            let raw = Double(counts[tier] ?? 0) / Double(total) * 100
            result[tier] = Int(raw.rounded())
        }
    }

    private var legendVoiceover: String {
        tierDistribution
            .filter { $0.value > 0 }
            .map { "\($0.value) percent \($0.key.displayName)" }
            .joined(separator: ", ")
    }
}

// MARK: - StressDataPoint

/// One day on the chart. `value` and `category` are nil when the day has no reading.
struct StressDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Int?
    let category: StressCategory?
}

// MARK: - FlowLayout (legend wrapping)

/// Lightweight wrapping layout for the tier legend so pills reflow on narrow
/// widths instead of clipping.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                y += lineHeight + lineSpacing
                x = 0
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            totalWidth = max(totalWidth, x - spacing)
        }
        return CGSize(width: totalWidth, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.minX + maxWidth, x > bounds.minX {
                y += lineHeight + lineSpacing
                x = bounds.minX
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

// MARK: - Preview

#Preview("StressOverTimeChart") {
    let today = Calendar.current.startOfDay(for: Date())
    func day(_ offset: Int) -> Date { Calendar.current.date(byAdding: .day, value: offset, to: today) ?? today }
    let data: [StressDataPoint] = [
        .init(date: day(-6), value: 24, category: .relaxed),
        .init(date: day(-5), value: 58, category: .moderate),
        .init(date: day(-4), value: nil, category: nil),
        .init(date: day(-3), value: 72, category: .moderate),
        .init(date: day(-2), value: 81, category: .high),
        .init(date: day(-1), value: 22, category: .relaxed),
        .init(date: day(0), value: 42, category: .mild)
    ]
    return VStack {
        StressOverTimeChart(data: data)
            .padding()
        Spacer()
    }
    .background(Color.V2.bg)
}
