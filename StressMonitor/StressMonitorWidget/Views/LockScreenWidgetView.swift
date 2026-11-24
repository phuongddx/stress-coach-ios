import SwiftUI
import WidgetKit

// Lock Screen accessories (UI V2). No emoji: the score, tier shape and tier name
// carry the reading, and "—" means no data. On the Lock Screen the system renders
// these in vibrant mode, so colour only appears in full-colour rendering and the
// key parts are marked `widgetAccentable()` for tinted modes.

// MARK: - Lock Screen: Accessory Rectangular

/// "Stress" header, score with tier shape + name, and a level bar. Stale readings
/// replace the bar with when it was last updated.
@available(iOS 17.0, *)
struct LockScreenRectangularView: View {
    let entry: StressEntry

    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "drop.fill")
                    .imageScale(.small)
                    .accessibilityHidden(true)
                Text("Stress")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .widgetAccentable()

            if let stress = entry.latestStress {
                let category = stress.stressCategory
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(WidgetReadingText.score(stress.level))
                        .font(.v2Number(.title2))
                        .widgetAccentable()
                    WidgetTierLabel(category: category, font: .headline)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)

                if entry.dataState == .stale {
                    Text(WidgetReadingText.updated(stress, state: entry.dataState))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    levelBar(level: stress.level, fill: renderingMode.showsTierColor ? category.fillColor : Color.primary)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("—")
                        .font(.v2Number(.title2))
                    Text("No reading yet")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WidgetReadingText.accessibilitySummary(entry.latestStress, state: entry.dataState))
    }

    private func levelBar(level: Double, fill: Color) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.tertiary)
                Capsule()
                    .fill(fill)
                    .frame(width: max(4, proxy.size.width * min(max(level, 0), 100) / 100))
                    .widgetAccentable()
            }
        }
        .frame(height: 4)
        .padding(.top, 2)
    }
}

// MARK: - Lock Screen: Accessory Circular

/// A level ring around the score and the tier shape (name as the accessibility
/// label). No reading: an empty ring, "—" and "No data".
@available(iOS 17.0, *)
struct LockScreenCircularView: View {
    let entry: StressEntry

    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        ZStack {
            Circle()
                .stroke(.tertiary, lineWidth: 5)

            if let stress = entry.latestStress {
                let category = stress.stressCategory
                Circle()
                    .trim(from: 0, to: min(max(stress.level, 0), 100) / 100)
                    .stroke(renderingMode.showsTierColor ? category.fillColor : Color.primary,
                            style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .widgetAccentable()

                VStack(spacing: 0) {
                    Text(WidgetReadingText.score(stress.level))
                        .font(.v2Number(.title3))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .widgetAccentable()
                    WidgetTierLabel(category: category, compact: true, font: .caption2)
                }
                .opacity(entry.dataState == .stale ? 0.6 : 1)
            } else {
                VStack(spacing: 0) {
                    Text("—")
                        .font(.v2Number(.title3))
                    Text("No data")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .padding(3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WidgetReadingText.accessibilitySummary(entry.latestStress, state: entry.dataState))
    }
}

// MARK: - Lock Screen: Accessory Inline

/// One tier shape and one line of text: "Stress 32 · Mild". Stale readings add
/// how old they are; no reading shows "Stress —".
@available(iOS 17.0, *)
struct LockScreenInlineView: View {
    let entry: StressEntry

    var body: some View {
        Group {
            if let stress = entry.latestStress {
                let category = stress.stressCategory
                let score = WidgetReadingText.score(stress.level)
                Label {
                    Text(entry.dataState == .stale
                         ? "\(score) · \(category.displayName) · \(WidgetReadingText.age(stress.timestamp))"
                         : "Stress \(score) · \(category.displayName)")
                } icon: {
                    Image(systemName: category.icon)
                }
            } else {
                Label {
                    Text("Stress —")
                } icon: {
                    Image(systemName: "drop.fill")
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WidgetReadingText.accessibilitySummary(entry.latestStress, state: entry.dataState))
    }
}

// MARK: - Lock Screen Widget Definition

/// Lock Screen widget supporting accessoryRectangular, accessoryCircular, accessoryInline.
@available(iOS 17.0, *)
struct LockScreenStressWidget: Widget {
    let kind: String = "LockScreenStressWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StressWidgetProvider()) { entry in
            LockScreenStressWidgetView(entry: entry)
        }
        .configurationDisplayName("Ripple")
        .description("Your stress score and tier on the Lock Screen.")
        .supportedFamilies([
            .accessoryRectangular,
            .accessoryCircular,
            .accessoryInline
        ])
    }
}

@available(iOS 17.0, *)
struct LockScreenStressWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: StressEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            LockScreenCircularView(entry: entry)
                .containerBackground(for: .widget) { AccessoryWidgetBackground() }

        case .accessoryInline:
            LockScreenInlineView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }

        default:
            LockScreenRectangularView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
    }
}
