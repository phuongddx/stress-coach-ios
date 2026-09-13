import Foundation
import Observation
import SwiftData

enum HistoryFilter: String, CaseIterable, Sendable {
    case all
    case relaxed
    case mild
    case moderate
    case high
    case severe

    var title: String {
        switch self {
        case .all:
            return "All"
        case .relaxed:
            return StressCategory.relaxed.displayName
        case .mild:
            return StressCategory.mild.displayName
        case .moderate:
            return StressCategory.moderate.displayName
        case .high:
            return StressCategory.high.displayName
        case .severe:
            return StressCategory.severe.displayName
        }
    }

    var category: StressCategory? {
        switch self {
        case .all:
            return nil
        case .relaxed:
            return .relaxed
        case .mild:
            return .mild
        case .moderate:
            return .moderate
        case .high:
            return .high
        case .severe:
            return .severe
        }
    }
}

struct HistoryDayGroup: Identifiable, Sendable {
    let date: Date
    let entries: [StressMeasurement]

    var id: Date { date }
}

struct HistorySummary: Sendable {
    let sevenDayAverage: Int?
    let best: Int?
    let peak: Int?
}

private enum HistoryTimelineError: LocalizedError {
    case loadFailed(String)

    var errorDescription: String? {
        switch self {
        case .loadFailed(let description):
            return description
        }
    }
}

@MainActor
@Observable
final class HistoryTimelineViewModel {
    private(set) var isLoading = false
    var selectedFilter: HistoryFilter = .all
    private(set) var dayGroups: [HistoryDayGroup] = []
    private(set) var summary: HistorySummary?
    private(set) var canLoadMore = true
    var errorMessage: String?

    private var allMeasurements: [StressMeasurement] = []
    private var oldestLoadedDate = Date()
    private let repository: StressRepositoryProtocol

    init(repository: StressRepositoryProtocol) {
        self.repository = repository
    }

    func loadInitial() async {
        isLoading = true
        defer { isLoading = false }

        let now = Date()
        let windowStart = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now

        do {
            let measurements = try await repository.fetchMeasurements(from: windowStart, to: now)
                .sorted { $0.timestamp > $1.timestamp }

            allMeasurements = measurements
            oldestLoadedDate = measurements.last?.timestamp ?? windowStart
            summary = makeSummary(from: measurements, now: now)
            canLoadMore = !measurements.isEmpty
            errorMessage = nil
            recomputeDayGroups()
        } catch {
            allMeasurements = []
            dayGroups = []
            summary = nil
            canLoadMore = false
            errorMessage = HistoryTimelineError.loadFailed(error.localizedDescription).errorDescription
        }
    }

    func loadEarlier() async {
        guard !isLoading, canLoadMore else { return }

        isLoading = true
        defer { isLoading = false }

        let windowEnd = oldestLoadedDate
        let windowStart = Calendar.current.date(byAdding: .day, value: -7, to: windowEnd) ?? windowEnd

        do {
            let fetchedMeasurements = try await repository.fetchMeasurements(from: windowStart, to: windowEnd)
            var loadedIdentifiers = Set(allMeasurements.map(\.persistentModelID))
            let newMeasurements = fetchedMeasurements.filter { loadedIdentifiers.insert($0.persistentModelID).inserted }

            guard !newMeasurements.isEmpty else {
                canLoadMore = false
                return
            }

            allMeasurements = (allMeasurements + newMeasurements)
                .sorted { $0.timestamp > $1.timestamp }
            oldestLoadedDate = allMeasurements.last?.timestamp ?? windowEnd
            errorMessage = nil
            recomputeDayGroups()
        } catch {
            errorMessage = HistoryTimelineError.loadFailed(error.localizedDescription).errorDescription
        }
    }

    func selectFilter(_ filter: HistoryFilter) {
        selectedFilter = filter
        recomputeDayGroups()
    }

    func route(for measurement: StressMeasurement) -> Route {
        .measurement(id: measurement.persistentModelID)
    }

    private func recomputeDayGroups() {
        let filteredMeasurements: [StressMeasurement]
        if let category = selectedFilter.category {
            filteredMeasurements = allMeasurements.filter { $0.category == category }
        } else {
            filteredMeasurements = allMeasurements
        }

        let groupedEntries = Dictionary(grouping: filteredMeasurements) { measurement in
            Calendar.current.startOfDay(for: measurement.timestamp)
        }

        dayGroups = groupedEntries
            .map { HistoryDayGroup(date: $0.key, entries: $0.value) }
            .sorted { $0.date > $1.date }
    }

    private func makeSummary(from measurements: [StressMeasurement], now: Date) -> HistorySummary? {
        let calendar = Calendar.current
        let sevenDayStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now))
            ?? calendar.startOfDay(for: now)
        let levels = measurements
            .filter { $0.timestamp >= sevenDayStart }
            .map(\.stressLevel)

        guard let bestLevel = levels.min(), let peakLevel = levels.max() else { return nil }

        let average = levels.reduce(0, +) / Double(levels.count)

        return HistorySummary(
            sevenDayAverage: Int(average.rounded()),
            best: Int(bestLevel.rounded()),
            peak: Int(peakLevel.rounded())
        )
    }
}
