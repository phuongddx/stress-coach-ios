import SwiftUI

/// One habit row inside the "Today's habits" group card on the Action tab.
///
/// Layout matches `05-action.html` §6:
/// - Row 1: icon + label w/ source pill ........ value text (mono, tabular-nums)
/// - Row 2: full-width progress bar (3px) toward daily goal
///
/// The whole row is a plain row (no card background/border) — it lives inside
/// an `ActionGroupCard` that provides the shared card chrome and separators.
struct HabitLogRow: View {
    let habit: Habit
    var onTap: (() -> Void)? = nil

    private var progress: Double {
        guard habit.hasDisplayValue, habit.goalValue > 0 else { return 0 }
        return min(1.0, habit.currentValue / habit.goalValue)
    }

    var body: some View {
        Button {
            // Only manual habits respond to a tap to increment.
            guard habit.source == .manual else { return }
            HapticManager.shared.buttonPress()
            onTap?()
        } label: {
            VStack(spacing: 6) {
                // Row 1: icon + label + value
                HStack(spacing: 12) {
                    Image(systemName: habit.type.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(tint)
                        .frame(width: 28, height: 28)

                    HStack(spacing: 6) {
                        Text(habit.type.displayName)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.Wellness.adaptivePrimaryText)
                        SourcePill(source: habit.source, tint: tint)
                    }

                    Spacer(minLength: 0)

                    Text(valueText)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.Wellness.adaptivePrimaryText)
                        .monospacedDigit()
                }
                .frame(minHeight: 44)

                // Row 2: progress bar (only for AUTO habits)
                if showProgressBar {
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(white: 60 / 255, opacity: 0.10))
                            Capsule()
                                .fill(tint)
                                .frame(width: proxy.size.width * progress)
                        }
                    }
                    .frame(height: 3)
                }
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 14)
        }
        .buttonStyle(.plain)
        .disabled(habit.source == .auto)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(habit.type.displayName): \(valueText)")
        .accessibilityHint(habit.source == .manual ? "Double tap to log one unit" : "Auto-tracked from HealthKit")
    }

    private var tint: Color {
        switch habit.type {
        case .hydration: return Color(hex: "#007AFF") // accent-soft blue per HTML
        case .sunlight:  return Color(hex: "#FE9901")  // gold per HTML
        case .caffeine:  return Color.Wellness.adaptiveSecondaryText // LOG uses neutral tint
        }
    }

    /// Show progress bar only for AUTO-tracked habits.
    private var showProgressBar: Bool {
        habit.source == .auto
    }

    /// Value text in "current / goal unit" format matching the HTML reference.
    /// e.g. "1.4 / 2.0 L", "2 / 3 cups", "42 / 60 min". "—" stands in for the
    /// current value of an AUTO habit HealthKit has not reported.
    private var valueText: String {
        let cur = habit.hasDisplayValue ? formatValue(habit.currentValue) : "—"
        let goal = formatValue(habit.goalValue)
        return "\(cur) / \(goal) \(habit.type.unit)"
    }

    /// Hydration shows one decimal (1.4); cups/min are whole numbers (2, 42).
    private func formatValue(_ v: Double) -> String {
        if habit.type == .hydration {
            return String(format: "%.1f", v)
        }
        return "\(Int(v.rounded()))"
    }
}

#Preview("HabitLogRow") {
    ScrollView {
        VStack(spacing: 0) {
            HabitLogRow(habit: Habit(type: .hydration, currentValue: 1.4, goalValue: 2.0, isAutoValueAvailable: true))
            ActionRowDivider()
            HabitLogRow(habit: Habit(type: .caffeine, currentValue: 2, goalValue: 3)) { }
            ActionRowDivider()
            HabitLogRow(habit: Habit(type: .sunlight, goalValue: 60))
        }
        .background(Color.Wellness.adaptiveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    .padding()
    .background(HomeCharacterDesignTokens.homeBackground)
}
