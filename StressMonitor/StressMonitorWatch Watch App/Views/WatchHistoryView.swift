import SwiftUI

/// Watch **History** screen — 7-day stress log (UI V2).
///
/// True-black canvas, scrolled with the Digital Crown:
///  - "This week · avg" — the one number for this glance, with its tier
///    (colour + shape + name), above a 7-day bar chart in tier fills
///  - Best / Peak rows, each with the tier shape and name
///  - A heatmap card and the recent-readings list (number · tier · time)
///  - An empty state featuring the companion + a "Measure Now" button
struct WatchHistoryView: View {
    @Bindable var viewModel: WatchStressViewModel

    private let readings: [SharedReading]

    init(viewModel: WatchStressViewModel) {
        self.viewModel = viewModel
        self.readings = WatchSharedDataStore.shared.history7Days
    }

    var body: some View {
        Group {
            if readings.isEmpty {
                emptyState
            } else {
                filledContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WatchDesignTokens.canvas.ignoresSafeArea())
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Filled content

    private var filledContent: some View {
        ScrollView {
            VStack(spacing: 8) {
                weekCard
                rangeCard
                heatmapCard
                readingList
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)
            .padding(.bottom, 10)
        }
    }

    // MARK: - Week summary + chart

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("This week · avg")
                .font(.caption2)
                .foregroundStyle(WatchV2.ink3)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(stats.avg)")
                    .font(.v2Number(.title2, weight: .bold))
                    .foregroundStyle(WatchV2.ink)
                WatchTierBadge(category: stats.avgCategory, font: .footnote.weight(.semibold))
            }
            .accessibilityElement(children: .combine)
            StressBarChart(entries: chartEntries)
                .frame(height: 64)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardShape.fill(WatchV2.surface))
    }

    // MARK: - Best / Peak

    private var rangeCard: some View {
        VStack(spacing: 0) {
            rangeRow(label: "Best", value: stats.best, category: stats.bestCategory)
            Divider().overlay(WatchV2.line)
            rangeRow(label: "Peak", value: stats.peak, category: stats.peakCategory)
        }
        .padding(.horizontal, 10)
        .background(cardShape.fill(WatchV2.surface))
    }

    private func rangeRow(label: String, value: Int, category: StressCategory) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.footnote)
                .foregroundStyle(WatchV2.ink2)
            Spacer(minLength: 4)
            Text("\(value)")
                .font(.v2Number(.headline))
                .foregroundStyle(WatchV2.ink)
            WatchTierBadge(category: category, font: .caption2.weight(.semibold))
        }
        .frame(minHeight: 36)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Heatmap

    private var heatmapCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Heatmap")
                .font(.caption2)
                .foregroundStyle(WatchV2.ink3)
            CalendarHeatmapView(readings: heatmapReadings)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(cardShape.fill(WatchV2.surface))
    }

    /// Adapt `SharedReading` list into the `WatchStressMeasurement` shape
    /// the heatmap expects.
    private var heatmapReadings: [WatchStressMeasurement] {
        readings
            .map { WatchStressMeasurement(
                timestamp: $0.timestamp,
                stressLevel: $0.level,
                hrv: 0,
                restingHeartRate: 0
            )}
    }

    // MARK: - Reading list

    private var readingList: some View {
        VStack(spacing: 4) {
            ForEach(readings.prefix(8), id: \.id) { reading in
                readingRow(reading)
            }
        }
    }

    private func readingRow(_ reading: SharedReading) -> some View {
        let category = StressCategory.category(for: reading.level)
        return HStack(spacing: 8) {
            Text("\(Int(reading.level))")
                .font(.v2Number(.headline, weight: .bold))
                .foregroundStyle(category.inkColor)
                .frame(minWidth: 26, alignment: .leading)

            VStack(alignment: .leading, spacing: 0) {
                WatchTierBadge(category: category, font: .footnote.weight(.semibold))
                Text(timeLabel(for: reading.timestamp))
                    .font(.caption2)
                    .foregroundStyle(WatchV2.ink3)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 40)
        .background(cardShape.fill(WatchV2.surface))
        .accessibilityElement()
        .accessibilityLabel("\(category.displayName), score \(Int(reading.level)), \(timeLabel(for: reading.timestamp))")
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: WatchV2.radiusCard, style: .continuous)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 6) {
            Spacer(minLength: 0)
            CharacterFaceView(creature: .ripple, category: nil, size: 48, showsHalo: true)
            Text("No readings yet")
                .font(.headline)
                .foregroundStyle(WatchV2.ink)
            Text("Take your first measurement to start tracking.")
                .font(.footnote)
                .foregroundStyle(WatchV2.ink3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
            Spacer(minLength: 0)
            Button {
                Task { await viewModel.measureStress() }
            } label: {
                Text("Measure Now")
                    .font(.headline)
                    .foregroundStyle(WatchV2.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 36)
                    .background(Capsule(style: .continuous).fill(WatchV2.accent))
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, WatchDesignTokens.contentSidePadding)
        .padding(.bottom, 4)
    }

    // MARK: - Derivations

    private var stats: (avg: Int, avgCategory: StressCategory, best: Int, bestCategory: StressCategory, peak: Int, peakCategory: StressCategory) {
        let levels = readings.map { $0.level }
        guard !levels.isEmpty else {
            return (0, .relaxed, 0, .relaxed, 0, .relaxed)
        }
        let avg = levels.reduce(0, +) / Double(levels.count)
        let best = levels.min() ?? 0
        let peak = levels.max() ?? 0
        return (
            Int(avg), StressCategory.category(for: avg),
            Int(best), StressCategory.category(for: best),
            Int(peak), StressCategory.category(for: peak)
        )
    }

    private var chartEntries: [StressBarChart.DayEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let symbols = Calendar.current.shortWeekdaySymbols
        // Build last 7 days oldest → newest.
        var entries: [StressBarChart.DayEntry] = []
        for offset in stride(from: 6, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let dayReadings = readings.filter { calendar.isDate($0.timestamp, inSameDayAs: day) }
            let level = dayReadings.isEmpty ? nil : dayReadings.map { $0.level }.reduce(0, +) / Double(dayReadings.count)
            let symbolIndex = calendar.component(.weekday, from: day) - 1
            let letter = String(symbols[symbolIndex].prefix(1))
            entries.append(.init(dayLabel: letter, level: level))
        }
        return entries
    }

    private func timeLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "TODAY · " + date.formatted(date: .omitted, time: .shortened).uppercased()
        }
        if calendar.isDateInYesterday(date) {
            return "YDAY · " + date.formatted(date: .omitted, time: .shortened).uppercased()
        }
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE · h:mm a"
        return fmt.string(from: date).uppercased()
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        WatchHistoryView(viewModel: WatchStressViewModel())
    }
}
#endif
