import Foundation

// MARK: - Purchase Availability

/// Single source of truth for whether in-app purchases are offered in this build.
///
/// Mirrors `ChatAvailability`: every purchase entry point reads `current`, so
/// flipping the single case below turns the paywall, the credit balance UI and
/// every upsell on or off without touching call sites.
///
/// Enabled for 1.1: the two StressMonitor Plus subscriptions
/// (`com.stressmonitor.app.plus.monthly`, `com.stressmonitor.app.plus.annual`)
/// exist in App Store Connect. `.postponed` stays as the kill switch: flipping
/// `current` back hides every paywall, upsell and chart lock at once (AC-13).
enum PurchaseAvailability: Sendable, Equatable {
    case enabled
    case postponed(reason: PostponedReason)

    static var current: PurchaseAvailability { .enabled }

    static var isEnabled: Bool { current == .enabled }
}

// MARK: - Postponed Reason

enum PostponedReason: String, Sendable {
    case awaitingAppStoreProducts
}
