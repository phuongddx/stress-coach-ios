import Foundation
import Observation

/// One bar of the Bio Age daily-estimate chart.
struct DailyBioAgeEstimate: Identifiable, Sendable {
    let day: Date
    let estimatedAge: Int

    var id: Date { day }
}

/// Presentation state for the Biological Age screen
/// (`design/screens/18-bio-age.html`). Aggregates the last 7 days of
/// measurements through the existing `BioAgeCalculator`; renders nothing the
/// calculator did not actually produce.
@MainActor
@Observable
final class BiologicalAgeViewModel {
    private(set) var isLoading = false
    private(set) var result: BioAgeResult?
    private(set) var hasSufficientData = false
    private(set) var chronologicalAge = 35
    private(set) var hrvAverage: Double?
    private(set) var restingHRAverage: Double?
    private(set) var dailyEstimates: [DailyBioAgeEstimate] = []
    var errorMessage: String?

    private let repository: StressRepositoryProtocol
    private let healthKit: HealthKitServiceProtocol
    private let calculator: BioAgeCalculator

    convenience init(repository: StressRepositoryProtocol) {
        self.init(
            repository: repository,
            healthKit: HealthKitManager(),
            calculator: BioAgeCalculator()
        )
    }

    init(
        repository: StressRepositoryProtocol,
        healthKit: HealthKitServiceProtocol,
        calculator: BioAgeCalculator
    ) {
        self.repository = repository
        self.healthKit = healthKit
        self.calculator = calculator
    }

    /// Loads the estimate from the last 7 days of readings. A failed fetch or
    /// thin history degrades to the insufficient-data state rather than
    /// inventing inputs.
    func load() async {
        isLoading = true
        defer { isLoading = false }

        chronologicalAge = resolveChronologicalAge()

        let now = Date()
        let windowStart = Calendar.current.date(
            byAdding: .day,
            value: -BioAgeCalculator.minimumDataDays,
            to: now
        ) ?? now

        var measurements: [StressMeasurement] = []
        do {
            measurements = try await repository.fetchMeasurements(from: windowStart, to: now)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }

        hasSufficientData = calculator.hasEnoughData(measurements: measurements)
        guard hasSufficientData else {
            result = nil
            hrvAverage = nil
            restingHRAverage = nil
            dailyEstimates = []
            return
        }

        hrvAverage = average(of: measurements.map(\.hrv).filter { $0 > 0 })
        restingHRAverage = average(of: measurements.map(\.restingHeartRate).filter { $0 > 0 })

        result = calculator.calculate(
            chronologicalAge: chronologicalAge,
            hrv: hrvAverage,
            restingHeartRate: restingHRAverage,
            sleepEfficiency: nil,
            previousResult: nil
        )

        dailyEstimates = makeDailyEstimates(from: measurements)
    }

    /// Chronological age from HealthKit DOB, falling back to the documented
    /// default used by `StressViewModel.calculateBioAge`.
    private func resolveChronologicalAge() -> Int {
        guard let dobComponents = healthKit.dateOfBirthComponents,
              let dob = Calendar.current.date(from: dobComponents) else {
            return 35
        }
        let components = Calendar.current.dateComponents([.year], from: dob, to: Date())
        return components.year ?? 35
    }

    private func makeDailyEstimates(from measurements: [StressMeasurement]) -> [DailyBioAgeEstimate] {
        Dictionary(grouping: measurements) { measurement in
            Calendar.current.startOfDay(for: measurement.timestamp)
        }
        .map { day, dayMeasurements -> DailyBioAgeEstimate? in
            let estimate = calculator.calculate(
                chronologicalAge: chronologicalAge,
                hrv: average(of: dayMeasurements.map(\.hrv).filter { $0 > 0 }),
                restingHeartRate: average(of: dayMeasurements.map(\.restingHeartRate).filter { $0 > 0 }),
                sleepEfficiency: nil,
                previousResult: nil
            )
            return estimate.map { DailyBioAgeEstimate(day: day, estimatedAge: $0.estimatedAge) }
        }
        .compactMap { $0 }
        .sorted { $0.day < $1.day }
    }

    private func average(of values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
