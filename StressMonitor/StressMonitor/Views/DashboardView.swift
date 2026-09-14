import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Environment(PaywallController.self) private var paywall
    @State private var viewModel: StressViewModel
    @Environment(\.scenePhase) private var scenePhase
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
        .background(HomeCharacterDesignTokens.homeBackground.ignoresSafeArea())
        .accessibleDynamicType()
        .alert("Couldn't load health data", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("Try Again") {
                viewModel.clearError()
                Task { await viewModel.loadCurrentStress() }
            }
            Button("Cancel", role: .cancel) {
                viewModel.clearError()
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
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

    // MARK: - Permission Required (HealthKit notDetermined / denied)

    private var permissionStateView: some View {
        ScrollView {
            VStack(spacing: 16) {
                PermissionCardView(
                    permissionType: .healthKit,
                    isLoading: viewModel.isRequestingAccess,
                    onGrantAccess: { Task { await viewModel.requestHealthKitAccess() } }
                )
                .padding(.horizontal, 16)
                .padding(.top, 24)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Reading / Loading Skeleton

    private var readingStateView: some View {
        ScrollView {
            VStack(spacing: 16) {
                NoDataCard(dataType: .stress, onAction: { Task { await viewModel.loadCurrentStress() } })
                    .padding(.horizontal, 16)
                    .padding(.top, 24)

                SkeletonBlock(height: 180)
                    .padding(.horizontal, 16)
                SkeletonBlock(height: 90)
                    .padding(.horizontal, 16)
                SkeletonBlock(height: 90)
                    .padding(.horizontal, 16)
                SkeletonBlock(height: 140)
                    .padding(.horizontal, 16)
            }
            .padding(.bottom, 16)
        }
    }

    // MARK: - Ready Dashboard Content

    private var readyStateView: some View {
        ScrollView {
            LazyVStack(spacing: 22) {
                dashboardContent(viewModel.currentStress)

            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Dashboard Content (9 sections, Home tab)

    @ViewBuilder
    private func dashboardContent(_ stress: StressResult?) -> some View {
        // 1. Date stamp + bio-age / streak chips (compact header, no greeting)
        HomeHeaderBar(
            date: Date(),
            bioAge: viewModel.bioAgeResult?.estimatedAge,
            streakDays: viewModel.todayMeasurements.count
        )
        .opacity(appearAnimation ? 1 : 0)

        // 2. Hero — semicircle gauge + score + Ripple inside + state label
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
                substate: substate(for: stress)
            )
        }
        .buttonStyle(.plain)
        .disabled(stress == nil)
        .accessibilityLabel("View full result")
        .opacity(appearAnimation ? 1 : 0)
        // 2b. Server coach score — daily score computed on the server from
        // uploaded health summaries, under the local reading
        ServerScoreCard()
            .opacity(appearAnimation ? 1 : 0)

        // 3. AI insight — Ripple's voice right under the hero
        if let insight = viewModel.aiInsight {
            RippleInsightCard(insight: insight, onAskRipple: nil)
                .opacity(appearAnimation ? 1 : 0)
        }

        // 4. Vitals triplet — HRV / Heart / Breath (color-coded, trend lines)
        VitalsTriplet(
            hrvValue: stress.map { "\(Int($0.hrv.rounded()))" } ?? "--",
            hrvTrend: hrvTrendLabel(stress),
            hrvTrendGood: viewModel.heartRateTrend != .down,
            hrValue: stress.map { "\(Int($0.heartRate.rounded()))" } ?? "--",
            hrTrend: "resting",
            rrValue: respiratoryDisplayValue(stress),
            rrTrend: stress == nil ? nil : "steady"
        )
        .opacity(appearAnimation ? 1 : 0)

        // 5. Mood check-in chips (Calm / Focused / Tense / Wired / Fried)
        MoodCheckInView(selected: viewModel.mood?.level) { level in
            viewModel.setMood(level)
        }
        .opacity(appearAnimation ? 1 : 0)

        // 6. Health data — Exercise / Sleep / Daylight (behavioral signals)
        HealthDataSection(
            exerciseMinutes: viewModel.todayExerciseMinutes,
            exerciseDelta: "yesterday",
            sleepHours: viewModel.todaySleepHours,
            sleepDelta: sleepDeltaLabel,
            daylightMinutes: viewModel.todayDaylightMinutes,
            daylightDelta: viewModel.todayDaylightMinutes == nil ? nil : "on target"
        )
        .opacity(appearAnimation ? 1 : 0)

        // 7. Quick actions — Box Breathing + Mini Walk (mid-screen)
        QuickActionGrid(first: .boxBreathing, second: .miniWalk)
            .opacity(appearAnimation ? 1 : 0)

        // 8. Stress over time — 7-day bar chart + tier legend
        StressOverTimeChart(
            data: viewModel.weeklyStressPoints,
            onUpgrade: { paywall.present(reason: .trendsLongRange) },
            onOpenHistory: { router.homePath.append(Route.history) }
        )
            .opacity(appearAnimation ? 1 : 0)

        // 9. Premium upsell — frosted glass banner (full-screen paywall)
        Button {
            paywall.present(reason: .general)
        } label: {
            PremiumBanner()
        }
        .buttonStyle(.plain)
        .opacity(appearAnimation ? 1 : 0)
    }

    // MARK: - Derivation helpers

    private func substate(for stress: StressResult?) -> String {
        guard let stress else { return "Waiting for a reading" }
        switch stress.category {
        case .relaxed:   return "Calm · recovered"
        case .mild:      return "Focused · steady"
        case .moderate:  return "Tense · busy"
        case .high:      return "Wired · push back"
        case .severe:    return "Fried · reset now"
        }
    }

    private func hrvTrendLabel(_ stress: StressResult?) -> String? {
        guard stress != nil else { return nil }
        switch viewModel.heartRateTrend {
        case .up:     return "+ vs avg"
        case .down:   return "- vs avg"
        case .stable: return "steady"
        }
    }

    private var sleepDeltaLabel: String? {
        guard viewModel.todaySleepHours != nil else { return nil }
        return "vs avg"
    }

    /// RR display string. Returns "--" when there is no stress result OR when
    /// RR data is unavailable (simulator) so the slot reads as empty, not zero.
    private func respiratoryDisplayValue(_ stress: StressResult?) -> String {
        guard stress != nil, let rr = viewModel.respiratoryRate else { return "--" }
        return String(format: "%.0f", rr.rounded())
    }

    // MARK: - Helpers

    private func loadInitialData() async {
        // Phase 3: Run baseline + dashboard data in parallel
        async let _: () = viewModel.loadBaseline()
        await viewModel.loadDashboardData()
        viewModel.observeHeartRate()

        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
            appearAnimation = true
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
