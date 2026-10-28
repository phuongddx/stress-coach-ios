import Foundation
import HealthKit

final class WatchHealthKitManager: HealthKitServiceProtocol {
  let healthStore = HKHealthStore()

  let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
  let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
  let sleepType = HKCategoryType(.sleepAnalysis)
  let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
  let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
  let appleStandTimeType = HKQuantityType.quantityType(forIdentifier: .appleStandTime)!
  let respiratoryRateType = HKQuantityType.quantityType(forIdentifier: .respiratoryRate)!
  let oxygenSaturationType = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!
  let restingHeartRateType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!
  let dietaryWaterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater)!
  let timeInDaylightType = HKQuantityType.quantityType(forIdentifier: .timeInDaylight)!

  func requestAuthorization() async throws {
    guard HKHealthStore.isHealthDataAvailable() else {
      throw HealthKitError.notAvailable
    }

    let typesToRead: Set<HKObjectType> = [
      hrvType, heartRateType, sleepType,
      stepCountType, activeEnergyType, appleStandTimeType,
      respiratoryRateType, oxygenSaturationType, restingHeartRateType,
      dietaryWaterType, timeInDaylightType,
      HKObjectType.workoutType()
    ]

    try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
  }

  func fetchLatestHRV() async throws -> HRVMeasurement? {
    let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
    let query = HKSampleQuery(
      sampleType: hrvType,
      predicate: nil,
      limit: 1,
      sortDescriptors: [sortDescriptor]
    ) { [weak self] _, samples, _ in
      guard let self = self,
        let sample = samples?.first as? HKQuantitySample
      else {
        return
      }

      let value = sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
      self.hrvResult = HRVMeasurement(value: value, timestamp: sample.endDate)
    }

    healthStore.execute(query)

    return await withCheckedContinuation { continuation in
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        continuation.resume(returning: self.hrvResult)
      }
    }
  }

  func fetchHeartRate(samples: Int) async throws -> [HeartRateSample] {
    let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
    let query = HKSampleQuery(
      sampleType: heartRateType,
      predicate: nil,
      limit: samples,
      sortDescriptors: [sortDescriptor]
    ) { [weak self] _, samples, _ in
      guard let self = self,
        let samples = samples as? [HKQuantitySample]
      else {
        return
      }

      let results = samples.map { sample in
        let value = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        return HeartRateSample(value: value, timestamp: sample.endDate)
      }

      self.heartRateResults = results
    }

    healthStore.execute(query)

    return await withCheckedContinuation { continuation in
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        continuation.resume(returning: self.heartRateResults ?? [])
      }
    }
  }

  private var hrvResult: HRVMeasurement?
  private var heartRateResults: [HeartRateSample]?

  func fetchHRVHistory(since: Date) async throws -> [HRVMeasurement] {
    let predicate = HKQuery.predicateForSamples(withStart: since, end: nil, options: .strictStartDate)
    let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
    let query = HKSampleQuery(
      sampleType: hrvType,
      predicate: predicate,
      limit: HKObjectQueryNoLimit,
      sortDescriptors: [sortDescriptor]
    ) { [weak self] _, samples, _ in
      guard let self = self,
        let samples = samples as? [HKQuantitySample]
      else {
        return
      }

      let results = samples.map { sample in
        let value = sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
        return HRVMeasurement(value: value, timestamp: sample.endDate)
      }

      self.hrvHistoryResults = results
    }

    healthStore.execute(query)

    return await withCheckedContinuation { continuation in
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        continuation.resume(returning: self.hrvHistoryResults ?? [])
      }
    }
  }

  func observeHeartRateUpdates() -> AsyncStream<HeartRateSample?> {
    AsyncStream { continuation in
      let query = HKObserverQuery(sampleType: heartRateType, predicate: nil) { _, completionHandler, error in
        // Always invoke the completion handler — failing it three times in a row
        // makes HealthKit disable observer delivery for the app.
        defer { completionHandler() }

        guard error == nil else {
          continuation.yield(nil)
          return
        }

        // Fetch the latest heart-rate sample on each change notification so the
        // stream carries real data instead of always yielding nil.
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let sampleQuery = HKSampleQuery(
          sampleType: self.heartRateType,
          predicate: nil,
          limit: 1,
          sortDescriptors: [sortDescriptor]
        ) { _, samples, _ in
          guard let sample = samples?.first as? HKQuantitySample else {
            continuation.yield(nil)
            return
          }
          let value = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
          continuation.yield(HeartRateSample(value: value, timestamp: sample.endDate))
        }
        self.healthStore.execute(sampleQuery)
      }
      self.healthStore.execute(query)

      continuation.onTermination = { @Sendable [weak self] _ in
        self?.healthStore.stop(query)
      }
    }
  }

  private var hrvHistoryResults: [HRVMeasurement]?

  // MARK: - Habit Totals

  /// Liters of water logged today; nil when HealthKit has no samples (or read
  /// access was not granted — HealthKit does not distinguish the two).
  func fetchTodayWaterLiters() async throws -> Double? {
    try await todaySum(type: dietaryWaterType, unit: .liter())
  }

  /// Minutes in daylight today; nil when HealthKit has no samples.
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

enum HealthKitError: Error {
  case notAvailable
  case authorizationDenied
  case noData
}
