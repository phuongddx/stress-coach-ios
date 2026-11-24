import SwiftUI

/// Root **Menu** screen — HIG-compliant list-based navigation.
///
/// Replaces the previous 6-page swipe `TabView` with a single scrollable
/// list.  Every destination is one tap away; the Digital Crown scrolls
/// naturally; and the current stress tier is always visible in the header.
///
/// Apple HIG: page-based navigation should be limited to 2–4 closely
/// related screens.  Six distinct sections with mixed purposes violate
/// this guideline and harm discoverability.
struct WatchMenuView: View {
    @Bindable var viewModel: WatchStressViewModel

    @AppStorage(
        WatchFacePreferences.Keys.theme,
        store: WatchFacePreferences.defaults
    ) private var themeRaw: String = WatchFacePreferences.defaultTheme.rawValue

    private var theme: WatchFaceTheme { WatchFaceTheme(rawValue: themeRaw) ?? .ripple }
    private var creature: CharacterCreature { theme.creature }
    private var category: StressCategory? { viewModel.currentLevel.map(StressCategory.category(for:)) }

    var body: some View {
        List {
            header
            menuRows
        }
        .listStyle(.carousel)
        .background(WatchDesignTokens.canvas.ignoresSafeArea())
        .task {
            await viewModel.requestAuthorization()
            await viewModel.loadLatestStress()
        }
    }

    // MARK: - Header

    /// One number per glance: companion, score, tier (shape + name + colour).
    private var header: some View {
        HStack(spacing: 10) {
            CharacterFaceView(
                creature: creature,
                category: category,
                size: 40,
                showsHalo: true
            )

            VStack(alignment: .leading, spacing: 0) {
                Text(viewModel.currentLevel.map { "\(Int($0.rounded()))" } ?? "—")
                    .font(.v2Number(.title2, weight: .bold))
                    .foregroundStyle(category?.inkColor ?? WatchV2.ink3)
                    .contentTransition(.numericText(value: viewModel.currentLevel ?? 0))

                if let category {
                    WatchTierBadge(category: category, font: .caption2.weight(.semibold))
                } else {
                    Text("No reading yet")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(WatchV2.ink3)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .listRowBackground(Color.clear)
    }

    // MARK: - Menu Rows

    private var menuRows: some View {
        Group {
            NavigationLink {
                WatchHomeView(viewModel: viewModel)
            } label: {
                menuRow(
                    icon: "house.fill",
                    iconColor: WatchV2.accent,
                    title: "Home",
                    subtitle: "Stress readout & companion"
                )
            }

            NavigationLink {
                WatchBreatheView()
            } label: {
                menuRow(
                    icon: "wind",
                    iconColor: WatchV2.lime,
                    title: "Breathe",
                    subtitle: "4-7-8 guided breathing"
                )
            }

            NavigationLink {
                WatchHistoryView(viewModel: viewModel)
            } label: {
                menuRow(
                    icon: "clock.arrow.2.circlepath",
                    iconColor: WatchV2.tierMild,
                    title: "History",
                    subtitle: "Past readings & trends"
                )
            }

            NavigationLink {
                WatchLoggingView()
            } label: {
                menuRow(
                    icon: "checkmark.circle.fill",
                    iconColor: WatchV2.tierElevated,
                    title: "Today",
                    subtitle: "Habits & mood check-in"
                )
            }

            NavigationLink {
                WatchCycleView()
            } label: {
                menuRow(
                    icon: "drop.fill",
                    iconColor: WatchV2.cycle,
                    title: "Cycle",
                    subtitle: "Phase tracking & predictions"
                )
            }
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 3, leading: 0, bottom: 3, trailing: 0))
    }

    // MARK: - Row

    /// V2 row: filled colour tile with an on-accent glyph, title + subtitle,
    /// on a rounded `surface` platter at least 44 pt tall.
    private func menuRow(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(WatchV2.onAccent)
                .frame(width: 28, height: 28)
                .background(iconColor, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(WatchV2.ink)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(WatchV2.ink3)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(WatchV2.ink3)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, minHeight: WatchV2.minHitTarget, alignment: .leading)
        .background(WatchV2.surface, in: RoundedRectangle(cornerRadius: WatchV2.radiusCard, style: .continuous))
        .contentShape(Rectangle())
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        WatchMenuView(viewModel: WatchStressViewModel())
    }
}
#endif
