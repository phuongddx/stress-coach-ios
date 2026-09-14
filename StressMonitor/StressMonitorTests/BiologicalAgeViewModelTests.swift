import Foundation
import SwiftData
import Testing
@testable import StressMonitor

@Suite("Biological Age ViewModel")
@MainActor
struct BiologicalAgeViewModelTests {

    private struct MeasurementSpec {
        let daysAgo: Int
        let hoursFromDayStart: Int
        let hrv: Double
        let restingHeartRate: Double
    }

    private struct HistoryFixture {
        let container: ModelContainer
        let measurements: [StressMeasurement]
    }

    private enum FakeRepositoryError: Error {
        case unsupported
    }

    @MainActor
    private final class FakeStressRepository: StressRepositoryProtocol {
        private let measurements: [StressMeasurement]

        init(measurements: [StressMeasurement]) {
            self.measurements = measurements
        }

        func fetchMeasurements(from startDate: Date, to endDate: Date) async throws -> [StressMeasurement] {
            measurements.filter { $0.timestamp >= startDate && $0.timestamp <= endDate }
        }

        func save(_ measurement: StressMeasurement) async throws {}

        func fetchRecent(limit: Int) async throws -> [StressMeasurement] {
            measurements
        }

        func fetchAll() async throws -> [StressMeasurement] {
            measurements
        }

        func deleteOlderThan(_ date: Date) async throws {
            throw FakeRepositoryError.unsupported
        }

        func getBaseline() async throws -> PersonalBaseline {
            throw FakeRepositoryError.unsupported
        }

        func updateBaseline(_ baseline: PersonalBaseline) async throws {
            throw FakeRepositoryError.unsupported
        }

        func delete(_ measurement: StressMeasurement) async throws {
            throw FakeRepositoryError.unsupported
        }

        func fetchAverageHRV(hours: Int) async throws -> Double {
            throw FakeRepositoryError.unsupported
        }

        func fetchAverageHRV(days: Int) async throws -> Double {
            throw FakeRepositoryError.unsupported
        }

        func deleteAllMeasurements() async throws {
            throw FakeRepositoryError.unsupported
        }
    }

    @MainActor
    private final class FakeHealthKitService: HealthKitServiceProtocol {
        var dateOfBirthComponents: DateComponents?

        func requestAuthorization() async throws {}

        func fetchLatestHRV() async throws -> HRVMeasurement? {
            nil
        }

        func fetchHeartRate(samples: Int) async throws -> [HeartRateSample] {
            []
        }

        func fetchHRVHistory(since date: Date) async throws -> [HRVMeasurement] {
            []
        }

        func observeHeartRateUpdates() -> AsyncStream<HeartRateSample?> {
            AsyncStream { continuation in
                continuation.finish()
            }
        }
    }

    @Test("load with insufficient data clears result and shows the insufficient state")
    func testLoad_InsufficientDataClearsResultAndShowsInsufficientState() async throws {
        let fixture = try makeFixture([
            MeasurementSpec(daysAgo: 0, hoursFromDayStart: 10, hrv: 78, restingHeartRate: 62),
            MeasurementSpec(daysAgo: 1, hoursFromDayStart: 10, hrv: 76, restingHeartRate: 64),
            MeasurementSpec(daysAgo: 2, hoursFromDayStart: 10, hrv: 74, restingHeartRate: 60)
        ])
        let viewModel = makeViewModel(
            repository: FakeStressRepository(measurements: fixture.measurements),
            healthKit: FakeHealthKitService()
        )

        await viewModel.load()

        #expect(viewModel.hasSufficientData == false)
        #expect(viewModel.result == nil)
        #expect(viewModel.dailyEstimates.isEmpty)
        #expect(viewModel.hrvAverage == nil)
        #expect(viewModel.restingHRAverage == nil)
        #expect(viewModel.isLoading == false)
    }

    @Test("load computes the result from seven-day averages")
    func testLoad_ComputesResultFromSevenDayAverages() async throws {
        let specs = (0...6).map { day in
            MeasurementSpec(daysAgo: day, hoursFromDayStart: 10, hrv: 78, restingHeartRate: 62)
        }
        let fixture = try makeFixture(specs)
        let healthKit = FakeHealthKitService()
        healthKit.dateOfBirthComponents = makeDateOfBirthComponents(yearsAgo: 35)
        let viewModel = makeViewModel(
            repository: FakeStressRepository(measurements: fixture.measurements),
            healthKit: healthKit
        )

        await viewModel.load()

        #expect(viewModel.hasSufficientData)
        #expect(viewModel.chronologicalAge == 35)
        let hrvAverage = try #require(viewModel.hrvAverage)
        let restingHRAverage = try #require(viewModel.restingHRAverage)
        #expect(abs(hrvAverage - 78) < 0.001)
        #expect(abs(restingHRAverage - 62) < 0.001)
        #expect(viewModel.result?.chronologicalAge == 35)
        #expect(viewModel.result?.estimatedAge == 33)
        #expect(viewModel.result?.difference == -2)
        #expect(viewModel.result?.differenceLabel == "2 years younger")
        #expect(viewModel.errorMessage == nil)
    }

    @Test("load uses HealthKit date of birth with an explicit fallback of 35")
    func testLoad_UsesHealthKitDateOfBirthWithExplicitFallback() async throws {
        let fixture = try makeFixture(sevenDaySpecs())

        let healthKitWithDOB = FakeHealthKitService()
        healthKitWithDOB.dateOfBirthComponents = makeDateOfBirthComponents(yearsAgo: 30)
        let viewModelWithDOB = makeViewModel(
            repository: FakeStressRepository(measurements: fixture.measurements),
            healthKit: healthKitWithDOB
        )
        await viewModelWithDOB.load()

        let viewModelWithoutDOB = makeViewModel(
            repository: FakeStressRepository(measurements: fixture.measurements),
            healthKit: FakeHealthKitService()
        )
        await viewModelWithoutDOB.load()

        #expect(viewModelWithDOB.chronologicalAge == 30)
        #expect(viewModelWithDOB.result?.chronologicalAge == 30)
        #expect(viewModelWithoutDOB.chronologicalAge == 35)
        #expect(viewModelWithoutDOB.result?.chronologicalAge == 35)
    }

    @Test("daily estimates are ordered old to new and omit days without a result")
    func testDailyEstimates_OrderedOldToNewAndOmitDaysWithoutResult() async throws {
        var specs = sevenDaySpecs()
        specs.append(
            MeasurementSpec(daysAgo: 3, hoursFromDayStart: 22, hrv: 0, restingHeartRate: 0)
        )
        let fixture = try makeFixture(specs)
        let viewModel = makeViewModel(
            repository: FakeStressRepository(measurements: fixture.measurements),
            healthKit: FakeHealthKitService()
        )

        await viewModel.load()

        let days = viewModel.dailyEstimates.map(\.day)
        #expect(viewModel.dailyEstimates.count == 7)
        #expect(zip(days, days.dropFirst()).allSatisfy { $0 < $1 })
        #expect(viewModel.dailyEstimates.allSatisfy { $0.estimatedAge == 33 })
    }

    @Test("daily chart summary describes the rendered range without fabrication")
    func testDailyChartSummary_DescribesRangeWithoutFabrication() {
        let ranged = [
            DailyBioAgeEstimate(day: Date(timeIntervalSinceNow: -172_800), estimatedAge: 28),
            DailyBioAgeEstimate(day: Date(timeIntervalSinceNow: -86_400), estimatedAge: 33),
            DailyBioAgeEstimate(day: Date(), estimatedAge: 26)
        ]
        let steady = [
            DailyBioAgeEstimate(day: Date(timeIntervalSinceNow: -86_400), estimatedAge: 30),
            DailyBioAgeEstimate(day: Date(), estimatedAge: 30)
        ]

        #expect(
            BioAgeDailyChart.accessibilitySummary(for: ranged)
                == "Bio age ranged 26 to 33 over the last 7 days"
        )
        #expect(
            BioAgeDailyChart.accessibilitySummary(for: steady)
                == "Bio age held at 30 over the last 7 days"
        )
        #expect(BioAgeDailyChart.accessibilitySummary(for: []) == nil)
    }

    // MARK: - Fixtures

    private func sevenDaySpecs() -> [MeasurementSpec] {
        (0...6).map { day in
            MeasurementSpec(daysAgo: day, hoursFromDayStart: 10, hrv: 78, restingHeartRate: 62)
        }
    }

    private func makeViewModel(
        repository: StressRepositoryProtocol,
        healthKit: HealthKitServiceProtocol
    ) -> BiologicalAgeViewModel {
        BiologicalAgeViewModel(
            repository: repository,
            healthKit: healthKit,
            calculator: BioAgeCalculator()
        )
    }

    private func makeDateOfBirthComponents(yearsAgo: Int) -> DateComponents {
        let calendar = Calendar.current
        let dob = calendar.date(byAdding: .year, value: -yearsAgo, to: Date()) ?? Date()
        return calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: dob
        )
    }

    private func makeFixture(_ specs: [MeasurementSpec]) throws -> HistoryFixture {
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: StressMeasurement.self,
            configurations: configuration
        )
        let context = container.mainContext
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        var measurements: [StressMeasurement] = []

        for spec in specs {
            let day = calendar.date(
                byAdding: .day,
                value: -spec.daysAgo,
                to: startOfToday
            )
            let requested = calendar.date(
                bySettingHour: spec.hoursFromDayStart,
                minute: 0,
                second: 0,
                of: day ?? startOfToday
            ) ?? startOfToday
            let timestamp = min(requested, Date())
            let measurement = StressMeasurement(
                timestamp: timestamp,
                stressLevel: 42,
                hrv: spec.hrv,
                restingHeartRate: spec.restingHeartRate
            )
            context.insert(measurement)
            measurements.append(measurement)
        }

        try context.save()
        return HistoryFixture(container: container, measurements: measurements)
    }
}
