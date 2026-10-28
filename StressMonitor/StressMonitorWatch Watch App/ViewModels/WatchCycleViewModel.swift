import Foundation
import Observation

// MARK: - WatchCycleViewModel

/// `UserDefaults`-backed view model for menstrual-cycle tracking on the
/// watch. Stores the most recent cycle-start date and derives the current
/// phase, day-of-cycle, and next-phase prediction from it.
///
/// All state lives on `@MainActor` so SwiftUI reads stay safe. Logging a
/// new cycle start also records the phase for the current day in
/// `loggedPhases`.
@MainActor
@Observable
final class WatchCycleViewModel {
    /// Current cycle snapshot derived from the most recent log, if any.
    private(set) var cycleData: CycleData?

    /// Per-day phase log (keyed by start-of-day `Date`).
    private(set) var loggedPhases: [Date: CyclePhase] = [:]

    private let defaults: UserDefaults
    private let cycleStartKey = "watch.cycle.start"
    private let cycleLengthKey = "watch.cycle.length"
    private let loggedPhasesKey = "watch.cycle.loggedPhases"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    // MARK: - Public API

    /// Record the start of a new cycle. Resets `loggedPhases` for the new
    /// cycle and re-derives `cycleData`.
    func logCycleStart(_ date: Date) {
        defaults.set(date, forKey: cycleStartKey)
        if defaults.object(forKey: cycleLengthKey) == nil {
            defaults.set(28, forKey: cycleLengthKey)
        }
        recompute(from: date)
        let day = Calendar.current.startOfDay(for: date)
        loggedPhases[day] = .menstrual
        persistLoggedPhases()
    }

    /// Predict the phase for "today" based on the logged cycle start.
    /// Returns `.menstrual` when no cycle has been logged.
    func predictNextPhase() -> CyclePhase {
        guard let data = cycleData else { return .menstrual }
        let nextDay = data.dayOfCycle + 1
        let clampedDay = ((nextDay - 1) % max(data.cycleLength, 1)) + 1
        return CyclePhase.phase(forDay: clampedDay)
    }

    /// Returns the stress-correlation note for the current phase, or `nil`
    /// when no cycle is logged.
    func stressCorrelationForToday() -> String? {
        cycleData?.currentPhase.stressCorrelation
    }

    // MARK: - Internals

    private func load() {
        let cycleLength = (defaults.object(forKey: cycleLengthKey) as? Int) ?? 28
        if let start = defaults.object(forKey: cycleStartKey) as? Date {
            recompute(from: start, cycleLength: cycleLength)
        }
        if let data = defaults.data(forKey: loggedPhasesKey),
           let decoded = try? JSONDecoder().decode([Date: CyclePhase].self, from: data) {
            loggedPhases = decoded
        }
    }

    private func recompute(from start: Date, cycleLength: Int? = nil) {
        let length = cycleLength ?? ((defaults.object(forKey: cycleLengthKey) as? Int) ?? 28)
        let calendar = Calendar.current
        let now = Date()
        let dayOfCycle = max(1, calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: now)).day.map { $0 + 1 } ?? 1)
        let phase = CyclePhase.phase(forDay: dayOfCycle)
        let nextPrediction = calendar.date(byAdding: .day, value: max(length, 1), to: start)
        cycleData = CycleData(
            currentPhase: phase,
            dayOfCycle: dayOfCycle,
            cycleLength: length,
            nextPrediction: nextPrediction
        )
    }

    private func persistLoggedPhases() {
        if let data = try? JSONEncoder().encode(loggedPhases) {
            defaults.set(data, forKey: loggedPhasesKey)
        }
    }
}
