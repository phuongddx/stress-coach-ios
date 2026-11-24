import SwiftData
import SwiftUI

/// Immediate post-reading result screen (UI V2).
///
/// Distinct from the retrospective `MeasurementDetailView`: this renders the
/// live `StressResult` the Home hero just produced. Layout: V2 gauge → delta
/// pill vs the previous reading → time and confidence → "What shaped this
/// score" factor card → Ripple takeaway → Breathe / Mini walk → View history.
///
/// Spec reference: ui-v2-design/screens.js `S.result`.
struct MeasurementResultView: View {
    let result: StressResult

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var viewModel: MeasurementResultViewModel?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let viewModel {
                    scoreHero(viewModel)
                    factorSection(viewModel)
                    if let insight = viewModel.insight {
                        RippleInsightCard(insight: insight, onAskRipple: nil)
                    }
                    actionRow
                    historyLink
                } else {
                    loadingSkeleton
                }
            }
            .padding(.horizontal, V2Metrics.margin)
            .padding(.vertical, 16)
        }
        .background(Color.V2.bg.ignoresSafeArea())
        .accessibleDynamicType()
        .navigationTitle("Your reading")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: Route.scienceSources(topic: .stressScore)) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(Color.V2.accent)
                        .frame(minWidth: V2Metrics.minTouchTarget, minHeight: V2Metrics.minTouchTarget)
                }
                .accessibilityLabel("About the stress score")
            }
        }
        .task {
            guard viewModel == nil else { return }
            let loadedViewModel = MeasurementResultViewModel(
                result: result,
                repository: StressRepository(modelContext: modelContext)
            )
            viewModel = loadedViewModel
            await loadedViewModel.load()
        }
    }

    // MARK: - Gauge hero

    private func scoreHero(_ viewModel: MeasurementResultViewModel) -> some View {
        VStack(spacing: 8) {
            V2StressGauge(score: result.level)
                .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? 280 : 232)

            if let deltaLabel = viewModel.deltaLabel {
                deltaPill(deltaLabel, delta: viewModel.previousDelta ?? 0)
            }

            Text("\(result.timestamp.formatted(date: .omitted, time: .shortened)) · \(viewModel.confidenceLabel)")
                .font(.footnote)
                .foregroundStyle(Color.V2.ink3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    /// Lower than last time is good; higher is not. No change gets a neutral capsule.
    @ViewBuilder
    private func deltaPill(_ label: String, delta: Int) -> some View {
        if delta == 0 {
            HStack(spacing: 4) {
                Image(systemName: "equal")
                    .imageScale(.small)
                    .accessibilityHidden(true)
                Text(label)
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.V2.ink2)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.V2.surface2))
        } else {
            V2DeltaPill(text: label, isUp: delta > 0, isGood: delta < 0)
        }
    }

    // MARK: - Factors

    private func factorSection(_ viewModel: MeasurementResultViewModel) -> some View {
        V2Card {
            VStack(alignment: .leading, spacing: 16) {
                Text("What shaped this score")
                    .font(.headline)
                    .foregroundStyle(Color.V2.ink)
                    .accessibilityAddTraits(.isHeader)

                if viewModel.factorRows.isEmpty {
                    Text("Breakdown unavailable for this reading.")
                        .font(.subheadline)
                        .foregroundStyle(Color.V2.ink2)
                } else {
                    ForEach(viewModel.factorRows) { row in
                        FactorBreakdownRow(
                            factor: row.factor,
                            value: row.value,
                            detailText: row.detailText
                        )
                    }

                    if let breakdown = result.factorBreakdown, breakdown.dataCompleteness < 1.0 {
                        V2Card(style: .flat, padding: 12) {
                            Text("Some factors were unavailable for this reading.")
                                .font(.footnote)
                                .foregroundStyle(Color.V2.ink2)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private var actionRow: some View {
        // Stacked: full-width buttons never truncate, at any text size.
        VStack(spacing: 8) { actionLinks }
    }

    @ViewBuilder
    private var actionLinks: some View {
        NavigationLink(value: Route.boxBreathing) {
            Label("Breathe 2 min", systemImage: "wind")
                .lineLimit(1)
        }
        .buttonStyle(.v2(.primary))
        .simultaneousGesture(hapticGesture)

        NavigationLink(value: Route.miniWalk) {
            Label("Mini walk", systemImage: "figure.walk")
                .lineLimit(1)
        }
        .buttonStyle(.v2(.secondary))
        .simultaneousGesture(hapticGesture)
    }

    private var historyLink: some View {
        NavigationLink(value: Route.history) {
            Text("View history")
        }
        .buttonStyle(.v2(.ghost))
        .simultaneousGesture(hapticGesture)
    }

    private var hapticGesture: some Gesture {
        TapGesture().onEnded {
            HapticManager.shared.buttonPress()
        }
    }

    // MARK: - Loading

    private var loadingSkeleton: some View {
        VStack(spacing: 16) {
            V2Skeleton(width: 200, height: 200, cornerRadius: 100)
            V2Skeleton(width: 180, height: 16)
            SkeletonBlock(height: 260)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("Measurement Result") {
    NavigationStack {
        MeasurementResultView(
            result: StressResult(
                level: 42,
                category: .mild,
                confidence: 0.96,
                hrv: 52,
                heartRate: 68,
                factorBreakdown: FactorBreakdown(
                    hrvComponent: 0.72,
                    hrComponent: 0.41,
                    sleepComponent: 0.35,
                    activityComponent: nil,
                    recoveryComponent: 0.48,
                    dataCompleteness: 0.85
                )
            )
        )
    }
    .modelContainer(
        for: StressMeasurement.self,
        inMemory: true
    )
}
