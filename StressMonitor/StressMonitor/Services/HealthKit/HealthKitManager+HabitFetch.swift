import Foundation
import HealthKit

// MARK: - Habit Data Source

/// The HealthKit-fed habit totals. A seam so `HabitViewModel` can be tested
/// without a live store.
@MainActor
protocol HabitHealthDataProviding {
    func requestAuthorization() async throws
    /// Liters of water logged today; nil when HealthKit has no samples (or
    /// read access was not granted — HealthKit does not distinguish the two).
    func fetchTodayWaterLiters() async throws -> Double?
    /// Minutes in daylight today; nil when HealthKit has no samples.
    func fetchTodayDaylightMinutes() async throws -> Double?
}

// MARK: - HealthKitManager Habit Fetch

extension HealthKitManager: HabitHealthDataProviding {

    func fetchTodayWaterLiters() async throws -> Double? {
        try await todaySum(type: dietaryWaterType, unit: .liter())
    }

    func fetchTodayDaylightMinutes() async throws -> Double? {
        try await todaySum(type: timeInDaylightType, unit: .minute())
    }

    private func todaySum(type: HKQuantityType, unit: HKUnit) async throws -> Double? {
        let now = Date()
        let start = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now)

        return try await withCheckedThrowingContinuation { continuation in
            var hasReturned = false
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                guard !hasReturned else { return }
                hasReturned = true
                if let error {
                    if (error as? HKError)?.code == .errorNoData {
                        continuation.resume(returning: nil)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                continuation.resume(returning: statistics?.sumQuantity()?.doubleValue(for: unit))
            }
            self.healthStore.execute(query)
        }
    }
}
