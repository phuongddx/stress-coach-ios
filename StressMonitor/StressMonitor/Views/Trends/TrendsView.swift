import SwiftUI
import SwiftData

// MARK: - TrendsView (UI V2)
//
// Spec reference: ui-v2-design/screens.js `S.trends`.
//   - Week / Month / 3 Months range chips (Month and 3 Months show a lock for Free)
//   - Summary of the week vs the prior 7 days
//   - Plus: daily bars, time in each tier, monthly heatmap, HRV trend
//   - Free: ONE locked preview (daily bars) plus a list of what Plus adds.
//     The other three charts keep their `.plusLocked(...)` call sites; they are
//     only rendered when `PlusAccess.isChartLocked` is false, i.e. exactly when
//     the modifier would show them unblurred anyway.
//   - Ripple weekly insight
// States: skeleton while the first load runs, empty card without readings.

struct TrendsView: View {
    @Environment(\.modelContext) private var modelContext
    // Optional so the preview without the app root's environment still runs.
    @Environment(PlusAccess.self) private var injectedPlusAccess: PlusAccess?
    @Environment(PaywallController.self) private var paywall: PaywallController?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var viewModel: TrendsViewModel

    /// Same rule `PlusLockedModifier` uses for every chart on this screen.
    private var isRangeLocked: Bool {
        (injectedPlusAccess ?? .shared).isChartLocked
    }

    /// Allocated once, not per view re-evaluation. `.task` swaps in the real
    /// environment `modelContext` on first appearance.
    private static let placeholderContext: ModelContext = {
        let container = try? ModelContainer(
            for: StressMeasurement.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container!)
    }()

    init() {
        _viewModel = State(initialValue: TrendsViewModel(modelContext: Self.placeholderContext))
    }

    var body: some View {
        trendsLayout
            .background(Color.V2.bg.ignoresSafeArea())
            .accessibleDynamicType()
            .navigationTitle("Trends")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                viewModel = TrendsViewModel(modelContext: modelContext)
                await viewModel.loadTrendData()
            }
            .onChange(of: isRangeLocked) { _, locked in
                if viewModel.enforceRangeLock(locked) {
                    Task { await viewModel.loadTrendData() }
                }
            }
    }

    // MARK: - Layout

    private var hasData: Bool {
        !viewModel.weeklyMeasurements.isEmpty
    }

    /// One column on phones and the Duo outer display. On the Duo inner
    /// display (regular width) the week sits left of the fold and the
    /// breakdown charts right of it.
    @ViewBuilder
    private var trendsLayout: some View {
        if DuoLayout.mode(for: horizontalSizeClass) == .twoColumns, hasData {
            FoldAwareSplit {
                trendsColumn {
                    chipRow
                    weekSection
                }
            } trailing: {
                trendsColumn {
                    breakdownSection
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(DuoLayoutID.twoColumns)
        } else {
            trendsColumn {
                chipRow
                if viewModel.weeklyMeasurements.isEmpty && viewModel.isLoading {
                    loadingSkeleton
                } else if viewModel.weeklyMeasurements.isEmpty {
                    NoDataCard(dataType: .trends) {
                        Task { await viewModel.loadTrendData() }
                    }
                } else {
                    weekSection
                    breakdownSection
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(DuoLayoutID.singleColumn)
        }
    }

    private func trendsColumn<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                content()
            }
            .padding(.horizontal, V2Metrics.margin)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }

    @ViewBuilder
    private var weekSection: some View {
        editorialSummary
        dailyBars
    }

    @ViewBuilder
    private var breakdownSection: some View {
        if isRangeLocked {
            // Free: one locked preview, then the list of what Plus adds.
            plusFeatureList
        } else {
            distributionCard
            calendarCard
            hrvCard
        }
        if let insight = viewModel.weeklyInsight {
            editorialInsight(insight)
        }
    }

    // MARK: - Chip Row

    private var chipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TrendsChip.allCases, id: \.self) { chip in
                    chipView(chip)
                }
            }
            .padding(.bottom, 2)
        }
    }

    private func chipView(_ chip: TrendsChip) -> some View {
        let isActive = chip.toTrendsTimeRange == viewModel.selectedTimeRange
        let isLocked = isRangeLocked && chip.toTrendsTimeRange.requiresPlus
        return V2Chip(
            title: chip.title,
            systemImage: isLocked ? "lock.fill" : nil,
            isSelected: isActive
        ) {
            if viewModel.selectRange(chip.toTrendsTimeRange, locked: isRangeLocked) {
                paywall?.present(reason: .trendsLongRange)
            } else {
                Task { await viewModel.loadTrendData() }
            }
        }
        .frame(minHeight: V2Metrics.minTouchTarget)
        .accessibilityLabel(isLocked ? "\(chip.title), requires Plus" : chip.title)
    }

    // MARK: - Loading

    private var loadingSkeleton: some View {
        VStack(alignment: .leading, spacing: 12) {
            V2Skeleton(width: 220, height: 22)
            V2Skeleton(width: 160, height: 14)
            V2Skeleton(height: 180, cornerRadius: V2Metrics.radiusLG)
                .padding(.top, 4)
            V2Skeleton(height: 120, cornerRadius: V2Metrics.radiusLG)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading trends")
    }

    // MARK: - 1. Editorial Summary

    private var editorialSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let delta = viewModel.editorialDelta {
                Text("Vs the prior 7 days")
                    .v2Eyebrow()

                Text("You're \(Text(delta).foregroundStyle(deltaColor)).")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.V2.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(viewModel.editorialSummary)
                .font(viewModel.editorialDelta == nil ? .title3.weight(.semibold) : .callout)
                .foregroundStyle(viewModel.editorialDelta == nil ? Color.V2.ink : Color.V2.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
    }

    private var deltaColor: Color {
        switch viewModel.stressCalmerPercent ?? 0 {
        case 1...:  return StressCategory.relaxed.color
        case 0:     return Color.V2.ink2
        default:    return StressCategory.high.color
        }
    }

    // MARK: - 2. Daily Stress Bars (7d)

    private var dailyBars: some View {
        StressBarChartView(
            dailyStress: viewModel.dailyStressData,
            averageValue: viewModel.dailyStressAverage,
            windowLabel: viewModel.dailyWindowLabel
        )
        .plusLocked(.trendsDailyBars)
    }

    // MARK: - 3. Distribution

    private var distributionCard: some View {
        let d = viewModel.distributionDays
        return DistributionBar(
            relaxedDays: d.relaxed,
            mildDays: d.mild,
            moderateDays: d.moderate,
            highDays: d.high,
            comment: viewModel.distributionComment,
            title: "Time in each tier",
            windowLabel: viewModel.dailyWindowLabel
        )
        .plusLocked(.trendsDistribution)
    }

    // MARK: - 4. Monthly Calendar Heatmap

    private var calendarCard: some View {
        MonthlyCalendarHeatmap(dailyLevels: viewModel.monthlyCalendar)
            .plusLocked(.trendsCalendar)
    }

    // MARK: - 5. HRV Trend

    private var hrvCard: some View {
        HRVTrendChart(
            dataPoints: viewModel.hrvData,
            referenceValue: viewModel.hrvAvg,
            deltaText: viewModel.hrvDeltaText,
            periodLabel: viewModel.selectedTimeRange.periodLabel
        )
        .plusLocked(.trendsHRV)
    }

    // MARK: - Free: What Plus Adds

    private var plusFeatureList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Also with Plus")
                .v2Eyebrow()
                .accessibilityAddTraits(.isHeader)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                plusRow(icon: "chart.bar.doc.horizontal", title: "Time in each tier", reason: .chart(.trendsDistribution))
                rowDivider
                plusRow(icon: "calendar", title: "Monthly heatmap", reason: .chart(.trendsCalendar))
                rowDivider
                plusRow(icon: "waveform.path.ecg", title: "HRV trend", reason: .chart(.trendsHRV))
                rowDivider
                plusRow(icon: "clock", title: "30- and 90-day ranges", reason: .trendsLongRange)
            }
            .v2CardBackground()
        }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Color.V2.line)
            .frame(height: 0.5)
            .padding(.leading, 60)
    }

    /// Same tap target the blurred chart used to offer: opens the paywall
    /// with that chart's reason.
    private func plusRow(icon: String, title: String, reason: PaywallReason) -> some View {
        Button {
            paywall?.present(reason: reason)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.V2.plus)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: V2Metrics.radiusXS, style: .continuous)
                            .fill(Color.V2.plusBg)
                    )
                    .accessibilityHidden(true)
                Text(title)
                    .font(.body)
                    .foregroundStyle(Color.V2.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                if !dynamicTypeSize.isAccessibilitySize {
                    V2PlusPill()
                }
            }
            .padding(.horizontal, V2Metrics.margin)
            .padding(.vertical, 10)
            .frame(minHeight: V2Metrics.minTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), Plus feature")
        .accessibilityHint("Double-tap to unlock Plus")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - 6. Weekly Insight

    private func editorialInsight(_ insight: String) -> some View {
        RippleInsightCard(
            insight: AIInsight(
                title: "Weekly insight",
                message: insight,
                actionTitle: nil,
                trendData: nil
            ),
            onAskRipple: nil
        )
    }
}

// MARK: - Chip Enum

enum TrendsChip: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case threeMonths = "3 Months"

    var title: String { rawValue }

    var toTrendsTimeRange: TrendsTimeRange {
        switch self {
        case .week:         return .week
        case .month:        return .month
        case .threeMonths:  return .threeMonths
        }
    }
}

#Preview("Trends") {
    NavigationStack {
        TrendsView()
            .stressNavigationDestinations()
    }
    .environment(AppRouter())
    .modelContainer(for: [StressMeasurement.self], inMemory: true)
}
