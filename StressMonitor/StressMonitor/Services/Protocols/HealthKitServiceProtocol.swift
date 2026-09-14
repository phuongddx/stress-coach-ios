import Foundation

@preconcurrency import HealthKit

protocol HealthKitServiceProtocol: Sendable {
    func requestAuthorization() async throws
    func fetchLatestHRV() async throws -> HRVMeasurement?
    func fetchHeartRate(samples: Int) async throws -> [HeartRateSample]
    func fetchHRVHistory(since: Date) async throws -> [HRVMeasurement]
    func observeHeartRateUpdates() -> AsyncStream<HeartRateSample?>
    func fetchSleepData(for date: Date) async throws -> SleepData?
    func fetchActivityData(for date: Date) async throws -> ActivityData?
    func fetchRecoveryData(for date: Date) async throws -> RecoveryData?
    /// User's date of birth components from HealthKit. Declared as a
    /// requirement so protocol-typed callers dynamically dispatch to the
    /// concrete implementation (an extension-only member would always use
    /// the `nil` default). The extension default keeps nil for mocks.
    var dateOfBirthComponents: DateComponents? { get }
}

extension HealthKitServiceProtocol {
    func fetchSleepData(for date: Date) async throws -> SleepData? { nil }
    func fetchActivityData(for date: Date) async throws -> ActivityData? { nil }
    func fetchRecoveryData(for date: Date) async throws -> RecoveryData? { nil }

    /// Latest respiratory rate (breaths/min). Default returns nil so mock and
    /// simulator services compile without their own implementation; the live
    /// HealthKitManager overrides with a real query.
    func fetchRespiratoryRate() async throws -> Double? { nil }

    /// User's date of birth components from HealthKit. Default returns nil;
    /// concrete implementation overrides via HKHealthStore.
    var dateOfBirthComponents: DateComponents? { nil }
}
