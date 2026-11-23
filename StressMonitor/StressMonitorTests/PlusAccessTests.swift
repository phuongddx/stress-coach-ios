import Foundation
import Testing
@testable import StressMonitor

// MARK: - Helpers

@MainActor
private func makeDefaults() -> UserDefaults {
    let name = "PlusAccessTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name) ?? .standard
    defaults.removePersistentDomain(forName: name)
    return defaults
}

@MainActor
private func makePremiumState(_ isPremium: Bool, defaults: UserDefaults) -> PremiumState {
    let state = PremiumState(defaults: defaults, key: "isPremiumUser")
    state.isPremiumUser = isPremium
    return state
}

/// Mutable clock so a test can move time forward after setup.
@MainActor
private final class FakeClock {
    var current: Date
    init(_ start: Date) { current = start }
}

// MARK: - PlusAccessTests

@MainActor
struct PlusAccessTests {

    @Test("Charts lock only when enabled, catalog loaded and not Plus")
    func lockTable() {
        var lockedCells = 0
        for availability in [PurchaseAvailability.enabled, .postponed(reason: .awaitingAppStoreProducts)] {
            for catalogReady in [false, true] {
                for isPremium in [false, true] {
                    let defaults = makeDefaults()
                    let access = PlusAccess(
                        premiumState: makePremiumState(isPremium, defaults: defaults),
                        availability: availability,
                        defaults: defaults
                    )
                    access.markCatalogLoaded(catalogReady)

                    let expected = availability == .enabled && catalogReady && !isPremium
                    #expect(access.isChartLocked == expected)
                    if access.isChartLocked { lockedCells += 1 }
                }
            }
        }
        #expect(lockedCells == 1)
    }

    @Test("catalogReady survives a fresh instance on the same defaults")
    func catalogReadyPersists() {
        let defaults = makeDefaults()
        let premium = makePremiumState(false, defaults: defaults)
        let first = PlusAccess(premiumState: premium, availability: .enabled, defaults: defaults)
        #expect(first.catalogReady == false)
        first.markCatalogLoaded(true)

        let second = PlusAccess(premiumState: premium, availability: .enabled, defaults: defaults)
        #expect(second.catalogReady)
        #expect(second.isChartLocked)

        second.markCatalogLoaded(false)
        let third = PlusAccess(premiumState: premium, availability: .enabled, defaults: defaults)
        #expect(third.catalogReady == false)
        #expect(third.isChartLocked == false)
    }

    @Test("A 1.0.1 user keeps charts for 14 days, then they lock")
    func legacyGraceExpires() throws {
        let defaults = makeDefaults()
        let clock = FakeClock(Date(timeIntervalSince1970: 1_800_000_000))
        let access = PlusAccess(
            premiumState: makePremiumState(false, defaults: defaults),
            availability: .enabled,
            defaults: defaults,
            now: { clock.current }
        )
        access.markCatalogLoaded(true)
        access.startLegacyGraceIfNeeded(hasCompletedOnboarding: true)

        #expect(access.legacyGraceUntil != nil)
        #expect(access.isChartLocked == false)

        clock.current = try #require(Calendar.current.date(byAdding: .day, value: 13, to: clock.current))
        #expect(access.isChartLocked == false)

        clock.current = try #require(Calendar.current.date(byAdding: .day, value: 2, to: clock.current))
        #expect(access.isChartLocked)
    }

    @Test("Grace is persisted and never restarts")
    func legacyGraceRunsOnce() {
        let defaults = makeDefaults()
        let premium = makePremiumState(false, defaults: defaults)
        let clock = FakeClock(Date(timeIntervalSince1970: 1_800_000_000))
        let first = PlusAccess(premiumState: premium, availability: .enabled, defaults: defaults, now: { clock.current })
        first.startLegacyGraceIfNeeded(hasCompletedOnboarding: true)
        let graceEnd = first.legacyGraceUntil

        clock.current = clock.current.addingTimeInterval(30 * 86_400)
        let second = PlusAccess(premiumState: premium, availability: .enabled, defaults: defaults, now: { clock.current })
        second.startLegacyGraceIfNeeded(hasCompletedOnboarding: true)
        #expect(second.legacyGraceUntil == graceEnd)
        #expect(second.isInLegacyGrace == false)
    }

    @Test("Trial length is kept only while the trial is available")
    func trialPeriodUnitFollowsAvailability() {
        let defaults = makeDefaults()
        let premium = makePremiumState(false, defaults: defaults)
        let access = PlusAccess(premiumState: premium, availability: .enabled, defaults: defaults)
        #expect(access.trialAvailable == false)
        #expect(access.trialPeriodUnit == nil)

        access.updateTrial(available: true, periodUnit: "14-day")
        let reloaded = PlusAccess(premiumState: premium, availability: .enabled, defaults: defaults)
        #expect(reloaded.trialAvailable)
        #expect(reloaded.trialPeriodUnit == "14-day")

        reloaded.updateTrial(available: false, periodUnit: "14-day")
        #expect(reloaded.trialPeriodUnit == nil)
    }

    @Test("A new user gets no grace, even after finishing onboarding later")
    func newUserHasNoGrace() {
        let defaults = makeDefaults()
        let access = PlusAccess(
            premiumState: makePremiumState(false, defaults: defaults),
            availability: .enabled,
            defaults: defaults
        )
        access.markCatalogLoaded(true)

        access.startLegacyGraceIfNeeded(hasCompletedOnboarding: false)
        #expect(access.legacyGraceUntil == nil)
        #expect(access.isChartLocked)

        access.startLegacyGraceIfNeeded(hasCompletedOnboarding: true)
        #expect(access.legacyGraceUntil == nil)
        #expect(access.isChartLocked)
    }
}
