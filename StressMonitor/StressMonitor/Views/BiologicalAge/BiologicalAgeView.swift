import SwiftData
import SwiftUI

/// Biological Age analytics screen matching `design/screens/18-bio-age.html`.
/// Hero result → honest driver rows (7-day HRV/RHR averages only) → daily
/// estimate chart with a chronological-age reference line → Ripple insight →
/// disclaimer. Thin history shows an insufficient-data card, never a fake age.
struct BiologicalAgeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: BiologicalAgeViewModel?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let viewModel {
                    if !viewModel.hasSufficientData && !viewModel.isLoading {
                        insufficientDataCard
                    } else if let result = viewModel.result {
                        hero(result, viewModel: viewModel)
                        driversSection(viewModel)
                        if !viewModel.dailyEstimates.isEmpty {
                            chartSection(viewModel)
                        }
                        RippleInsightCard(
                            insight: AIInsight(
                                title: "Biological Age",
                                message: result.characterExpression,
                                actionTitle: nil,
                                trendData: nil
                            ),
                            onAskRipple: nil
                        )
                        disclaimer
                    }
                } else {
                    loadingSkeleton
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(HomeCharacterDesignTokens.homeBackground.ignoresSafeArea())
        .accessibleDynamicType()
        .navigationTitle("Biological Age")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard viewModel == nil else { return }
            let loadedViewModel = BiologicalAgeViewModel(
                repository: StressRepository(modelContext: modelContext)
            )
            viewModel = loadedViewModel
            await loadedViewModel.load()
        }
    }

    // MARK: - Hero

    private func hero(_ result: BioAgeResult, viewModel: BiologicalAgeViewModel) -> some View {
        let tint = heroTint(for: result.difference)

        return VStack(spacing: 6) {
            Text("YOUR BIO AGE")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(result.estimatedAge)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
                Text("yrs")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint)
            }

            Text(result.differenceLabel)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)

            trendRow(result.trend)

            Text("Chronological \(viewModel.chronologicalAge)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Biological age \(result.estimatedAge) years, \(result.differenceLabel), "
                + "\(result.trend.label), chronological \(viewModel.chronologicalAge)"
        )
    }

    /// Trend is dual-coded (icon + text) and tinted with existing adaptive
    /// colors — no prototype-only purple.
    private func trendRow(_ trend: BioAgeTrend) -> some View {
        let tint: Color
        switch trend {
        case .improving:
            tint = .primaryGreen
        case .declining:
            tint = .stressColor(for: .high)
        case .stable:
            tint = .primaryBlue
        }

        return HStack(spacing: 6) {
            Image(systemName: trend.icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(trend.label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
        }
        .accessibilityElement(children: .combine)
    }

    private func heroTint(for difference: Int) -> Color {
        if difference < 0 {
            return .primaryGreen
        }
        if difference > 0 {
            return .stressColor(for: .high)
        }
        return .primaryBlue
    }

    // MARK: - Drivers

    private func driversSection(_ viewModel: BiologicalAgeViewModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WHAT'S DRIVING IT")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText)

            VStack(spacing: 0) {
                driverRow(
                    title: "HRV",
                    detail: "7-day avg",
                    value: viewModel.hrvAverage.map { "\(Int($0.rounded())) ms" } ?? "—"
                )
                driverDivider
                driverRow(
                    title: "Resting heart rate",
                    detail: "7-day avg",
                    value: viewModel.restingHRAverage.map { "\(Int($0.rounded())) bpm" } ?? "—"
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Color.Wellness.adaptiveCardBackground,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
    }

    private func driverRow(title: String, detail: String, value: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.Wellness.adaptivePrimaryText)
                Text(detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
            }
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.Wellness.adaptivePrimaryText)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(detail), \(value)")
    }

    private var driverDivider: some View {
        Rectangle()
            .fill(Color.Wellness.adaptiveSecondaryText.opacity(0.10))
            .frame(height: 0.5)
    }

    // MARK: - Chart

    private func chartSection(_ viewModel: BiologicalAgeViewModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("7-DAY RANGE")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText)

            VStack(alignment: .leading, spacing: 4) {
                Text("Day-by-day estimate")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.Wellness.adaptivePrimaryText)
                BioAgeDailyChart(
                    estimates: viewModel.dailyEstimates,
                    chronologicalAge: viewModel.chronologicalAge
                )
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color.Wellness.adaptiveCardBackground,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
    }

    // MARK: - States

    private var disclaimer: some View {
        Text("Biological age is an estimate based on HRV and resting heart rate. Not a medical diagnosis.")
            .font(.system(size: 11, weight: .regular))
            .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
    }

    private var insufficientDataCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "leaf.circle")
                .font(.system(size: 34))
                .foregroundStyle(Color.primaryGreen.opacity(0.7))
                .accessibilityHidden(true)
            Text("Not enough data yet")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.Wellness.adaptivePrimaryText)
            Text("Take stress readings for at least \(BioAgeCalculator.minimumDataDays) days to see your biological age.")
                .font(.system(size: 13))
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            Color.Wellness.adaptiveCardBackground,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .padding(.top, 24)
    }

    // MARK: - Loading

    private var loadingSkeleton: some View {
        VStack(spacing: 14) {
            SkeletonBlock(height: 120)
            SkeletonBlock(height: 88)
            SkeletonBlock(height: 180)
        }
    }
}

#Preview("Biological Age") {
    NavigationStack {
        BiologicalAgeView()
    }
    .modelContainer(
        for: StressMeasurement.self,
        inMemory: true
    )
}
