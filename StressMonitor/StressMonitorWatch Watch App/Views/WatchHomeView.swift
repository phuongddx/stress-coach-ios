import SwiftUI

/// Watch **Home** screen — stress readout hero (UI V2).
///
/// True-black canvas with a faint companion tint. A 240° gauge (same
/// geometry as the iPhone `V2StressGauge`) wraps the companion; below it
/// sits the one number for this glance, the tier (colour + shape + name)
/// and an "out of 100 · time" caption.
struct WatchHomeView: View {
    @Bindable var viewModel: WatchStressViewModel

    @AppStorage(
        WatchFacePreferences.Keys.theme,
        store: WatchFacePreferences.defaults
    ) private var themeRaw: String = WatchFacePreferences.defaultTheme.rawValue

    private var theme: WatchFaceTheme { WatchFaceTheme(rawValue: themeRaw) ?? .ripple }
    private var creature: CharacterCreature { theme.creature }
    private var category: StressCategory? { viewModel.currentLevel.map(StressCategory.category(for:)) }
    private var score: Int? { viewModel.currentLevel.map { Int($0.rounded()) } }

    @ScaledMetric(relativeTo: .largeTitle) private var gaugeSize: CGFloat = 112

    private var readingTime: Date? {
        viewModel.currentStress?.timestamp ?? WatchSharedDataStore.shared.latest?.timestamp
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            WatchStressGauge(score: viewModel.currentLevel, lineWidth: 9) {
                CharacterFaceView(
                    creature: creature,
                    category: category,
                    size: min(gaugeSize, 132) * 0.52,
                    showsHalo: true
                )
            }
            .frame(width: min(gaugeSize, 132), height: min(gaugeSize, 132))
            // The 240° arc is open at the bottom — tuck the readout into it.
            .padding(.bottom, -min(gaugeSize, 132) * 0.16)

            readout

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(homeBackground.ignoresSafeArea())
        .task {
            await viewModel.requestAuthorization()
            await viewModel.loadLatestStress()
        }
    }

    // MARK: - Subviews

    /// One number per glance: the score in ink, the tier as colour + shape
    /// + name, and an "out of 100 · time" caption.
    private var readout: some View {
        VStack(spacing: 1) {
            Text(score.map(String.init) ?? "—")
                .font(.v2Number(.largeTitle, weight: .bold))
                .foregroundStyle(score == nil ? WatchV2.ink3 : WatchV2.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText(value: Double(score ?? 0)))

            if let category {
                WatchTierBadge(category: category, font: .footnote.weight(.semibold))
            } else {
                Text("No reading yet")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(WatchV2.ink3)
            }

            Text(caption)
                .font(.caption2)
                .foregroundStyle(WatchV2.ink3)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityElement()
        .accessibilityLabel(viewModel.currentLevel.map { StressCategory.category(for: $0).accessibilityValue(level: $0) } ?? "No stress reading yet")
    }

    private var caption: String {
        guard score != nil, let readingTime else { return "out of 100" }
        return "out of 100 · \(readingTime.formatted(date: .omitted, time: .shortened))"
    }

    // MARK: - Helpers

    private var homeBackground: some View {
        ZStack {
            WatchDesignTokens.canvas
            WatchFaceBackgroundView(
                style: WatchFacePreferences.backgroundStyle,
                theme: theme
            )
            .opacity(0.5)
        }
    }
}

#if DEBUG
#Preview {
    WatchHomeView(viewModel: WatchStressViewModel())
}
#endif
