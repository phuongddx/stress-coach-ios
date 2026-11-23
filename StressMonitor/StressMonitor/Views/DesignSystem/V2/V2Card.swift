import SwiftUI

/// UI V2 card: `surface`, radius 22, padding 16, a soft 1 pt shadow in light
/// mode only. `.flat` uses `surface2`, `.tint` uses `accentSoft`.
enum V2CardStyle { case standard, flat, tint }

struct V2Card<Content: View>: View {
    typealias Style = V2CardStyle

    var style: Style = .standard
    var padding: CGFloat = V2Metrics.margin
    @ViewBuilder let content: Content

    init(style: Style = .standard, padding: CGFloat = V2Metrics.margin, @ViewBuilder content: () -> Content) {
        self.style = style
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .v2CardBackground(style)
    }
}

private struct V2CardBackground: ViewModifier {
    let style: V2CardStyle
    @Environment(\.colorScheme) private var colorScheme

    private var fill: Color {
        switch style {
        case .standard: return Color.V2.surface
        case .flat: return Color.V2.surface2
        case .tint: return Color.V2.accentSoft
        }
    }

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: V2Metrics.radiusLG, style: .continuous)
        content
            .background(shape.fill(fill))
            .overlay(shape.strokeBorder(style == .standard ? Color.V2.line : .clear, lineWidth: 0.5))
            .shadow(
                color: style == .standard && colorScheme == .light ? Color.V2.ink.opacity(0.06) : .clear,
                radius: 1, x: 0, y: 1
            )
    }
}

extension View {
    /// Applies the V2 card surface to an existing layout.
    func v2CardBackground(_ style: V2CardStyle = .standard) -> some View {
        modifier(V2CardBackground(style: style))
    }
}

/// title3 semibold section title with an optional trailing accent link.
struct V2SectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.V2.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.V2.accent)
                    .frame(minHeight: V2Metrics.minTouchTarget)
            }
        }
    }
}

#Preview("Cards") {
    ScrollView {
        VStack(spacing: 16) {
            V2SectionHeader(title: "Today", actionTitle: "See all") {}
            V2Card { Text("Standard card").foregroundStyle(Color.V2.ink) }
            V2Card(style: .flat) { Text("Flat card").foregroundStyle(Color.V2.ink) }
            V2Card(style: .tint) { Text("Tint card").foregroundStyle(Color.V2.ink) }
        }
        .padding()
    }
    .background(Color.V2.bg)
}
