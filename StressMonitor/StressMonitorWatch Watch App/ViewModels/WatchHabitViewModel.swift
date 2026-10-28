import Foundation
import Observation

/// Loads and updates the three daily habits shown on the Action tab.
///
/// The watch app does not use SwiftData. One row per habit per day is kept in
/// `UserDefaults`. On first load of a day with no rows, every habit is seeded at
/// 0 so each card renders. The LOG habit (caffeine) is bumped via
/// `logManual(_:amount:)`; AUTO habits (hydration, sunlight) stay "—" until
/// HealthKit reports today's value.
@Observable
@MainActor
final class WatchHabitViewModel {
    /// Today's habit rows, keyed by HabitType for O(1) lookup in the view.
    private(set) var today: [HabitType: WatchHabit] = [:]

    /// Storage key for the persisted `[WatchHabit]` array (today's rows only).
    private let storageKey = "WatchHabitViewModel.today"

    private let healthKit = WatchHealthKitManager()

    init() {
        loadToday()
    }

    // MARK: - Read

    func habit(for type: HabitType) -> WatchHabit? {
        today[type]
    }

    // MARK: - Write

    /// Add to a habit's current value (e.g. tapping "+" on a cup of water).
    func logManual(_ type: HabitType, amount: Double = 1) {
        guard let habit = today[type] else { return }
        today[type]?.currentValue = min(habit.goalValue * 2, habit.currentValue + amount)
        save()
    }

    /// Replace the live value of an AUTO habit (HealthKit feed updates this).
    /// A nil value means HealthKit has nothing for today, so the card goes back
    /// to "—" rather than showing a measured zero.
    func setAutoValue(_ type: HabitType, value: Double?) {
        guard today[type] != nil else { return }
        today[type]?.isAutoValueAvailable = value != nil
        today[type]?.currentValue = max(0, value ?? 0)
        save()
    }

    /// Reads today's water and daylight totals from HealthKit into the AUTO rows.
    func refreshAutoHabits() async {
        // Re-asking is silent unless a type is still undetermined; this is how
        // installs that predate these two read types get prompted for them.
        try? await healthKit.requestAuthorization()
        let water = try? await healthKit.fetchTodayWaterLiters()
        let daylight = try? await healthKit.fetchTodayDaylightMinutes()
        setAutoValue(.hydration, value: water)
        setAutoValue(.sunlight, value: daylight)
    }

    // MARK: - Loading

    func loadToday() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())

        var byType: [HabitType: WatchHabit] = [:]

        // Restore today's rows from UserDefaults
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let rows = try? JSONDecoder().decode([WatchHabit].self, from: data) {
            for row in rows where calendar.isDate(row.date, inSameDayAs: startOfDay) {
                byType[row.type] = row
            }
        }

        // Seed any missing habit types for today so every row renders
        for type in HabitType.allCases where byType[type] == nil {
            byType[type] = WatchHabit(type: type, date: startOfDay)
        }

        today = byType
        save()
    }

    // MARK: - Persistence

    private func save() {
        let rows = Array(today.values)
        if let data = try? JSONEncoder().encode(rows) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
