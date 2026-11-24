import SwiftUI

// MARK: - CharacterAssetCatalog

/// Bridges the design-exported character SVGs to SwiftUI `Image` assets.
///
/// The app renders characters primarily through procedural SwiftUI views
/// (``CharacterAssetResolver.characterView(for:mood:size:)``) for mood-reactive
/// animations. This catalog provides **static** SVG-backed images for contexts
/// that don't need mood animation — list avatars, grid tiles, picker sheets,
/// tab icons, widgets, and locked-character placeholders.
///
/// ## Asset Catalog Structure
/// ```
/// Assets.xcassets/RippleV2/
///   ripple-v2-<pose>.imageset, ripple-v2-<pose>-head.imageset (512 artboard)
/// Assets.xcassets/Characters/
///   blossom.imageset       (blossom.svg, 100×100)
///   ember.imageset         (ember.svg, 100×100)
///   zephyr.imageset        (zephyr.svg, 100×100)
///   lumi.imageset          (lumi.svg, 100×100)
/// ```
///
/// All SVGs have `preserves-vector-representation: true` so they scale
/// crisply at any display size.
enum CharacterAssetCatalog {

    // MARK: - Asset Names

    /// Character asset name in the Asset Catalog. Ripple (and the legacy
    /// `ripple-hero` id) resolve to the Ripple v2 base pose.
    static func assetName(for characterId: String) -> String {
        let id = characterId.lowercased()
        switch id {
        case "ripple", "ripple-hero": return RipplePose.base.assetName
        default: return id
        }
    }

    /// Hero-size asset name. Ripple v2 is a single 512 artboard, so the hero
    /// and the standard asset are the same drawing.
    static func heroAssetName(for characterId: String) -> String {
        assetName(for: characterId)
    }

    // MARK: - SwiftUI Image

    /// Static character image from the Asset Catalog (SVG-backed).
    /// Use for list rows, grid tiles, picker sheets — anywhere a non-animated
    /// character avatar is needed.
    static func image(for characterId: String) -> Image {
        Image(assetName(for: characterId))
    }

    /// Hero-size character image.
    static func heroImage(for characterId: String) -> Image {
        Image(heroAssetName(for: characterId))
    }

    // MARK: - CharacterCreature Convenience

    static func image(for creature: CharacterCreature) -> Image {
        image(for: creature.id)
    }

    static func heroImage(for creature: CharacterCreature) -> Image {
        heroImage(for: creature.id)
    }

    // MARK: - Display Size Presets

    /// Standard display sizes from the character export sheet.
    enum DisplaySize {
        case tabIcon      // 24pt
        case listItem     // 48pt
        case gridTile     // 92pt
        case cardHero     // 120pt
        case detailHero   // 160pt

        var points: CGFloat {
            switch self {
            case .tabIcon:    return 24
            case .listItem:   return 48
            case .gridTile:   return 92
            case .cardHero:   return 120
            case .detailHero: return 160
            }
        }
    }

    // MARK: - Bundled Check

    /// Character IDs that have a bundled SVG asset.
    static let bundledCharacterIds: Set<String> = [
        "ripple", "blossom", "ember", "zephyr", "lumi"
    ]

    /// Whether a static SVG asset exists for the given character ID.
    static func hasAsset(for characterId: String) -> Bool {
        bundledCharacterIds.contains(characterId.lowercased())
    }
}

// MARK: - MoodFaceAssetCatalog

/// Bridges the design-exported mood-face SVGs to SwiftUI `Image` assets.
///
/// These 5 SVGs (24×24 viewBox) match the mood faces from `icon-system.html`.
/// For WCAG compliance, the mood color must always be applied as a tint or
/// background when using these icons.
///
/// ## Asset Catalog Structure
/// ```
/// Assets.xcassets/MoodFaces/
///   mood-relaxed.imageset   (0–25, #34C759)
///   mood-mild.imageset      (26–50, #007AFF)
///   mood-moderate.imageset  (51–75, #FFD60A)
///   mood-high.imageset      (76–90, #FF9500)
///   mood-severe.imageset    (91+, #FF3B30)
/// ```
enum MoodFaceAssetCatalog {

    // MARK: - Asset Names

    /// Mood-face asset name in the Asset Catalog.
    static func assetName(for mood: MoodFaceIcon) -> String {
        "mood-\(mood.rawValue)"
    }

    // MARK: - SwiftUI Image

    /// Static mood-face image from the Asset Catalog (SVG-backed).
    /// Apply `.foregroundStyle(mood.color)` or use inside a colored circle
    /// for WCAG-compliant dual-coding.
    static func image(for mood: MoodFaceIcon) -> Image {
        Image(assetName(for: mood))
    }

    /// Convenience: stress level → mood-face image.
    static func image(stressLevel: Double) -> Image {
        image(for: .from(stressLevel: stressLevel))
    }
}
