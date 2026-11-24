import SwiftUI

// MARK: - WatchLoggingView

/// Watch **Logging** screen — daily habit check-in and mood picker.
///
/// Layout:
///  - Title "Today" + date sublabel at the top
///  - 3 habit rings (hydration, caffeine, sunlight) in an HStack
///  - A compact mood picker row with 5 SF Symbol buttons
///
/// UI V2: 44 pt habit rings on `surface` cards, 32 pt mood wells with
/// 44 pt hit areas, text styles throughout. Habits owned by
/// `WatchHabitViewModel`, mood owned by `WatchMoodViewModel`.
struct WatchLoggingView: View {
    @State private var habitViewModel = WatchHabitViewModel()
    @State private var moodViewModel = WatchMoodViewModel()
    @State private var selectedMood: WatchMood?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                header
                habitsSection
                moodSection
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)
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
                .font(.headline)
                .foregroundStyle(WatchV2.ink)
            Spacer(minLength: 0)
            Text(headerDate)
                .font(.caption2)
                .foregroundStyle(WatchV2.ink3)
        }
        .frame(maxWidth: .infinity)
    }

    private var headerDate: String {
        Date().formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    // MARK: - Habits

    private var habitsSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Habits")
                .font(.caption2)
                .foregroundStyle(WatchV2.ink3)

            HStack(spacing: 4) {
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
            VStack(spacing: 2) {
                if habit.hasDisplayValue {
                    HabitRingView(habit: habit)
                } else {
                    emptyHabitRing(habit)
                }
                Text(habit.type.displayName)
                    .font(.caption2)
                    .foregroundStyle(WatchV2.ink2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(habit.hasDisplayValue ? habit.displayRatio : "—")
                    .font(.v2Number(.caption2))
                    .foregroundStyle(WatchV2.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(isManual ? "+1" : "Auto")
                    .font(.caption2.weight(isManual ? .bold : .regular))
                    .foregroundStyle(isManual ? WatchV2.accent : WatchV2.ink3)
            }
            .frame(maxWidth: .infinity, minHeight: WatchV2.minHitTarget)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: WatchV2.radiusCard, style: .continuous)
                    .fill(WatchV2.surface)
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
        let size: CGFloat = 44
        return ZStack {
            Circle()
                .stroke(WatchV2.surface2, lineWidth: max(5, size * 0.085))
            Image(systemName: habit.type.icon)
                .font(.footnote.weight(.semibold))
                .imageScale(.small)
                .foregroundStyle(WatchV2.ink3)
        }
        .frame(width: size, height: size)
    }

    // MARK: - Mood

    private var moodSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("How do you feel?")
                .font(.caption2)
                .foregroundStyle(WatchV2.ink3)

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
