import Foundation
import HealthKit

@MainActor
@Observable
final class HealthKitManager: HealthKitServiceProtocol {
    let healthStore: HKHealthStore

    let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
    let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
    let sleepType = HKCategoryType(.sleepAnalysis)
    let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
    let appleStandTimeType = HKQuantityType.quantityType(forIdentifier: .appleStandTime)!
    let respiratoryRateType = HKQuantityType.quantityType(forIdentifier: .respiratoryRate)!
    let oxygenSaturationType = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!
    let restingHeartRateType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!
    let dietaryWaterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater)!
    let timeInDaylightType = HKQuantityType.quantityType(forIdentifier: .timeInDaylight)!

    init(healthStore: HKHealthStore = .init()) {
        self.healthStore = healthStore
    }

    var dateOfBirthComponents: DateComponents? {
        HKHealthStore.isHealthDataAvailable()
            ? try? healthStore.dateOfBirthComponents()
            : nil
    }

    func requestAuthorization() async throws {
        let readTypes: Set<HKObjectType> = [
            hrvType, heartRateType, sleepType,
            stepCountType, activeEnergyType, appleStandTimeType,
            respiratoryRateType, oxygenSaturationType, restingHeartRateType,
            dietaryWaterType, timeInDaylightType,
            HKCharacteristicType(.dateOfBirth),
            HKObjectType.workoutType()
        ]
        try await healthStore.requestAuthorization(toShare: [] as Set<HKSampleType>, read: readTypes)
    }

    func fetchLatestHRV() async throws -> HRVMeasurement? {
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            var queryHasReturned = false

            let wrappedQuery = HKSampleQuery(
                sampleType: self.hrvType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard !queryHasReturned else { return }
                queryHasReturned = true

                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }

                let value = sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                let measurement = HRVMeasurement(value: value, timestamp: sample.endDate)
                continuation.resume(returning: measurement)
            }

            self.healthStore.execute(wrappedQuery)
        }
    }

    func fetchHeartRate(samples: Int) async throws -> [HeartRateSample] {
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            var queryHasReturned = false

            let query = HKSampleQuery(
                sampleType: self.heartRateType,
                predicate: nil,
                limit: samples,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard !queryHasReturned else { return }
                queryHasReturned = true

                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let samples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }

                let heartRates = samples.map { sample in
                    let value = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    return HeartRateSample(value: value, timestamp: sample.endDate)
                }

                continuation.resume(returning: heartRates)
            }

            self.healthStore.execute(query)
        }
    }

    func fetchHRVHistory(since: Date) async throws -> [HRVMeasurement] {
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let predicate = HKQuery.predicateForSamples(withStart: since, end: nil, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            var queryHasReturned = false

            let query = HKSampleQuery(
                sampleType: self.hrvType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard !queryHasReturned else { return }
                queryHasReturned = true

                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let samples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }

                let measurements = samples.map { sample in
                    let value = sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                    return HRVMeasurement(value: value, timestamp: sample.endDate)
                }

                continuation.resume(returning: measurements)
            }

            self.healthStore.execute(query)
        }
    }

    func observeHeartRateUpdates() -> AsyncStream<HeartRateSample?> {
        return AsyncStream { continuation in
            let query = HKObserverQuery(sampleType: self.heartRateType, predicate: nil) { _, completionHandler, error in
                // Foreground-only stream (no enableBackgroundDelivery). Always invoke
                // the completion handler so HealthKit keeps delivering updates.
                defer { completionHandler() }

                guard error == nil else {
                    continuation.yield(nil)
                    return
                }

                // fetchHeartRate is @MainActor-isolated, so hop explicitly to the
                // main actor instead of capturing @MainActor self in an unstructured,
                // unisolated Task (avoids Swift 6 concurrency warnings).
                Task { @MainActor [weak self] in
                    do {
                        guard let self else { return }
                        let samples = try await self.fetchHeartRate(samples: 1)
                        continuation.yield(samples.first)
                    } catch {
                        continuation.yield(nil)
                    }
                }
            }

            self.healthStore.execute(query)

            continuation.onTermination = { @Sendable [weak self] _ in
                guard let self else { return }
                self.healthStore.stop(query)
            }
        }
    }
}
