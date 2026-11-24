import SwiftUI

// MARK: - StressBarChart

/// Compact 7-day stress bar chart (iOS DS §12 vocabulary).
///
/// Hairline gridlines and rounded bars in the V2 tier fill colours. Today's
/// day label is drawn in full ink; other labels in ink3.
/// Each bar's fill colour is resolved from the per-day average using the
/// 5-tier stress scale so the chart doubles as a week-at-a-glance read.
struct StressBarChart: View {
    /// One entry per day, oldest → newest.  `nil` level = no data.
    let entries: [DayEntry]
    var todayIndex: Int { entries.count - 1 }

    /// Chart geometry (matches the watch design output).
    private let barCornerRadius: CGFloat = 4
    private let maxBarWidth: CGFloat = 18
    private let gridlineTopOpacity: Double = 0.07
    private let baselineOpacity: Double = 0.12

    var body: some View {
        Canvas { ctx, size in
            drawGridlines(ctx: ctx, size: size)
            drawBars(ctx: ctx, size: size)
            drawDayLabels(ctx: ctx, size: size)
        }
        .accessibilityElement()
        .accessibilityLabel(accessibilitySummary)
    }

    // MARK: - Drawing

    private func drawGridlines(ctx: GraphicsContext, size: CGSize) {
        let gridTop = size.height * 0.16
        let gridMid = size.height * 0.50
        let baseline = size.height * 0.82
        let leftEdge: CGFloat = 0
        let rightEdge = size.width

        var topLine = Path()
        topLine.move(to: CGPoint(x: leftEdge, y: gridTop))
        topLine.addLine(to: CGPoint(x: rightEdge, y: gridTop))
        ctx.stroke(topLine, with: .color(WatchV2.ink.opacity(gridlineTopOpacity)),
                   lineWidth: 0.5)

        var midLine = Path()
        midLine.move(to: CGPoint(x: leftEdge, y: gridMid))
        midLine.addLine(to: CGPoint(x: rightEdge, y: gridMid))
        ctx.stroke(midLine, with: .color(WatchV2.ink.opacity(gridlineTopOpacity)),
                   lineWidth: 0.5)

        var baseLine = Path()
        baseLine.move(to: CGPoint(x: leftEdge, y: baseline))
        baseLine.addLine(to: CGPoint(x: rightEdge, y: baseline))
        ctx.stroke(baseLine, with: .color(WatchDesignTokens.separator), lineWidth: 0.5)
    }

    private func drawBars(ctx: GraphicsContext, size: CGSize) {
        guard entries.count > 0 else { return }
        let baseline = size.height * 0.82
        let topLimit = size.height * 0.16
        let availableHeight = baseline - topLimit
        let count = CGFloat(entries.count)
        let slot = size.width / count
        let barWidth = min(maxBarWidth, slot * 0.72)
        let xPadding: CGFloat = (slot - barWidth) / 2

        for (i, entry) in entries.enumerated() {
            guard let level = entry.level else { continue }
            let normalized = min(max(level, 0), 100) / 100.0
            let h = availableHeight * CGFloat(normalized)
            let x = CGFloat(i) * slot + xPadding
            let y = baseline - h
            let rect = CGRect(x: x, y: y, width: barWidth, height: h)
            let path = Path(roundedRect: rect, cornerRadius: barCornerRadius, style: .continuous)
            let category = StressCategory.category(for: level)
            ctx.fill(path, with: .color(category.fillColor))
        }
    }

    private func drawDayLabels(ctx: GraphicsContext, size: CGSize) {
        let baseline = size.height * 0.82
        let count = CGFloat(entries.count)
        let slot = size.width / count
        for (i, entry) in entries.enumerated() {
            let isToday = i == todayIndex
            let color = isToday ? WatchV2.ink : WatchV2.ink3
            let resolved = ctx.resolve(
                Text(entry.dayLabel)
                    .font(isToday ? .caption2.weight(.bold) : .caption2)
                    .foregroundColor(color)
            )
            let textSize = resolved.measure(in: CGSize(width: slot, height: size.height))
            let origin = CGPoint(
                x: CGFloat(i) * slot + (slot - textSize.width) / 2,
                y: baseline + 4
            )
            ctx.draw(resolved, at: origin, anchor: .topLeading)
        }
    }

    // MARK: - Helpers

    private var accessibilitySummary: String {
        let filled = entries.compactMap { $0.level }
        guard !filled.isEmpty else { return "No chart data available." }
        let avg = filled.reduce(0, +) / Double(filled.count)
        let peak = filled.max() ?? 0
        let best = filled.min() ?? 0
        return "7-day stress chart. Average \(Int(avg)), best \(Int(best)), peak \(Int(peak))."
    }
}

// MARK: - DayEntry

extension StressBarChart {
    /// One day's aggregate reading for the chart.
    struct DayEntry: Identifiable, Hashable {
        let id = UUID()
        let dayLabel: String      // single letter, e.g. "T"
        let level: Double?        // nil = no reading
    }
}

#if DEBUG
#Preview("Bar chart") {
    let entries: [StressBarChart.DayEntry] = [
        .init(dayLabel: "W", level: 42),
        .init(dayLabel: "T", level: 48),
        .init(dayLabel: "F", level: 24),
        .init(dayLabel: "S", level: 62),
        .init(dayLabel: "S", level: 20),
        .init(dayLabel: "M", level: 16),
        .init(dayLabel: "T", level: 42)
    ]
    return StressBarChart(entries: entries)
        .frame(width: 188, height: 56)
        .padding()
        .background(WatchDesignTokens.canvas)
}
#endif
