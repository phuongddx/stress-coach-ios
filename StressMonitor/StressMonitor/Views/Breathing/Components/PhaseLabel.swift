import SwiftUI

/// Phase word ("Breathe in") with the seconds countdown below, sitting on the
/// accent core of the breathing arena (UI V2 `S.session`).
struct PhaseLabel: View {
    let phase: BoxBreathingPhase
    let secondsRemaining: Int
    var tint: Color = Color.V2.onAccent

    var body: some View {
        VStack(spacing: 2) {
            Text(phase.displayWord)
                .font(.headline)
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("\(secondsRemaining)")
                .font(.v2Number(.largeTitle, weight: .bold))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(phase.displayWord), \(secondsRemaining) seconds remaining")
    }
}

extension BoxBreathingPhase {
    /// Display word for the breathing arena centre.
    var displayWord: String {
        switch self {
        case .inhale:  return "Breathe in"
        case .holdIn:  return "Hold"
        case .exhale:  return "Breathe out"
        case .holdOut: return "Hold"
        }
    }
}

#Preview("PhaseLabel") {
    HStack(spacing: 32) {
        PhaseLabel(phase: .inhale, secondsRemaining: 3)
        PhaseLabel(phase: .holdIn, secondsRemaining: 2)
        PhaseLabel(phase: .exhale, secondsRemaining: 4)
        PhaseLabel(phase: .holdOut, secondsRemaining: 1)
    }
    .padding(40)
    .background(Color.V2.accent)
}
