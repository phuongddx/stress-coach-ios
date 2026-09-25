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
        ]
        try? await store.requestAuthorization(toShare: [], read: types)
    }

    private var onboardingContent: some View {
        ZStack(alignment: .top) {
            // Progress dots navigation at top
            progressDots
                .padding(.top, 16)
                .zIndex(1)

            // Screen content — TabView with page style for swipe
            TabView(selection: $currentScreen) {
                // Screen 0: Welcome
                OnboardingWelcomeView(onGetStarted: { goToScreen(1) })
                    .tag(0)

                // Screen 1: Permissions
                OnboardingHealthSyncView(
                    onAuthorize: { goToScreen(2) },
                    onBack: { goToScreen(0) }
                )
                .tag(1)

                // Screen 2: Dashboard Preview
                if let repo = stressRepository {
                    OnboardingSuccessView(
                        repository: repo,
                        onGoToDashboard: { finishOnboarding() },
                        onBack: { goToScreen(1) }
                    )
                    .tag(2)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
        }
        .background(HomeCharacterDesignTokens.darkCanvas)
    }

    // MARK: - Progress Dots

    private var progressDots: some View {
        HStack(spacing: 10) {
            // Dot 1
            navDot(index: 0, label: "1")

            // Line 1→2
            navLine(filled: currentScreen >= 1)

            // Dot 2
            navDot(index: 1, label: "2")

            // Line 2→3
            navLine(filled: currentScreen >= 2)

            // Dot 3
            navDot(index: 2, label: "3")

            // Screen label
            Text(screenLabel)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(HomeCharacterDesignTokens.mutedInk)
                .kerning(0.5)
                .padding(.leading, 12)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            HomeCharacterDesignTokens.darkCanvas.opacity(0.92)
                .background(.ultraThinMaterial)
        )
    }

    private func navDot(index: Int, label: String) -> some View {
        Button(action: { goToScreen(index) }) {
            ZStack {
                Circle()
                    .stroke(borderColor(for: index), lineWidth: 2)
                    .background(
                        Circle()
                            .fill(backgroundColor(for: index))
                    )
                    .frame(width: 32, height: 32)

                Text(label)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(textColor(for: index))
            }
        }
        .disabled(index > currentScreen + 1) // Can't skip ahead
    }

    private func navLine(filled: Bool) -> some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(filled ? HomeCharacterDesignTokens.Blossom.primary : Color.white.opacity(0.06))
            .frame(width: 40, height: 2)
            .animation(.easeInOut(duration: 0.35), value: filled)
    }

    // MARK: - Helpers

    private var screenLabel: String {
        switch currentScreen {
        case 0: return "Welcome"
        case 1: return "Permissions"
        case 2: return "Dashboard"
        default: return ""
        }
    }

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

    private func borderColor(for index: Int) -> Color {
        if index == currentScreen {
            return HomeCharacterDesignTokens.Ripple.primary
        } else if index < currentScreen {
            return HomeCharacterDesignTokens.Blossom.primary
        }
        return HomeCharacterDesignTokens.mutedInk
    }

    private func backgroundColor(for index: Int) -> Color {
        if index == currentScreen {
            return HomeCharacterDesignTokens.Ripple.primary
        } else if index < currentScreen {
            return HomeCharacterDesignTokens.Blossom.primary
        }
        return .clear
    }

    private func textColor(for index: Int) -> Color {
        if index <= currentScreen {
            return HomeCharacterDesignTokens.darkCanvas
        }
        return HomeCharacterDesignTokens.mutedInk
    }
}

#Preview {
    OnboardingContainerView()
        .environment(AppRouter())
        .environment(PaywallController())
        .modelContainer(for: [StressMeasurement.self, CharacterUnlock.self], inMemory: true)
}
