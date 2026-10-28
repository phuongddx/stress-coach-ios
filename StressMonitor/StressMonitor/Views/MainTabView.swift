import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Environment(PaywallController.self) private var paywall
    /// Single source of the latest reading: the Home dashboard drives it and the
    /// Action tab reads it, so both show the same real result.
    @State private var stressViewModel: StressViewModel?
    // Health-sync consent prompt state. The service is the signal source:
    // a 403 CONSENT_REQUIRED during the foreground upload flips
    // `needsConsent`, and the explanation sheet presents from here — above
    // the whole tab hierarchy, like the paywall.
    @StateObject private var healthSync = HealthSyncService.shared
    @State private var showConsentSheet = false

    // Per-tab navigation restoration (Axiom nav.md Pattern 6). `Route` is
    // Codable, so each path round-trips through `NavigationPath.CodableRepresentation`.
    // Defensive decode in `AppRouter.decodePath` drops corrupt/schema-shifted data.
    @SceneStorage("nav.home")     private var homeData: Data?
    @SceneStorage("nav.action")   private var actionData: Data?
    @SceneStorage("nav.trends")   private var trendsData: Data?
    @SceneStorage("nav.settings") private var settingsData: Data?
    @SceneStorage("nav.selectedTab") private var selectedTabData: Int?
    @State private var didRestore = false

    var body: some View {
        // `@Bindable` projects the environment-owned `PaywallController` so we
        // can drive `.fullScreenCover(item:)` off the singleton's `presentation`.
        @Bindable var paywall = paywall
        TabView(selection: Binding(get: { router.selectedTab }, set: { router.selectedTab = $0 })) {
            Tab(value: TabItem.home) {
                NavigationStack(path: router.binding(for: .home)) {
                    homeView
                        .stressNavigationDestinations()
                }
            } label: {
                Label {
                    Text(TabItem.home.title)
                } icon: {
                    Image(systemName: tabSymbol(for: .home))
                }
            }

            Tab(value: TabItem.action) {
                NavigationStack(path: router.binding(for: .action)) {
                    ActionView(
                        stressResult: stressViewModel?.currentStress,
                        baseline: stressViewModel?.baseline
                    )
                        .stressNavigationDestinations()
                }
            } label: {
                Label {
                    Text(TabItem.action.title)
                } icon: {
                    Image(systemName: tabSymbol(for: .action))
                }
            }

            Tab(value: TabItem.trend) {
                NavigationStack(path: router.binding(for: .trend)) {
                    TrendsView()
                        .stressNavigationDestinations()
                }
            } label: {
                Label {
                    Text(TabItem.trend.title)
                } icon: {
                    Image(systemName: tabSymbol(for: .trend))
                }
            }

            Tab(value: TabItem.settings) {
                NavigationStack(path: router.binding(for: .settings)) {
                    SettingsView()
                        .stressNavigationDestinations()
                }
            } label: {
                Label {
                    Text(TabItem.settings.title)
                } icon: {
                    Image(systemName: tabSymbol(for: .settings))
                }
            }
        }
        .onChange(of: router.selectedTab) {
            HapticManager.shared.buttonPress()
            selectedTabData = router.selectedTab.rawValue
        }
        .onAppear {
            // Mirror the current prompt state on mount: the foreground sync
            // may have flipped `needsConsent` before this view existed
            // (e.g. while onboarding was still up).
            showConsentSheet = healthSync.needsConsent
            if stressViewModel == nil {
                stressViewModel = makeStressViewModel(repository: StressRepository(modelContext: modelContext))
            }
            restoreNavigationIfNeeded()
            // The dashboard loads the shared reading when Home appears; a launch
            // restored onto another tab would otherwise leave Action without one.
            if router.selectedTab != .home, let viewModel = stressViewModel, viewModel.currentStress == nil {
                Task { await viewModel.loadCurrentStress() }
            }
        }
        // Persist on push/pop (counts change). NavigationPath isn't Equatable,
        // but every push/pop changes `.count`, so counts are a sufficient trigger.
        .onChange(of: router.homePath.count)     { homeData     = AppRouter.encodePath(router.homePath) }
        .onChange(of: router.actionPath.count)   { actionData   = AppRouter.encodePath(router.actionPath) }
        .onChange(of: router.trendsPath.count)   { trendsData   = AppRouter.encodePath(router.trendsPath) }
        .onChange(of: router.settingsPath.count) { settingsData = AppRouter.encodePath(router.settingsPath) }
        .overlay(alignment: .topTrailing) {
            #if DEBUG
            if DemoMode.isEnabled {
                DemoModeBannerView()
                    .padding(.trailing, 16)
                    .padding(.top, 8)
            }
            #endif
        }
        // Consent prompt: presents when the upload path discovers missing
        // server-side consent. Transition-driven — "Not Now" leaves
        // `needsConsent` true, so the sheet stays quiet until consent state
        // actually changes again (grant, revoke, or a later 403 episode).
        .sheet(isPresented: $showConsentSheet) {
            HealthConsentView()
        }
        .onChange(of: healthSync.needsConsent) { _, needsConsent in
            showConsentSheet = needsConsent
        }
        // Paywall sits ABOVE the entire TabView (all tabs + their navigation
        // stacks). The controller is owned at the app root and injected via
        // environment so any descendant can call `paywall.present(reason:)`.
        .fullScreenCover(item: $paywall.presentation) { presentation in
            PaywallView(reason: presentation.reason)
        }
    }

    @ViewBuilder
    private var homeView: some View {
        if let viewModel = stressViewModel {
            DashboardView(viewModel: viewModel)
        }
        // Empty until onAppear fills stressViewModel (avoids a throwaway repository on first body eval)
    }

    private func makeStressViewModel(repository: StressRepository) -> StressViewModel {
        #if DEBUG
        if DemoMode.isEnabled {
            return StressViewModel(
                healthKit: SimulatorHealthKitService(),
                algorithm: MultiFactorStressCalculator(),
                repository: repository
            )
        }
        #endif
        return StressViewModel(
            healthKit: HealthKitManager(),
            algorithm: MultiFactorStressCalculator(),
            repository: repository
        )
    }

    /// SF Symbol for a tab, switching to the filled variant when selected.
    private func tabSymbol(for tab: TabItem) -> String {
        router.selectedTab == tab ? tab.sfSymbolActive : tab.sfSymbol
    }

    /// One-shot restore of per-tab navigation paths + selected tab from
    /// `@SceneStorage`. Idempotent guard via `didRestore`. Decoding failures
    /// (corrupt data, schema change) yield an empty path — never a crash.
    private func restoreNavigationIfNeeded() {
        guard !didRestore else { return }
        didRestore = true
        router.homePath = AppRouter.decodePath(homeData)
        router.actionPath = AppRouter.decodePath(actionData)
        router.trendsPath = AppRouter.decodePath(trendsData)
        router.settingsPath = AppRouter.decodePath(settingsData)
        if let raw = selectedTabData, let tab = TabItem(rawValue: raw) {
            router.selectedTab = tab
        }
    }
}

#Preview {
    MainTabView()
        .environment(AppRouter())
        .environment(PaywallController())
        .modelContainer(for: [StressMeasurement.self, CharacterUnlock.self], inMemory: true)
}
