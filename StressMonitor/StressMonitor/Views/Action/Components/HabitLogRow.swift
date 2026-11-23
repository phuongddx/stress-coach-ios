import SwiftUI

/// One habit row inside the "Today's habits" group (UI V2).
///
/// Soft icon tile, habit name, value line ("2 / 3 cups"), and:
/// - LOG habits (caffeine): a −/+ stepper with 44 pt targets. `+` calls
///   `onTap`; `−` shows only when the caller adds `.onDecrement(_:)`.
/// - AUTO habits (hydration, sunlight): a lime progress bar toward the goal
///   and an "Apple Health" source line; no stepper.
///
/// Lives inside an `ActionGroupCard`, which provides the card chrome.
/// Spec reference: ui-v2-design/screens.js `S.action` habits, v2.css `.stepper`.
struct HabitLogRow: View {
    let habit: Habit
    var onTap: (() -> Void)?
    private var decrementAction: (() -> Void)?

    init(habit: Habit, onTap: (() -> Void)? = nil) {
        self.habit = habit
        self.onTap = onTap
    }

    /// Adds the `−` half of the stepper (LOG habits only).
    func onDecrement(_ action: @escaping () -> Void) -> HabitLogRow {
        var copy = self
        copy.decrementAction = action
        return copy
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var tileSize: CGFloat = 30

    private var isManual: Bool { habit.source == .manual }

    private var progress: Double {
        guard habit.hasDisplayValue, habit.goalValue > 0 else { return 0 }
        return min(1.0, habit.currentValue / habit.goalValue)
    }

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 12))

        layout {
            HStack(spacing: 12) {
                ActionIconTile(
                    icon: habit.type.icon,
                    tint: Color.V2.accentSoft,
                    foreground: Color.V2.accent,
                    size: tileSize
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.type.displayName)
                        .font(.body)
                        .foregroundStyle(Color.V2.ink)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(Color.V2.ink3)
                        .monospacedDigit()
                    if !isManual {
                        progressBar
                    }
                }
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if isManual {
                stepper
                    .padding(.leading, dynamicTypeSize.isAccessibilitySize ? tileSize + 12 : 0)
            }
        }
        .padding(.horizontal, V2Metrics.margin)
        .padding(.vertical, 4)
        .frame(minHeight: V2Metrics.minTouchTarget)
        .accessibilityElement(children: isManual ? .ignore : .combine)
        .accessibilityLabel("\(habit.type.displayName): \(valueText)")
        .accessibilityHint(isManual ? "Swipe up or down to log" : "Auto-tracked from HealthKit")
        .modifier(HabitAdjustableAction(isEnabled: isManual, increment: increment, decrement: decrementIfAllowed))
    }

    // MARK: - Stepper

    private var canDecrement: Bool {
        decrementAction != nil && habit.currentValue >= 1
    }

    private var stepper: some View {
        HStack(spacing: 0) {
            if decrementAction != nil {
                stepperButton(symbol: "minus", label: "Less", action: decrementIfAllowed)
                    .disabled(!canDecrement)
                Rectangle()
                    .fill(Color.V2.line)
                    .frame(width: 0.5, height: 18)
                    .accessibilityHidden(true)
            }
            stepperButton(symbol: "plus", label: "More", action: increment)
                .disabled(onTap == nil)
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.V2.surface2)
                .frame(height: 36)
        )
    }

    private func stepperButton(symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.V2.ink2)
                .frame(width: V2Metrics.minTouchTarget, height: V2Metrics.minTouchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(HabitStepperButtonStyle())
        .accessibilityLabel("\(label) \(habit.type.displayName)")
    }

    private func increment() {
        guard isManual, let onTap else { return }
        HapticManager.shared.buttonPress()
        onTap()
    }

    private func decrementIfAllowed() {
        guard isManual, canDecrement, let decrementAction else { return }
        HapticManager.shared.buttonPress()
        decrementAction()
    }

    // MARK: - Auto progress

    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.V2.surface2)
                Capsule()
                    .fill(Color.V2.lime)
                    .frame(width: proxy.size.width * progress)
            }
        }
        .frame(height: 4)
        .frame(maxWidth: 160)
        .accessibilityHidden(true)
    }

    // MARK: - Copy

    private var subtitle: String {
        isManual ? valueText : "\(valueText) · Apple Health"
    }

    /// "current / goal unit", e.g. "1.4 / 2.0 L", "2 / 3 cups", "42 / 60 min".
    /// "—" stands in for the current value of an AUTO habit HealthKit has not
    /// reported.
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

/// VoiceOver adjustable action for LOG habits (swipe up = log one more).
private struct HabitAdjustableAction: ViewModifier {
    let isEnabled: Bool
    let increment: () -> Void
    let decrement: () -> Void

    func body(content: Content) -> some View {
        if isEnabled {
            content.accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: increment()
                case .decrement: decrement()
                @unknown default: break
                }
            }
        } else {
            content
        }
    }
}

/// Dims a stepper half while pressed or disabled; no scale.
private struct HabitStepperButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isEnabled ? (configuration.isPressed ? 0.5 : 1) : 0.38)
    }
}

#Preview("HabitLogRow") {
    ScrollView {
        ActionGroupCard {
            VStack(spacing: 0) {
                HabitLogRow(habit: Habit(type: .hydration, currentValue: 1.4, goalValue: 2.0, isAutoValueAvailable: true))
                ActionRowDivider()
                HabitLogRow(habit: Habit(type: .caffeine, currentValue: 2, goalValue: 3)) {}
                    .onDecrement {}
                ActionRowDivider()
                HabitLogRow(habit: Habit(type: .sunlight, goalValue: 60))
            }
        }
        .padding()
    }
    .background(Color.V2.bg)
}
