import SwiftUI

// MARK: - WatchFaceBackgroundStyle

/// Background rendering style for the watch face / Home canvas.
///
/// Four styles are retained from the previous design. Every treatment is a
/// soft, low-opacity companion tint wash over the true-black V2 canvas.
/// No mesh gradients.
enum WatchFaceBackgroundStyle: String, CaseIterable, Codable, Sendable {
    /// Flat soft tint — subtle, battery-friendly.
    case solid
    /// Two-stop vertical tint ramp.
    case gradient
    /// Multi-stop diagonal wash evoking northern lights (soft).
    case aurora
    /// Layered wave-like wash evoking calm water.
    case ocean

    var displayName: String {
        switch self {
        case .solid:    return "Solid"
        case .gradient: return "Gradient"
        case .aurora:   return "Aurora"
        case .ocean:    return "Ocean"
        }
    }

    /// SF Symbol used in the picker swatch.
    var iconName: String {
        switch self {
        case .solid:    return "circle.fill"
        case .gradient: return "arrow.up.arrow.down.circle"
        case .aurora:   return "sparkles"
        case .ocean:    return "water.waves"
        }
    }
}

// MARK: - WatchFaceTheme

/// Five preset colour themes, one per elemental companion.  Bridges 1:1
/// to `CharacterCreature` so the Settings preview can render the actual
/// companion SVG instead of an emoji.
enum WatchFaceTheme: String, CaseIterable, Codable, Sendable {
    case ripple
    case blossom
    case ember
    case zephyr
    case lumi

    /// Underlying companion used to render the character glyph.
    var creature: CharacterCreature {
        switch self {
        case .ripple:  return .ripple
        case .blossom: return .blossom
        case .ember:   return .ember
        case .zephyr:  return .zephyr
        case .lumi:    return .lumi
        }
    }

    var displayName: String { creature.displayName }

    /// Theme primary colour (delegates to the companion palette).
    var primaryColor: Color { creature.primaryColor }

    /// Theme secondary colour (delegates to the companion palette).
    var secondaryColor: Color { creature.secondaryColor }
}

// MARK: - WatchFaceBackgroundView

/// Renders the chosen background treatment as a SwiftUI `View`.
///
/// All styles are deliberately restrained — low-opacity tints over the
/// black canvas.  Used in-app (Home, Settings preview) and as
/// `containerBackground` content for complications (where watchOS
/// overlays its own dark complication canvas by platform contract).
struct WatchFaceBackgroundView: View {
    let style: WatchFaceBackgroundStyle
    let theme: WatchFaceTheme

    var body: some View {
        switch style {
        case .solid:
            theme.primaryColor.opacity(0.10)

        case .gradient:
            LinearGradient(
                colors: [
                    theme.primaryColor.opacity(0.14),
                    theme.secondaryColor.opacity(0.06)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

        case .aurora:
            LinearGradient(
                stops: [
                    .init(color: theme.primaryColor.opacity(0.16), location: 0.0),
                    .init(color: theme.secondaryColor.opacity(0.10), location: 0.5),
                    .init(color: theme.primaryColor.opacity(0.04), location: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

        case .ocean:
            LinearGradient(
                stops: [
                    .init(color: theme.secondaryColor.opacity(0.12), location: 0.0),
                    .init(color: theme.primaryColor.opacity(0.18), location: 0.45),
                    .init(color: theme.secondaryColor.opacity(0.08), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}
