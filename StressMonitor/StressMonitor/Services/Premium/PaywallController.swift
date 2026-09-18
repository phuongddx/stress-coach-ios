import Foundation
import Observation

/// Why the paywall is being shown. Drives analytics (and, later, per-reason
/// header copy). Keep cases coarse and meaningful.
enum PaywallReason: Hashable {
    case general
    case trendsLongRange
    case bioAgeDetail
    case characters
    case breathingAdvanced
    case feature(named: String)
    /// A chat send was rejected with HTTP 402 INSUFFICIENT_CREDITS. A
    /// server-side premium user never receives 402, so this reason presents
    /// regardless of local premium state — see `present(reason:)`.
    case outOfCredits
}

/// Identifiable presentation envelope so `.fullScreenCover(item:)` can drive
/// off a single value instead of a raw boolean.
struct PaywallPresentation: Identifiable, Hashable {
    let id = UUID()
    let reason: PaywallReason
}

/// Single source of truth for presenting the paywall **full-screen, from
/// anywhere in the app**.
///
/// Mounted once at the app root (see `StressMonitorApp`):
/// ```swift
/// .fullScreenCover(item: paywall.presentationBinding) { presentation in
///     PaywallView(reason: presentation.reason)
/// }
/// ```
/// Any view — inside a tab, inside a sheet, a locked-feature overlay, a
/// notification handler — can present the paywall with:
/// ```swift
/// @Environment(PaywallController.self) private var paywall
/// paywall.present(reason: .trendsLongRange)
/// ```
///
/// `present(_:)` is a no-op when the user is already premium (decision: never
/// show the paywall to an unlocked user).
@MainActor
@Observable
final class PaywallController {
    /// The active presentation, or `nil` when dismissed. Settable so the root
    /// `.fullScreenCover(item:)` binding can write `nil` on dismiss; use
    /// `present(reason:)` to show (it enforces the premium guard).
    var presentation: PaywallPresentation?

    /// Premium status consulted by the no-op guard. Injectable for tests.
    private let premiumState: PremiumState

    /// Whether purchases are offered at all. Injectable so tests can pin the
    /// enabled-path guard semantics while the shipping build stays postponed.
    private let availability: PurchaseAvailability

    init(premiumState: PremiumState = .shared, availability: PurchaseAvailability = .current) {
        self.premiumState = premiumState
        self.availability = availability
    }

    /// Present the paywall full-screen for `reason`.
    ///
    /// No-ops entirely while `PurchaseAvailability` is postponed — the single
    /// choke point that keeps every purchase path off-screen.
    ///
    /// No-ops when the user already has premium — except for `.outOfCredits`:
    /// the backend never 402s a server-side premium subscriber, so a 402
    /// reaching the client means the server does not consider this user
    /// premium, and the resubscribe/buy-credits paywall is exactly the path
    /// they need (a locally-premium user hitting 402 is in a divergence
    /// state; suppressing the paywall would leave a dead-end error string).
    func present(reason: PaywallReason) {
        guard availability == .enabled else { return }
        if reason != .outOfCredits {
            guard !premiumState.isPremiumUser else { return }
        }
        presentation = PaywallPresentation(reason: reason)
    }

    /// Dismiss the paywall.
    func dismiss() {
        presentation = nil
    }
}
