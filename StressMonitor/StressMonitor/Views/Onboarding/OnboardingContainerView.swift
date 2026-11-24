import SwiftData
import SwiftUI
import HealthKit

// MARK: - Onboarding Container
// Orchestrates the 3-screen onboarding flow using TabView with PageStyle.
// Screen 0: Welcome, Screen 1: Permissions, Screen 2: Dashboard Preview
struct OnboardingContainerView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var currentScreen = 0
    /// `@AppStorage` (not `@State`) so the view re-renders when account
    /// deletion resets the flag and the app has to fall back to onboarding.
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    /// Lazily-created repository
    @State private var stressRepository: StressRepository?

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                MainTabView()
                    .task {
                        // Request HealthKit permission on app launch if not yet determined
                        await requestHealthKitIfNeeded()
                    }
            } else {
                onboardingContent
            }
        }
        .onAppear {
            if stressRepository == nil {
                stressRepository = StressRepository(modelContext: modelContext)
            }
        }
    }

    // MARK: - HealthKit Permission

    @MainActor
    private func requestHealthKitIfNeeded() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let store = HKHealthStore()
        let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        let status = store.authorizationStatus(for: hrvType)
        // Only request if not yet determined — if denied, the Settings card handles re-prompting
        guard status == .notDetermined else { return }

        let types: Set<HKObjectType> = [
            HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!,
            HKCategoryType(.sleepAnalysis),
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKCharacteristicType(.dateOfBirth),
        ]
        try? await store.requestAuthorization(toShare: [], read: types)
    }

    private var onboardingContent: some View {
        // Screen content — TabView with page style for swipe. Each screen
        // draws its own step dots above its CTA (UI V2 layout).
        TabView(selection: $currentScreen) {
            // Screen 0: Welcome
            OnboardingWelcomeView(
                onGetStarted: { goToScreen(1) },
                onSelectStep: { goToScreen($0) }
            )
            .tag(0)

            // Screen 1: Permissions
            OnboardingHealthSyncView(
                onAuthorize: { goToScreen(2) },
                onBack: { goToScreen(0) },
                onSelectStep: { goToScreen($0) }
            )
            .tag(1)

            // Screen 2: Dashboard Preview
            if let repo = stressRepository {
                OnboardingSuccessView(
                    repository: repo,
                    onGoToDashboard: { finishOnboarding() },
                    onBack: { goToScreen(1) },
                    onSelectStep: { goToScreen($0) }
                )
                .tag(2)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(Color.V2.bg.ignoresSafeArea())
    }

    // MARK: - Helpers

    private func goToScreen(_ index: Int) {
        withAnimation(.easeInOut(duration: 0.35)) {
            currentScreen = index
        }
    }

    private func finishOnboarding() {
        withAnimation(.easeInOut(duration: 0.5)) {
            hasCompletedOnboarding = true
        }
    }
}

#Preview {
    OnboardingContainerView()
        .environment(AppRouter())
        .environment(PaywallController())
        .modelContainer(for: [StressMeasurement.self, CharacterUnlock.self], inMemory: true)
}
