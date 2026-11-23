import SwiftUI

struct HistoryTimelineEntryCard: View {
    let measurement: StressMeasurement

    private var score: Int {
        Int(measurement.stressLevel.rounded())
    }

    private var timeText: String {
        measurement.timestamp.formatted(date: .omitted, time: .shortened)
    }

    private var subtitleText: String {
        var parts: [String] = []
        if measurement.hrv > 0 {
            parts.append("HRV \(Int(measurement.hrv.rounded())) ms")
        }
        if measurement.restingHeartRate > 0 {
            parts.append("HR \(Int(measurement.restingHeartRate.rounded())) bpm")
        }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }

    @ScaledMetric(relativeTo: .title2) private var scoreWidth: CGFloat = 44

    /// One reading as a grouped-list row (UI V2): the score in its tier text
    /// colour, the tier badge, time and vitals, and a chevron.
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("\(score)")
                .font(.v2Number(.title2))
                .foregroundStyle(measurement.category.color)
                .frame(minWidth: scoreWidth, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                V2TierBadge(category: measurement.category, font: .body.weight(.semibold))
                Text("\(timeText) · \(subtitleText)")
                    .font(.footnote)
                    .foregroundStyle(Color.V2.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.V2.ink3)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, V2Metrics.margin)
        .padding(.vertical, 10)
        .frame(minHeight: 60, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(measurement.category.displayName), \(score), \(timeText)")
    }
}

#Preview("History Timeline Entry Card") {
    HistoryTimelineEntryCard(
        measurement: StressMeasurement(
            timestamp: Date(),
            stressLevel: 42,
            hrv: 58,
            restingHeartRate: 62
        )
    )
    .v2CardBackground()
    .padding()
    .background(Color.V2.bg)
}
