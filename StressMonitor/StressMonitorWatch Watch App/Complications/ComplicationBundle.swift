import WidgetKit
import SwiftUI

// MARK: - Complication Bundle
/// WidgetKit bundle configuration for watchOS complications.
///
/// Supports 4 families, all rendered with the UI V2 tier colours and tier
/// shapes. "—" stands for no data; no emoji anywhere.
/// - **Accessory Circular** — 240° gauge + score + tier shape
/// - **Accessory Rectangular** — companion + "Stress N" + tier (shape +
///   name) + HRV + level bar
/// - **Accessory Inline** — tier shape + score + tier name (single line;
///   the inline family only renders one image and text)
/// - **Accessory Corner** — companion + score, curved tier shape + name
struct ComplicationBundle: WidgetBundle {
    var body: some Widget {
        CircularComplication()
        RectangularComplication()
        InlineComplication()
        CornerComplication()
    }
}

// MARK: - Corner Complication (watchOS 10+)

/// Minimal corner complication — Ripple companion glyph + numeric score.
struct CornerComplication: Widget {
    let kind: String = "CornerComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CornerComplicationProvider()) { entry in
            CornerComplicationView(entry: entry)
                .containerBackground(for: .widget) {
                    WatchFaceBackgroundView(
                        style: WatchFacePreferences.backgroundStyle,
                        theme: WatchFacePreferences.theme
                    )
                }
        }
        .configurationDisplayName("Ripple")
        .description("Your stress companion and score in the watch face corner.")
        .supportedFamilies([.accessoryCorner])
    }
}

struct CornerComplicationEntry: TimelineEntry {
    let date: Date
    let stressLevel: Double
    let category: StressCategory
}

struct CornerComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> CornerComplicationEntry {
        CornerComplicationEntry(date: Date(), stressLevel: 0, category: .relaxed)
    }

    func getSnapshot(in context: Context, completion: @escaping (CornerComplicationEntry) -> Void) {
        let entry = ComplicationDataProvider.shared.fetchLatestEntry()
        completion(CornerComplicationEntry(
            date: Date(),
            stressLevel: entry.stressLevel,
            category: entry.category
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CornerComplicationEntry>) -> Void) {
        let entry = ComplicationDataProvider.shared.fetchLatestEntry()
        let nextRefresh = ComplicationDataProvider.shared.nextRefreshDate()
        completion(Timeline(
            entries: [
                CornerComplicationEntry(
                    date: Date(),
                    stressLevel: entry.stressLevel,
                    category: entry.category
                )
            ],
            policy: .after(nextRefresh)
        ))
    }
}

struct CornerComplicationView: View {
    let entry: CornerComplicationEntry

    private var isPlaceholder: Bool { ComplicationDataProvider.shared.fetchLatestEntry().isPlaceholder }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            CharacterFaceView(creature: .ripple, category: isPlaceholder ? nil : entry.category, size: 22, showsHalo: false)
            Text(isPlaceholder ? "—" : "\(Int(entry.stressLevel.rounded()))")
                .font(.v2Number(.headline, weight: .bold))
                .foregroundStyle(isPlaceholder ? WatchV2.ink3 : entry.category.color)
                .widgetAccentable()
        }
        .widgetLabel {
            if isPlaceholder {
                Text("No data")
            } else {
                Text("\(Image(systemName: entry.category.icon)) \(entry.category.displayName)")
                    .foregroundStyle(entry.category.color)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isPlaceholder ? "No stress reading yet" : entry.category.accessibilityValue(level: entry.stressLevel))
    }
}
