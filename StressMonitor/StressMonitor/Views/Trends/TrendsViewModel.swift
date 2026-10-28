import SwiftUI
import SwiftData

@Observable
class TrendsViewModel {
    // MARK: - Date Selection
    var selectedDate: Date = Date()
    var selectedTimeRange: TrendsTimeRange = .week

    // MARK: - Week Navigation
    var weekOffset: Int = 0

    var isCurrentWeek: Bool {
        weekOffset == 0
    }

    var currentWeekStartDate: Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let daysToSunday = weekday - 1
        let sunday = calendar.date(byAdding: .day, value: -daysToSunday, to: today) ?? today
        return calendar.date(byAdding: .weekOfYear, value: weekOffset, to: sunday) ?? sunday
    }

    var weekDates: [Date] {
        let calendar = Calendar.current
        return (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: currentWeekStartDate)
        }
    }

    // MARK: - Computed Properties
    var weekStartDate: Date {
        currentWeekStartDate
    }

    // MARK: - Data
    var hrvData: [ChartDataPoint] = []
    var averageHRV: Double = 0
    var hrvRange: ClosedRange<Double> = 0...0
    var trendDirection: TrendDirection = .stable
    var stressDistribution: StressDistribution = .init()
    var weeklyInsight: String?
    var patternInsights: [PatternInsight] = []
    var selectedDataPoint: ChartDataPoint?
    var isLoading = false

    // MARK: - New properties for Figma design
    var weeklyMeasurements: [StressMeasurement] = []
    var dailyStressData: [DailyStressData] = []
    /// Last 7 days vs the 7 days before, independent of the selected range.
    /// Nil when either window has no measurements.
    var stressWeekComparison: WeekComparison?
    var hrvWeekComparison: WeekComparison?

    // MARK: - Ripple Trends Helpers

    /// Maps each day (startOfDay) to its StressTier for calendar stress dots.
    var dailyStressTiers: [Date: StressTier] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: weeklyMeasurements) {
            calendar.startOfDay(for: $0.timestamp)
        }
        return grouped.mapValues { measurements in
            let avg = measurements.map { $0.stressLevel }.reduce(0, +) / Double(measurements.count)
            return StressTier.from(level: avg)
        }
    }

    /// Whether average stress is trending down this week (for Ripple's message).
    var stressTrendingDown: Bool {
        guard dailyStressData.count >= 2 else { return true }
        let recent = dailyStressData.suffix(3).map { $0.averageStress }.reduce(0, +) / Double(min(3, dailyStressData.count))
        let older = dailyStressData.prefix(3).map { $0.averageStress }.reduce(0, +) / Double(min(3, dailyStressData.count))
        return recent <= older
    }

    /// Day name with the best (highest) HRV, for the "Best Day" tile.
    var bestHRVDayLabel: String? {
        guard let best = hrvData.max(by: { $0.value < $1.value }) else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: best.date)
    }

    /// Conversational trend badge text for the HRV card.
    var hrvTrendBadge: String {
        switch trendDirection {
        case .up:     return "↗ Improving"
        case .down:   return "↘ Declining"
        case .stable: return "→ Steady"
        }
    }

    // MARK: - Derived Trend Aggregates

    /// Three-band distribution collapsed from the four-band `stressDistribution`.
    /// - relaxed = relaxed only
    /// - mixed   = normal + elevated
    /// - high    = high
    /// Values are rounded percentages; the DistributionBar view enforces the
    /// exact 100% sum, so this property is allowed to be off by ±1 from
    /// rounding.
    var distribution: (relaxed: Double, mixed: Double, high: Double) {
        let d = stressDistribution
        let relaxed = d.relaxed
        let mixed = d.normal + d.elevated
        let high = d.high
        return (relaxed, mixed, high)
    }

    /// Day-of-month → average stress level for the current month. Used by the
    /// MonthlyCalendarHeatmap to color each cell.
    var monthlyCalendar: [Date: Double] {
        let calendar = Calendar.current
        let now = Date()
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
            return [:]
        }
        let monthMeasurements = weeklyMeasurements.filter { $0.timestamp >= monthStart }
        let grouped = Dictionary(grouping: monthMeasurements) {
            calendar.startOfDay(for: $0.timestamp)
        }
        return grouped.mapValues { measurements in
            measurements.map { $0.stressLevel }.reduce(0, +) / Double(measurements.count)
        }
    }

    /// Personal HRV average used as the chart reference line. Zero only when
    /// there are no HRV points, in which case the chart shows its empty state.
    var hrvAvg: Double {
        averageHRV
    }

    /// Week-over-week HRV delta text for the chart summary: average HRV over
    /// the last 7 days vs the 7 days before. Nil without data in both windows.
    var hrvDeltaText: String? {
        guard let pct = hrvWeekComparison?.percentChange else { return nil }
        let rounded = Int(pct.rounded())
        guard rounded != 0 else { return nil }
        return "\(rounded > 0 ? "+" : "")\(rounded)% vs prior 7 days"
    }

    /// Day counts per stress tier for the current week, used by DistributionBar.
    /// Each day is classified by its average stress level into the 4-tier system.
    var distributionDays: (relaxed: Int, mild: Int, moderate: Int, high: Int) {
        var r = 0, m = 0, mo = 0, h = 0
        for day in dailyStressData where day.averageStress > 0 {
            switch day.averageStress {
            case ..<25:   r += 1
            case ..<50:   m += 1
            case ..<75:   mo += 1
            default:      h += 1
            }
        }
        return (r, m, mo, h)
    }

    /// Label for the window `dailyStressData` and `distributionDays` cover.
    var dailyWindowLabel: String {
        let count = dailyStressData.count
        return count == 1 ? "1 day" : "\(count) days"
    }

    /// Distribution comment derived from the dominant tier of the daily window.
    /// States the tier only; no trend is checked here.
    var distributionComment: String? {
        guard dailyStressData.contains(where: { $0.averageStress > 0 }) else { return nil }
        let d = distributionDays
        let maxTier = max(d.relaxed, d.mild, d.moderate, d.high)
        let tiesAtTop = [d.relaxed, d.mild, d.moderate, d.high].filter { $0 == maxTier }.count > 1
        if tiesAtTop {
            return "Your days were split across stress tiers."
        } else if d.mild == maxTier {
            return "Most days landed in Mild."
        } else if d.relaxed == maxTier {
            return "Most days were Relaxed — great recovery this week."
        } else if d.moderate == maxTier {
            return "Moderate stress dominated — consider prioritizing rest tomorrow."
        } else if d.high == maxTier {
            return "Several high-stress days — take it easy and recover."
        }
        return nil
    }

    /// Average of all daily stress values for the bar chart header.
    var dailyStressAverage: Int {
        let valid = dailyStressData.filter { $0.averageStress > 0 }
        guard !valid.isEmpty else { return 0 }
        let avg = valid.map { $0.averageStress }.reduce(0, +) / Double(valid.count)
        return Int(avg.rounded())
    }

    /// Days with at least one measurement, from the daily bar window.
    private var daysWithData: [DailyStressData] {
        dailyStressData.filter { $0.averageStress > 0 }
    }

    /// Editorial one-liner naming the hardest and best day of the daily window.
    /// Falls back to a neutral prompt until two days have data.
    var editorialSummary: String {
        let days = daysWithData
        guard days.count >= 2,
              let hardest = days.max(by: { $0.averageStress < $1.averageStress }),
              let best = days.min(by: { $0.averageStress < $1.averageStress }) else {
            return "Track for a full week to unlock your trends story."
        }
        return "Hardest day was \(hardest.dayLabel) (\(Int(hardest.averageStress))), " +
               "best was \(best.dayLabel) (\(Int(best.averageStress)))."
    }

    /// Percent change in average stress, last 7 days vs the 7 days before.
    /// Positive = calmer. Nil without data in both windows.
    var stressCalmerPercent: Int? {
        guard let pct = stressWeekComparison?.percentChange else { return nil }
        return Int((-pct).rounded())
    }

    /// Short delta label for the editorial header (e.g. "18% calmer").
    var editorialDelta: String? {
        guard let calmer = stressCalmerPercent else { return nil }
        if calmer == 0 { return "about the same" }
        return "\(abs(calmer))% \(calmer > 0 ? "calmer" : "more stressed")"
    }

    private let repository: StressRepositoryProtocol

    init(modelContext: ModelContext, baselineCalculator: BaselineCalculator? = nil) {
        self.repository = StressRepository(modelContext: modelContext, baselineCalculator: baselineCalculator)
    }

    // MARK: - Navigation Methods
    func previousWeek() {
        weekOffset -= 1
        Task {
            await loadTrendData()
        }
    }

    func nextWeek() {
        guard !isCurrentWeek else { return }
        weekOffset += 1
        Task {
            await loadTrendData()
        }
    }

    func goToToday() {
        weekOffset = 0
        selectedDate = Calendar.current.startOfDay(for: Date())
        Task {
            await loadTrendData()
        }
    }

    func selectDate(_ date: Date) {
        selectedDate = date
        Task {
            await loadTrendData()
        }
    }

    func loadTrendData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let calendar = Calendar.current
            let now = Date()
            var startDate: Date
            var groupBy: Calendar.Component

            switch selectedTimeRange {
            case .day:
                startDate = calendar.date(byAdding: .hour, value: -24, to: now) ?? now
                groupBy = .hour
            case .week:
                startDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
                groupBy = .day
            case .twoWeeks:
                startDate = calendar.date(byAdding: .day, value: -14, to: now) ?? now
                groupBy = .day
            case .month:
                startDate = calendar.date(byAdding: .day, value: -30, to: now) ?? now
                groupBy = .day
            case .threeMonths:
                startDate = calendar.date(byAdding: .month, value: -3, to: now) ?? now
                groupBy = .weekOfYear
            }

            let measurements = try await repository.fetchMeasurements(from: startDate, to: now)

            let comparisonStart = calendar.date(byAdding: .day, value: -14, to: now) ?? now
            let comparisonWindow = try await repository.fetchMeasurements(from: comparisonStart, to: now)
            stressWeekComparison = Self.weekComparison(measurements: comparisonWindow, now: now) { $0.stressLevel }
            hrvWeekComparison = Self.weekComparison(measurements: comparisonWindow, now: now) { $0.hrv }

            hrvData = processChartData(measurements: measurements, groupBy: groupBy)
            averageHRV = calculateAverage(from: hrvData)
            hrvRange = calculateRange(from: hrvData)
            trendDirection = calculateTrend()
            stressDistribution = calculateDistribution(measurements: measurements)
            weeklyInsight = generateWeeklyInsight(measurements: measurements)
            patternInsights = generatePatternInsights(measurements: measurements)

            // Store weekly measurements for heatmap
            weeklyMeasurements = measurements

            // Compute daily stress averages for bar chart (last 7 days)
            dailyStressData = computeDailyStress(measurements: measurements)

        } catch {
            hrvData = []
            stressWeekComparison = nil
            hrvWeekComparison = nil
        }
    }

    /// Averages `value` over the 7 days ending at `now` and the 7 days before
    /// it. Nil when either window has no measurements.
    static func weekComparison(
        measurements: [StressMeasurement],
        now: Date,
        calendar: Calendar = .current,
        value: (StressMeasurement) -> Double
    ) -> WeekComparison? {
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: now),
              let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: now) else { return nil }
        let current = measurements.filter { $0.timestamp > weekAgo && $0.timestamp <= now }
        let previous = measurements.filter { $0.timestamp > twoWeeksAgo && $0.timestamp <= weekAgo }
        guard !current.isEmpty, !previous.isEmpty else { return nil }
        return WeekComparison(
            currentAverage: current.map(value).reduce(0, +) / Double(current.count),
            previousAverage: previous.map(value).reduce(0, +) / Double(previous.count)
        )
    }

    private func processChartData(measurements: [StressMeasurement], groupBy: Calendar.Component) -> [ChartDataPoint] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: measurements) { measurement in
            calendar.dateInterval(of: groupBy, for: measurement.timestamp)?.start ?? measurement.timestamp
        }

        return grouped.map { bucketStart, measurements in
            let avgHRV = measurements.map { $0.hrv }.reduce(0, +) / Double(measurements.count)
            return ChartDataPoint(date: bucketStart, value: avgHRV)
        }.sorted { $0.date < $1.date }
    }

    private func calculateAverage(from data: [ChartDataPoint]) -> Double {
        guard !data.isEmpty else { return 0 }
        return data.map { $0.value }.reduce(0, +) / Double(data.count)
    }

    private func calculateRange(from data: [ChartDataPoint]) -> ClosedRange<Double> {
        guard !data.isEmpty else { return 0...0 }
        let values = data.map { $0.value }
        return (values.min() ?? 0)...(values.max() ?? 0)
    }

    private func calculateTrend() -> TrendDirection {
        guard hrvData.count >= 2 else { return .stable }

        let recent = hrvData.suffix(3).map { $0.value }.reduce(0, +) / Double(min(3, hrvData.count))
        let older = hrvData.prefix(3).map { $0.value }.reduce(0, +) / Double(min(3, hrvData.count))

        let diff = recent - older
        if diff > 5 { return .up }
        if diff < -5 { return .down }
        return .stable
    }

    private func calculateDistribution(measurements: [StressMeasurement]) -> StressDistribution {
        guard !measurements.isEmpty else { return .init() }

        let total = Double(measurements.count)

        return StressDistribution(
            relaxed: Double(measurements.filter { $0.stressLevel <= 25 }.count) / total * 100,
            normal: Double(measurements.filter { $0.stressLevel > 25 && $0.stressLevel <= 50 }.count) / total * 100,
            elevated: Double(measurements.filter { $0.stressLevel > 50 && $0.stressLevel <= 75 }.count) / total * 100,
            high: Double(measurements.filter { $0.stressLevel > 75 }.count) / total * 100
        )
    }

    private func generateWeeklyInsight(measurements: [StressMeasurement]) -> String {
        guard measurements.count >= 7 else {
            return "Continue tracking for 7 days to unlock weekly insights"
        }

        guard let change = hrvWeekComparison?.percentChange else {
            return "Track for another week to see week-over-week changes"
        }

        if change > 10 {
            return "Your HRV is \(Int(change))% higher than the 7 days before - great recovery!"
        } else if change < -10 {
            return "Your HRV is \(Int(abs(change)))% lower than the 7 days before - prioritize rest"
        } else {
            return "Your HRV is stable compared to the 7 days before"
        }
    }

    private func generatePatternInsights(measurements: [StressMeasurement]) -> [PatternInsight] {
        var insights: [PatternInsight] = []

        let calendar = Calendar.current
        let weekdayAvg = Dictionary(grouping: measurements) { calendar.component(.weekday, from: $0.timestamp) }
            .mapValues { measurements in
                measurements.map { $0.hrv }.reduce(0, +) / Double(measurements.count)
            }

        let weekdayAvgValues = Array(weekdayAvg.values)
        if weekdayAvgValues.count >= 5 {
            let saturdayAvg = weekdayAvg[7] ?? 0
            let sundayAvg = weekdayAvg[1] ?? 0
            let weekendAvg = (saturdayAvg + sundayAvg) / 2
            let weekdayAvgCalc = weekdayAvgValues.filter { $0 != saturdayAvg && $0 != sundayAvg }.reduce(0, +) / Double(weekdayAvgValues.count - 2)

            if weekendAvg > weekdayAvgCalc * 1.1 {
                insights.append(PatternInsight(
                    icon: "📈",
                    title: "Weekly Pattern",
                    description: "Your HRV is \(Int(((weekendAvg / weekdayAvgCalc) - 1) * 100))% higher on weekends vs weekdays"
                ))
            }
        }

        if let bestDay = weekdayAvg.max(by: { $0.value < $1.value }) {
            let dayName = calendar.weekdaySymbols[bestDay.key - 1]
            insights.append(PatternInsight(
                icon: "💤",
                title: "Best Recovery Day",
                description: "\(dayName) (\(Int(bestDay.value)) ms average)"
            ))
        }

        if let bestHRV = measurements.map({ $0.hrv }).max(), let bestDate = measurements.first(where: { $0.hrv == bestHRV })?.timestamp {
            insights.append(PatternInsight(
                icon: "🏃",
                title: "Personal Best",
                description: "\(Int(bestHRV)) ms on \(formatDate(bestDate))"
            ))
        }

        return insights
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    /// Groups measurements from selected time range into daily averages for the bar chart
    private func computeDailyStress(measurements: [StressMeasurement]) -> [DailyStressData] {
        let calendar = Calendar.current
        let now = Date()
        let shortDays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let daysToShow = min(selectedTimeRange.days, 7) // Show max 7 bars

        // Build ordered list of last N days (oldest → newest)
        return (0..<daysToShow).compactMap { offset -> DailyStressData? in
            guard let dayDate = calendar.date(byAdding: .day, value: -(daysToShow - 1 - offset), to: calendar.startOfDay(for: now)),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayDate) else { return nil }

            let dayMeasurements = measurements.filter { $0.timestamp >= dayDate && $0.timestamp < dayEnd }
            let avg = dayMeasurements.isEmpty ? 0.0 : dayMeasurements.map { $0.stressLevel }.reduce(0, +) / Double(dayMeasurements.count)

            // Calculate distribution for this day
            let total = Double(dayMeasurements.count)
            let relaxed = total > 0 ? Double(dayMeasurements.filter { $0.stressLevel <= 25 }.count) / total * 100 : 0
            let normal = total > 0 ? Double(dayMeasurements.filter { $0.stressLevel > 25 && $0.stressLevel <= 50 }.count) / total * 100 : 0
            let warning = total > 0 ? Double(dayMeasurements.filter { $0.stressLevel > 50 && $0.stressLevel <= 75 }.count) / total * 100 : 0
            let stressed = total > 0 ? Double(dayMeasurements.filter { $0.stressLevel > 75 }.count) / total * 100 : 0

            let weekday = calendar.component(.weekday, from: dayDate) // 1=Sun, 7=Sat
            let dateNum = calendar.component(.day, from: dayDate)
            return DailyStressData(
                dayLabel: shortDays[weekday - 1],
                averageStress: avg,
                dateNumber: dateNum,
                distribution: StressDistributionPerDay(
                    relaxed: relaxed,
                    normal: normal,
                    warning: warning,
                    stressed: stressed
                )
            )
        }
    }
}

/// Average of a metric over the last 7 days vs the 7 days before.
struct WeekComparison: Equatable {
    let currentAverage: Double
    let previousAverage: Double

    /// Percent change from the previous window to the current one; nil when
    /// the previous average is not positive.
    var percentChange: Double? {
        guard previousAverage > 0 else { return nil }
        return (currentAverage - previousAverage) / previousAverage * 100
    }
}

struct ChartDataPoint: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let value: Double

    static func == (lhs: ChartDataPoint, rhs: ChartDataPoint) -> Bool {
        lhs.id == rhs.id
    }
}

struct StressDistribution {
    var relaxed: Double = 0
    var normal: Double = 0
    var elevated: Double = 0
    var high: Double = 0
}

struct PatternInsight {
    let icon: String
    let title: String
    let description: String
}

enum TrendsTimeRange: String, CaseIterable {
    case day = "24H"
    case week = "7D"
    case twoWeeks = "14D"
    case month = "4W"
    case threeMonths = "3M"

    var displayName: String {
        switch self {
        case .day: return "Last 24 hours"
        case .week: return "Last 7 days"
        case .twoWeeks: return "Last 14 days"
        case .month: return "Last 30 days"
        case .threeMonths: return "Last 3 months"
        }
    }

    /// Compact window label for chart headers.
    var periodLabel: String {
        switch self {
        case .day: return "24 hours"
        case .week: return "7 days"
        case .twoWeeks: return "14 days"
        case .month: return "30 days"
        case .threeMonths: return "3 months"
        }
    }

    var days: Int {
        switch self {
        case .day: return 1
        case .week: return 7
        case .twoWeeks: return 14
        case .month: return 30
        case .threeMonths: return 90
        }
    }
}

/// One day's average stress data used for the bar chart
struct DailyStressData: Identifiable {
    let id = UUID()
    let dayLabel: String     // e.g. "Mon", "Tue"
    let averageStress: Double
    var dateNumber: Int? = nil  // e.g. 22 for the 22nd of the month
    var distribution: StressDistributionPerDay? = nil
}

/// Per-day stress distribution for stacked bar chart
struct StressDistributionPerDay {
    var relaxed: Double = 0
    var normal: Double = 0
    var warning: Double = 0
    var stressed: Double = 0
}
