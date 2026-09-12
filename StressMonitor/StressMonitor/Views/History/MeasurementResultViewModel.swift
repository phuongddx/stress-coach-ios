import Foundation
import Observation
import SwiftData

/// One row of the result screen's five-factor breakdown, in design order.
struct ResultFactorRow: Identifiable, Sendable {
    let factor: FactorBreakdownRow.Factor
    /// Normalized stress contribution 0–1 (nil = factor unavailable).
    let value: Double?
    /// Raw input summary (e.g. "52 ms"); nil when not derivable.
    var detailText: String? = nil

    var id: FactorBreakdownRow.Factor { factor }
}

/// Presentation state for the immediate post-reading result screen
/// (`design/screens/07-measurement.html`).
@MainActor
@Observable
final class MeasurementResultViewModel {
    private(set) var isLoading = false
    private(set) var previousDelta: Int?
    private(set) var insight: AIInsight?
    var errorMessage: String?

    private let result: StressResult
    private let repository: StressRepositoryProtocol

    init(result: StressResult, repository: StressRepositoryProtocol) {
        self.result = result
        self.repository = repository
    }

    /// The five factors in design order; empty for legacy readings without a
    /// breakdown so the View can show its unavailable note.
    var factorRows: [ResultFactorRow] {
        guard let breakdown = result.factorBreakdown else { return [] }
        return [
            ResultFactorRow(
                factor: .hrv,
                value: breakdown.hrvComponent,
                detailText: "\(Int(result.hrv.rounded())) ms"
            ),
            ResultFactorRow(
                factor: .heartRate,
                value: breakdown.hrComponent,
                detailText: "\(Int(result.heartRate.rounded())) bpm"
            ),
            ResultFactorRow(factor: .sleep, value: breakdown.sleepComponent),
            ResultFactorRow(factor: .activity, value: breakdown.activityComponent),
            ResultFactorRow(factor: .recovery, value: breakdown.recoveryComponent)
        ]
    }

    var confidenceLabel: String {
        let analysis = result.factorBreakdown == nil ? "2-factor" : "5-factor"
        return "\(Int((result.confidence * 100).rounded()))% confidence · \(analysis) analysis"
    }

    /// Nil hides the delta ribbon (no prior reading or a failed fetch).
    var deltaLabel: String? {
        guard let previousDelta else { return nil }
        switch previousDelta {
        case ..<0:
            return "Down \(abs(previousDelta)) pts from your last reading"
        case 1...:
            return "Up \(previousDelta) pts from your last reading"
        default:
            return "No change from your last reading"
        }
    }

    /// Loads the vs-previous delta and Ripple takeaway. Degrades honestly:
    /// a failed fetch hides the ribbon rather than inventing a baseline.
    func load() async {
        isLoading = true
        defer { isLoading = false }

        let windowStart = Calendar.current.date(
            byAdding: .day,
            value: -7,
            to: result.timestamp
        ) ?? result.timestamp

        var history: [StressMeasurement] = []
        do {
            history = try await repository.fetchMeasurements(
                from: windowStart,
                to: result.timestamp
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }

        previousDelta = history
            .filter { $0.timestamp < result.timestamp }
            .max { $0.timestamp < $1.timestamp }
            .map { Int((result.level - $0.stressLevel).rounded()) }

        insight = InsightGenerator.generate(from: result, history: history)
    }
}
