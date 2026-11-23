import SwiftUI

/// One row of the multi-factor stress breakdown (UI V2), drawn with `V2FactorRow`:
/// icon, factor name, the factor's share of the stress signal as a bar and percent,
/// and a footnote with the raw reading and confidence when known.
///
/// When `value` is nil the factor was unavailable for this measurement; the row
/// shows "No data" rather than dropping silently.
struct FactorBreakdownRow: View {
    enum Factor: Hashable {
        case hrv, heartRate, sleep, activity, recovery

        var displayName: String {
            switch self {
            case .hrv:        return "HRV"
            case .heartRate:  return "Heart Rate"
            case .sleep:      return "Sleep"
            case .activity:   return "Activity"
            case .recovery:   return "Recovery"
            }
        }

        var icon: String {
            switch self {
            case .hrv:        return "waveform.path.ecg"
            case .heartRate:  return "heart.fill"
            case .sleep:      return "moon.zzz.fill"
            case .activity:   return "figure.run"
            case .recovery:   return "leaf.fill"
            }
        }
    }

    let factor: Factor
    /// Normalized stress contribution 0–1 (nil = factor unavailable).
    var value: Double?
    /// Optional human-readable raw input (e.g. "52 ms", "68 bpm").
    var detailText: String? = nil
    var confidence: Double? = nil

    var body: some View {
        V2FactorRow(
            systemImage: factor.icon,
            name: factor.displayName,
            level: value.map { min(1, max(0.03, $0)) },
            value: value.map { "\(Int(($0 * 100).rounded()))" },
            unit: value == nil ? nil : "%",
            sentence: sentence
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(factor.displayName). \(value == nil ? "Not available" : detailText ?? valueText)")
    }

    private var valueText: String {
        if let value {
            return "\(Int((value * 100).rounded()))%"
        }
        return "—"
    }

    /// "52 ms · high confidence" style footnote built from the existing inputs.
    private var sentence: String? {
        var parts: [String] = []
        if let detailText, detailText != "—" {
            parts.append("Measured \(detailText)")
        }
        if let confidence {
            switch confidence {
            case 0.8...:    parts.append("high confidence")
            case 0.5..<0.8: parts.append("medium confidence")
            default:        parts.append("low confidence")
            }
        }
        guard !parts.isEmpty else { return nil }
        let joined = parts.joined(separator: " · ")
        return joined.prefix(1).uppercased() + joined.dropFirst()
    }
}

#Preview {
    VStack(spacing: 14) {
        FactorBreakdownRow(factor: .hrv, value: 0.72, detailText: "52 ms", confidence: 0.85)
        FactorBreakdownRow(factor: .heartRate, value: 0.41, detailText: "68 bpm", confidence: 0.62)
        FactorBreakdownRow(factor: .sleep, value: nil)
        FactorBreakdownRow(factor: .activity, value: 0.30, detailText: "45 min", confidence: 0.4)
        FactorBreakdownRow(factor: .recovery, value: nil)
    }
    .padding()
    .background(Color.V2.bg)
}
