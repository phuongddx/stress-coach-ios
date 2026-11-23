import Foundation
import Testing
@testable import StressMonitor

// MARK: - OnboardingPaywallGateTests

struct OnboardingPaywallGateTests {

    private static let postponed = PurchaseAvailability.postponed(reason: .awaitingAppStoreProducts)

    @Test("A new free user sees the paywall once after onboarding")
    func newUserSeesPaywall() {
        #expect(OnboardingPaywallGate.shouldPresent(
            didShowOnboardingPaywall: false, isLegacyUser: false, availability: .enabled, isPremiumUser: false
        ))
    }

    @Test("A 1.0.1 user never sees the onboarding paywall")
    func legacyUserSkipped() {
        #expect(!OnboardingPaywallGate.shouldPresent(
            didShowOnboardingPaywall: false, isLegacyUser: true, availability: .enabled, isPremiumUser: false
        ))
    }

    @Test("Already shown once: not shown again")
    func shownOnlyOnce() {
        #expect(!OnboardingPaywallGate.shouldPresent(
            didShowOnboardingPaywall: true, isLegacyUser: false, availability: .enabled, isPremiumUser: false
        ))
    }

    @Test("A Plus member is not asked to buy Plus")
    func premiumSkipped() {
        #expect(!OnboardingPaywallGate.shouldPresent(
            didShowOnboardingPaywall: false, isLegacyUser: false, availability: .enabled, isPremiumUser: true
        ))
    }

    @Test("Nothing shows while purchases are postponed")
    func postponedSkipped() {
        #expect(!OnboardingPaywallGate.shouldPresent(
            didShowOnboardingPaywall: false, isLegacyUser: false, availability: Self.postponed, isPremiumUser: false
        ))
    }

    @Test("Legacy status follows the grace decision")
    @MainActor
    func legacyFollowsGrace() {
        let name = "OnboardingGate.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        let premium = PremiumState(defaults: defaults, key: "isPremiumUser")

        let legacy = PlusAccess(premiumState: premium, availability: .enabled, defaults: defaults)
        legacy.startLegacyGraceIfNeeded(hasCompletedOnboarding: true)
        #expect(legacy.isLegacyUser)

        let freshName = "OnboardingGate.\(UUID().uuidString)"
        let freshDefaults = UserDefaults(suiteName: freshName) ?? .standard
        let newcomer = PlusAccess(premiumState: premium, availability: .enabled, defaults: freshDefaults)
        newcomer.startLegacyGraceIfNeeded(hasCompletedOnboarding: false)
        #expect(!newcomer.isLegacyUser)
    }
}
