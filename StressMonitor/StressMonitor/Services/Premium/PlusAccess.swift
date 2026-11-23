import Foundation
import Observation

/// Decides whether Plus-only charts are shown blurred.
///
/// A chart locks only when every condition holds (SPEC 6.1):
/// purchases are enabled, the Plus products loaded at least once (so a user
/// is never asked to pay for something the store cannot sell), the user is
/// not on Plus, and any legacy grace period has ended.
///
/// Injected into the view tree next to `PaywallController`:
/// ```swift
/// @Environment(PlusAccess.self) private var plusAccess
/// ```
@MainActor
@Observable
final class PlusAccess {
    static let shared = PlusAccess()

    /// Length of the free chart window for people who onboarded before 1.1
    /// (SPEC 6.9, Q8).
    static let legacyGraceDays = 14

    // MARK: - Storage Keys

    enum Keys {
        static let catalogReady = "plusAccess.catalogReady"
        static let trialAvailable = "plusAccess.trialAvailable"
        static let trialPeriodUnit = "plusAccess.trialPeriodUnit"
        static let legacyGraceUntil = "plusAccess.legacyGraceUntil"
        /// Set on the first 1.1 launch so a user who onboards later is
        /// never mistaken for a 1.0.1 user.
        static let legacyGraceEvaluated = "plusAccess.legacyGraceEvaluated"
    }

    // MARK: - State

    /// The Plus products loaded on the most recent attempt. Persisted so the
    /// charts do not flash unblurred on every launch before the store answers.
    private(set) var catalogReady: Bool {
        didSet { defaults.set(catalogReady, forKey: Keys.catalogReady) }
    }

    /// The annual free trial can still be offered to this Apple ID. Drives
    /// "Try Plus free" versus "Unlock Plus" on locked charts; false until the
    /// store confirms, so a chart never promises a trial that is not there.
    private(set) var trialAvailable: Bool {
        didSet { defaults.set(trialAvailable, forKey: Keys.trialAvailable) }
    }

    /// Trial length from the annual product (e.g. "14-day"), only while the
    /// trial is available. Feeds the Home banner's call to action.
    private(set) var trialPeriodUnit: String? {
        didSet { defaults.set(trialPeriodUnit, forKey: Keys.trialPeriodUnit) }
    }

    /// End of the legacy grace period, or nil when the user has none.
    private(set) var legacyGraceUntil: Date? {
        didSet { defaults.set(legacyGraceUntil, forKey: Keys.legacyGraceUntil) }
    }

    private let premiumState: PremiumState
    private let availability: PurchaseAvailability
    private let defaults: UserDefaults
    private let now: () -> Date

    // MARK: - Init

    init(
        premiumState: PremiumState = .shared,
        availability: PurchaseAvailability = .current,
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init
    ) {
        self.premiumState = premiumState
        self.availability = availability
        self.defaults = defaults
        self.now = now
        self.catalogReady = defaults.bool(forKey: Keys.catalogReady)
        self.trialAvailable = defaults.bool(forKey: Keys.trialAvailable)
        self.trialPeriodUnit = defaults.string(forKey: Keys.trialPeriodUnit)
        self.legacyGraceUntil = defaults.object(forKey: Keys.legacyGraceUntil) as? Date
    }

    // MARK: - Rules

    var isInLegacyGrace: Bool {
        guard let legacyGraceUntil else { return false }
        return now() < legacyGraceUntil
    }

    /// Finished onboarding before 1.1 (the same people who get the grace
    /// window). They never see the onboarding paywall.
    var isLegacyUser: Bool {
        legacyGraceUntil != nil
    }

    var isChartLocked: Bool {
        availability == .enabled
            && catalogReady
            && !premiumState.isPremiumUser
            && !isInLegacyGrace
    }

    // MARK: - Updates

    func markCatalogLoaded(_ ok: Bool) {
        guard catalogReady != ok else { return }
        catalogReady = ok
    }

    func updateTrial(available: Bool, periodUnit: String?) {
        if trialAvailable != available { trialAvailable = available }
        let unit = available ? periodUnit : nil
        if trialPeriodUnit != unit { trialPeriodUnit = unit }
    }

    /// Runs once per install. A user who had already finished onboarding on
    /// the first 1.1 launch came from 1.0.1 and gets the grace window; a new
    /// user has not onboarded yet at that point and gets none.
    func startLegacyGraceIfNeeded(hasCompletedOnboarding: Bool) {
        guard !defaults.bool(forKey: Keys.legacyGraceEvaluated) else { return }
        defaults.set(true, forKey: Keys.legacyGraceEvaluated)
        guard hasCompletedOnboarding else { return }
        legacyGraceUntil = Calendar.current.date(
            byAdding: .day,
            value: Self.legacyGraceDays,
            to: now()
        )
    }
}
