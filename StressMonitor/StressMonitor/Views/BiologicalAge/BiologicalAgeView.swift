import SwiftData
import SwiftUI

/// Biological Age analytics screen (UI V2, `S.bioage`).
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

    @ScaledMetric(relativeTo: .largeTitle) private var heroNumberSize: CGFloat = 72

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let viewModel, !(viewModel.isLoading && viewModel.result == nil) {
                    if viewModel.chronologicalAge == nil && !viewModel.isLoading {
                        dateOfBirthCard
                        disclaimer
                    } else if !viewModel.hasSufficientData && !viewModel.isLoading {
                        insufficientDataCard
                        disclaimer
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
            .padding(.horizontal, V2Metrics.margin)
            .padding(.vertical, 16)
        }
        .background(Color.V2.bg.ignoresSafeArea())
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
        VStack(spacing: 4) {
            Text("Estimated")
                .v2Eyebrow()

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(result.estimatedAge)")
                    .font(.system(size: heroNumberSize, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Color.V2.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("yrs")
                    .font(.v2Number(.title3))
                    .foregroundStyle(Color.V2.ink2)
            }

            Text("Your age \(chronologicalAge) · \(Text(result.differenceLabel).fontWeight(.semibold).foregroundStyle(differenceColor(for: result.difference)))")
                .font(.subheadline)
                .foregroundStyle(Color.V2.ink2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, V2Metrics.margin)
        .v2CardBackground()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Biological age \(result.estimatedAge) years, \(result.differenceLabel), "
                + "chronological \(chronologicalAge)"
        )
    }

    /// Younger reads in the Relaxed text colour, older in the High text
    /// colour; the word itself always carries the meaning.
    private func differenceColor(for difference: Int) -> Color {
        if difference < 0 { return StressCategory.relaxed.color }
        if difference > 0 { return StressCategory.high.color }
        return Color.V2.ink2
    }

    // MARK: - Drivers

    private func driversSection(_ viewModel: BiologicalAgeViewModel) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("What drives it")
                .font(.headline)
                .foregroundStyle(Color.V2.ink)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, 4)

            driverRow(
                icon: AppIconSystem.Metric.hrv.sfSymbol,
                title: "HRV",
                detail: "7-day avg",
                value: viewModel.hrvAverage.map { "\(Int($0.rounded())) ms" } ?? "—"
            )
            driverDivider
            driverRow(
                icon: "heart.fill",
                title: "Heart rate",
                detail: "7-day avg",
                value: viewModel.restingHRAverage.map { "\(Int($0.rounded())) bpm" } ?? "—"
            )
        }
        .padding(V2Metrics.margin)
        .frame(maxWidth: .infinity, alignment: .leading)
        .v2CardBackground()
    }

    private func driverRow(icon: String, title: String, detail: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Color.V2.accent)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: V2Metrics.radiusXS, style: .continuous)
                        .fill(Color.V2.accentSoft)
                )
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.V2.ink)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Color.V2.ink3)
            }
            Spacer(minLength: 8)
            Text(value)
                .font(.v2Number(.subheadline))
                .foregroundStyle(Color.V2.ink)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(detail), \(value)")
    }

    private var driverDivider: some View {
        Rectangle()
            .fill(Color.V2.line)
            .frame(height: 0.5)
            .padding(.leading, 48)
    }

    // MARK: - Chart

    private func chartSection(_ viewModel: BiologicalAgeViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    chartTitle
                    Spacer(minLength: 8)
                    chartCaption
                }
                VStack(alignment: .leading, spacing: 2) {
                    chartTitle
                    chartCaption
                }
            }
            if let chronologicalAge = viewModel.chronologicalAge {
                BioAgeDailyChart(
                    estimates: viewModel.dailyEstimates,
                    chronologicalAge: chronologicalAge
                )
                .plusLocked(.bioAgeDaily)
            }
        }
        .padding(V2Metrics.margin)
        .frame(maxWidth: .infinity, alignment: .leading)
        .v2CardBackground()
    }

    private var chartTitle: some View {
        Text("Daily estimate")
            .font(.headline)
            .foregroundStyle(Color.V2.ink)
            .accessibilityAddTraits(.isHeader)
    }

    private var chartCaption: some View {
        Text("Last 7 days")
            .font(.footnote)
            .foregroundStyle(Color.V2.ink3)
    }

    // MARK: - States

    private var disclaimer: some View {
        Text("Biological age is an estimate based on HRV and heart rate. Not a medical diagnosis.")
            .font(.footnote)
            .foregroundStyle(Color.V2.ink3)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
            .padding(.top, 4)
    }

    private var dateOfBirthCard: some View {
        V2StateView(
            systemImage: "calendar.badge.plus",
            title: "Add your date of birth",
            message: "Biological age compares your heart signals with typical values for your age. Add your date of birth in the Health app to see it."
        )
        .padding(.vertical, 8)
        .v2CardBackground()
        .accessibilityElement(children: .combine)
        .padding(.top, 8)
    }

    private var insufficientDataCard: some View {
        V2StateView(
            systemImage: "hourglass",
            title: "Needs a week of data",
            message: "Take stress readings for at least \(BioAgeCalculator.minimumDataDays) days to see your biological age."
        )
        .padding(.vertical, 8)
        .v2CardBackground()
        .accessibilityElement(children: .combine)
        .padding(.top, 8)
    }

    // MARK: - Loading

    private var loadingSkeleton: some View {
        VStack(spacing: 12) {
            V2Skeleton(height: 150, cornerRadius: V2Metrics.radiusLG)
            V2Skeleton(height: 120, cornerRadius: V2Metrics.radiusLG)
            V2Skeleton(height: 200, cornerRadius: V2Metrics.radiusLG)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading biological age")
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
