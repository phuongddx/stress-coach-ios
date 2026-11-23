import Foundation

/// Decides whether a new user sees the paywall once, right after onboarding
/// (SPEC Q2). People who onboarded before 1.1 never see it.
enum OnboardingPaywallGate {
    /// UserDefaults key recording that the onboarding paywall was shown.
    static let didShowKey = "didShowOnboardingPaywall"

    static func shouldPresent(
        didShowOnboardingPaywall: Bool,
        isLegacyUser: Bool,
        availability: PurchaseAvailability,
        isPremiumUser: Bool
    ) -> Bool {
        !didShowOnboardingPaywall
            && !isLegacyUser
            && availability == .enabled
            && !isPremiumUser
    }
}
