import SwiftUI
import Charts
import WidgetKit

/// Medium widget (UI V2): score and tier on the left, recent readings on the
/// right. Fewer than two readings shows "Gathering data…"; stale readings dim
/// and say when they were last updated; no reading shows "—".
@available(iOS 17.0, *)
public struct MediumWidgetView: View {

    let entry: StressEntry

    public init(entry: StressEntry) {
        self.entry = entry
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 16) {
            summaryColumn
                .frame(width: 128, alignment: .leading)
                .frame(maxHeight: .infinity, alignment: .topLeading)
            historyColumn
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WidgetReadingText.accessibilitySummary(entry.latestStress, state: entry.dataState))
        .widgetV2HomeContainer(isPlaceholder: entry.isPlaceholder)
    }

    // MARK: - Summary

    private var summaryColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Stress AI Coach")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.V2.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 0)

            if let stress = entry.latestStress {
                let isStale = entry.dataState == .stale
                Group {
                    WidgetScoreText(level: stress.level)
                    WidgetTierLabel(category: stress.stressCategory)
                }
                .opacity(isStale ? 0.6 : 1)
                Text(isStale ? WidgetReadingText.updated(stress, state: entry.dataState) : WidgetReadingText.time(stress.timestamp))
                    .font(.caption2)
                    .foregroundStyle(isStale ? Color.V2.ink2 : Color.V2.ink3)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else {
                WidgetScoreText(level: nil)
                Text("No reading yet")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.V2.ink)
                    .lineLimit(1)
                Text("Open the app to measure")
                    .font(.caption2)
                    .foregroundStyle(Color.V2.ink3)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    // MARK: - History

    private var historyColumn: some View {
        let readings = widgetRecentReadings(entry.history, limit: 12)

        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center) {
                Text("Recent readings")
                    .font(.caption2)
                    .foregroundStyle(Color.V2.ink3)
                    .lineLimit(1)
                Spacer(minLength: 4)
                WidgetCompanionBadge(category: entry.latestStress?.stressCategory, size: 30)
            }

            if entry.latestStress == nil {
                Text("Readings appear here after your first measurement.")
                    .font(.footnote)
                    .foregroundStyle(Color.V2.ink3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            } else if readings.count >= 2 {
                WidgetTrendLine(readings: readings)
                    .opacity(entry.dataState == .stale ? 0.6 : 1)
            } else {
                WidgetGatheringView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
private extension StressEntry {
    static var previewMedium: StressEntry {
        let now = Date()
        let history: [StressData] = (0..<8).map { i -> StressData in
            let level = Double(40 + i * 3)
            let offset = TimeInterval(-i * 3600)
            return StressData(
                level: level,
                category: "mild",
                hrv: 50,
                heartRate: 70,
                confidence: 0.85,
                timestamp: now.addingTimeInterval(offset)
            )
        }
        return StressEntry(
            date: now,
            latestStress: StressData(
                level: 55, category: "moderate", hrv: 42,
                heartRate: 75, confidence: 0.8, timestamp: now
            ),
            history: history,
            baseline: (50.0, 60.0),
            isPlaceholder: false
        )
    }
}

@available(iOS 17.0, *)
#Preview {
    MediumWidgetView(entry: .previewMedium)
        .previewContext(WidgetPreviewContext(family: .systemMedium))
}
