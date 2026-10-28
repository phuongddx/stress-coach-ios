import Foundation
import SwiftData
import Testing
@testable import StressMonitor

/// Pins that AUTO habit rows show HealthKit's value or nothing: never the
/// seeded zero presented as a measurement.
@MainActor
struct HabitViewModelTests {

    @MainActor
    private final class FakeHabitHealth: HabitHealthDataProviding {
        var water: Double?
        var daylight: Double?

        func requestAuthorization() async throws {}
        func fetchTodayWaterLiters() async throws -> Double? { water }
        func fetchTodayDaylightMinutes() async throws -> Double? { daylight }
    }

    /// Held for the test's lifetime: a context outlives its container only by crashing.
    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: Habit.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeViewModel(health: FakeHabitHealth) async -> HabitViewModel {
        let viewModel = HabitViewModel(modelContext: container.mainContext, healthKit: health)
        // Let the refresh started by loading finish before assertions run.
        await Task.yield()
        return viewModel
    }

    @Test("AUTO rows have no display value until HealthKit reports")
    func autoRowsEmptyWithoutSamples() async throws {
        let viewModel = await makeViewModel(health: FakeHabitHealth())

        #expect(viewModel.habit(for: .hydration)?.hasDisplayValue == false)
        #expect(viewModel.habit(for: .sunlight)?.hasDisplayValue == false)
    }

    @Test("refreshAutoHabits writes today's HealthKit totals into the AUTO rows")
    func refreshWritesHealthKitTotals() async throws {
        let health = FakeHabitHealth()
        health.water = 1.4
        health.daylight = 42
        let viewModel = await makeViewModel(health: health)

        await viewModel.refreshAutoHabits()

        let hydration = try #require(viewModel.habit(for: .hydration))
        let sunlight = try #require(viewModel.habit(for: .sunlight))
        #expect(hydration.hasDisplayValue)
        #expect(hydration.currentValue == 1.4)
        #expect(sunlight.hasDisplayValue)
        #expect(sunlight.currentValue == 42)
    }

    @Test("an AUTO row returns to empty when HealthKit no longer has samples")
    func autoRowClearsWhenSamplesDisappear() async throws {
        let health = FakeHabitHealth()
        health.water = 1.4
        let viewModel = await makeViewModel(health: health)
        await viewModel.refreshAutoHabits()
        #expect(viewModel.habit(for: .hydration)?.hasDisplayValue == true)

        health.water = nil
        await viewModel.refreshAutoHabits()

        #expect(viewModel.habit(for: .hydration)?.hasDisplayValue == false)
    }

    @Test("the LOG habit always has a display value and still logs manually")
    func manualHabitUnaffected() async throws {
        let viewModel = await makeViewModel(health: FakeHabitHealth())

        #expect(viewModel.habit(for: .caffeine)?.hasDisplayValue == true)
        viewModel.logManual(.caffeine)
        #expect(viewModel.habit(for: .caffeine)?.currentValue == 1)
    }
}
