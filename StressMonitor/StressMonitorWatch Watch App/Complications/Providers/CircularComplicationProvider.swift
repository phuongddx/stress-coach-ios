import WidgetKit
import SwiftUI

// MARK: - Circular Complication Provider
/// WidgetKit provider for circular watchOS complications
/// Displays a full-circle stress gauge with color-coded levels
struct CircularComplicationProvider: TimelineProvider {

    // MARK: - TimelineProvider
    /// Placeholder entry during complication loading
    func placeholder(in context: Context) -> CircularComplicationEntry {
        CircularComplicationEntry(
            date: Date(),
            entry: ComplicationEntry.placeholder
        )
    }

    /// Snapshot for complication gallery
    func getSnapshot(in context: Context, completion: @escaping (CircularComplicationEntry) -> Void) {
        let entry = ComplicationDataProvider.shared.fetchLatestEntry()
        completion(CircularComplicationEntry(
            date: Date(),
            entry: entry
        ))
    }

    /// Timeline entries for complication display
    func getTimeline(in context: Context, completion: @escaping (Timeline<CircularComplicationEntry>) -> Void) {
        let entry = ComplicationDataProvider.shared.fetchLatestEntry()
        let nextRefresh = ComplicationDataProvider.shared.nextRefreshDate()

        completion(Timeline(
            entries: [
                CircularComplicationEntry(
                    date: Date(),
                    entry: entry
                )
            ],
            policy: .after(nextRefresh)
        ))
    }
}

// MARK: - Circular Complication Entry
/// Timeline entry for circular complications
struct CircularComplicationEntry: TimelineEntry {
    let date: Date
    let entry: ComplicationEntry
}

// MARK: - Circular Complication View
/// SwiftUI view for circular complication display (UI V2).
///
/// The same 240° gauge geometry as Home and the iPhone hero: `surface2`
/// track, tier-fill value arc, the score in the centre and the tier shape
/// in the arc's opening. "—" and an empty track when there is no data.
struct CircularComplicationView: View {
    @Environment(\.widgetFamily) var family
    let entry: CircularComplicationEntry

    var body: some View {
        WatchStressGauge(score: entry.entry.isPlaceholder ? nil : entry.entry.stressLevel, lineWidth: 4) {
            VStack(spacing: 0) {
                Text(entry.entry.isPlaceholder ? "—" : "\(Int(entry.entry.stressLevel.rounded()))")
                    .font(.v2Number(.headline, weight: .bold))
                    .foregroundStyle(entry.entry.isPlaceholder ? WatchV2.ink3 : WatchV2.ink)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if !entry.entry.isPlaceholder {
                    Image(systemName: entry.entry.category.icon)
                        .font(.caption2)
                        .imageScale(.small)
                        .foregroundStyle(stressColor)
                        .widgetAccentable()
                }
            }
            .offset(y: 3)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entry.entry.isPlaceholder
            ? "No stress reading yet"
            : entry.entry.category.accessibilityValue(level: entry.entry.stressLevel))
        .widgetURL(deepLinkURL)
    }

    // MARK: - Computed Properties
    private var stressColor: Color {
        entry.entry.category.color
    }

    private var deepLinkURL: URL? {
        URL(string: "stressmonitor://dashboard")
    }
}

// MARK: - Circular Complication Widget
/// Widget definition for circular complication family
struct CircularComplication: Widget {
    let kind: String = "CircularComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CircularComplicationProvider()) { entry in
            CircularComplicationView(entry: entry)
                .containerBackground(for: .widget) {
                    WatchFaceBackgroundView(
                        style: WatchFacePreferences.backgroundStyle,
                        theme: WatchFacePreferences.theme
                    )
                }
        }
        .configurationDisplayName("Stress Ring")
        .description("Shows your current stress level as a color-coded ring")
        .supportedFamilies([.accessoryCircular])
    }
}

// MARK: - Preview
#Preview(as: .accessoryCircular) {
    CircularComplication()
} timeline: {
    CircularComplicationEntry(
        date: Date(),
        entry: ComplicationEntry(
            stressLevel: 25,
            category: .mild,
            hrv: 45,
            heartRate: 68,
            timestamp: Date()
        )
    )
}
