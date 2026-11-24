import SwiftUI

/// A navigation row inside an inset grouped list on the Action tab (UI V2):
/// a 30 pt icon tile, a body title, a footnote subtitle and a chevron.
///
/// Uses **value-based navigation** (`NavigationLink(value:)`) so the parent
/// `NavigationStack` resolves the destination via `Route` +
/// `.stressNavigationDestinations()`.
///
/// Spec reference: ui-v2-design/screens.js `li()` / `group()`.
struct ActionGroupRow: View {
    let icon: String
    let title: String
    let subtitle: String
    /// Icon tile fill.
    var tint: Color = Color.V2.accent
    /// Glyph colour on the tile.
    var iconForeground: Color = Color.V2.onAccent
    let route: Route

    var body: some View {
        NavigationLink(value: route) {
            ActionRowLabel(icon: icon, title: title, subtitle: subtitle, tint: tint, iconForeground: iconForeground) {
                ActionRowChevron()
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
        .accessibilityHint("Double tap to open")
    }
}

/// Shared row layout for the Action tab lists: icon tile, title, optional
/// subtitle and a trailing accessory. At least 44 pt tall.
struct ActionRowLabel<Trailing: View>: View {
    let icon: String
    let title: String
    let subtitle: String?
    var tint: Color
    var iconForeground: Color
    let trailing: Trailing

    @ScaledMetric(relativeTo: .body) private var tileSize: CGFloat = 30

    init(
        icon: String,
        title: String,
        subtitle: String?,
        tint: Color = Color.V2.accent,
        iconForeground: Color = Color.V2.onAccent,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.tint = tint
        self.iconForeground = iconForeground
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 12) {
            ActionIconTile(icon: icon, tint: tint, foreground: iconForeground, size: tileSize)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(Color.V2.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(Color.V2.ink3)
                }
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing
        }
        .padding(.horizontal, V2Metrics.margin)
        .padding(.vertical, 4)
        .frame(minHeight: V2Metrics.minTouchTarget)
        .contentShape(Rectangle())
    }
}

/// 30 pt rounded icon tile used by grouped-list rows.
struct ActionIconTile: View {
    let icon: String
    var tint: Color = Color.V2.accent
    var foreground: Color = Color.V2.onAccent
    var size: CGFloat = 30

    var body: some View {
        Image(systemName: icon)
            .font(.callout.weight(.semibold))
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: V2Metrics.radiusXS, style: .continuous)
                    .fill(tint)
            )
            .accessibilityHidden(true)
    }
}

/// Trailing chevron for navigation rows.
struct ActionRowChevron: View {
    var body: some View {
        Image(systemName: AppIconSystem.Nav.forward.sfSymbol)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.V2.ink3)
            .accessibilityHidden(true)
    }
}

/// Inset grouped list container (UI V2 `.group`): `surface`, radius 16,
/// soft shadow in light mode only.
struct ActionGroupCard<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: V2Metrics.radiusMD, style: .continuous)
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(shape.fill(Color.V2.surface))
            .clipShape(shape)
            .shadow(
                color: colorScheme == .light ? Color.V2.ink.opacity(0.06) : .clear,
                radius: 1, x: 0, y: 1
            )
    }
}

/// Hairline between rows, inset to line up with the row titles.
struct ActionRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.V2.line)
            .frame(height: 0.5)
            .padding(.leading, 58)
            .accessibilityHidden(true)
    }
}

/// Uppercase group header (UI V2 `.ghead`).
struct ActionGroupHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .v2Eyebrow()
            .padding(.horizontal, V2Metrics.margin)
            .padding(.top, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Footnote under a group (UI V2 `.gfoot`).
struct ActionGroupFooter: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(Color.V2.ink3)
            .padding(.horizontal, V2Metrics.margin)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("ActionGroupRow") {
    NavigationStack {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                ActionGroupHeader(title: "Breathe")
                ActionGroupCard {
                    ActionGroupRow(icon: "wind", title: "Box breathing", subtitle: "4-4-4-4 · 2 min", route: .boxBreathing)
                }
                ActionGroupHeader(title: "Move")
                ActionGroupCard {
                    ActionGroupRow(
                        icon: "figure.walk",
                        title: "Mini walk",
                        subtitle: "10 min · 1,000 steps",
                        tint: StressCategory.relaxed.fillColor,
                        iconForeground: Color.V2.onLime,
                        route: .miniWalk
                    )
                }
            }
            .padding(16)
        }
        .background(Color.V2.bg)
        .stressNavigationDestinations()
    }
}
