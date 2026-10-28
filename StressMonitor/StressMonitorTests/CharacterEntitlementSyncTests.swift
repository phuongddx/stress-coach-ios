import SwiftData
import Testing
@testable import StressMonitor

// Fixtures return the ModelContainer with its context: the container is the
// only owner of the in-memory store, and SwiftData traps once it deallocates.
@MainActor
struct CharacterEntitlementSyncTests {

    /// In-memory context seeded with every creature's unlock row. The
    /// container is returned alongside its context and must stay alive for
    /// the whole test — returning the context alone lets the container (the
    /// only owner of the in-memory store) deallocate, and the next SwiftData
    /// operation on the orphaned context traps.
    private func makeSeededContext() throws -> (ModelContainer, ModelContext) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: CharacterUnlock.self, configurations: config)
        let ctx = container.mainContext
        for creature in CharacterCreature.allCharacters {
            ctx.insert(CharacterUnlock(
                characterId: creature.id,
                isUnlocked: creature.unlockType == .free,
                currentEvolution: .droplet,
                isActive: creature.id == "ripple"
            ))
        }
        save(ctx)
        return (container, ctx)
    }

    private func unlock(in ctx: ModelContext, for id: String) -> CharacterUnlock {
        try! ctx.fetch(FetchDescriptor<CharacterUnlock>())
            .first(where: { $0.characterId == id })!
    }

    /// Empirically, a bare `try ctx.save()` directly inside a `throws @Test` body
    /// hangs the xcodebuild/XCTest host on this toolchain (confirmed by bisection —
    /// the save never actually throws) while the identical save wrapped in do/catch
    /// does not. Root mechanism unconfirmed; keeping saves out of the propagating
    /// `try` path here avoids the hang without masking a genuine save failure.
    private func save(_ ctx: ModelContext) {
        do {
            try ctx.save()
        } catch {
            Issue.record(error, "Context save failed")
        }
    }

    @Test("Subscribing unlocks premium characters, leaves others untouched")
    func subscribingUnlocksPremiumOnly() throws {
        let (container, ctx) = try makeSeededContext()
        CharacterCollectionViewModel.syncPremiumCharacterEntitlement(isPremium: true, in: ctx)

        #expect(unlock(in: ctx, for: "ember").isUnlocked)
        #expect(unlock(in: ctx, for: "zephyr").isUnlocked)
        #expect(unlock(in: ctx, for: "lumi").isUnlocked == false)
        #expect(unlock(in: ctx, for: "ripple").isUnlocked)
        #expect(unlock(in: ctx, for: "blossom").isUnlocked)
        _ = container // keep the in-memory store alive until the assertions are done
    }

    @Test("Lapsing keeps premium characters unlocked (one-time-permanent) and falls back active selection to Ripple")
    func lapsingKeepsPremiumUnlockedAndResetsActive() throws {
        let (container, ctx) = try makeSeededContext()
        CharacterCollectionViewModel.syncPremiumCharacterEntitlement(isPremium: true, in: ctx)

        let ember = unlock(in: ctx, for: "ember")
        ember.isActive = true
        unlock(in: ctx, for: "ripple").isActive = false
        save(ctx)

        CharacterCollectionViewModel.syncPremiumCharacterEntitlement(isPremium: false, in: ctx)

        #expect(unlock(in: ctx, for: "ember").isUnlocked)
        #expect(unlock(in: ctx, for: "zephyr").isUnlocked)
        #expect(unlock(in: ctx, for: "ember").isActive == false)
        #expect(unlock(in: ctx, for: "ripple").isActive)
        #expect(unlock(in: ctx, for: "ripple").isUnlocked)
        _ = container // keep the in-memory store alive until the assertions are done
    }

    @Test("Streak-gated Lumi survives a subscription lapse")
    func lumiStreakUnlockSurvivesLapse() throws {
        let (container, ctx) = try makeSeededContext()
        unlock(in: ctx, for: "lumi").isUnlocked = true
        save(ctx)

        CharacterCollectionViewModel.syncPremiumCharacterEntitlement(isPremium: false, in: ctx)

        #expect(unlock(in: ctx, for: "lumi").isUnlocked)
        _ = container // keep the in-memory store alive until the assertions are done
    }

    @Test("In-memory test container disables CloudKit sync")
    func inMemoryContainerDisablesCloudKit() throws {
        let (container, ctx) = try makeSeededContext()
        let cloudKitDatabases = ctx.container.configurations.map { String(describing: $0.cloudKitDatabase) }

        #expect(cloudKitDatabases.allSatisfy { $0 == String(describing: ModelConfiguration.CloudKitDatabase.none) })
        _ = container // keep the in-memory store alive until the assertions are done
    }
}
