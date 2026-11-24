import SwiftUI
import WidgetKit

/// Small widget (UI V2): score, tier shape + name, companion face, and when the
/// reading was taken. Stale readings dim and say when they were last updated;
/// no reading shows "—".
@available(iOS 17.0, *)
public struct SmallWidgetView: View {

    let entry: StressEntry

    public init(entry: StressEntry) {
        self.entry = entry
    }

    public var body: some View {
        Group {
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

    // MARK: - Reading

    @ViewBuilder
    private func readingContent(_ stress: StressData) -> some View {
        let category = stress.stressCategory
        let isStale = entry.dataState == .stale

        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("Stress")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.V2.accent)
                Spacer(minLength: 4)
                if !isStale {
                    Text(WidgetReadingText.time(stress.timestamp))
                        .font(.caption2)
                        .foregroundStyle(Color.V2.ink3)
                }
            }
            .lineLimit(1)

            Spacer(minLength: 0)

            HStack(alignment: .center, spacing: 6) {
                WidgetScoreText(level: stress.level)
                Spacer(minLength: 0)
                WidgetCompanionBadge(tier: WidgetStressTier.from(category: stress.stressCategory), size: 44)
            }
            .opacity(isStale ? 0.6 : 1)

            WidgetTierLabel(category: category)
                .opacity(isStale ? 0.6 : 1)

            Text(isStale ? WidgetReadingText.updated(stress, state: entry.dataState) : category.v2Substate)
                .font(.caption2)
                .foregroundStyle(isStale ? Color.V2.ink2 : Color.V2.ink3)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    // MARK: - Empty

    private var emptyContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Stress")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.V2.accent)

            Spacer(minLength: 0)

            HStack(alignment: .center, spacing: 6) {
                WidgetScoreText(level: nil)
                Spacer(minLength: 0)
                WidgetCompanionBadge(tier: .resting, size: 44)
            }

            Text("No reading yet")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.V2.ink)
                .lineLimit(1)
            Text("Open the app to measure")
                .font(.caption2)
                .foregroundStyle(Color.V2.ink3)
                .lineLimit(2)
        }
    }
}

// MARK: - Preview

#if DEBUG
@available(iOS 17.0, *)
struct SmallWidgetPreviewProvider: PreviewProvider {
    static var previews: some View {
        let entry = StressEntry(
            date: Date(),
            latestStress: nil,
            history: [],
            baseline: nil,
            isPlaceholder: true
        )
        return SmallWidgetView(entry: entry)
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
#endif
