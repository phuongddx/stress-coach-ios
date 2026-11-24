import SwiftUI
import Charts
import WidgetKit

/// Large widget (UI V2): companion, score, tier and substate, one Ripple line,
/// and recent readings as tier-coloured bars. Fewer than two readings shows
/// "Gathering data…"; stale readings dim and say when they were last updated;
/// no reading shows "—".
@available(iOS 17.0, *)
public struct LargeWidgetView: View {

    let entry: StressEntry

    public init(entry: StressEntry) {
        self.entry = entry
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if let stress = entry.latestStress {
                readingContent(stress)
            } else {
                emptyContent
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WidgetReadingText.accessibilitySummary(entry.latestStress, state: entry.dataState))
        .widgetV2HomeContainer(isPlaceholder: entry.isPlaceholder)
    }

    private var isStale: Bool { entry.dataState == .stale }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("Stress AI Coach")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.V2.accent)
            Spacer(minLength: 4)
            if let stress = entry.latestStress {
                Text(WidgetReadingText.updated(stress, state: entry.dataState))
                    .font(.caption2)
                    .foregroundStyle(isStale ? Color.V2.ink2 : Color.V2.ink3)
            }
        }
        .lineLimit(1)
    }

    // MARK: - Reading

    @ViewBuilder
    private func readingContent(_ stress: StressData) -> some View {
        let category = stress.stressCategory

        HStack(alignment: .center, spacing: 12) {
            WidgetCompanionBadge(tier: WidgetStressTier.from(category: category), size: 64)
            VStack(alignment: .leading, spacing: 2) {
                WidgetScoreText(level: stress.level)
                WidgetTierLabel(category: category, font: .headline)
                Text(isStale ? "Not updated recently" : category.v2Substate)
                    .font(.footnote)
                    .foregroundStyle(Color.V2.ink2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .opacity(isStale ? 0.6 : 1)

        let ripple = Text("Ripple:").fontWeight(.semibold).foregroundStyle(Color.V2.ink)
        Text("\(ripple) \(isStale ? "Open the app for a fresh reading." : category.widgetTip)")
            .font(.footnote)
            .foregroundStyle(Color.V2.ink2)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.V2.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

        let readings = widgetRecentReadings(entry.history, limit: 12)
        VStack(alignment: .leading, spacing: 6) {
            Text("Recent readings")
                .font(.caption2)
                .foregroundStyle(Color.V2.ink3)
            if readings.count >= 2 {
                WidgetHistoryBars(readings: readings)
                    .opacity(isStale ? 0.6 : 1)
            } else {
                WidgetGatheringView()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 80, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Empty

    @ViewBuilder
    private var emptyContent: some View {
        HStack(alignment: .center, spacing: 12) {
            WidgetCompanionBadge(tier: .resting, size: 64)
            VStack(alignment: .leading, spacing: 2) {
                WidgetScoreText(level: nil)
                Text("No reading yet")
                    .font(.headline)
                    .foregroundStyle(Color.V2.ink)
            }
        }

        Text("Open Stress AI Coach and take a measurement to see your stress here.")
            .font(.footnote)
            .foregroundStyle(Color.V2.ink2)
            .fixedSize(horizontal: false, vertical: true)

        VStack(alignment: .leading, spacing: 6) {
            Text("Recent readings")
                .font(.caption2)
                .foregroundStyle(Color.V2.ink3)
            Text("Readings appear here after your first measurement.")
                .font(.footnote)
                .foregroundStyle(Color.V2.ink3)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .multilineTextAlignment(.center)
                .background(Color.V2.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .frame(maxWidth: .infinity, minHeight: 80, maxHeight: .infinity, alignment: .topLeading)
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
