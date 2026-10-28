import Foundation
import Observation
import SwiftData

/// Loads and updates the three daily habits shown on the Action tab.
///
/// One row per habit per day is kept in SwiftData. On first load of a day with
/// no rows, every habit is seeded at 0 so each row renders. The LOG habit
/// (caffeine) is bumped via `logManual(_:amount:)`; AUTO habits (hydration,
/// sunlight) stay "—" until HealthKit reports today's value.
@Observable
@MainActor
final class HabitViewModel {
    /// Today's habit rows, keyed by HabitType for O(1) lookup in the view.
    private(set) var today: [HabitType: Habit] = [:]

    private let modelContext: ModelContext
    private let healthKit: HabitHealthDataProviding

    init(modelContext: ModelContext, healthKit: HabitHealthDataProviding? = nil) {
        self.modelContext = modelContext
        self.healthKit = healthKit ?? HealthKitManager()
        loadToday()
    }

    // MARK: - Read

    func habit(for type: HabitType) -> Habit? {
        today[type]
    }

    // MARK: - Write

    /// Add to a habit's current value (e.g. tapping "+" on a cup of water).
    func logManual(_ type: HabitType, amount: Double = 1) {
        guard let habit = today[type] else { return }
        habit.currentValue = min(habit.goalValue * 2, habit.currentValue + amount)
        save()
    }

    /// Replace the live value of an AUTO habit (HealthKit feed updates this).
    /// A nil value means HealthKit has nothing for today, so the row goes back
    /// to "—" rather than showing a measured zero.
    func setAutoValue(_ type: HabitType, value: Double?) {
        guard let habit = today[type] else { return }
        habit.isAutoValueAvailable = value != nil
        habit.currentValue = max(0, value ?? 0)
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
        let descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { $0.date >= startOfDay }
        )

        let rows = (try? modelContext.fetch(descriptor)) ?? []

        // Index existing rows by type
        var byType: [HabitType: Habit] = [:]
        for row in rows where byType[row.type] == nil {
            byType[row.type] = row
        }

        // Seed any missing habit types for today so every row renders
        for type in HabitType.allCases where byType[type] == nil {
            let habit = Habit(type: type, date: startOfDay)
            modelContext.insert(habit)
            byType[type] = habit
        }

        today = byType
        save()
        Task { [weak self] in await self?.refreshAutoHabits() }
    }

    private func save() {
        try? modelContext.save()
    }
}
