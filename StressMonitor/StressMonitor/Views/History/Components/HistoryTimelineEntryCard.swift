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
            parts.append("RHR \(Int(measurement.restingHeartRate.rounded())) bpm")
        }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.stressColor(for: measurement.category))
                .frame(width: 4)
                .frame(maxHeight: .infinity)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(score)")
                        .font(.system(size: 21, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.stressColor(for: measurement.category))

                    Text(measurement.category.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.Wellness.adaptivePrimaryText)

                    Image(systemName: measurement.category.icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.stressColor(for: measurement.category))
                        .accessibilityHidden(true)
                }

                Text(subtitleText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
            }

            Spacer(minLength: 8)

            Text(timeText)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
        }
        .padding(14)
        .frame(minHeight: 64, alignment: .leading)
        .background(Color.Wellness.adaptiveCardBackground.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
    .padding()
    .background(HomeCharacterDesignTokens.homeBackground)
}
