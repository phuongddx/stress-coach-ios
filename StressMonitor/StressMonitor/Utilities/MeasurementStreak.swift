import Foundation

enum MeasurementStreak {
    /// How far back callers fetch measurements before computing a streak.
    static let lookbackDays = 365

    /// Consecutive calendar days with at least one measurement, ending today.
    /// A day with no reading yet doesn't break the streak until it is over,
    /// so the count runs back from yesterday when today is still empty.
    static func days(from timestamps: [Date], calendar: Calendar = .current, now: Date = Date()) -> Int {
        let days = Set(timestamps.map { calendar.startOfDay(for: $0) })
        var cursor = calendar.startOfDay(for: now)
        if !days.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }
        var streak = 0
        while days.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }
}
