import SwiftData
import SwiftUI

/// Immediate post-reading result screen matching `design/screens/07-measurement.html`.
///
/// Distinct from the retrospective `MeasurementDetailView`: this renders the
/// live `StressResult` the Home hero just produced. Layout: score ring →
/// confidence row → vs-previous delta ribbon → 5-factor breakdown → Ripple
/// takeaway → Breathe / Mini Walk actions → "View history" CTA.
struct MeasurementResultView: View {
    let result: StressResult

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: MeasurementResultViewModel?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if let viewModel {
                    scoreHero
                    confidenceRow(viewModel)
                    if let deltaLabel = viewModel.deltaLabel {
                        deltaRibbon(deltaLabel)
                    }
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
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(HomeCharacterDesignTokens.homeBackground.ignoresSafeArea())
        .accessibleDynamicType()
        .navigationTitle("Result")
        .navigationBarTitleDisplayMode(.inline)
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

    // MARK: - Score ring

    private var scoreHero: some View {
        ZStack {
            Circle()
                .stroke(Color.Wellness.adaptiveSecondaryText.opacity(0.10), lineWidth: 13)
            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(
                    LinearGradient(
                        colors: [result.category.color.opacity(0.85), result.category.color],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 13, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text("\(Int(result.level.rounded()))")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(result.category.color)

                Text(result.category.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(result.category.color)
                    .stressDualCoding(result.category, showsCaption: false)

                Text(result.timestamp, format: .dateTime.hour().minute())
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(0.4)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
                    .padding(.top, 2)
            }
        }
        .frame(width: 200, height: 200)
        .padding(.top, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Stress score \(Int(result.level.rounded())), \(result.category.displayName)"
        )
    }

    private var ringProgress: Double {
        min(1, max(0.01, result.level / 100))
    }

    // MARK: - Confidence + delta

    private func confidenceRow(_ viewModel: MeasurementResultViewModel) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.primaryGreen)
                .frame(width: 6, height: 6)
                .accessibilityHidden(true)
            Text(viewModel.confidenceLabel)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func deltaRibbon(_ label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: deltaIcon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(deltaColor)
                .accessibilityHidden(true)
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(deltaColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(deltaColor.opacity(0.10), in: Capsule())
        .accessibilityElement(children: .combine)
    }

    private var deltaIcon: String {
        guard let previousDelta = viewModel?.previousDelta else { return "minus" }
        switch previousDelta {
        case ..<0: return "arrow.down.circle.fill"
        case 1...: return "arrow.up.circle.fill"
        default: return "minus.circle.fill"
        }
    }

    private var deltaColor: Color {
        guard let previousDelta = viewModel?.previousDelta else {
            return Color.Wellness.adaptiveSecondaryText
        }
        switch previousDelta {
        case ..<0: return .stressRelaxed
        case 1...: return .stressHigh
        default: return Color.Wellness.adaptiveSecondaryText
        }
    }

    // MARK: - 5-factor breakdown

    private func factorSection(_ viewModel: MeasurementResultViewModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("5-factor breakdown")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
                .padding(.horizontal, 4)

            if viewModel.factorRows.isEmpty {
                Text("Breakdown unavailable for this reading.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        Color.Wellness.adaptiveCardBackground,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.factorRows.enumerated()), id: \.element.id) { pair in
                        if pair.offset > 0 {
                            factorDivider
                        }
                        FactorBreakdownRow(
                            factor: pair.element.factor,
                            value: pair.element.value,
                            detailText: pair.element.detailText
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Color.Wellness.adaptiveCardBackground,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )

                if let breakdown = result.factorBreakdown, breakdown.dataCompleteness < 1.0 {
                    Text("Some factors were unavailable for this reading.")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
                        .padding(.horizontal, 4)
                        .padding(.top, 2)
                }
            }
        }
    }

    private var factorDivider: some View {
        Rectangle()
            .fill(Color.Wellness.adaptiveSecondaryText.opacity(0.10))
            .frame(height: 0.5)
    }

    // MARK: - Actions

    private var actionRow: some View {
        HStack(spacing: 10) {
            routeLink(route: .boxBreathing, title: "Breathe 2min", icon: "wind", style: .secondary)
            routeLink(route: .miniWalk, title: "Mini Walk", icon: "figure.walk", style: .primary)
        }
        .padding(.top, 2)
    }

    private var historyLink: some View {
        NavigationLink(value: Route.history) {
            Text("View history")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.primaryBlue)
        }
        .buttonStyle(.plain)
        .minimumTouchTarget(DesignTokens.Layout.minTouchTarget)
        .simultaneousGesture(hapticGesture)
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
    }

    private enum ActionStyle {
        case primary
        case secondary
    }

    private func routeLink(route: Route, title: String, icon: String, style: ActionStyle) -> some View {
        NavigationLink(value: route) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .accessibilityHidden(true)
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                style == .primary ? AnyShapeStyle(Color.primaryBlue) : AnyShapeStyle(Color.Wellness.adaptiveCardBackground),
                in: Capsule()
            )
            .foregroundStyle(
                style == .primary
                    ? AnyShapeStyle(Color.white)
                    : AnyShapeStyle(Color.primaryBlue)
            )
        }
        .buttonStyle(.plain)
        .minimumTouchTarget(DesignTokens.Layout.minTouchTarget)
        .simultaneousGesture(hapticGesture)
    }

    private var hapticGesture: some Gesture {
        TapGesture().onEnded {
            HapticManager.shared.buttonPress()
        }
    }

    // MARK: - Loading

    private var loadingSkeleton: some View {
        VStack(spacing: 14) {
            Circle()
                .stroke(Color.Wellness.adaptiveSecondaryText.opacity(0.10), lineWidth: 13)
                .frame(width: 200, height: 200)
                .padding(.top, 6)

            SkeletonBlock(height: 24)
            SkeletonBlock(height: 260)
            SkeletonBlock(height: 64)
        }
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
