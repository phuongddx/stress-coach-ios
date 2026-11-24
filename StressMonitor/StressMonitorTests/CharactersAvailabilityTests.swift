import Foundation
import Testing
@testable import StressMonitor

// MARK: - CharactersAvailabilityTests

/// Characters / companions are hidden in 1.1.0 (`CharactersAvailability`).
/// These tests pin that the switch is off in this build and that every Plus
/// surface that used to promise companions follows it.
struct CharactersAvailabilityTests {

    private static let hidden = CharactersAvailability.hidden(reason: .unfinishedForRelease)

    /// Words that must not appear in Plus copy while Characters is hidden.
    private static let companionWords = ["companion", "ember", "zephyr", "lumi", "blossom", "evolution"]

    private static func mentionsCompanions(_ text: String) -> Bool {
        let lower = text.lowercased()
        return companionWords.contains { lower.contains($0) }
    }

    @Test("Characters is hidden in this build")
    func hiddenInThisBuild() {
        #expect(CharactersAvailability.current != .enabled)
        #expect(!CharactersAvailability.isEnabled)
    }

    @Test("Hidden: the paywall hero shows Ripple alone")
    func paywallHeroRippleOnly() {
        #expect(Self.hidden.paywallHeroCharacterIds == ["ripple"])
        #expect(CharactersAvailability.current.paywallHeroCharacterIds == ["ripple"])
    }

    @Test("Hidden: the paywall lists only chat, charts and trends")
    func paywallBenefitsHaveNoCompanions() {
        let benefits = IAPBenefitsCard.benefits(Self.hidden)
        #expect(benefits.count == 3)
        for benefit in benefits {
            #expect(!Self.mentionsCompanions(benefit.title + " " + benefit.description))
        }
    }

    @Test("Hidden: the success screen lists only chat, charts and trends")
    func successLinesHaveNoCompanions() {
        let lines = PurchaseSuccessView.unlockedLines(Self.hidden)
        #expect(lines.map(\.text) == [
            "Unlimited AI chat with Ripple",
            "All your charts, unblurred",
            "30- and 90-day Trends"
        ])
    }

    @Test("Hidden: the Home Plus banner does not promise companions")
    func bannerHasNoCompanions() {
        #expect(!Self.mentionsCompanions(PremiumBanner.benefits(Self.hidden)))
        #expect(!Self.mentionsCompanions(PremiumBanner.accessibilityLabel(Self.hidden)))
        #expect(PremiumBanner.benefits(Self.hidden).contains("90-day"))
    }

    @Test("Enabled: the companion content comes back unchanged")
    func enabledRestoresCompanions() {
        #expect(CharactersAvailability.enabled.paywallHeroCharacterIds == ["zephyr", "ripple", "ember"])
        #expect(IAPBenefitsCard.benefits(.enabled).contains { $0.title == "Plus companions" })
        #expect(PurchaseSuccessView.unlockedLines(.enabled).count == 4)
        #expect(PremiumBanner.benefits(.enabled).contains("premium companions"))
    }
}
