import SwiftUI
import SwiftData

// MARK: - TrendsView (Light Theme Redesign)
//
// Six sections matching `06-trends.html`:
//   1. Editorial summary — computed from this week's daily stress
//   2. Daily stress bars (7d) — StressBarChartView
//   3. Distribution stacked bar — DistributionBar (4-tier day counts)
//   4. Calendar heatmap — MonthlyCalendarHeatmap (current month, today outlined)
//   5. HRV trend line — HRVTrendChart (52 ms reference)
//   6. Editorial insight — pattern detected card

struct TrendsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: TrendsViewModel

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
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Chip row — Week / Month / 3 Months
                chipRow
                if viewModel.weeklyMeasurements.isEmpty && !viewModel.isLoading {
                    NoDataCard(dataType: .trends) {
                        Task { await viewModel.loadTrendData() }
                    }
                } else {
                    editorialSummary
                    dailyBars
                    distributionCard
                    calendarCard
                    hrvCard
                    if let insight = viewModel.weeklyInsight {
                        editorialInsight(insight)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(HomeCharacterDesignTokens.homeBackground.ignoresSafeArea())
        .accessibleDynamicType()
        .navigationTitle("Trends")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel = TrendsViewModel(modelContext: modelContext)
            await viewModel.loadTrendData()
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
        return Button {
            viewModel.selectedTimeRange = chip.toTrendsTimeRange
            Task { await viewModel.loadTrendData() }
        } label: {
            Text(chip.title)
                .font(.system(size: 13, weight: isActive ? .semibold : .medium))
                .foregroundStyle(
                    isActive
                        ? Color.white
                        : Color.Wellness.adaptiveSecondaryText
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    isActive
                        ? AnyShapeStyle(Color(hex: "#0288D1"))
                        : AnyShapeStyle(Color.Wellness.adaptiveSecondaryText.opacity(0.08))
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .minimumTouchTarget(DesignTokens.Layout.minTouchTarget)
    }

    // MARK: - 1. Editorial Summary

    private var editorialSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let delta = viewModel.editorialDelta {
                Text("Vs the prior 7 days")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.Wellness.adaptiveSecondaryText.opacity(0.6))

                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("You're ")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Color.Wellness.adaptivePrimaryText)
                    Text(delta)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(deltaColor)
                    Text(".")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Color.Wellness.adaptivePrimaryText)
                }
            }

            Text(viewModel.editorialSummary)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.Wellness.adaptivePrimaryText)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private var deltaColor: Color {
        switch viewModel.stressCalmerPercent ?? 0 {
        case 1...:  return Color(hex: "#34C759")
        case 0:     return Color.Wellness.adaptiveSecondaryText
        default:    return Color(hex: "#FF9500")
        }
    }

    // MARK: - 2. Daily Stress Bars (7d)

    private var dailyBars: some View {
        StressBarChartView(
            dailyStress: viewModel.dailyStressData,
            averageValue: viewModel.dailyStressAverage
        )
    }

    // MARK: - 3. Distribution

    private var distributionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Time spent by tier")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.Wellness.adaptivePrimaryText)
                Spacer()
                Text(viewModel.dailyWindowLabel)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.Wellness.adaptiveSecondaryText.opacity(0.6))
            }
            let d = viewModel.distributionDays
            DistributionBar(
                relaxedDays: d.relaxed,
                mildDays: d.mild,
                moderateDays: d.moderate,
                highDays: d.high,
                comment: viewModel.distributionComment
            )
        }
    }

    // MARK: - 4. Monthly Calendar Heatmap

    private var calendarCard: some View {
        MonthlyCalendarHeatmap(dailyLevels: viewModel.monthlyCalendar)
    }

    // MARK: - 5. HRV Trend

    private var hrvCard: some View {
        HRVTrendChart(
            dataPoints: viewModel.hrvData,
            referenceValue: viewModel.hrvAvg,
            deltaText: viewModel.hrvDeltaText,
            periodLabel: viewModel.selectedTimeRange.periodLabel
        )
    }

    // MARK: - 6. Editorial Insight

    private func editorialInsight(_ insight: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Pattern detected")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText.opacity(0.6))

            Text(insight)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.Wellness.adaptiveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.Wellness.adaptiveSecondaryText.opacity(0.08), lineWidth: 1)
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
