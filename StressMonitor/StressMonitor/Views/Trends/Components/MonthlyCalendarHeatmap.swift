import SwiftUI

/// Monthly heatmap (UI V2, ui-v2-design/screens.js `S.trends` heat).
///
/// Renders a full month as a Monday-anchored 7-column grid of rounded cells.
/// Each day that has stress data is filled with its tier fill colour
/// (Relaxed / Mild / Elevated / High) and the date in the matching on-fill
/// colour. Today gets an `ink` outline. Future days are faint, empty
/// leading/trailing cells are transparent.
struct MonthlyCalendarHeatmap: View {
    /// Maps start-of-day → average stress level (0–100).
    let dailyLevels: [Date: Double]
    var monthDate: Date = Date()

    private let calendar = Calendar.current

    // MARK: - Month Math

    private var monthSymbol: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: monthDate)
    }

    private var monthStart: Date {
        let components = calendar.dateComponents([.year, .month], from: monthDate)
        return calendar.date(from: components) ?? monthDate
    }

    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
    }

    /// Monday = 0, Sunday = 6 (Calendar weekday is 1=Sun … 7=Sat).
    private var leadingBlanks: Int {
        let weekday = calendar.component(.weekday, from: monthStart)
        return (weekday + 5) % 7
    }

    private var today: Date {
        calendar.startOfDay(for: Date())
    }

    private var totalCells: Int {
        let raw = leadingBlanks + daysInMonth
        // Pad to a full week so trailing days render.
        let remainder = raw % 7
        return remainder == 0 ? raw : raw + (7 - remainder)
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(monthSymbol)
                    .font(.headline)
                    .foregroundStyle(Color.V2.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                Text("daily average")
                    .font(.footnote)
                    .foregroundStyle(Color.V2.ink3)
            }

            weekdayHeader

            LazyVGrid(columns: columns, spacing: 5) {
                ForEach(0..<totalCells, id: \.self) { index in
                    cell(at: index)
                }
            }

            legend
        }
        .padding(V2Metrics.margin)
        .frame(maxWidth: .infinity, alignment: .leading)
        .v2CardBackground()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Monthly stress calendar for \(monthSymbol).")
    }

    // MARK: - Weekday Header

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: 5) {
            ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.V2.ink3)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 2)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Cell

    @ViewBuilder
    private func cell(at index: Int) -> some View {
        if index < leadingBlanks || index >= leadingBlanks + daysInMonth {
            // Leading/trailing empty cell — transparent.
            Color.clear
                .aspectRatio(1, contentMode: .fit)
        } else {
            let day = index - leadingBlanks + 1
            let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) ?? monthStart
            let isToday = calendar.isDate(date, inSameDayAs: today)
            let isFuture = date > today
            let level = dailyLevels[calendar.startOfDay(for: date)]
            let tier = level.map { stressTier(for: $0) }

            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(cellBackground(tier: tier, isFuture: isFuture))

                Text("\(day)")
                    .font(.v2Number(.caption2, weight: .medium))
                    .foregroundStyle(cellTextColor(tier: tier, isFuture: isFuture))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(
                        isToday ? Color.V2.ink : (isFuture ? Color.V2.line2 : Color.clear),
                        lineWidth: isToday ? 2 : 1
                    )
            )
            .accessibilityLabel(accessibilityLabel(for: day, tier: tier, isToday: isToday, isFuture: isFuture))
        }
    }

    // MARK: - Tier Helpers (4-band, matching CSS)

    /// Maps a 0–100 stress level to the 4-tier system used by the HTML
    /// (Relaxed / Mild / Moderate / High). Different from StressTier's
    /// 5-band system — the calendar uses simpler 4-step grouping.
    private func stressTier(for level: Double) -> StressCategory {
        switch level {
        case ..<25:   return .relaxed
        case ..<50:   return .mild
        case ..<75:   return .moderate
        default:      return .high
        }
    }

    private func cellBackground(tier: StressCategory?, isFuture: Bool) -> Color {
        if isFuture {
            return Color.clear
        }
        if let tier {
            return tier.fillColor
        }
        return Color.V2.surface2
    }

    private func cellTextColor(tier: StressCategory?, isFuture: Bool) -> Color {
        if isFuture {
            return Color.V2.ink3
        }
        if let tier {
            return tier.onFillColor
        }
        return Color.V2.ink2
    }

    // MARK: - Legend

    private var legend: some View {
        let columns = dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible(), alignment: .leading)]
            : Array(repeating: GridItem(.flexible(), spacing: 8, alignment: .leading), count: 3)
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
            ForEach([StressCategory.relaxed, .mild, .moderate, .high], id: \.self) { tier in
                legendItem(label: tier.displayName) {
                    Image(systemName: tier.icon)
                        .font(.caption2)
                        .foregroundStyle(tier.fillColor)
                }
            }
            legendItem(label: "Upcoming") {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(Color.V2.line2, lineWidth: 1)
                    .frame(width: 10, height: 10)
            }
        }
        .padding(.top, 4)
    }

    private func legendItem<Marker: View>(label: String, @ViewBuilder marker: () -> Marker) -> some View {
        HStack(spacing: 6) {
            marker()
                .accessibilityHidden(true)
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.V2.ink2)
        }
    }

    // MARK: - Accessibility

    private func accessibilityLabel(
        for day: Int,
        tier: StressCategory?,
        isToday: Bool,
        isFuture: Bool
    ) -> String {
        var parts = ["Day \(day)"]
        if isToday { parts.append("today") }
        if isFuture { parts.append("upcoming") }
        if let tier { parts.append("\(tier.rawValue) stress") } else { parts.append("no data") }
        return parts.joined(separator: ", ")
    }
}

#Preview("MonthlyCalendarHeatmap") {
    let now = Date()
    let cal = Calendar.current
    var levels: [Date: Double] = [:]
    for offset in 0..<20 {
        if let date = cal.date(byAdding: .day, value: -offset, to: cal.startOfDay(for: now)) {
            levels[cal.startOfDay(for: date)] = Double.random(in: 10...85)
        }
    }
    return VStack {
        MonthlyCalendarHeatmap(dailyLevels: levels)
        Spacer()
    }
    .padding()
    .background(Color.V2.bg)
}
