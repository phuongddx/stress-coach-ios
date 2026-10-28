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

    @ScaledMetric(relativeTo: .caption2) private var caption2Scale: CGFloat = 1
    @ScaledMetric(relativeTo: .footnote) private var footnoteScale: CGFloat = 1
    @ScaledMetric(relativeTo: .title2) private var title2Scale: CGFloat = 1
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

    private var header: some View {
        HStack(spacing: 10) {
            CharacterFaceView(
                creature: creature,
                category: category,
                size: 44,
                showsHalo: true
            )

            VStack(alignment: .leading, spacing: 1) {
                Text(category?.displayName.uppercased() ?? "NO READING YET")
                    .font(.system(size: 9 * caption2Scale, weight: .semibold, design: .monospaced))
                    .tracking(0.08 * 9)
                    .foregroundStyle(category?.color ?? WatchDesignTokens.muted)

                Text(viewModel.currentLevel.map { "\(Int($0.rounded()))" } ?? "—")
                    .font(.system(size: 24 * title2Scale, weight: .bold, design: .rounded).monospacedDigit())
                    .tracking(-0.02 * 24)
                    .foregroundStyle(category?.inkColor ?? WatchDesignTokens.muted)
                    .contentTransition(.numericText(value: viewModel.currentLevel ?? 0))
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
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
                    iconColor: WatchDesignTokens.accent,
                    title: "Home",
                    subtitle: "Stress readout & companion"
                )
            }

            NavigationLink {
                WatchBreatheView()
            } label: {
                menuRow(
                    icon: "wind",
                    iconColor: Color.stressMild,
                    title: "Breathe",
                    subtitle: "4-7-8 guided breathing"
                )
            }

            NavigationLink {
                WatchHistoryView(viewModel: viewModel)
            } label: {
                menuRow(
                    icon: "clock.arrow.2.circlepath",
                    iconColor: Color.stressModerate,
                    title: "History",
                    subtitle: "Past readings & trends"
                )
            }

            NavigationLink {
                WatchLoggingView()
            } label: {
                menuRow(
                    icon: "checkmark.circle.fill",
                    iconColor: Color(hex: "#FE9901"),
                    title: "Today",
                    subtitle: "Habits & mood check-in"
                )
            }

            NavigationLink {
                WatchCycleView()
            } label: {
                menuRow(
                    icon: "drop.fill",
                    iconColor: Color(hex: "#CE93D8"),
                    title: "Cycle",
                    subtitle: "Phase tracking & predictions"
                )
            }
        }
    }

    // MARK: - Row

    private func menuRow(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String
    ) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.14))
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold)) // dated exception 2026-09-05: icon inside fixed 30pt circular well
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 14 * footnoteScale, weight: .semibold, design: .rounded))
                    .foregroundStyle(WatchDesignTokens.ink)

                Text(subtitle)
                    .font(.system(size: 9.5 * caption2Scale, weight: .regular, design: .default))
                    .foregroundStyle(WatchDesignTokens.muted)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 10 * footnoteScale, weight: .semibold))
                .foregroundStyle(WatchDesignTokens.mutedSystem)
        }
        .padding(.vertical, 3)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        WatchMenuView(viewModel: WatchStressViewModel())
    }
}
#endif
