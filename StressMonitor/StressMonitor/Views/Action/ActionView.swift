import SwiftUI
import SwiftData

// MARK: - ActionView (UI V2)
//
// Spec reference: ui-v2-design/screens.js `S.action` (default, no reading,
// chat off). Inset grouped lists on `Color.V2.bg`:
//   1. Header: large "Action" title + "Now · <tier> <score> · <time>"
//   2. Ripple recommendation (tint card)
//   3. Breathe → BreathingExerciseView
//   4. Move → MiniWalkView
//   5. Reflect → Chat sheet ("Coming in the next update" when Chat is off)
//   6. Today's habits: Hydration / Sunlight (Apple Health), Caffeine (stepper)

struct ActionView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var habitViewModel: HabitViewModel?
    @State private var isChatPresented = false

    /// Latest real reading from the shared Home-tab view model. Defaults to
    /// nil (no data) — the header, recommendation card, and chat context all
    /// handle that case.
    var stressResult: StressResult? = nil
    var baseline: PersonalBaseline? = nil
    /// Preview-only override for the Chat-off state. Runtime always reads
    /// `ChatAvailability.current`.
    var chatAvailabilityOverride: Bool? = nil

    private var stressLevel: Double? {
        stressResult?.level
    }

    /// True only when Chat is reachable in this build. Compile-time under
    /// `#if DEBUG`, so the Release build elides the enabled branch entirely.
    private var isChatAvailable: Bool {
        chatAvailabilityOverride ?? ChatAvailability.current.isAvailable
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                nowLine
                RippleRecommendationCard(
                    stressLevel: stressLevel,
                    isChatAvailable: isChatAvailable,
                    onTalkToRipple: { presentChat() }
                )
                breatheGroup
                moveGroup
                reflectGroup
                habitsSection
            }
            .padding(.horizontal, V2Metrics.margin)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .background(Color.V2.bg.ignoresSafeArea())
        .accessibleDynamicType()
        .navigationTitle("Action")
        .navigationBarTitleDisplayMode(.large)
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
    /// otherwise no-op.
    private func presentChat() {
        guard isChatAvailable else { return }
        isChatPresented = true
    }

    // MARK: - 1. Header

    /// "Now · Mild 32 · 9:54 PM" — tier shape + name in the tier colour, the
    /// score in the number font. No reading: "Now · 9:54 PM".
    private var nowLine: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { nowLineParts }
            VStack(alignment: .leading, spacing: 2) { nowLineParts }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Color.V2.ink3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(nowAccessibilityLabel)
    }

    @ViewBuilder
    private var nowLineParts: some View {
        Text("Now")
        if let level = stressLevel {
            let category = StressResult.category(for: level)
            HStack(spacing: 6) {
                Text("·")
                V2TierBadge(category: category)
                Text("\(Int(level.rounded()))")
                    .font(.v2Number(.subheadline, weight: .semibold))
                    .foregroundStyle(category.color)
            }
        }
        Text("· \(timeString)")
    }

    private var nowAccessibilityLabel: String {
        if let level = stressLevel {
            let category = StressResult.category(for: level)
            return "Now. Stress \(category.displayName), \(Int(level.rounded())). \(timeString)"
        }
        return "Now. \(timeString)"
    }

    private var timeString: String {
        Date().formatted(date: .omitted, time: .shortened)
    }

    // MARK: - 3. Breathe Group

    private var breatheGroup: some View {
        VStack(alignment: .leading, spacing: 6) {
            ActionGroupHeader(title: "Breathe")
            ActionGroupCard {
                ActionGroupRow(
                    icon: "wind",
                    title: "Box breathing",
                    subtitle: "4-4-4-4 · 2 min",
                    route: .boxBreathing
                )
                .accessibilityIdentifier("action.boxBreathing")
            }
        }
    }

    // MARK: - 4. Move Group

    private var moveGroup: some View {
        let seconds = MiniWalkViewModel.defaultDurationSeconds
        let minutes = seconds / 60
        let targetSteps = MiniWalkViewModel.targetSteps(forDurationSeconds: seconds)
        return VStack(alignment: .leading, spacing: 6) {
            ActionGroupHeader(title: "Move")
            ActionGroupCard {
                ActionGroupRow(
                    icon: "figure.walk",
                    title: "Mini walk",
                    subtitle: "\(minutes) min · \(targetSteps.formatted()) steps",
                    tint: StressCategory.relaxed.fillColor,
                    iconForeground: StressCategory.relaxed.onFillColor,
                    route: .miniWalk
                )
            }
        }
    }

    // MARK: - 5. Reflect Group

    private var reflectGroup: some View {
        VStack(alignment: .leading, spacing: 6) {
            ActionGroupHeader(title: "Reflect")
            ActionGroupCard {
                if isChatAvailable {
                    Button {
                        HapticManager.shared.buttonPress()
                        presentChat()
                    } label: {
                        ActionRowLabel(
                            icon: "bubble.left",
                            title: "Talk to Ripple",
                            subtitle: "Work through what is on your mind",
                            tint: Color.V2.Companion.lumi,
                            iconForeground: Color.V2.onAccent
                        ) {
                            ActionRowChevron()
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Talk to Ripple. Work through what is on your mind")
                    .accessibilityHint("Double tap to open")
                    .accessibilityIdentifier("action.reflect.talkToRipple")
                } else {
                    ActionRowLabel(
                        icon: "bubble.left",
                        title: "Talk to Ripple",
                        subtitle: "Coming in the next update",
                        tint: Color.V2.surface3,
                        iconForeground: Color.V2.ink3
                    ) {
                        Text("Soon")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.V2.ink2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.V2.surface2))
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Talk to Ripple. Coming in the next update")
                }
            }
        }
    }

    // MARK: - 6. Today's Habits

    private var habitsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            ActionGroupHeader(title: "Today's habits")
            ActionGroupCard {
                VStack(spacing: 0) {
                    ForEach(Array(HabitType.allCases.enumerated()), id: \.element) { idx, type in
                        if idx > 0 { ActionRowDivider() }
                        let habit = habitViewModel?.habit(for: type) ?? Habit(type: type)
                        HabitLogRow(habit: habit) {
                            habitViewModel?.logManual(type)
                        }
                        .onDecrement {
                            // Undo one logged unit; never below zero.
                            guard habit.currentValue >= 1 else { return }
                            habitViewModel?.logManual(type, amount: -1)
                        }
                    }
                }
            }
            ActionGroupFooter(text: "Habits help Ripple spot what moves your score.")
        }
    }
}

// MARK: - Previews

#Preview("Default") {
    NavigationStack {
        ActionView(stressResult: StressResult(level: 32, category: .mild, confidence: 0.9, hrv: 48, heartRate: 68))
            .stressNavigationDestinations()
    }
}

#Preview("No Stress Data") {
    NavigationStack {
        ActionView()
            .stressNavigationDestinations()
    }
}

#Preview("Chat off") {
    NavigationStack {
        ActionView(
            stressResult: StressResult(level: 32, category: .mild, confidence: 0.9, hrv: 48, heartRate: 68),
            chatAvailabilityOverride: false
        )
        .stressNavigationDestinations()
    }
    .preferredColorScheme(.dark)
}
