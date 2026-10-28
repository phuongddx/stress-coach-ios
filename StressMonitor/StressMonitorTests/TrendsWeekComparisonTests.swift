import Foundation
import SwiftData
import Testing
@testable import StressMonitor

/// Pins the Trends comparison and copy to what the data supports: a real
/// last-7-days vs prior-7-days average, and tier statements without trend claims.
@MainActor
struct TrendsWeekComparisonTests {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func measurement(daysAgo: Double, stress: Double, hrv: Double = 40) -> StressMeasurement {
        StressMeasurement(
            timestamp: now.addingTimeInterval(-daysAgo * 86_400),
            stressLevel: stress,
            hrv: hrv
        )
    }

    /// Held for the test's lifetime: a context outlives its container only by crashing.
    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: StressMeasurement.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeViewModel() -> TrendsViewModel {
        TrendsViewModel(modelContext: ModelContext(container))
    }

    // MARK: - weekComparison

    @Test("averages the last 7 days against the 7 days before")
    func averagesBothWindows() {
        let data = [
            measurement(daysAgo: 2, stress: 60),
            measurement(daysAgo: 4, stress: 40),
            measurement(daysAgo: 9, stress: 80),
            measurement(daysAgo: 12, stress: 60),
        ]

        let comparison = TrendsViewModel.weekComparison(measurements: data, now: now) { $0.stressLevel }

        #expect(comparison == WeekComparison(currentAverage: 50, previousAverage: 70))
    }

    @Test("is nil when the previous 7 days have no measurements")
    func nilWithoutPreviousWindow() {
        let data = [measurement(daysAgo: 2, stress: 60), measurement(daysAgo: 4, stress: 40)]

        let comparison = TrendsViewModel.weekComparison(measurements: data, now: now) { $0.stressLevel }

        #expect(comparison == nil)
    }

    @Test("is nil when the last 7 days have no measurements")
    func nilWithoutCurrentWindow() {
        let data = [measurement(daysAgo: 9, stress: 60)]

        let comparison = TrendsViewModel.weekComparison(measurements: data, now: now) { $0.stressLevel }

        #expect(comparison == nil)
    }

    // MARK: - Editorial delta

    @Test("lower stress than the prior 7 days reads as calmer")
    func calmerDelta() {
        let viewModel = makeViewModel()
        viewModel.stressWeekComparison = WeekComparison(currentAverage: 40, previousAverage: 50)

        #expect(viewModel.editorialDelta == "20% calmer")
    }

    @Test("higher stress than the prior 7 days reads as more stressed")
    func moreStressedDelta() {
        let viewModel = makeViewModel()
        viewModel.stressWeekComparison = WeekComparison(currentAverage: 60, previousAverage: 50)

        #expect(viewModel.editorialDelta == "20% more stressed")
    }

    @Test("no comparison means no delta line")
    func noDeltaWithoutComparison() {
        let viewModel = makeViewModel()

        #expect(viewModel.editorialDelta == nil)
    }

    @Test("HRV delta is the week-over-week change, not a split of the range")
    func hrvDeltaIsWeekOverWeek() {
        let viewModel = makeViewModel()
        viewModel.hrvWeekComparison = WeekComparison(currentAverage: 55, previousAverage: 50)

        #expect(viewModel.hrvDeltaText == "+10% vs prior 7 days")
    }

    // MARK: - Distribution comment

    @Test("a Mild-dominant window states the tier without claiming a trend")
    func mildCommentHasNoTrendClaim() {
        let viewModel = makeViewModel()
        viewModel.dailyStressData = [
            DailyStressData(dayLabel: "Mon", averageStress: 30),
            DailyStressData(dayLabel: "Tue", averageStress: 32),
            DailyStressData(dayLabel: "Wed", averageStress: 28),
        ]

        #expect(viewModel.distributionComment == "Most days landed in Mild.")
    }

    @Test("tied top tiers are reported as split")
    func tiedTiersReportedAsSplit() {
        let viewModel = makeViewModel()
        viewModel.dailyStressData = [
            DailyStressData(dayLabel: "Mon", averageStress: 10),
            DailyStressData(dayLabel: "Tue", averageStress: 30),
        ]

        #expect(viewModel.distributionComment == "Your days were split across stress tiers.")
    }
}
