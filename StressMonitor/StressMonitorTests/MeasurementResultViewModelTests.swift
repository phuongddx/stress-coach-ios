import Foundation
import SwiftData
import Testing
@testable import StressMonitor

@Suite("Measurement Result ViewModel")
@MainActor
struct MeasurementResultViewModelTests {

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

    @Test("load computes delta from the latest prior reading, excluding itself")
    func testLoad_ComputesPreviousDeltaFromLatestPriorMeasurement() async throws {
        let now = Date()
        let fixture = try makeFixture([
            MeasurementSpec(secondsAgo: 0, stressLevel: 42.4, hrv: 52, restingHeartRate: 68),
            MeasurementSpec(secondsAgo: 86_400, stressLevel: 58, hrv: 44, restingHeartRate: 72),
            MeasurementSpec(secondsAgo: 172_800, stressLevel: 30, hrv: 66, restingHeartRate: 60)
        ])
        let repository = FakeStressRepository(measurements: fixture.measurements)
        let viewModel = MeasurementResultViewModel(
            result: makeResult(timestamp: now, level: 42.4),
            repository: repository
        )

        await viewModel.load()

        #expect(viewModel.previousDelta == -16)
        #expect(viewModel.deltaLabel == "Down 16 pts from your last reading")
        #expect(viewModel.errorMessage == nil)
    }

    @Test("load hides the delta ribbon when no prior reading exists")
    func testLoad_HidesDeltaWhenNoPriorReading() async throws {
        let now = Date()
        let repository = FakeStressRepository(measurements: [])
        let viewModel = MeasurementResultViewModel(
            result: makeResult(timestamp: now, level: 42),
            repository: repository
        )

        await viewModel.load()

        #expect(viewModel.previousDelta == nil)
        #expect(viewModel.deltaLabel == nil)
    }

    @Test("factor rows map all five components in design order")
    func testFactorRows_MapAllFiveComponentsAndPreserveNilAsUnavailable() {
        let viewModel = MeasurementResultViewModel(
            result: makeResult(timestamp: Date(), level: 42),
            repository: FakeStressRepository(measurements: [])
        )

        let rows = viewModel.factorRows

        #expect(rows.map(\.factor) == [.hrv, .heartRate, .sleep, .activity, .recovery])
        #expect(rows[0].value == 0.72)
        #expect(rows[0].detailText == "52 ms")
        #expect(rows[1].value == 0.41)
        #expect(rows[1].detailText == "68 bpm")
        #expect(rows[2].value == nil)
        #expect(rows[2].detailText == nil)
        #expect(rows[3].value == 0.55)
        #expect(rows[4].value == nil)
    }

    @Test("factor rows are empty for legacy results without a breakdown")
    func testFactorRows_EmptyWhenBreakdownMissing() {
        let viewModel = MeasurementResultViewModel(
            result: StressResult(
                level: 42,
                category: .mild,
                confidence: 0.7,
                hrv: 52,
                heartRate: 68
            ),
            repository: FakeStressRepository(measurements: [])
        )

        #expect(viewModel.factorRows.isEmpty)
    }

    @Test("confidence label reflects factor count")
    func testConfidenceLabel_ReflectsFactorCount() {
        let multiFactor = MeasurementResultViewModel(
            result: makeResult(timestamp: Date(), level: 42),
            repository: FakeStressRepository(measurements: [])
        )
        let legacy = MeasurementResultViewModel(
            result: StressResult(
                level: 42,
                category: .mild,
                confidence: 0.96,
                hrv: 52,
                heartRate: 68
            ),
            repository: FakeStressRepository(measurements: [])
        )

        #expect(multiFactor.confidenceLabel == "96% confidence · 5-factor analysis")
        #expect(legacy.confidenceLabel == "96% confidence · 2-factor analysis")
    }

    @Test("load surfaces the deterministic high-stress insight")
    func testLoad_SurfacesInsightFromHistory() async throws {
        let now = Date()
        let repository = FakeStressRepository(measurements: [])
        let viewModel = MeasurementResultViewModel(
            result: makeResult(timestamp: now, level: 80),
            repository: repository
        )

        await viewModel.load()

        #expect(viewModel.insight?.title == "High Stress Detected")
    }

    // MARK: - Fixtures

    private struct MeasurementSpec {
        let secondsAgo: Int
        let stressLevel: Double
        let hrv: Double
        let restingHeartRate: Double
    }

    private func makeFixture(_ specs: [MeasurementSpec]) throws -> HistoryFixture {
        let container = try ModelContainer(
            for: StressMeasurement.self,
            configurations: ModelConfiguration(
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
        )
        let context = container.mainContext
        let now = Date()
        let measurements = specs.map { spec in
            let measurement = StressMeasurement(
                timestamp: now.addingTimeInterval(TimeInterval(-spec.secondsAgo)),
                stressLevel: spec.stressLevel,
                hrv: spec.hrv,
                restingHeartRate: spec.restingHeartRate
            )
            context.insert(measurement)
            return measurement
        }
        try context.save()
        return HistoryFixture(container: container, measurements: measurements)
    }

    private func makeResult(timestamp: Date, level: Double) -> StressResult {
        StressResult(
            level: level,
            category: StressResult.category(for: level),
            confidence: 0.96,
            hrv: 52,
            heartRate: 68,
            timestamp: timestamp,
            factorBreakdown: FactorBreakdown(
                hrvComponent: 0.72,
                hrComponent: 0.41,
                sleepComponent: nil,
                activityComponent: 0.55,
                recoveryComponent: nil,
                dataCompleteness: 0.8
            )
        )
    }
}
