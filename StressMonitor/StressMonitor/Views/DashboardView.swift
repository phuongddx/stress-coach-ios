import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Environment(PaywallController.self) private var paywall
    @Environment(PlusAccess.self) private var injectedPlusAccess: PlusAccess?
    @State private var viewModel: StressViewModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var appeared = false
    @State private var appearAnimation = false

    init(viewModel: StressViewModel? = nil, repository: StressRepository? = nil) {
        if let viewModel = viewModel {
            _viewModel = State(initialValue: viewModel)
        } else if let repository = repository {
            _viewModel = State(initialValue: StressViewModel(
                healthKit: HealthKitManager(),
                algorithm: MultiFactorStressCalculator(),
                repository: repository
            ))
        } else {
            _viewModel = State(initialValue: StressViewModel(
                healthKit: HealthKitManager(),
                algorithm: MultiFactorStressCalculator(),
                repository: StressRepository(modelContext: ModelContext((try? ModelContainer(for: StressMeasurement.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))!))
            ))
        }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if viewModel.isPermissionRequired {
                permissionStateView
            } else if viewModel.isLoading && viewModel.currentStress == nil {
                readingStateView
            } else {
                readyStateView
            }
        }
        .background(Color.V2.bg.ignoresSafeArea())
        .accessibleDynamicType()
        .task {
            if !appeared {
                appeared = true
                // Load custom fonts in background — accepted trade-off: <200ms font flash on cold start only
                // Task {} (not Task.detached) — FontBlaster inferred MainActor in Swift 6 mode
                Task(priority: .utility) {
                    FontBlaster.blast()
                }
                // Show skeleton immediately, load data async
                await loadInitialData()
                viewModel.startAutoRefresh()
            }
        }
        .onDisappear {
            viewModel.stopAutoRefresh()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && viewModel.isPermissionRequired {
                Task { await viewModel.loadCurrentStress() }
            }
        }
    }

    // MARK: - Inline error

    /// Load failures show inline at the top of Home (V2 error card) rather
    /// than in a modal alert. Same actions: retry reloads, dismiss clears.
    @ViewBuilder
    private var errorBanner: some View {
        if let error = viewModel.errorMessage {
            V2ErrorCard(
                title: "Couldn't load health data",
                message: error,
                onRetry: {
                    viewModel.clearError()
                    Task { await viewModel.loadCurrentStress() }
                },
                onDismiss: { viewModel.clearError() }
            )
        }
    }

    private var header: some View {
        HomeHeaderBar(
            date: Date(),
            bioAge: viewModel.bioAgeResult?.estimatedAge,
            streakDays: viewModel.streakDays
        )
    }

    // MARK: - Permission Required (HealthKit notDetermined / denied)

    private var permissionStateView: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                errorBanner
                PermissionCardView(
                    permissionType: .healthKit,
                    isLoading: viewModel.isRequestingAccess,
                    onGrantAccess: { Task { await viewModel.requestHealthKitAccess() } }
                )
                disclaimer
            }
            .padding(.horizontal, V2Metrics.margin)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Reading / Loading Skeleton

    private var readingStateView: some View {
        ScrollView {
            VStack(spacing: 12) {
                header
                errorBanner
                V2Card {
                    VStack(spacing: 12) {
                        V2Skeleton(width: 170, height: 170, cornerRadius: 85)
                        V2Skeleton(width: 120, height: 14)
                    }
                    .frame(maxWidth: .infinity)
                }
                SkeletonBlock(height: 84)
                HStack(spacing: 8) {
                    SkeletonBlock(height: 76)
                    SkeletonBlock(height: 76)
                    SkeletonBlock(height: 76)
                }
                SkeletonBlock(height: 150)
                Text("Reading Apple Health…")
                    .font(.footnote)
                    .foregroundStyle(Color.V2.ink3)
                    .padding(.top, 4)
                    .accessibilityAddTraits(.updatesFrequently)
            }
            .padding(.horizontal, V2Metrics.margin)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Ready Dashboard Content

    private var readyStateView: some View {
        Group {
            switch DuoLayout.mode(for: horizontalSizeClass) {
            case .singleColumn:
                ScrollView {
                    LazyVStack(spacing: 16) {
                        dashboardContent(viewModel.currentStress)
                    }
                    .padding(.horizontal, V2Metrics.margin)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(DuoLayoutID.singleColumn)
            case .twoColumns:
                // iPhone Duo inner display: today on the left of the fold,
                // the week and quick resets on the right.
                FoldAwareSplit {
                    dashboardColumn { summaryContent(viewModel.currentStress) }
                } trailing: {
                    dashboardColumn { weekContent }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(DuoLayoutID.twoColumns)
            }
        }
    }

    private func dashboardColumn<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                content()
            }
            .padding(.horizontal, V2Metrics.margin)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Dashboard Content (Home tab)

    /// One column (phones, the Duo outer display): the original order.
    @ViewBuilder
    private func dashboardContent(_ stress: StressResult?) -> some View {
        todayContent(stress)
        moodCheckIn
        healthData
        quickReset
        stressOverTime
        premiumUpsell
        disclaimer
            .padding(.top, 8)
    }

    /// Left column in two columns: today's reading and signals.
    @ViewBuilder
    private func summaryContent(_ stress: StressResult?) -> some View {
        todayContent(stress)
        healthData
    }

    /// Right column in two columns: the week, quick resets and check-in.
    @ViewBuilder
    private var weekContent: some View {
        stressOverTime
        quickReset
        moodCheckIn
        premiumUpsell
        disclaimer
            .padding(.top, 8)
    }

    @ViewBuilder
    private func todayContent(_ stress: StressResult?) -> some View {
        // 1. Date + bio-age / streak tags, then the greeting
        header
            .opacity(appearAnimation ? 1 : 0)

        // 1b. Load error, inline
        errorBanner

        // 2. Hero — V2 gauge + Ripple in the gauge opening + substate/tags
        Button {
            guard let stress else { return }
            HapticManager.shared.buttonPress()
            router.homePath.append(Route.measurementResult(stress))
        } label: {
            StressHeroCard(
                level: stress?.level ?? 0,
                category: stress?.category ?? .relaxed,
                confidence: stress?.confidence,
                measuredAt: viewModel.lastRefresh,
                substate: substate(for: stress),
                factorCount: factorCount(for: stress)
            )
        }
        .buttonStyle(HeroCardButtonStyle())
        .disabled(stress == nil)
        .accessibilityLabel("View full result")
        // Sits outside the card's Button so the two taps never nest: the card
        // opens the reading, this opens the research behind the score.
        .overlay(alignment: .topTrailing) {
            ScienceInfoButton(topic: .stressScore) { topic in
                router.homePath.append(Route.scienceSources(topic: topic))
            }
            .padding(.trailing, 8)
            .padding(.top, 6)
        }
        .opacity(appearAnimation ? 1 : 0)

        // 3. AI insight — Ripple's voice right under the hero
        if let insight = viewModel.aiInsight {
            RippleInsightCard(insight: insight, onAskRipple: nil, generatedAt: stress?.timestamp)
                .opacity(appearAnimation ? 1 : 0)
        }

        // 4. Vitals — HRV / Heart / Breath tiles
        VitalsTriplet(
            hrvValue: stress.map { "\(Int($0.hrv.rounded()))" } ?? "—",
            hrvTrend: deltaLabel(viewModel.hrvDeltaVsWeeklyAverage),
            hrvTrendGood: (viewModel.hrvDeltaVsWeeklyAverage ?? 0) > 0,
            hrValue: heartRateDisplayValue(stress),
            hrTrend: deltaLabel(viewModel.heartRateDeltaVsWeeklyAverage),
            rrValue: respiratoryDisplayValue(stress)
        )
        .opacity(appearAnimation ? 1 : 0)

        // 4b. Server coach score — daily score computed on the server from
        // uploaded health summaries
        ServerScoreCard()
            .opacity(appearAnimation ? 1 : 0)

    }

    private var moodCheckIn: some View {
        // 5. Mood check-in (Calm / Focused / Tense / Wired / Fried)
        MoodCheckInView(selected: viewModel.mood?.level) { level in
            viewModel.setMood(level)
        }
        .padding(.top, 8)
        .opacity(appearAnimation ? 1 : 0)

    }

    private var healthData: some View {
        // 6. Health data — Exercise / Sleep / Daylight (behavioral signals)
        HealthDataSection(
            exerciseMinutes: viewModel.lastWorkoutMinutes,
            exerciseDelta: workoutDayLabel,
            sleepHours: viewModel.todaySleepHours,
            daylightMinutes: viewModel.todayDaylightMinutes
        )
        .opacity(appearAnimation ? 1 : 0)

    }

    private var quickReset: some View {
        // 7. Quick reset — Box Breathing + Mini Walk
        QuickActionGrid(first: .boxBreathing, second: .miniWalk)
            .padding(.top, 8)
            .opacity(appearAnimation ? 1 : 0)

    }

    private var stressOverTime: some View {
        // 8. Stress over time — 7-day bar chart + tier legend. The section
        // header (with the History link) stays outside the Plus lock.
        VStack(alignment: .leading, spacing: 8) {
            V2SectionHeader(title: "Stress over time", actionTitle: "History") {
                HapticManager.shared.buttonPress()
                router.homePath.append(Route.history)
            }
            StressOverTimeChart(data: viewModel.weeklyStressPoints)
                .plusLocked(.homeStressOverTime)
        }
        .padding(.top, 8)
        .opacity(appearAnimation ? 1 : 0)

    }

    @ViewBuilder
    private var premiumUpsell: some View {
        // 9. Premium upsell (full-screen paywall).
        // Hidden while purchases are postponed, so the dashboard never
        // references purchasable content. Plus members never see it.
        if PurchaseAvailability.isEnabled && !PremiumState.shared.isPremiumUser {
            Button {
                paywall.present(reason: .general)
            } label: {
                PremiumBanner(trialPeriodUnit: (injectedPlusAccess ?? .shared).trialPeriodUnit)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            .opacity(appearAnimation ? 1 : 0)
        }

    }

    private var disclaimer: some View {
        Text("Stress AI Coach is a wellness app, not a medical device. It does not diagnose or treat any condition.")
            .font(.caption)
            .foregroundStyle(Color.V2.ink3)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
    }

    // MARK: - Derivation helpers

    private func substate(for stress: StressResult?) -> String {
        stress?.category.v2Substate ?? "Waiting for a reading"
    }

    private func deltaLabel(_ delta: Int?) -> String? {
        guard let delta else { return nil }
        if delta == 0 { return "on avg" }
        return "\(delta > 0 ? "+" : "")\(delta) vs avg"
    }

    private func factorCount(for stress: StressResult?) -> Int? {
        guard let stress else { return nil }
        guard let breakdown = stress.factorBreakdown else { return 2 }
        return [
            breakdown.hrvComponent,
            breakdown.hrComponent,
            breakdown.sleepComponent,
            breakdown.activityComponent,
            breakdown.recoveryComponent
        ].compactMap { $0 }.count
    }

    /// A heart rate of 0 means the reading had no heart-rate sample.
    private func heartRateDisplayValue(_ stress: StressResult?) -> String {
        guard let stress, stress.heartRate > 0 else { return "—" }
        return "\(Int(stress.heartRate.rounded()))"
    }

    private var workoutDayLabel: String? {
        guard viewModel.lastWorkoutMinutes != nil, let end = viewModel.lastWorkoutEndDate else { return nil }
        let calendar = Calendar.current
        if calendar.isDateInToday(end) { return "today" }
        if calendar.isDateInYesterday(end) { return "yesterday" }
        return nil
    }

    /// RR display string. Returns "—" when there is no stress result OR when
    /// RR data is unavailable (simulator) so the slot reads as empty, not zero.
    private func respiratoryDisplayValue(_ stress: StressResult?) -> String {
        guard stress != nil, let rr = viewModel.respiratoryRate else { return "—" }
        return String(format: "%.0f", rr.rounded())
    }

    // MARK: - Helpers

    private func loadInitialData() async {
        // Phase 3: Run baseline + dashboard data in parallel
        async let _: () = viewModel.loadBaseline()
        await viewModel.loadDashboardData()
        viewModel.observeHeartRate()

        if reduceMotion {
            appearAnimation = true
        } else {
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                appearAnimation = true
            }
        }
    }
}

// MARK: - Previews

#Preview("Dashboard - With Mock Data") {
    let viewModel = PreviewDataFactory.mockDashboardViewModel()
    NavigationStack {
        DashboardView(viewModel: viewModel)
            .stressNavigationDestinations()
    }
    .environment(PaywallController())
}

#Preview("Dashboard - No Data") {
    NavigationStack {
        DashboardView(repository: StressRepository(modelContext: ModelContext((try? ModelContainer(for: StressMeasurement.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))!)))
            .stressNavigationDestinations()
    }
    .environment(PaywallController())
}

#Preview("Dashboard - Dark Mode") {
    let viewModel = PreviewDataFactory.mockDashboardViewModel()
    NavigationStack {
        DashboardView(viewModel: viewModel)
            .stressNavigationDestinations()
    }
    .environment(PaywallController())
    .preferredColorScheme(.dark)
}

/// Hero card tap style: a light press dim, and no disabled fade, so the
/// no-reading card keeps full contrast while it can't be opened.
private struct HeroCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}
