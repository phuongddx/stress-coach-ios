import SwiftUI
import WidgetKit

// MARK: - Ripple Complication Head

/// Ripple v2 level head for complications (spec §4.2, §4.4).
///
/// `nil` category (no reading) shows Ripple asleep. In tinted / accented
/// watch faces the image uses `.accentedDesaturated`: the SDK documents
/// `.fullColor` as "Only applies to iOS", so on watchOS it would fall back
/// to the default alpha-only silhouette and lose the face. Desaturated
/// luminance keeps the eyes and mouth readable in the accent tint. In
/// full-colour faces the head renders in its own colours.
///
/// Hidden from VoiceOver: every complication that uses it already speaks
/// the level in its own accessibility label.
struct RippleComplicationHead: View {
    let category: StressCategory?
    let size: CGFloat

    var body: some View {
        Image(RipplePose.from(category: category).headAssetName)
            .resizable()
            .widgetAccentedRenderingMode(.accentedDesaturated)
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
