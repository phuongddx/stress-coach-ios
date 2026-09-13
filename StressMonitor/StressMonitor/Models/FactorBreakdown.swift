import Foundation

// MARK: - FactorBreakdown

/// Per-factor normalized stress values from a multi-factor calculation.
/// All component fields are optional — nil means that factor was unavailable.
struct FactorBreakdown: Codable, Hashable, Sendable {
    let hrvComponent: Double?
    let hrComponent: Double?
    let sleepComponent: Double?
    let activityComponent: Double?
    let recoveryComponent: Double?
    /// Fraction of total weight that contributed: 1.0 = all factors present
    let dataCompleteness: Double
}
