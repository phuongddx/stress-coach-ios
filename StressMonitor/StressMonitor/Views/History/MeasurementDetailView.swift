import SwiftUI
import SwiftData

/// Measurement detail screen matching `12-measurement-detail.html`.
///
/// Layout: big stress score + category label + timestamp → segmented stress-scale
/// position bar → 5-factor breakdown with weight bars → context card (HR/HRV/Sleep/
/// Steps/Mood) → action row (Breathe / Ask Ripple / Share).
struct MeasurementDetailView: View {
    let measurement: StressMeasurement
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @State private var viewModel: DetailViewModel?
    @State private var showChatSheet = false
    @Environment(\.dismiss) private var dismiss

    init(measurement: StressMeasurement) {
        self.measurement = measurement
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                scoreHero
                    .padding(.horizontal, 20)

                stressScaleBar
                    .padding(.horizontal, 20)

                factorBreakdownSection
                    .padding(.horizontal, 20)

                contextCard
                    .padding(.horizontal, 20)

                if let viewModel = viewModel, !viewModel.recommendations.isEmpty {
                    recommendationsCard
                        .padding(.horizontal, 20)
                }

                actionBar
                    .padding(.horizontal, 20)
                    .padding(.top, 2)
            }
            .padding(.vertical, 16)
        }
        .background(Color.appBackground)
        .accessibleDynamicType()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(navTitle)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.Wellness.adaptivePrimaryText)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { viewModel?.shareMeasurement() }) {
                    Image(systemName: AppIconSystem.System.export_.sfSymbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.primaryBlue)
                }
                .minimumTouchTarget(DesignTokens.Layout.minTouchTarget)
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

    // MARK: - Score hero (big number + state + time)

    private var scoreHero: some View {
        VStack(spacing: 4) {
            Text("\(Int(measurement.stressLevel))")
                .font(.system(size: 80, weight: .heavy, design: .rounded))
                .foregroundStyle(category.color)
                .accessibilityLabel("Stress score \(Int(measurement.stressLevel))")

            Text(categoryDisplayName)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(category.color)
                .stressDualCoding(category, showsCaption: false)

            Text(formatFullDate(measurement.timestamp))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
                .tracking(0.4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Stress scale position bar

    private var stressScaleBar: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Stress scale · position")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
                    .tracking(0.4)
                    .textCase(.uppercase)
                Spacer()
            }

            GeometryReader { proxy in
                let width = proxy.size.width
                HStack(spacing: 0) {
                    ForEach(0..<Self.scaleCategories.count, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(segmentColor(i))
                            .frame(height: 8)
                            .overlay(
                                activeSegmentIndex == i
                                    ? RoundedRectangle(cornerRadius: 2)
                                        .stroke(Color.Wellness.adaptivePrimaryText, lineWidth: 2)
                                    : nil
                            )
                            .padding(.trailing, i == Self.scaleCategories.count - 1 ? 0 : 2)
                            .frame(width: width * segmentFraction(i))
                    }
                }
                .overlay(alignment: .leading) {
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.Wellness.adaptivePrimaryText)
                        .offset(x: markerOffset(barWidth: width), y: -12)
                }
            }
            .frame(height: 8)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    ForEach(Self.scaleLabels, id: \.self) { value in
                        let fraction = CGFloat(value) / 100
                        Text("\(value)")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
                            .fixedSize()
                            .alignmentGuide(.leading) { $0.width * fraction }
                            .offset(x: proxy.size.width * fraction)
                    }
                }
            }
            .frame(height: 12)
        }
        .padding(12)
        .background(Color.Wellness.adaptiveCardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - 5-factor breakdown

    private var factorBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("5-factor breakdown")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                FactorBreakdownRow(factor: .hrv, value: factorBreakdown.hrvComponent, detailText: hrvDetailText)
                factorDivider
                FactorBreakdownRow(factor: .heartRate, value: factorBreakdown.hrComponent, detailText: hrDetailText)
                factorDivider
                FactorBreakdownRow(factor: .sleep, value: factorBreakdown.sleepComponent)
                factorDivider
                FactorBreakdownRow(factor: .activity, value: factorBreakdown.activityComponent)
                factorDivider
                FactorBreakdownRow(factor: .recovery, value: factorBreakdown.recoveryComponent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.Wellness.adaptiveCardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            if factorBreakdown.dataCompleteness < 1.0 {
                Text("Some factors were unavailable for this measurement.")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
                    .padding(.horizontal, 4)
                    .padding(.top, 2)
            }
        }
    }

    private var factorDivider: some View {
        Rectangle()
            .fill(Color.Wellness.adaptiveSecondaryText.opacity(0.10))
            .frame(height: 0.5)
    }

    // MARK: - Context card (HR / HRV / Sleep / Steps / Mood)

    private var contextCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Context")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                contextRow(label: "Heart rate", value: heartRateText)
                contextDivider
                contextRow(label: "HRV (SDNN)", value: hrvText)
                contextDivider
                contextRow(label: "Confidence", value: confidenceText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.Wellness.adaptiveCardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func contextRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.Wellness.adaptivePrimaryText)
        }
        .padding(.vertical, 6)
    }

    private var contextDivider: some View {
        Rectangle()
            .fill(Color.Wellness.adaptiveSecondaryText.opacity(0.10))
            .frame(height: 0.5)
    }

    // MARK: - Recommendations

    private var recommendationsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recommendations")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
                .padding(.horizontal, 4)

            VStack(spacing: 10) {
                ForEach(viewModel?.recommendations ?? [], id: \.title) { rec in
                    RecommendationCard(recommendation: rec)
                }
            }
        }
    }

    // MARK: - Action bar

    private var actionBar: some View {
        HStack(spacing: 6) {
            actionButton(icon: "wind", label: "Breathe") {
                router.deepLink(to: .boxBreathing, in: .action)
            }
            actionButton(icon: "bubble.left.fill", label: "Ask Ripple") {
                showChatSheet = true
            }
            actionButton(icon: "square.and.arrow.up", label: "Share") {
                viewModel?.shareMeasurement()
            }
        }
    }

    private func actionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.shared.buttonPress()
            action()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(Color.primaryBlue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.Wellness.adaptiveCardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var category: StressCategory {
        measurement.category
    }

    private var categoryDisplayName: String {
        switch category {
        case .relaxed:  return "Relaxed"
        case .mild:     return "Mild"
        case .moderate: return "Moderate"
        case .high:     return "High"
        case .severe:   return "Severe"
        }
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
    private static let scaleLabels = [0, 25, 50, 75, 100]

    private var activeSegmentIndex: Int {
        Self.scaleCategories.firstIndex(of: StressResult.category(for: measurement.stressLevel)) ?? 0
    }

    private func segmentFraction(_ index: Int) -> CGFloat {
        CGFloat(Self.scaleBounds[index + 1] - Self.scaleBounds[index]) / 100
    }

    private func markerOffset(barWidth: CGFloat) -> CGFloat {
        let clamped = min(1, max(0, measurement.stressLevel / 100))
        return barWidth * clamped - 5
    }

    private func segmentColor(_ index: Int) -> Color {
        switch index {
        case 0: return .stressRelaxed
        case 1: return .stressMild
        case 2: return .stressModerate
        case 3: return .stressHigh
        default: return .stressSevere
        }
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
