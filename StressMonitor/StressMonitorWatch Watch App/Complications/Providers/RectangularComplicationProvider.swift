import WidgetKit
import SwiftUI

// MARK: - Rectangular Complication Provider
/// WidgetKit provider for rectangular watchOS complications
/// Displays stress score with HRV trend in a compact rectangular layout
struct RectangularComplicationProvider: TimelineProvider {

    // MARK: - TimelineProvider
    /// Placeholder entry during complication loading
    func placeholder(in context: Context) -> RectangularComplicationEntry {
        RectangularComplicationEntry(
            date: Date(),
            entry: ComplicationEntry.placeholder
        )
    }

    /// Snapshot for complication gallery
    func getSnapshot(in context: Context, completion: @escaping (RectangularComplicationEntry) -> Void) {
        let entry = ComplicationDataProvider.shared.fetchLatestEntry()
        completion(RectangularComplicationEntry(
            date: Date(),
            entry: entry
        ))
    }

    /// Timeline entries for complication display
    func getTimeline(in context: Context, completion: @escaping (Timeline<RectangularComplicationEntry>) -> Void) {
        let entry = ComplicationDataProvider.shared.fetchLatestEntry()
        let nextRefresh = ComplicationDataProvider.shared.nextRefreshDate()

        completion(Timeline(
            entries: [
                RectangularComplicationEntry(
                    date: Date(),
                    entry: entry
                )
            ],
            policy: .after(nextRefresh)
        ))
    }
}

// MARK: - Rectangular Complication Entry
/// Timeline entry for rectangular complications
struct RectangularComplicationEntry: TimelineEntry {
    let date: Date
    let entry: ComplicationEntry
}

// MARK: - Rectangular Complication View
/// SwiftUI view for rectangular complication display (UI V2).
///
/// Companion on the leading edge, then "Stress N", the tier (shape + name
/// in the tier colour) with HRV, and a level bar in the tier fill.
/// "—" / "No data" and an empty bar when there is no reading.
struct RectangularComplicationView: View {
    let entry: RectangularComplicationEntry

    private var data: ComplicationEntry { entry.entry }

    var body: some View {
        HStack(spacing: 8) {
            CharacterFaceView(creature: .ripple, category: data.isPlaceholder ? nil : data.category, size: 26, showsHalo: false)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("Stress")
                        .font(.footnote)
                        .foregroundStyle(WatchV2.ink2)
                    Text(data.stressLevelText)
                        .font(.v2Number(.headline, weight: .bold))
                        .foregroundStyle(data.isPlaceholder ? WatchV2.ink3 : WatchV2.ink)
                }

                HStack(spacing: 4) {
                    if data.isPlaceholder {
                        Text("No data")
                            .foregroundStyle(WatchV2.ink3)
                    } else {
                        Image(systemName: data.category.icon)
                            .imageScale(.small)
                            .foregroundStyle(stressColor)
                            .widgetAccentable()
                        Text(data.category.displayName)
                            .foregroundStyle(stressColor)
                        Text("· HRV \(data.hrvText) ms")
                            .foregroundStyle(WatchV2.ink3)
                    }
                }
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

                Capsule()
                    .fill(WatchV2.surface2)
                    .frame(height: 3)
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            Capsule()
                                .fill(stressColor)
                                .frame(width: proxy.size.width * fraction)
                                .widgetAccentable()
                        }
                    }
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(data.isPlaceholder
            ? "No stress reading yet"
            : "\(data.category.accessibilityValue(level: data.stressLevel)), HRV \(data.hrvText) milliseconds")
        .widgetURL(deepLinkURL)
    }

    private var fraction: CGFloat {
        data.isPlaceholder ? 0 : CGFloat(min(max(data.stressLevel, 0), 100) / 100)
    }

    // MARK: - Computed Properties
    private var stressColor: Color {
        entry.entry.category.color
    }

    private var deepLinkURL: URL? {
        URL(string: "stressmonitor://dashboard")
    }
}

// MARK: - Rectangular Complication Widget
/// Widget definition for rectangular complication family
struct RectangularComplication: Widget {
    let kind: String = "RectangularComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RectangularComplicationProvider()) { entry in
            RectangularComplicationView(entry: entry)
                .containerBackground(for: .widget) {
                    WatchFaceBackgroundView(
                        style: WatchFacePreferences.backgroundStyle,
                        theme: WatchFacePreferences.theme
                    )
                }
        }
        .configurationDisplayName("Stress & HRV")
        .description("Shows your current stress level and HRV measurement")
        .supportedFamilies([.accessoryRectangular])
    }
}

// MARK: - Preview
#Preview(as: .accessoryRectangular) {
    RectangularComplication()
} timeline: {
    RectangularComplicationEntry(
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

#Preview("High Stress") {
    RectangularComplicationView(entry: RectangularComplicationEntry(
        date: Date(),
        entry: ComplicationEntry(
            stressLevel: 78,
            category: .high,
            hrv: 28,
            heartRate: 92,
            timestamp: Date()
        )
    ))
    .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
}

#Preview("Placeholder") {
    RectangularComplicationView(entry: RectangularComplicationEntry(
        date: Date(),
        entry: ComplicationEntry.placeholder
    ))
    .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
}
