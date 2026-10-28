import Foundation
import SwiftData
import Testing
@testable import StressMonitor

/// WidgetPublisher.Keys and WidgetDataProvider.Keys are both `private` and live in
/// separate compile targets (StressMonitor app vs. StressMonitorWidget extension), so
/// they cannot be compared by type. This regression-proofs the contract via the literal
/// key strings both sides are known to use instead.
struct WidgetPublisherKeyMatchingTests {
    private static let suiteName = "group.stress.ai.com"

    private static let allKeys = [
        "latest_stress_level",
        "latest_stress_category",
        "latest_hrv",
        "latest_heart_rate",
        "latest_timestamp",
        "latest_confidence"
    ]

    private func cleanUp(_ defaults: UserDefaults) {
        for key in Self.allKeys {
            defaults.removeObject(forKey: key)
        }
    }

    @Test("publish writes all six App-Group UserDefaults keys")
    func publishWritesAllSixKeys() {
        let defaults = UserDefaults(suiteName: Self.suiteName)!
        cleanUp(defaults)

        let measurement = StressMeasurement(
            timestamp: Date(),
            stressLevel: 42,
            hrv: 55,
            restingHeartRate: 68,
            confidences: nil
        )

        WidgetPublisher.publish(measurement)

        #expect(defaults.object(forKey: "latest_stress_level") != nil)
        #expect(defaults.object(forKey: "latest_stress_category") != nil)
        #expect(defaults.object(forKey: "latest_hrv") != nil)
        #expect(defaults.object(forKey: "latest_heart_rate") != nil)
        #expect(defaults.object(forKey: "latest_timestamp") != nil)
        #expect(defaults.object(forKey: "latest_confidence") != nil)

        cleanUp(defaults)
    }

    @Test("published values match the source measurement")
    func publishedValuesMatchSource() {
        let defaults = UserDefaults(suiteName: Self.suiteName)!
        cleanUp(defaults)

        let timestamp = Date()
        let measurement = StressMeasurement(
            timestamp: timestamp,
            stressLevel: 61,
            hrv: 38,
            restingHeartRate: 74,
            confidences: nil
        )

        WidgetPublisher.publish(measurement)

        #expect(defaults.double(forKey: "latest_stress_level") == measurement.stressLevel)
        #expect(defaults.string(forKey: "latest_stress_category") == measurement.categoryRawValue)
        #expect(defaults.double(forKey: "latest_hrv") == measurement.hrv)
        #expect(defaults.double(forKey: "latest_heart_rate") == measurement.restingHeartRate)
        #expect(defaults.double(forKey: "latest_confidence") == 1.0)
        #expect(defaults.double(forKey: "latest_timestamp") == measurement.timestamp.timeIntervalSince1970)

        cleanUp(defaults)
    }

    // MARK: - Live write-path tests (plan 01-06)

    @Test("loadCurrentStress saves the calculated measurement through the repository")
    @MainActor
    func loadCurrentStressSavesCalculatedMeasurement() async {
        let healthKit = MockHealthKitService()
        healthKit.mockHRV = 55
        healthKit.mockHeartRate = 72
        let algorithm = MockStressAlgorithmService()
        algorithm.mockStressLevel = 61
        let repository = MockStressRepository()

        let viewModel = StressViewModel(
            healthKit: healthKit,
            algorithm: algorithm,
            repository: repository
        )
        await viewModel.loadCurrentStress()

        #expect(repository.mockMeasurements.count == 1)
        let saved = repository.mockMeasurements.first
        #expect(saved?.stressLevel == 61)
        #expect(saved?.hrv == 55)
        #expect(saved?.restingHeartRate == 72)
        #expect(viewModel.currentStress?.level == 61)
    }

    @Test("the live dashboard path writes all six widget suite keys")
    @MainActor
    func liveDashboardPathWritesAllSixSuiteKeys() async throws {
        let defaults = try #require(UserDefaults(suiteName: Self.suiteName))
        cleanUp(defaults)
        defer { cleanUp(defaults) }

        let healthKit = MockHealthKitService()
        let algorithm = MockStressAlgorithmService()
        algorithm.mockStressLevel = 42

        // Real repository over an in-memory container — the same shape
        // DashboardView's default init uses. The container must outlive its
        // mainContext for the whole test, or SwiftData traps.
        let container = try ModelContainer(
            for: StressMeasurement.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repository = StressRepository(modelContext: ModelContext(container))

        let viewModel = StressViewModel(
            healthKit: healthKit,
            algorithm: algorithm,
            repository: repository
        )
        await viewModel.loadCurrentStress()

        for key in Self.allKeys {
            #expect(defaults.object(forKey: key) != nil, "expected non-nil value for \(key)")
        }
        let publishedLevel = defaults.double(forKey: "latest_stress_level")
        #expect(publishedLevel == 42)
        #expect(publishedLevel == viewModel.currentStress?.level)

        withExtendedLifetime(container) {}
    }

    @Test("repeated loads of the same underlying reading persist exactly once")
    @MainActor
    func repeatedLoadsOfSameReadingPersistOnce() async {
        let healthKit = MockHealthKitService()
        let firstReadingDate = Date(timeIntervalSince1970: 1_750_000_000)
        healthKit.mockHRVTimestamp = firstReadingDate
        let repository = MockStressRepository()

        let viewModel = StressViewModel(
            healthKit: healthKit,
            algorithm: MockStressAlgorithmService(),
            repository: repository
        )
        await viewModel.loadCurrentStress()
        await viewModel.loadCurrentStress()
        #expect(repository.mockMeasurements.count == 1)

        healthKit.mockHRVTimestamp = firstReadingDate.addingTimeInterval(600)
        await viewModel.loadCurrentStress()
        #expect(repository.mockMeasurements.count == 2)
    }
}
