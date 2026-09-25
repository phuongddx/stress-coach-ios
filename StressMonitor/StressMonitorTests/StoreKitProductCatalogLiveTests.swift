import Foundation
import Testing
@testable import StressMonitor

@MainActor
struct StoreKitProductCatalogLiveTests {

    @Test("Live catalog resolves no product IDs — this release ships no IAP")
    func liveCatalogEmpty() {
        let catalog = StoreKitProductCatalog.live
        #expect(
            catalog.allProductIDs.isEmpty,
            "StoreKitProductCatalog.live.allProductIDs is non-empty. This release removed all STOREKIT_* Info.plist keys; the live catalog must resolve empty."
        )
    }

    @Test("Live catalog resolves no subscription group ID")
    func liveCatalogNoGroupID() {
        let catalog = StoreKitProductCatalog.live
        #expect(
            catalog.subscriptionGroupID == nil,
            "Subscription group ID resolved but STOREKIT_PREMIUM_SUBSCRIPTION_GROUP_ID was removed from Info.plist for this release."
        )
    }

    @Test("Live catalog resolves no small credit-pack product ID")
    func liveCatalogNoSmallPack() {
        let catalog = StoreKitProductCatalog.live
        #expect(
            catalog.packID(for: .small) == nil,
            "Small pack product ID resolved but STOREKIT_CREDITS_SMALL_PRODUCT_ID was removed from Info.plist for this release."
        )
    }

    @Test("Live catalog resolves no large credit-pack product ID")
    func liveCatalogNoLargePack() {
        let catalog = StoreKitProductCatalog.live
        #expect(
            catalog.packID(for: .large) == nil,
            "Large pack product ID resolved but STOREKIT_CREDITS_LARGE_PRODUCT_ID was removed from Info.plist for this release."
        )
    }

    @Test("A hardcoded small-pack product ID does not round-trip through pack(for:)")
    func liveSmallPackIDDoesNotRoundTrip() {
        let catalog = StoreKitProductCatalog.live
        #expect(
            catalog.pack(for: "com.stressmonitor.app.credits.small") == nil,
            "pack(for:) resolved a pack for a product ID this release no longer configures."
        )
    }

    @Test("A hardcoded annual product ID is absent from the live catalog")
    func liveCatalogDoesNotContainAnnual() {
        let catalog = StoreKitProductCatalog.live
        #expect(
            catalog.allProductIDs.contains("com.stressmonitor.app.premium.annual") == false,
            "Annual product ID present in live catalog; STOREKIT_PREMIUM_ANNUAL_PRODUCT_ID was removed from Info.plist for this release."
        )
    }
}
