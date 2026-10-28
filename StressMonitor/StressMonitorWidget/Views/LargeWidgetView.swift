import SwiftUI
import Charts
import WidgetKit

/// Large widget — **character face + trend chart + stress-tier descriptor, no numeric score**.
@available(iOS 17.0, *)
public struct LargeWidgetView: View {

    let entry: StressEntry

    public init(entry: StressEntry) {
        self.entry = entry
    }

    @ScaledMetric(relativeTo: .caption2) private var caption2Scale: CGFloat = 1
    @ScaledMetric(relativeTo: .footnote) private var footnoteScale: CGFloat = 1
    @ScaledMetric(relativeTo: .largeTitle) private var largeTitleScale: CGFloat = 1
    @ScaledMetric(relativeTo: .title3) private var title3Scale: CGFloat = 1
    public var body: some View {
        VStack(spacing: 0) {
            if entry.isPlaceholder {
                placeholderView
            } else if let stress = entry.latestStress {
                stressContent(stress: stress, isStale: entry.dataState == .stale)
            } else {
                emptyStateView
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: - Character-Reactive Content

    @ViewBuilder
    private func stressContent(stress: StressData, isStale: Bool) -> some View {
        let tier = WidgetStressTier.from(level: stress.level)

        VStack(spacing: 0) {
            headerSection(tier: tier, stress: stress, isStale: isStale)

            Divider().opacity(0.3)

            if entry.history.count >= 2 {
                historyChartSection(tier: tier)
            } else {
                gatheringDataSection
            }

            Divider().opacity(0.3)

            moodDescriptorsSection(tier: tier)
        }
        .opacity(isStale ? 0.6 : 1.0)
    }

    // MARK: - Header

    @ViewBuilder
    private func headerSection(tier: WidgetStressTier, stress: StressData, isStale: Bool) -> some View {
        HStack(spacing: 14) {
            WidgetCharacterFace(tier: tier, size: 72, showsRing: true, glow: true)

            VStack(alignment: .leading, spacing: 2) {
                Text(tier.label)
                    .font(.system(size: 20 * title3Scale, weight: .bold, design: .rounded))
                    .foregroundColor(tier.accent)
                    .contentTransition(.opacity)

                Text((isStale ? "Stale · " : "") + stress.timestamp.formatted(.relative(presentation: .named)))
                    .font(.system(size: 10 * caption2Scale))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    // MARK: - Gathering Data Placeholder (history not yet published)

    private var gatheringDataSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 20 * title3Scale))
                .foregroundColor(.secondary.opacity(0.6))
            Text("Gathering data…")
                .font(.system(size: 9 * caption2Scale))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .padding(.vertical, 8)
    }

    // MARK: - History Chart (no axis labels)

    @ViewBuilder
    private func historyChartSection(tier: WidgetStressTier) -> some View {
        Chart(entry.history.suffix(24)) { item in
            let pTier = WidgetStressTier.from(level: item.level)
            LineMark(
                x: .value("Time", item.timestamp),
                y: .value("Stress", item.level)
            )
            .foregroundStyle(pTier.accent)
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))

            AreaMark(
                x: .value("Time", item.timestamp),
                y: .value("Stress", item.level)
            )
            .foregroundStyle(
                .linearGradient(
                    colors: [tier.accent.opacity(0.3), tier.accent.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)
        }
        .chartYScale(domain: 0...100)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 6)) { _ in
                AxisGridLine().foregroundStyle(Color.secondary.opacity(0.15))
            }
        }
        .frame(height: 80)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Mood Descriptors (no numbers)

    @ViewBuilder
    private func moodDescriptorsSection(tier: WidgetStressTier) -> some View {
        HStack(spacing: 8) {
            moodPill(icon: "heart.fill", label: moodDescriptor(tier: tier), color: tier.accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func moodPill(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9 * caption2Scale))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10 * caption2Scale, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    private func moodDescriptor(tier: WidgetStressTier) -> String {
        switch tier {
        case .resting:     return "Very low stress"
        case .calm:        return "Low stress"
        case .balanced:    return "Moderate stress"
        case .tense:       return "Elevated stress"
        case .overwhelmed: return "High stress"
        }
    }

    // MARK: - Placeholder

    private var placeholderView: some View {
        VStack(spacing: 8) {
            WidgetCharacterFace(tier: .balanced, size: 60, showsRing: true)
                .opacity(0.5)
            Text("StressMonitor")
                .font(.system(size: 12 * footnoteScale, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding()
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Text("💧")
                .font(.system(size: 36 * largeTitleScale))
            Text("No Data Yet")
                .font(.system(size: 13 * footnoteScale, weight: .medium))
                .foregroundColor(.primary)
            Text("Open StressMonitor and take a measurement to see your character here.")
                .font(.system(size: 10 * caption2Scale))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
private extension StressEntry {
    static var previewLarge: StressEntry {
        let now = Date()
        let history = (0..<12).map { i in
            StressData(
                level: Double(30 + Int.random(in: 0...30)),
                category: "mild", hrv: 50, heartRate: 70,
                confidence: 0.85,
                timestamp: now.addingTimeInterval(TimeInterval(-i * 7200))
            )
        }
        return StressEntry(
            date: now,
            latestStress: StressData(
                level: 45, category: "moderate", hrv: 48,
                heartRate: 72, confidence: 0.82, timestamp: now
            ),
            history: history,
            baseline: (50.0, 60.0),
            isPlaceholder: false
        )
    }
}

@available(iOS 17.0, *)
#Preview {
    LargeWidgetView(entry: .previewLarge)
        .previewContext(WidgetPreviewContext(family: .systemLarge))
}
