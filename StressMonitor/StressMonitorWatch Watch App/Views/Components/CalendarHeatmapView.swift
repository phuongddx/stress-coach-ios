import SwiftUI

// MARK: - CalendarHeatmapView

/// Compact stress calendar heatmap.
///
/// Renders a 7-row (days of week) by N-column (weeks) grid of cells
/// coloured by stress level. Empty cells (no reading) are hairlined. Day
/// labels appear down the left edge; week labels can be derived from the
/// data range. Today's cell is outlined in ink.
///
/// The colour map uses the 5-tier stress scale so the heatmap doubles as
/// a tier overview at a glance (WCAG dual-coding: colour + tier glyph
/// read from the underlying reading).
struct CalendarHeatmapView: View {
    let readings: [WatchStressMeasurement]

    /// Optional override of how many weeks to render (default: fit the
    /// data range, capped at 12 weeks).
    var maxWeeks: Int = 12
    /// Show the left-edge weekday initial column.
    var showsDayLabels: Bool = true

    private let calendar = Calendar.current
    private let cellSize: CGFloat = 12
    private let cellSpacing: CGFloat = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let summary = headerSummary {
                Text(summary)
                    .font(.caption2)
                    .foregroundStyle(WatchV2.ink3)
                    .lineLimit(2)
            }

            HStack(alignment: .top, spacing: 6) {
                if showsDayLabels {
                    dayLabelColumn
                }
                grid
            }
        }
        .accessibilityElement()
        .accessibilityLabel(accessibilitySummary)
    }

    // MARK: - Grid

    private var grid: some View {
        let weeks = computedWeeks
        return GeometryReader { proxy in
            let available = proxy.size.width
            let spacing = cellSpacing * CGFloat(max(weeks.count - 1, 0))
            let slot = max((available - spacing) / CGFloat(max(weeks.count, 1)), 6)
            HStack(spacing: cellSpacing) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    VStack(spacing: cellSpacing) {
                        ForEach(0..<7) { dayIndex in
                            cell(for: week, dayIndex: dayIndex, size: slot)
                        }
                    }
                }
            }
        }
        .frame(height: cellSize * 7 + cellSpacing * 6)
    }

    private func cell(for week: WeekBucket, dayIndex: Int, size: CGFloat) -> some View {
        let day = week.days[dayIndex]
        let category = day.level.map { StressCategory.category(for: $0) }
        let isToday = calendar.isDateInToday(day.date)
        let isEmpty = day.level == nil

        return RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(cellFill(category: category, isEmpty: isEmpty))
            .overlay(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .stroke(
                        isToday ? WatchV2.ink : .clear,
                        lineWidth: isToday ? 1.2 : 0
                    )
            )
            .frame(width: size, height: cellSize)
            .accessibilityLabel(cellLabel(day: day, isToday: isToday))
    }

    private func cellFill(category: StressCategory?, isEmpty: Bool) -> Color {
        if isEmpty { return WatchV2.surface2 }
        return (category ?? .relaxed).fillColor
    }

    // MARK: - Day labels

    private var dayLabelColumn: some View {
        VStack(spacing: cellSpacing) {
            ForEach(dayLabels, id: \.self) { label in
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(WatchV2.ink3)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(width: 10, height: cellSize)
            }
        }
    }

    private var dayLabels: [String] {
        // Sunday-first to match Calendar.weekday; take first letter.
        let symbols = calendar.shortWeekdaySymbols
        return symbols.map { String($0.prefix(1)) }
    }

    // MARK: - Header

    private var headerSummary: String? {
        let filled = readings.filter { $0.stressLevel >= 0 }
        guard !filled.isEmpty else { return nil }
        let count = filled.count
        return "\(count) READING\(count == 1 ? "" : "S") · LAST \(weeksSpanLabel)"
    }

    private var weeksSpanLabel: String {
        let weeks = computedWeeks
        if weeks.count <= 1 { return "WEEK" }
        return "\(weeks.count) WEEKS"
    }

    // MARK: - Week bucketing

    /// Oldest → newest, each `WeekBucket` covers Sunday → Saturday.
    private var computedWeeks: [WeekBucket] {
        guard let range = dataRange else { return [] }
        let firstSunday = calendar.nextDate(
            after: range.start.addingTimeInterval(-7 * 24 * 3600),
            matching: DateComponents(weekday: 1),
            matchingPolicy: .nextTime
        ) ?? range.start
        var weeks: [WeekBucket] = []
        var cursor = firstSunday
        while cursor <= range.end && weeks.count < maxWeeks {
            var days: [DayBucket] = []
            for offset in 0..<7 {
                guard let day = calendar.date(byAdding: .day, value: offset, to: cursor) else { continue }
                let level = readings.first { calendar.isDate($0.timestamp, inSameDayAs: day) }?.stressLevel
                days.append(DayBucket(date: day, level: level))
            }
            weeks.append(WeekBucket(days: days))
            cursor = (calendar.date(byAdding: .day, value: 7, to: cursor)) ?? Date.distantFuture
        }
        return weeks
    }

    private var dataRange: (start: Date, end: Date)? {
        guard let earliest = readings.map({ $0.timestamp }).min(),
              let latest = readings.map({ $0.timestamp }).max() else { return nil }
        return (earliest, latest)
    }

    // MARK: - Accessibility

    private var accessibilitySummary: String {
        let filled = readings.compactMap { $0.stressLevel }
        guard !filled.isEmpty else { return "Calendar heatmap empty." }
        let avg = filled.reduce(0, +) / Double(filled.count)
        return "Stress heatmap, \(filled.count) days, average \(Int(avg))."
    }

    private func cellLabel(day: DayBucket, isToday: Bool) -> String {
        let dateStr = day.date.formatted(date: .abbreviated, time: .omitted)
        if let level = day.level {
            let cat = StressCategory.category(for: level)
            return "\(cat.displayName), \(Int(level))\(isToday ? ", today" : ""), \(dateStr)"
        }
        return "No reading\(isToday ? ", today" : ""), \(dateStr)"
    }
}

// MARK: - Models

private struct WeekBucket {
    let days: [DayBucket] // length 7, index 0 = Sunday
}

private struct DayBucket {
    let date: Date
    let level: Double?
}

#if DEBUG
private struct HeatmapPreviewData {
    static let readings: [WatchStressMeasurement] = {
        let now = Date()
        let cal = Calendar.current
        var readings: [WatchStressMeasurement] = []
        for dayOffset in stride(from: -27, through: 0, by: 1) {
            guard let date = cal.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            let level = Double.random(in: 10...80)
            readings.append(WatchStressMeasurement(
                timestamp: date,
                stressLevel: level,
                hrv: 50,
                restingHeartRate: 60
            ))
        }
        return readings
    }()
}

#Preview("Heatmap") {
    CalendarHeatmapView(readings: HeatmapPreviewData.readings)
        .frame(width: 180)
        .padding()
        .background(WatchDesignTokens.canvas)
}
#endif
