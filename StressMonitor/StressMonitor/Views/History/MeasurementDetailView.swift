import SwiftUI
import SwiftData

/// Measurement detail screen (UI V2).
///
/// Layout: header card (small gauge + tier + substate + confidence) → "Where
/// this sits" tier scale → factor card → context card → "What could help"
/// (recommendations) → Breathe / Ask Ripple. Share stays in the toolbar.
///
/// Spec reference: ui-v2-design/screens.js `S.detail`.
struct MeasurementDetailView: View {
    let measurement: StressMeasurement
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var viewModel: DetailViewModel?
    @State private var showChatSheet = false
    @Environment(\.dismiss) private var dismiss

    init(measurement: StressMeasurement) {
        self.measurement = measurement
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                scoreHero
                stressScaleBar
                factorBreakdownSection
                contextCard

                if let viewModel = viewModel, !viewModel.recommendations.isEmpty {
                    recommendationsSection
                }

                actionBar
            }
            .padding(.horizontal, V2Metrics.margin)
            .padding(.vertical, 16)
        }
        .background(Color.V2.bg.ignoresSafeArea())
        .accessibleDynamicType()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(navTitle)
                    .font(.headline)
                    .foregroundStyle(Color.V2.ink)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { viewModel?.shareMeasurement() }) {
                    Image(systemName: AppIconSystem.System.export_.sfSymbol)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.V2.accent)
                        .frame(minWidth: V2Metrics.minTouchTarget, minHeight: V2Metrics.minTouchTarget)
                }
                .accessibilityLabel("Share measurement")
            }
        }
        .task {
            viewModel = DetailViewModel(measurement: measurement, modelContext: modelContext)
            await viewModel?.loadData()
        }
        .sheet(isPresented: $showChatSheet) {
            ChatBottomSheetView(
                stressResult: measurement.stressResult,
                baseline: viewModel?.baseline
            )
        }
    }

    // MARK: - Score header

    private var scoreHero: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 16))
        return V2Card {
            layout {
                V2StressGauge(score: measurement.stressLevel, lineWidth: 10, showsTier: false)
                    .frame(width: 120)
                    .accessibilityLabel("Stress score \(Int(measurement.stressLevel))")

                VStack(alignment: .leading, spacing: 4) {
                    V2TierBadge(category: category, font: .title2.weight(.semibold))
                    Text(category.v2Substate)
                        .font(.subheadline)
                        .foregroundStyle(Color.V2.ink2)
                    Text(formatFullDate(measurement.timestamp))
                        .font(.footnote)
                        .foregroundStyle(Color.V2.ink3)
                    if confidenceText != "—" {
                        Text("\(confidenceText) confidence")
                            .font(.footnote)
                            .foregroundStyle(Color.V2.ink3)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Stress scale position bar

    private var stressScaleBar: some View {
        V2Card {
            VStack(spacing: 8) {
                HStack {
                    Text("0")
                    Spacer()
                    Text("Where this sits")
                    Spacer()
                    Text("100")
                }
                .font(.footnote)
                .foregroundStyle(Color.V2.ink3)

                GeometryReader { proxy in
                    let width = proxy.size.width
                    HStack(spacing: 2) {
                        ForEach(0..<Self.scaleCategories.count, id: \.self) { i in
                            Rectangle()
                                .fill(Self.scaleCategories[i].fillColor)
                                .frame(width: max(0, width * segmentFraction(i) - 2))
                        }
                    }
                    .frame(height: 10)
                    .clipShape(Capsule())
                    .overlay(alignment: .topLeading) {
                        Image(systemName: "arrowtriangle.up.fill")
                            .font(.caption)
                            .foregroundStyle(Color.V2.ink)
                            .offset(x: markerOffset(barWidth: width), y: 12)
                    }
                }
                .frame(height: 28, alignment: .top)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Stress scale position: \(Int(measurement.stressLevel)) of 100, \(category.displayName)")
    }

    // MARK: - Factors

    private var factorBreakdownSection: some View {
        V2Card {
            VStack(alignment: .leading, spacing: 16) {
                Text("Factors")
                    .font(.headline)
                    .foregroundStyle(Color.V2.ink)
                    .accessibilityAddTraits(.isHeader)

                FactorBreakdownRow(factor: .hrv, value: factorBreakdown.hrvComponent, detailText: hrvDetailText)
                FactorBreakdownRow(factor: .heartRate, value: factorBreakdown.hrComponent, detailText: hrDetailText)
                FactorBreakdownRow(factor: .sleep, value: factorBreakdown.sleepComponent)
                FactorBreakdownRow(factor: .activity, value: factorBreakdown.activityComponent)
                FactorBreakdownRow(factor: .recovery, value: factorBreakdown.recoveryComponent)

                if factorBreakdown.dataCompleteness < 1.0 {
                    V2Card(style: .flat, padding: 12) {
                        Text("Some factors were unavailable for this measurement.")
                            .font(.footnote)
                            .foregroundStyle(Color.V2.ink2)
                    }
                }
            }
        }
    }

    // MARK: - Context card (HR / HRV / Confidence)

    private var contextCard: some View {
        V2Card(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Context")
                    .font(.headline)
                    .foregroundStyle(Color.V2.ink)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.horizontal, V2Metrics.margin)
                    .padding(.top, V2Metrics.margin)
                    .padding(.bottom, 4)
                contextRow(label: "Heart rate", value: heartRateText)
                contextDivider
                contextRow(label: "HRV (SDNN)", value: hrvText)
                contextDivider
                contextRow(label: "Confidence", value: confidenceText)
            }
            .padding(.bottom, 4)
        }
    }

    private func contextRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.V2.ink2)
            Spacer()
            Text(value)
                .font(.v2Number(.subheadline))
                .foregroundStyle(Color.V2.ink)
        }
        .padding(.horizontal, V2Metrics.margin)
        .frame(minHeight: V2Metrics.minTouchTarget)
        .accessibilityElement(children: .combine)
    }

    private var contextDivider: some View {
        Rectangle()
            .fill(Color.V2.line)
            .frame(height: 0.5)
            .padding(.leading, V2Metrics.margin)
    }

    // MARK: - What could help

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            V2SectionHeader(title: "What could help")
            VStack(spacing: 0) {
                ForEach(Array((viewModel?.recommendations ?? []).enumerated()), id: \.element.title) { index, rec in
                    if index > 0 { contextDivider.padding(.leading, 52) }
                    RecommendationCard(recommendation: rec)
                }
            }
            .v2CardBackground()
        }
    }

    // MARK: - Action bar

    private var actionBar: some View {
        VStack(spacing: 8) {
            Button {
                HapticManager.shared.buttonPress()
                router.deepLink(to: .boxBreathing, in: .action)
            } label: {
                Label("Breathe 2 min", systemImage: "wind")
            }
            .buttonStyle(.v2(.primary))

            Button {
                HapticManager.shared.buttonPress()
                showChatSheet = true
            } label: {
                Label("Ask Ripple about this reading", systemImage: "bubble.left.fill")
            }
            .buttonStyle(.v2(.secondary))
        }
    }

    // MARK: - Helpers

    private var category: StressCategory {
        measurement.category
    }

    private var navTitle: String {
        let time = formatTimeShort(measurement.timestamp)
        let cal = Calendar.current
        let prefix: String
        if cal.isDateInToday(measurement.timestamp) { prefix = "Today" }
        else if cal.isDateInYesterday(measurement.timestamp) { prefix = "Yesterday" }
        else { prefix = formatDateShort(measurement.timestamp) }
        return "\(prefix) · \(time)"
    }

    /// Builds a `FactorBreakdown` from the measurement's individual component fields.
    private var factorBreakdown: FactorBreakdown {
        FactorBreakdown(
            hrvComponent: measurement.hrvComponent,
            hrComponent: measurement.hrComponent,
            sleepComponent: measurement.sleepComponent,
            activityComponent: measurement.activityComponent,
            recoveryComponent: measurement.recoveryComponent,
            dataCompleteness: measurement.dataCompleteness ?? 0
        )
    }

    private var hrvText: String {
        measurement.hrv > 0 ? "\(Int(measurement.hrv)) ms" : "—"
    }

    private var heartRateText: String {
        measurement.restingHeartRate > 0 ? "\(Int(measurement.restingHeartRate)) bpm" : "—"
    }

    private var hrvDetailText: String? { measurement.hrv > 0 ? hrvText : nil }
    private var hrDetailText: String? { measurement.restingHeartRate > 0 ? heartRateText : nil }

    private var confidenceText: String {
        guard let confidences = measurement.confidences, !confidences.isEmpty else { return "—" }
        let avg = confidences.reduce(0, +) / Double(confidences.count)
        return "\(Int(avg * 100))%"
    }

    private static let scaleCategories: [StressCategory] = [.relaxed, .mild, .moderate, .high, .severe]
    /// Lower edge of each tier, then the scale maximum. Mirrors `StressResult.category(for:)`.
    private static let scaleBounds: [Double] = [0, 25, 50, 75, 90, 100]
    private func segmentFraction(_ index: Int) -> CGFloat {
        CGFloat(Self.scaleBounds[index + 1] - Self.scaleBounds[index]) / 100
    }

    private func markerOffset(barWidth: CGFloat) -> CGFloat {
        let clamped = min(1, max(0, measurement.stressLevel / 100))
        return barWidth * clamped - 6
    }

    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d · h:mm a"
        return formatter.string(from: date)
    }

    private func formatDateShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private func formatTimeShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}
