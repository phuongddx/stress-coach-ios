import SwiftUI

// MARK: - WatchLoggingView

/// Watch **Logging** screen — daily habit check-in and mood picker.
///
/// Layout:
///  - Title "Today" + date sublabel at the top
///  - 3 habit rings (hydration, caffeine, sunlight) in an HStack
///  - A compact mood picker row with 5 SF Symbol buttons
///
/// All colours and spacing come from `WatchDesignTokens` so this screen
/// reads as a sibling of the Home and History canvases. Habits owned by
/// `WatchHabitViewModel`, mood owned by `WatchMoodViewModel`.
struct WatchLoggingView: View {
    @State private var habitViewModel = WatchHabitViewModel()
    @State private var moodViewModel = WatchMoodViewModel()
    @State private var selectedMood: WatchMood?

    @ScaledMetric(relativeTo: .body) private var bodyScale: CGFloat = 1
    @ScaledMetric(relativeTo: .caption2) private var caption2Scale: CGFloat = 1
    var body: some View {
        ScrollView {
            VStack(spacing: WatchDesignTokens.Spacing.sm) {
                header
                habitsSection
                moodSection
            }
            .padding(.horizontal, WatchDesignTokens.contentSidePadding)
            .padding(.top, 4)
            .padding(.bottom, 12)
        }
        .background(WatchDesignTokens.canvas.ignoresSafeArea())
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { selectedMood = moodViewModel.latest?.mood }
        .task { await habitViewModel.refreshAutoHabits() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Today")
                .font(.system(size: 17 * bodyScale, weight: .bold, design: .rounded))
                .tracking(-0.02 * 17)
                .foregroundStyle(WatchDesignTokens.ink)
            Spacer(minLength: 0)
            Text(headerDate)
                .font(.system(size: 8.5 * caption2Scale, weight: .semibold, design: .monospaced))
                .tracking(0.06 * 8.5)
                .foregroundStyle(WatchDesignTokens.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private var headerDate: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE · MMM d"
        return fmt.string(from: Date()).uppercased()
    }

    // MARK: - Habits

    private var habitsSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("HABITS")
                .font(.system(size: 8.5 * caption2Scale, weight: .semibold, design: .monospaced))
                .tracking(0.06 * 8.5)
                .foregroundStyle(WatchDesignTokens.muted)

            HStack(spacing: WatchDesignTokens.Spacing.xs) {
                ForEach(HabitType.allCases) { type in
                    if let habit = habitViewModel.habit(for: type) {
                        habitCard(habit)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func habitCard(_ habit: WatchHabit) -> some View {
        let isManual = habit.type.source == .manual
        Button {
            if isManual { habitViewModel.logManual(habit.type, amount: 1) }
        } label: {
            VStack(spacing: 4) {
                if habit.hasDisplayValue {
                    HabitRingView(habit: habit, size: 60)
                } else {
                    emptyHabitRing(habit)
                }
                Text(habit.type.displayName.uppercased())
                    .font(.system(size: 7, weight: .semibold, design: .monospaced)) // dated exception 2026-09-05: 3-across habit-card single-word micro-label — cannot wrap
                    .tracking(0.06 * 7)
                    .foregroundStyle(WatchDesignTokens.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7) // dated exception 2026-09-05: 3-across card label cannot wrap; shrink keeps it visible
                if isManual {
                    Text("+1")
                        .font(.system(size: 7.5 * caption2Scale, weight: .semibold, design: .monospaced))
                        .tracking(0.04 * 7.5)
                        .foregroundStyle(Color(hex: "#FE9901"))
                } else {
                    Text("AUTO")
                        .font(.system(size: 7 * caption2Scale, weight: .semibold, design: .monospaced))
                        .tracking(0.04 * 7)
                        .foregroundStyle(WatchDesignTokens.mutedSystem)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: WatchDesignTokens.radiusCard, style: .continuous)
                    .fill(WatchDesignTokens.surface)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isManual)
        .accessibilityLabel(habit.hasDisplayValue
            ? "\(habit.type.displayName), \(habit.currentValue) of \(habit.goalValue) \(habit.type.unit)"
            : "\(habit.type.displayName), no reading yet")
    }

    /// Stand-in for the ring of an AUTO habit HealthKit has not reported.
    private func emptyHabitRing(_ habit: WatchHabit) -> some View {
        let size: CGFloat = 60
        return ZStack {
            Circle()
                .stroke(WatchDesignTokens.separator, lineWidth: max(5, size * 0.085))
            VStack(spacing: 1) {
                Image(systemName: habit.type.icon)
                    .font(.system(size: size * 0.22, weight: .semibold)) // dated exception 2026-09-05: ring geometry — font proportional to ring diameter
                    .foregroundStyle(WatchDesignTokens.ink)
                Text("—")
                    .font(.system(size: size * 0.16, weight: .semibold, design: .rounded)) // dated exception 2026-09-05: ring geometry — font proportional to ring diameter
                    .foregroundStyle(WatchDesignTokens.inkSecondary)
            }
        }
        .frame(width: size, height: size)
    }

    // MARK: - Mood

    private var moodSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("MOOD")
                .font(.system(size: 8.5 * caption2Scale, weight: .semibold, design: .monospaced))
                .tracking(0.06 * 8.5)
                .foregroundStyle(WatchDesignTokens.muted)

            MoodPickerRow(
                selectedMood: $selectedMood,
                onSelected: { mood in moodViewModel.log(mood: mood) }
            )
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        WatchLoggingView()
    }
}
#endif
