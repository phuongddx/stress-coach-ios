import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Resolves a character id to an SVG-backed ``Image`` (from Assets.xcassets).
///
/// The canonical entry point is ``characterView(for:mood:size:)``, which
/// routes each character id to its exported SVG illustration. The legacy
/// `assetName`/`resolvedAssetName` helpers are retained for callers that
/// still resolve image assets (e.g. the illustration export pipeline).
public enum CharacterAssetResolver {

    /// Route a character id to its SVG illustration.
    ///
    /// Unknown ids fall back to the Ripple (water) character so the UI never
    /// renders empty when an id is stale or missing.
    static func characterView(for id: String, mood: RippleMood, size: CGFloat = 120) -> AnyView {
        // `mood` drives the ambient animation applied by StressBuddyIllustration;
        // the SVG itself is multi-colored (preserves-vector-representation = true)
        // so we render in .original mode to keep all design-system colors intact.
        let assetName = Self.assetName(for: id)
        return AnyView(
            Image(assetName)
                .resizable()
                .renderingMode(.original)
                .aspectRatio(1, contentMode: .fit)
                .frame(width: size, height: size)
        )
    }

    /// Apply the per-evolution scale factor so callers can keep using the
    /// evolution metadata without reimplementing the size curve.
    static func characterView(
        for id: String,
        evolution: EvolutionStage,
        mood: RippleMood,
        size: CGFloat = 120
    ) -> AnyView {
        characterView(for: id, mood: mood, size: size * evolution.scaleFactor)
    }

    // MARK: - Asset Name Resolution

    /// Map a character id to its SVG imageset name in Assets.xcassets.
    /// Ripple and unknown ids use the Ripple v2 base pose.
    static func assetName(for id: String) -> String {
        switch id {
        case "blossom": return "blossom"
        case "ember":   return "ember"
        case "zephyr":  return "zephyr"
        case "lumi":    return "lumi"
        default:        return RipplePose.base.assetName
        }
    }
}

// MARK: - Legacy Asset-Name Resolution

extension CharacterAssetResolver {

    /// Canonical droplet-stage fallback mood used when a more specific asset
    /// is missing. The bundled placeholder assets are named with the legacy
    /// `calm` slug, so the fallback references that slug directly rather than
    /// regenerating from a `RippleMood` value.
    private static let fallbackDropletSlug = "calm"

    private static let placeholderCharacterAssets: Set<String> = [
        "blossom_droplet_calm",
        "ember_droplet_calm",
        "zephyr_droplet_calm",
        "lumi_droplet_calm",
    ]

    private static let legacyMoodAssets: Set<String> = [
        "CharacterSleeping",
        "CharacterCalm",
        "CharacterConcerned",
        "CharacterWorried",
        "CharacterOverwhelmed",
    ]

    /// Generate the canonical asset name for a specific character state.
    ///
    /// - Deprecated: Prefer ``characterView(for:mood:size:)``. This helper
    ///   is retained only for the illustration export pipeline.
    @available(*, deprecated, message: "Use CharacterAssetResolver.characterView(for:mood:size:) for on-screen rendering.")
    static func assetName(
        characterId: String,
        evolution: EvolutionStage,
        mood: RippleMood
    ) -> String {
        "\(characterId)_\(evolution.rawValue)_\(mood.rawValue)"
    }

    /// Resolve the best available asset name using the project fallback chain.
    ///
    /// - Deprecated: See ``assetName(characterId:evolution:mood:)``.
    @available(*, deprecated, message: "Use CharacterAssetResolver.characterView(for:mood:size:) for on-screen rendering.")
    static func resolvedAssetName(
        characterId: String,
        evolution: EvolutionStage,
        mood: RippleMood,
        bundle: Bundle = .main
    ) -> String {
        let exact = "\(characterId)_\(evolution.rawValue)_\(mood.rawValue)"
        if assetExists(named: exact, in: bundle) {
            return exact
        }

        let characterFallback = "\(characterId)_\(EvolutionStage.droplet.rawValue)_\(fallbackDropletSlug)"
        if assetExists(named: characterFallback, in: bundle) {
            return characterFallback
        }

        let legacy = legacyAssetName(for: mood)
        if assetExists(named: legacy, in: bundle) {
            return legacy
        }

        return "CharacterCalm"
    }

    static func legacyAssetName(for mood: RippleMood) -> String {
        switch mood {
        case .relaxed:      return "CharacterSleeping"
        case .serene:       return "CharacterCalm"
        case .focused:      return "CharacterConcerned"
        case .worried:      return "CharacterWorried"
        case .celebrating:  return "CharacterOverwhelmed"
        case .happy:        return "CharacterCalm"
        case .determined:   return "CharacterOverwhelmed"
        case .tired:        return "CharacterSleeping"
        }
    }

    private static func assetExists(named name: String, in bundle: Bundle) -> Bool {
        if placeholderCharacterAssets.contains(name) || legacyMoodAssets.contains(name) {
            return true
        }

        #if canImport(UIKit)
        return UIImage(named: name, in: bundle, compatibleWith: nil) != nil
        #else
        return false
        #endif
    }
}
