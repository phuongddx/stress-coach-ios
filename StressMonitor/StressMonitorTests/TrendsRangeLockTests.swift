import Foundation
import SwiftData
import Testing
@testable import StressMonitor

// MARK: - TrendsRangeLockTests

/// SPEC 6.1: the 30- and 90-day Trends views are part of Plus.
@MainActor
struct TrendsRangeLockTests {

    /// Held for the test's lifetime: a context outlives its container only by crashing.
    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: StressMeasurement.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
    }

    private func makeViewModel() -> TrendsViewModel {
        TrendsViewModel(modelContext: ModelContext(container))
    }

    @Test("Locked: 30 and 90 days ask for the paywall and keep 7 days")
    func lockedLongRangesNeedPaywall() {
        let viewModel = makeViewModel()
        for range in [TrendsTimeRange.month, .threeMonths] {
            #expect(viewModel.selectRange(range, locked: true))
            #expect(viewModel.selectedTimeRange == .week)
        }
    }

    @Test("Locked: 7 days stays selectable")
    func lockedWeekIsFree() {
        let viewModel = makeViewModel()
        #expect(viewModel.selectRange(.week, locked: true) == false)
        #expect(viewModel.selectedTimeRange == .week)
    }

    @Test("Unlocked: 30 days is selected without a paywall")
    func unlockedMonthSelects() {
        let viewModel = makeViewModel()
        #expect(viewModel.selectRange(.month, locked: false) == false)
        #expect(viewModel.selectedTimeRange == .month)
    }

    @Test("Losing Plus on a 90-day view falls back to 7 days")
    func losingPlusFallsBack() {
        let viewModel = makeViewModel()
        viewModel.selectRange(.threeMonths, locked: false)
        #expect(viewModel.enforceRangeLock(false) == false)
        #expect(viewModel.selectedTimeRange == .threeMonths)

        #expect(viewModel.enforceRangeLock(true))
        #expect(viewModel.selectedTimeRange == .week)
        #expect(viewModel.enforceRangeLock(true) == false)
    }

    @Test("Only the 30- and 90-day ranges require Plus")
    func requiresPlusFlags() {
        let gated = TrendsTimeRange.allCases.filter(\.requiresPlus)
        #expect(Set(gated) == [.month, .threeMonths])
    }
}
