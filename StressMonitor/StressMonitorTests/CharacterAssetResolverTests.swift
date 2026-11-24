import Testing
import UIKit
@testable import StressMonitor

struct CharacterAssetResolverTests {
    @Test("Resolves full asset name for valid combination")
    func resolvesFullAssetName() {
        let name = CharacterAssetResolver.assetName(
            characterId: "ripple",
            evolution: .droplet,
            mood: .serene
        )

        #expect(name == "ripple_droplet_serene")
    }

    @Test("Resolves tidal worried asset")
    func resolvesTidalWorried() {
        let name = CharacterAssetResolver.assetName(
            characterId: "ember",
            evolution: .tidal,
            mood: .worried
        )

        #expect(name == "ember_tidal_worried")
    }

    @Test("Returns character calm fallback when exact asset is missing")
    func returnsCharacterFallbackWhenAssetMissing() {
        let name = CharacterAssetResolver.resolvedAssetName(
            characterId: "lumi",
            evolution: .tidal,
            mood: .worried
        )

        // Bundled placeholder assets use the legacy `calm` slug for the
        // droplet-stage fallback, so the resolver returns that name even
        // though the requested mood was `worried`.
        #expect(name == "lumi_droplet_calm")
    }

    @Test("All characters have valid naming pattern")
    func allCharactersValidNaming() {
        for creature in CharacterCreature.allCharacters {
            for evolution in EvolutionStage.allCases {
                for mood in RippleMood.allCases {
                    let name = CharacterAssetResolver.assetName(
                        characterId: creature.id,
                        evolution: evolution,
                        mood: mood
                    )
                    #expect(!name.isEmpty)
                    #expect(name.contains(creature.id))
                    #expect(name.contains(evolution.rawValue))
                    #expect(name.contains(mood.rawValue))
                }
            }
        }
    }

    @Test("Ripple and unknown ids render the Ripple v2 base pose")
    func rippleResolvesToV2() {
        #expect(CharacterAssetResolver.assetName(for: "ripple") == "ripple-v2-base")
        #expect(CharacterAssetResolver.assetName(for: "unknown-id") == "ripple-v2-base")
        #expect(CharacterAssetResolver.assetName(for: "ember") == "ember")
    }

    @Test("Legacy Ripple artwork is no longer in the bundle")
    func legacyRippleAssetsRemoved() {
        for name in ["ripple", "ripple-hero", "ripple_droplet_calm"] {
            #expect(UIImage(named: name) == nil, "\(name) should be removed")
        }
    }

    @Test("Ripple's droplet fallback skips the removed placeholder")
    func rippleFallbackSkipsRemovedPlaceholder() {
        let name = CharacterAssetResolver.resolvedAssetName(
            characterId: "ripple",
            evolution: .tidal,
            mood: .worried
        )
        #expect(name != "ripple_droplet_calm")
    }
}

