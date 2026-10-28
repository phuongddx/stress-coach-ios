import SwiftUI
import SwiftData

// MARK: - ActionView (Light Theme Redesign)
//
// Six sections matching `05-action.html`:
//   1. Header "What helps right now" — stress level + time eyebrow
//   2. Ripple recommendation hero
//   3. Breathe group → BreathingExerciseView
//   4. Move group → MiniWalkView
//   5. Reflect group → Chat sheet
//   6. Today's habits — 3× HabitLogRow (Hydration / Sunlight AUTO, Caffeine LOG)

struct ActionView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var habitViewModel: HabitViewModel?
    @State private var isChatPresented = false

    /// Latest real reading from the shared Home-tab view model. Defaults to
    /// nil (no data) — the header, recommendation card, and chat context all
    /// handle that case.
    var stressResult: StressResult? = nil
    var baseline: PersonalBaseline? = nil

    private var stressLevel: Double? {
        stressResult?.level
    }

    /// True only when Chat is reachable in this build. Compile-time under
    /// `#if DEBUG`, so the Release build elides the enabled branch entirely.
    private var isChatAvailable: Bool {
        ChatAvailability.current.isAvailable
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                sectionHeader
                VStack(spacing: 6) {
                    RippleRecommendationCard(stressLevel: stressLevel) {
                        presentChat()
                    }
                    if !isChatAvailable {
                        Text("AI Coaching arrives in our next update")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }
                }
                breatheGroup
                moveGroup
                reflectGroup
                habitsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(HomeCharacterDesignTokens.homeBackground.ignoresSafeArea())
        .accessibleDynamicType()
        .navigationTitle("Action")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isChatPresented) {
            ChatBottomSheetView(stressResult: stressResult, baseline: baseline)
        }
        .onAppear {
            if habitViewModel == nil {
                habitViewModel = HabitViewModel(modelContext: modelContext)
            } else {
                habitViewModel?.loadToday()
            }
        }
    }

    /// Opens the Chat sheet only when Chat is available in this build;
    /// otherwise no-op. The disabled entry-point presentation is handled
    /// inline by the cards that read `isChatAvailable`.
    private func presentChat() {
        guard isChatAvailable else { return }
        isChatPresented = true
    }

    // MARK: - 1. Header

    private var sectionHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let level = stressLevel {
                let category = StressResult.category(for: level).displayName
                Text("Now · \(category) \(Int(level.rounded())) · \(timeEyebrow)")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(1.0)
                    .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
            } else {
                Text(timeEyebrow.uppercased())
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(1.0)
                    .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
            }

            Text("What helps right now")
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.Wellness.adaptivePrimaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private var timeEyebrow: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: Date())
    }

    // MARK: - 3. Breathe Group

    private var breatheGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            groupLabel("Breathe", hint: "2 min")
            ActionGroupCard {
                ActionGroupRow(
                    icon: "wind",
                    title: "Box Breathing",
                    subtitle: "4-4-4-4 · 2 min",
                    tint: HomeCharacterDesignTokens.Ripple.primary,
                    route: .boxBreathing
                )
            }
        }
    }

    // MARK: - 4. Move Group

    private var moveGroup: some View {
        let seconds = MiniWalkViewModel.defaultDurationSeconds
        let minutes = seconds / 60
        let targetSteps = MiniWalkViewModel.targetSteps(forDurationSeconds: seconds)
        return VStack(alignment: .leading, spacing: 8) {
            groupLabel("Move", hint: "\(minutes) min")
            ActionGroupCard {
                ActionGroupRow(
                    icon: "figure.walk",
                    title: "Mini Walk",
                    subtitle: "\(minutes) min · target \(targetSteps.formatted()) steps",
                    tint: Color(hex: "#34C759"),
                    route: .miniWalk
                )
            }
        }
    }

    // MARK: - 5. Reflect Group

    private var reflectGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            groupLabel("Reflect")
            ActionGroupCard {
                VStack(spacing: 0) {
                    reflectRow(
                        icon: "bubble.left",
                        title: "Talk to Ripple",
                        subtitle: isChatAvailable
                            ? "Process today's stressor"
                            : "Process today's stressor · coming soon",
                        tint: HomeCharacterDesignTokens.Ripple.primary,
                        action: {
                            HapticManager.shared.buttonPress()
                            presentChat()
                        }
                    )
                }
            }
        }
    }

    /// A reflect row — same layout as ActionGroupRow but driven by a Button
    /// (sheet presentation) rather than a NavigationLink push.
    private func reflectRow(
        icon: String,
        title: String,
        subtitle: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.Wellness.adaptivePrimaryText)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: AppIconSystem.Nav.forward.sfSymbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.Wellness.adaptiveSecondaryText.opacity(0.55))
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
        .accessibilityHint("Double tap to open")
    }

    // MARK: - 6. Today's Habits

    private var habitsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            groupLabel("Today's habits", hint: "Tap to log")
            ActionGroupCard {
                VStack(spacing: 0) {
                    ForEach(Array(HabitType.allCases.enumerated()), id: \.element) { idx, type in
                        if idx > 0 { ActionRowDivider() }
                        let habit = habitViewModel?.habit(for: type) ?? Habit(type: type)
                        HabitLogRow(habit: habit) {
                            habitViewModel?.logManual(type)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    /// Group label with optional right-aligned hint — matches HTML `.group-label`.
    @ViewBuilder
    private func groupLabel(_ title: String, hint: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
            Spacer(minLength: 0)
            if let hint = hint {
                Text(hint)
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.Wellness.adaptiveSecondaryText.opacity(0.7))
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 2)
    }
}

// MARK: - Previews

#Preview {
    NavigationStack {
        ActionView(stressResult: StressResult(level: 62, category: .moderate, confidence: 0.9, hrv: 38, heartRate: 78))
            .stressNavigationDestinations()
    }
}

#Preview("No Stress Data") {
    NavigationStack {
        ActionView()
            .stressNavigationDestinations()
    }
}
