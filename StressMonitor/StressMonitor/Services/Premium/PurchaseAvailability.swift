import Foundation

// MARK: - Purchase Availability

/// Single source of truth for whether in-app purchases are offered in this build.
///
/// Mirrors `ChatAvailability`: every purchase entry point reads `current`, so
/// flipping the single case below turns the paywall, the credit balance UI and
/// every upsell on or off without touching call sites.
///
/// Postponed for 1.0.1 (App Review submission 2292ae85, Guideline 2.1(b)): the
/// credit consumables were never created in App Store Connect and the three
/// subscriptions were never attached to a review submission, so the app must
/// not reference purchasable content. Flip to `.enabled` only once all five
/// products exist, carry App Review screenshots, and are attached to the
/// version submission.
enum PurchaseAvailability: Sendable, Equatable {
    case enabled
    case postponed(reason: PostponedReason)

    static var current: PurchaseAvailability { .postponed(reason: .awaitingAppStoreProducts) }

    static var isEnabled: Bool { current == .enabled }
}

// MARK: - Postponed Reason

enum PostponedReason: String, Sendable {
    case awaitingAppStoreProducts
}
