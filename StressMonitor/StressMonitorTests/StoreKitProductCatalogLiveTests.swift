import Foundation
import Testing
@testable import StressMonitor

/// Pins the shipped Info.plist: 1.1 sells StressMonitor Plus (monthly + annual)
/// and no credit packs.
@MainActor
struct StoreKitProductCatalogLiveTests {

    @Test("Live catalog resolves exactly the Plus monthly and annual products")
    func liveCatalogHasPlusProducts() {
        let catalog = StoreKitProductCatalog.live
        #expect(catalog.monthlyProductID == "com.stressmonitor.app.plus.monthly")
        #expect(catalog.annualProductID == "com.stressmonitor.app.plus.annual")
        #expect(catalog.allProductIDs == ["com.stressmonitor.app.plus.monthly", "com.stressmonitor.app.plus.annual"])
    }

    @Test("Live catalog resolves the Plus subscription group ID")
    func liveCatalogHasGroupID() {
        #expect(StoreKitProductCatalog.live.subscriptionGroupID == "22605738")
    }

    @Test("Live catalog resolves no small credit-pack product ID")
    func liveCatalogNoSmallPack() {
        let catalog = StoreKitProductCatalog.live
        #expect(
            catalog.packID(for: .small) == nil,
            "Small pack product ID resolved but credit packs are not sold in 1.1."
        )
    }

    @Test("Live catalog resolves no large credit-pack product ID")
    func liveCatalogNoLargePack() {
        let catalog = StoreKitProductCatalog.live
        #expect(
            catalog.packID(for: .large) == nil,
            "Large pack product ID resolved but credit packs are not sold in 1.1."
        )
    }

    @Test("A hardcoded small-pack product ID does not round-trip through pack(for:)")
    func liveSmallPackIDDoesNotRoundTrip() {
        let catalog = StoreKitProductCatalog.live
        #expect(
            catalog.pack(for: "com.stressmonitor.app.credits.small") == nil,
            "pack(for:) resolved a pack for a product ID this release does not configure."
        )
    }
}
