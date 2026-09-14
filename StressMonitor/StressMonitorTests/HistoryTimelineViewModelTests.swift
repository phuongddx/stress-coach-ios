import Foundation
import SwiftData
import Testing
@testable import StressMonitor

@Suite("History Timeline ViewModel")
@MainActor
struct HistoryTimelineViewModelTests {

    private struct MeasurementSpec {
        let daysAgo: Int
        let hoursFromDayStart: Int
        let stressLevel: Double
        let hrv: Double
        let restingHeartRate: Double
    }

    private struct HistoryFixture {
        let container: ModelContainer
        let measurements: [StressMeasurement]
    }

    private struct RequestedWindow {
        let startDate: Date
        let endDate: Date
    }

    private enum FakeRepositoryError: Error {
        case unsupported
    }

    @MainActor
    private final class FakeStressRepository: StressRepositoryProtocol {
        private(set) var requestedWindows: [RequestedWindow] = []
        private let measurements: [StressMeasurement]

        init(measurements: [StressMeasurement]) {
            self.measurements = measurements
        }

        func fetchMeasurements(from startDate: Date, to endDate: Date) async throws -> [StressMeasurement] {
            requestedWindows.append(RequestedWindow(startDate: startDate, endDate: endDate))
            return measurements.filter { $0.timestamp >= startDate && $0.timestamp <= endDate }
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

    @Test("loadInitial groups by local day with newest entries first")
    func testLoadInitial_GroupsByLocalDayNewestFirst() async throws {
        let fixture = try makeFixture([
            MeasurementSpec(
                daysAgo: 0,
                hoursFromDayStart: 0,
                stressLevel: 42,
                hrv: 58,
                restingHeartRate: 62
            ),
            MeasurementSpec(
                daysAgo: 1,
                hoursFromDayStart: 11,
                stressLevel: 92,
                hrv: 26,
                restingHeartRate: 84
            ),
            MeasurementSpec(
                daysAgo: 1,
                hoursFromDayStart: 10,
                stressLevel: 22,
                hrv: 74,
                restingHeartRate: 54
            )
        ])
        let repository = FakeStressRepository(measurements: fixture.measurements)
        let viewModel = HistoryTimelineViewModel(repository: repository)

        await viewModel.loadInitial()

        #expect(viewModel.dayGroups.count == 2)
        #expect(viewModel.dayGroups[0].date > viewModel.dayGroups[1].date)
        #expect(viewModel.dayGroups[0].entries.map(\.stressLevel) == [42])
        #expect(viewModel.dayGroups[1].entries.map(\.stressLevel) == [92, 22])
    }

    @Test("selectFilter severe keeps only severe records")
    func testSelectFilter_SevereKeepsSevereRecordsOnly() async throws {
        let fixture = try makeFixture([
            MeasurementSpec(daysAgo: 0, hoursFromDayStart: 0, stressLevel: 42, hrv: 58, restingHeartRate: 62),
            MeasurementSpec(daysAgo: 1, hoursFromDayStart: 10, stressLevel: 92, hrv: 26, restingHeartRate: 84),
            MeasurementSpec(daysAgo: 1, hoursFromDayStart: 10, stressLevel: 94, hrv: 24, restingHeartRate: 88)
        ])
        let repository = FakeStressRepository(measurements: fixture.measurements)
        let viewModel = HistoryTimelineViewModel(repository: repository)
        await viewModel.loadInitial()

        viewModel.selectFilter(.severe)

        let levels = viewModel.dayGroups.flatMap(\.entries).map(\.stressLevel)
        #expect(levels == [92, 94])
        #expect(levels.allSatisfy { StressResult.category(for: $0) == .severe })
    }

    @Test("summary computes rounded average, best, and peak")
    func testSummary_ComputesRoundedAverageBestAndPeak() async throws {
        let fixture = try makeFixture([
            MeasurementSpec(daysAgo: 1, hoursFromDayStart: 10, stressLevel: 20.4, hrv: 70, restingHeartRate: 55),
            MeasurementSpec(daysAgo: 2, hoursFromDayStart: 10, stressLevel: 40.4, hrv: 58, restingHeartRate: 62),
            MeasurementSpec(daysAgo: 3, hoursFromDayStart: 10, stressLevel: 60.4, hrv: 42, restingHeartRate: 71)
        ])
        let repository = FakeStressRepository(measurements: fixture.measurements)
        let viewModel = HistoryTimelineViewModel(repository: repository)

        await viewModel.loadInitial()

        let summary = try #require(viewModel.summary)
        #expect(abs(Double(summary.sevenDayAverage ?? -1) - 40.4) < 0.5)
        #expect(summary.best == 20)
        #expect(summary.peak == 60)
    }

    @Test("loadEarlier appends older records without duplicates")
    func testLoadEarlier_AppendsOlderRecordsWithoutDuplicates() async throws {
        let fixture = try makeFixture([
            MeasurementSpec(daysAgo: 6, hoursFromDayStart: 10, stressLevel: 42, hrv: 58, restingHeartRate: 62),
            MeasurementSpec(daysAgo: 7, hoursFromDayStart: 10, stressLevel: 72, hrv: 36, restingHeartRate: 78)
        ])
        let repository = FakeStressRepository(measurements: fixture.measurements)
        let viewModel = HistoryTimelineViewModel(repository: repository)
        await viewModel.loadInitial()

        await viewModel.loadEarlier()

        let entries = viewModel.dayGroups.flatMap(\.entries)
        let identifiers = Set(entries.map(\.persistentModelID))
        #expect(entries.count == 2)
        #expect(identifiers.count == entries.count)
        #expect(entries.map(\.stressLevel) == [42, 72])
        #expect(repository.requestedWindows.count == 2)
    }

    @Test("loadEarlier stops when an older window is empty")
    func testLoadEarlier_StopsWhenWindowIsEmpty() async throws {
        let fixture = try makeFixture([
            MeasurementSpec(daysAgo: 6, hoursFromDayStart: 10, stressLevel: 42, hrv: 58, restingHeartRate: 62)
        ])
        let repository = FakeStressRepository(measurements: fixture.measurements)
        let viewModel = HistoryTimelineViewModel(repository: repository)
        await viewModel.loadInitial()
        #expect(viewModel.canLoadMore)

        await viewModel.loadEarlier()

        #expect(viewModel.dayGroups.flatMap(\.entries).count == 1)
        #expect(viewModel.canLoadMore == false)
    }

    @Test("route returns the measurement persistent identifier")
    func testRoute_ReturnsMeasurementPersistentIdentifierRoute() async throws {
        let fixture = try makeFixture([
            MeasurementSpec(daysAgo: 0, hoursFromDayStart: 22, stressLevel: 42, hrv: 58, restingHeartRate: 62)
        ])
        let repository = FakeStressRepository(measurements: fixture.measurements)
        let viewModel = HistoryTimelineViewModel(repository: repository)
        let measurement = fixture.measurements[0]

        let route = viewModel.route(for: measurement)

        if case .measurement(let identifier) = route {
            #expect(identifier == measurement.persistentModelID)
        } else {
            Issue.record("Expected a measurement route")
        }
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
            let timestamp = calendar.date(
                bySettingHour: spec.hoursFromDayStart,
                minute: 0,
                second: 0,
                of: day ?? startOfToday
            ) ?? startOfToday
            let measurement = StressMeasurement(
                timestamp: timestamp,
                stressLevel: spec.stressLevel,
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
