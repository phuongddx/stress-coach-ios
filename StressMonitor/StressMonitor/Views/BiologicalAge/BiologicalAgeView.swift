import SwiftData
import SwiftUI

/// Biological Age analytics screen matching `design/screens/18-bio-age.html`.
/// Hero result → honest driver rows (7-day HRV/heart-rate averages only) → daily
/// estimate chart with a chronological-age reference line → Ripple insight →
/// disclaimer. A missing date of birth or thin history shows an explanatory
/// card, never a fake age.
struct BiologicalAgeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: BiologicalAgeViewModel?
    /// Presented as a sheet rather than pushed: this screen is reachable from
    /// more than one tab, so it must not assume which navigation path it is on.
    @State private var showsSources = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let viewModel {
                    if viewModel.chronologicalAge == nil && !viewModel.isLoading {
                        dateOfBirthCard
                    } else if !viewModel.hasSufficientData && !viewModel.isLoading {
                        insufficientDataCard
                    } else if let result = viewModel.result, let chronologicalAge = viewModel.chronologicalAge {
                        hero(result, chronologicalAge: chronologicalAge)
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ScienceInfoButton(topic: .biologicalAge) { _ in
                    showsSources = true
                }
            }
        }
        .sheet(isPresented: $showsSources) {
            NavigationStack {
                ScienceSourcesView(focusedTopic: .biologicalAge)
            }
        }
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

    private func hero(_ result: BioAgeResult, chronologicalAge: Int) -> some View {
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

            Text("Chronological \(chronologicalAge)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Biological age \(result.estimatedAge) years, \(result.differenceLabel), "
                + "chronological \(chronologicalAge)"
        )
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
                    title: "Heart rate",
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
                if let chronologicalAge = viewModel.chronologicalAge {
                    BioAgeDailyChart(
                        estimates: viewModel.dailyEstimates,
                        chronologicalAge: chronologicalAge
                    )
                }
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
        Text("Biological age is an estimate based on HRV and heart rate. Not a medical diagnosis.")
            .font(.system(size: 11, weight: .regular))
            .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
    }

    private var dateOfBirthCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 34))
                .foregroundStyle(Color.primaryBlue.opacity(0.7))
                .accessibilityHidden(true)
            Text("Date of birth needed")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.Wellness.adaptivePrimaryText)
            Text("Add your date of birth in the Health app to see biological age.")
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
