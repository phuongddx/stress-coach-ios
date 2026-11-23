import SwiftUI

/// "Quick reset" row on Home (UI V2): two card tiles with an accent icon, a
/// title and a duration line. Tiles stack at accessibility text sizes.
///
/// Uses **value-based navigation** (`NavigationLink(value:)`); the parent
/// `NavigationStack` resolves each `Route` via `.stressNavigationDestinations()`.
///
/// Spec reference: ui-v2-design/screens.js `S.home` "Quick reset".
struct QuickActionGrid: View {
    let first: QuickActionTile
    let second: QuickActionTile

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            V2SectionHeader(title: "Quick reset")
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 8))
                : AnyLayout(HStackLayout(alignment: .top, spacing: 8))
            layout {
                first
                second
            }
        }
    }
}

/// Single quick action card tile.
struct QuickActionTile: View {
    /// Kept for API compatibility; both tiles share the V2 accent.
    enum Accent {
        case breathing
        case walk
    }

    let accent: Accent
    let symbol: String
    let title: String
    let meta: String
    let route: Route

    /// Same box for every symbol so the titles line up across tiles.
    @ScaledMetric(relativeTo: .title3) private var iconSize: CGFloat = 28

    var body: some View {
        NavigationLink(value: route) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.V2.accent)
                    .frame(width: iconSize, height: iconSize, alignment: .leading)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.V2.ink)
                Text(meta)
                    .font(.footnote)
                    .foregroundStyle(Color.V2.ink3)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
            .v2CardBackground()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(meta)")
        .accessibilityHint("Double tap to start")
    }
}

// MARK: - Convenience factory

extension QuickActionTile {
    static var boxBreathing: QuickActionTile {
        QuickActionTile(
            accent: .breathing,
            symbol: "wind",
            title: "Box breathing",
            meta: "2 min · calm focus",
            route: .boxBreathing
        )
    }

    static var miniWalk: QuickActionTile {
        QuickActionTile(
            accent: .walk,
            symbol: "figure.walk",
            title: "Mini walk",
            meta: "10 min · reset",
            route: .miniWalk
        )
    }
}

// MARK: - Preview

#Preview("QuickActionGrid") {
    NavigationStack {
        QuickActionGrid(first: .boxBreathing, second: .miniWalk)
            .padding()
            .background(Color.V2.bg)
            .stressNavigationDestinations()
    }
}
