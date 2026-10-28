import SwiftUI

/// 7-day stress bar chart.
///
/// Each bar's height encodes the peak stress for that day; the bar's color
/// encodes the stress tier. Subtle gridlines at 25 / 50 / 75 imply the 0–100
/// scale without needing axis labels. Today's bar gets a thin outline. Days
/// without a reading stay empty. A tier legend summarizes the distribution
/// across the days that have readings.
///
/// Spec reference: design/screens/04-home.html — `.stress-chart`.
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
        VStack(alignment: .leading, spacing: 16) {
            header

            chartArea

            legend
        }
        .padding(16)
        .background(Color.Wellness.adaptiveCardBackground.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Stress over time, last 7 days. \(legendVoiceover)")
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Stress over time")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.Wellness.adaptivePrimaryText)
            Spacer()
            HStack(spacing: 4) {
                Text("LAST 7 DAYS")
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .tracking(1.0)
                    .foregroundStyle(Color.Wellness.adaptiveSecondaryText)

                if let onOpenHistory {
                    Button {
                        HapticManager.shared.buttonPress()
                        onOpenHistory()
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.primaryBlue)
                    }
                    .buttonStyle(.plain)
                    .minimumTouchTarget(DesignTokens.Layout.minTouchTarget)
                    .accessibilityLabel("All history")
                }
            }
        }
    }

    // MARK: - Bars

    private var chartArea: some View {
        ZStack(alignment: .bottom) {
            gridlines
            HStack(alignment: .bottom, spacing: 7) {
                ForEach(displayData, id: \.date) { point in
                    barColumn(for: point)
                }
            }
        }
        .frame(height: 116)
    }

    private var gridlines: some View {
        VStack {
            Spacer()
            gridline(at: 0.75)
            gridline(at: 0.50)
            gridline(at: 0.25)
            Rectangle()
                .fill(Color(hex: "#3C3C43").opacity(0.12))
                .frame(height: 1)
        }
    }

    private func gridline(at fraction: CGFloat) -> some View {
        Rectangle()
            .fill(Color(hex: "#3C3C43").opacity(0.10))
            .frame(height: 1)
            .padding(.leading, 2)
            .offset(y: -fraction * 104)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func barColumn(for point: StressDataPoint) -> some View {
        let isToday = Calendar.current.isDateInToday(point.date)
        return VStack(spacing: 6) {
            GeometryReader { geo in
                if let value = point.value, let category = point.category {
                    let height = max(2, CGFloat(value) / 100.0 * geo.size.height)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.stressColor(for: category))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(Color.Wellness.adaptivePrimaryText, lineWidth: isToday ? 1.5 : 0)
                        )
                        .frame(height: height)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
            .frame(height: 100)

            Text(dayLabel(for: point.date, isToday: isToday))
                .font(.system(size: 9, weight: isToday ? .bold : .regular, design: .monospaced))
                .tracking(0.4)
                .foregroundStyle(isToday ? Color.Wellness.adaptivePrimaryText : Color.Wellness.adaptiveSecondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Legend

    private var legend: some View {
        let distribution = tierDistribution
        return Group {
            if distribution.isEmpty {
                Text("No readings in the last 7 days")
                    .font(.system(size: 10.5, weight: .regular))
                    .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
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
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.stressColor(for: tier))
                .frame(width: 8, height: 8)
            Text(tier.displayName)
                .font(.system(size: 10.5, weight: .regular))
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
            Text("\(percent)%")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.Wellness.adaptivePrimaryText)
        }
    }

    // MARK: - Data shaping

    private var displayData: [StressDataPoint] {
        Array(data.suffix(7))
    }

    private func dayLabel(for date: Date, isToday: Bool) -> String {
        guard !isToday else { return "TODAY" }
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
    .background(HomeCharacterDesignTokens.homeBackground)
}
