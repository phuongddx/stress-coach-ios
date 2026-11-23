import Foundation
import Testing
@testable import StressMonitor

/// Guards the local `.storekit` file against drifting from App Store Connect.
/// Values mirror ASC as checked on 22/11/2026: group "Plus" (22605738),
/// annual 25.99 with a 2-week free trial, monthly 4.99 without a trial.
struct StoreKitConfigFileTests {

    // MARK: - Fixture

    private final class BundleAnchor {}

    private struct Subscription {
        let productID: String
        let displayPrice: String
        let period: String
        let groupID: String
        let introOffer: [String: Any]?
    }

    private struct Config {
        let groupID: String
        let groupName: String
        let subscriptions: [Subscription]
    }

    private static func loadConfig() throws -> Config {
        let bundle = Bundle(for: BundleAnchor.self)
        let url = try #require(bundle.url(forResource: "StressMonitorProducts", withExtension: "storekit"))
        let data = try Data(contentsOf: url)
        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let groups = try #require(root["subscriptionGroups"] as? [[String: Any]])
        #expect(groups.count == 1)
        let group = try #require(groups.first)
        let subs = try #require(group["subscriptions"] as? [[String: Any]])
        return Config(
            groupID: group["id"] as? String ?? "",
            groupName: group["name"] as? String ?? "",
            subscriptions: subs.map {
                Subscription(
                    productID: $0["productID"] as? String ?? "",
                    displayPrice: $0["displayPrice"] as? String ?? "",
                    period: $0["recurringSubscriptionPeriod"] as? String ?? "",
                    groupID: $0["subscriptionGroupID"] as? String ?? "",
                    introOffer: $0["introductoryOffer"] as? [String: Any]
                )
            }
        )
    }

    // MARK: - Tests

    @Test("Subscription group is Plus with the App Store Connect id")
    func groupMatchesASC() throws {
        let config = try Self.loadConfig()
        #expect(config.groupName == "Plus")
        #expect(config.groupID == "22605738")
        #expect(config.subscriptions.allSatisfy { $0.groupID == "22605738" })
    }

    @Test("Exactly the two plus.* products exist")
    func exactlyTwoPlusProducts() throws {
        let config = try Self.loadConfig()
        let ids = Set(config.subscriptions.map(\.productID))
        #expect(ids == ["com.stressmonitor.app.plus.monthly", "com.stressmonitor.app.plus.annual"])
    }

    @Test("Annual is 25.99 per year with a 2-week free trial")
    func annualPriceAndTrial() throws {
        let config = try Self.loadConfig()
        let annual = try #require(config.subscriptions.first { $0.productID == "com.stressmonitor.app.plus.annual" })
        #expect(annual.displayPrice == "25.99")
        #expect(annual.period == "P1Y")
        let intro = try #require(annual.introOffer)
        #expect(intro["paymentMode"] as? String == "free")
        #expect(intro["subscriptionPeriod"] as? String == "P2W")
    }

    @Test("Monthly is 4.99 per month with no trial")
    func monthlyPriceNoTrial() throws {
        let config = try Self.loadConfig()
        let monthly = try #require(config.subscriptions.first { $0.productID == "com.stressmonitor.app.plus.monthly" })
        #expect(monthly.displayPrice == "4.99")
        #expect(monthly.period == "P1M")
        #expect(monthly.introOffer == nil)
    }
}
