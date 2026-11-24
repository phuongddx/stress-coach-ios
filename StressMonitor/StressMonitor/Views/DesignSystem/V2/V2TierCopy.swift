import Foundation

extension StressCategory {
    /// Short UI V2 line shown under a score ("Focused · steady").
    /// Spec reference: ui-v2-design/screens.js `TIERS[].sub`.
    var v2Substate: String {
        switch self {
        case .relaxed:  return "Calm · recovered"
        case .mild:     return "Focused · steady"
        case .moderate: return "Tense · busy"
        case .high:     return "Wired · ease off"
        case .severe:   return "Running hot · time to reset"
        }
    }
}
