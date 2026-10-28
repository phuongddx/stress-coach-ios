import SwiftUI

/// A single row inside an action group card on the Action tab.
///
/// SF Symbol icon (no colored circle wrapper — removes the icon-wrap AI-slop tell)
/// + title + subtitle + trailing chevron. Uses **value-based navigation**
/// (`NavigationLink(value:)`) so the parent `NavigationStack` resolves the
/// destination via `Route` + `.stressNavigationDestinations()`.
///
/// Designed to be placed inside an `ActionGroupCard` which provides the shared
/// background, rounded corners, and hairline separators between rows.
struct ActionGroupRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color
    let route: Route

    var body: some View {
        NavigationLink(value: route) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.Wellness.adaptivePrimaryText)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: AppIconSystem.Nav.forward.sfSymbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.Wellness.adaptiveSecondaryText.opacity(0.55))
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
        .accessibilityHint("Double tap to open")
    }
}

/// Container that gives a group of action rows a shared card background with
/// hairline separators — matching the iOS Settings grouped-list style.
///
/// Usage:
/// ```swift
/// ActionGroupCard {
///     ActionGroupRow(icon: "wind", ..., route: .breathingSession)
///     ActionGroupRow(icon: "figure.walk", ..., route: .miniWalk)
/// }
/// ```
struct ActionGroupCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .background(Color.Wellness.adaptiveCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.Wellness.adaptiveSecondaryText.opacity(0.10), lineWidth: 0.5)
            )
    }
}

/// Hairline separator placed between action rows inside a group card.
/// Each row except the last gets a bottom divider at `0.5px` opacity,
/// matching `border-bottom: 0.5px solid rgba(60,60,67,0.12)`.
struct ActionRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(white: 60 / 255, opacity: 0.12))
            .frame(height: 0.5)
            .padding(.horizontal, 14)
    }
}

#Preview("ActionGroupRow") {
    NavigationStack {
        ScrollView {
            VStack(spacing: 18) {
                ActionGroupCard {
                    VStack(spacing: 0) {
                        ActionGroupRow(
                            icon: "wind",
                            title: "Box Breathing",
                            subtitle: "4-4-4-4 · 2 min",
                            tint: HomeCharacterDesignTokens.Ripple.primary,
                            route: .boxBreathing
                        )
                    }
                }
                ActionGroupCard {
                    VStack(spacing: 0) {
                        ActionGroupRow(
                            icon: "figure.walk",
                            title: "Mini Walk",
                            subtitle: "10 min · target 1,000 steps",
                            tint: Color(hex: "#34C759"),
                            route: .miniWalk
                        )
                    }
                }
            }
            .padding(16)
        }
        .background(HomeCharacterDesignTokens.homeBackground)
        .stressNavigationDestinations()
    }
}
