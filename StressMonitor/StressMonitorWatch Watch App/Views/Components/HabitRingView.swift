import SwiftUI

// MARK: - HabitRingView

/// Circular progress ring for a single daily habit (UI V2).
///
/// A `surface2` track, an accent progress arc (lime once the goal is
/// reached) and the habit icon in the centre. The `current/goal` count is
/// drawn by the caller beneath the ring (`WatchHabit.displayRatio`) so the
/// ring interior never needs a fixed-size font.
struct HabitRingView: View {
    let habit: WatchHabit
    var size: CGFloat = 44

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var ringWidth: CGFloat { max(5, size * 0.085) }
    private var fraction: CGFloat {
        let goal = max(habit.goalValue, 1)
        return CGFloat(min(max(habit.currentValue / goal, 0), 1))
    }
    private var isComplete: Bool { habit.currentValue >= habit.goalValue }

    var body: some View {
        ZStack {
            track
            progressArc
            centerStack
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel(accessibilitySummary)
    }

    // MARK: - Subviews

    private var track: some View {
        Circle()
            .stroke(WatchV2.surface2, lineWidth: ringWidth)
    }

    private var progressArc: some View {
        Circle()
            .trim(from: 0, to: fraction)
            .stroke(
                arcColor,
                style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .animation(
                WatchDesignTokens.motion(WatchDesignTokens.Motion.default, reduceMotion: reduceMotion),
                value: fraction
            )
    }

    private var centerStack: some View {
        Image(systemName: habit.type.icon)
            .font(.footnote.weight(.semibold))
            .imageScale(.small)
            .foregroundStyle(isComplete ? WatchV2.lime : WatchV2.ink)
    }

    // MARK: - Helpers

    private var arcColor: Color {
        isComplete ? WatchV2.lime : WatchV2.accent
    }

    private var accessibilitySummary: String {
        let pct = Int(fraction * 100)
        let status = isComplete ? ", goal reached" : ""
        return "\(habit.type.displayName), \(habit.displayCurrent) of \(habit.displayGoal) \(habit.type.unit)\(status), \(pct) percent."
    }
}

// MARK: - Display formatting

extension WatchHabit {
    var displayCurrent: String {
        type == .hydration ? String(format: "%.1f", currentValue) : "\(Int(currentValue))"
    }

    var displayGoal: String {
        type == .hydration ? String(format: "%.1f", goalValue) : "\(Int(goalValue))"
    }

    /// "1.2/2.0", "1/3", …
    var displayRatio: String { "\(displayCurrent)/\(displayGoal)" }
}

#if DEBUG
private struct HabitRingPreviewData {
    static let habits: [WatchHabit] = [
        WatchHabit(type: .hydration, currentValue: 1.4, goalValue: 2.0),
        WatchHabit(type: .caffeine, currentValue: 1, goalValue: 3),
        WatchHabit(type: .sunlight, currentValue: 42, goalValue: 60)
    ]
}

#Preview("Habit rings") {
    HStack(spacing: 12) {
        ForEach(HabitRingPreviewData.habits) { habit in
            HabitRingView(habit: habit)
        }
    }
    .padding()
    .background(WatchV2.canvas)
}
#endif
