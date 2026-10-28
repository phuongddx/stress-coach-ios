import SwiftUI

/// Behavioral metrics row — Exercise / Sleep / Daylight.
///
/// Separate from the vitals triplet: these are behaviors, not bio-signals.
/// Each item shows an outline icon, a rounded numeric value with unit, a label,
/// and a small delta context line. Daylight is the novel signal that gives the
/// app character.
///
/// Spec reference: design/screens/04-home.html — `.health-data`.
struct HealthDataSection: View {
    let exerciseMinutes: Int?
    let exerciseDelta: String?

    let sleepHours: Double?
    let sleepDelta: String?

    let daylightMinutes: Int?
    let daylightDelta: String?

    init(
        exerciseMinutes: Int? = nil,
        exerciseDelta: String? = nil,
        sleepHours: Double? = nil,
        sleepDelta: String? = nil,
        daylightMinutes: Int? = nil,
        daylightDelta: String? = nil
    ) {
        self.exerciseMinutes = exerciseMinutes
        self.exerciseDelta = exerciseDelta
        self.sleepHours = sleepHours
        self.sleepDelta = sleepDelta
        self.daylightMinutes = daylightMinutes
        self.daylightDelta = daylightDelta
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            item(
                symbol: "figure.run",
                value: exerciseMinutes.map { "\($0)" } ?? "—",
                unit: "min",
                label: "Last workout",
                delta: exerciseDelta,
                deltaGood: false
            )
            item(
                symbol: "moon.stars",
                value: sleepHours.map { sleepParts($0).value } ?? "—",
                unit: sleepHours.map { sleepParts($0).unit } ?? "",
                label: "Sleep",
                delta: sleepDelta,
                deltaGood: sleepDelta != nil
            )
            item(
                symbol: "sun.max",
                value: daylightMinutes.map { "\($0)" } ?? "—",
                unit: "min",
                label: "Daylight",
                delta: daylightDelta,
                deltaGood: daylightDelta != nil
            )
        }
        .padding(16)
        .background(Color.Wellness.adaptiveCardBackground.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Health behaviors. Last workout \(exerciseMinutes.map { "\($0) minutes" } ?? "unknown"). Sleep \(sleepHours.map { sleepSpoken($0) } ?? "unknown"). Daylight \(daylightMinutes.map { "\($0) minutes" } ?? "unknown").")
    }

    private func item(
        symbol: String,
        value: String,
        unit: String,
        label: String,
        delta: String?,
        deltaGood: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
                .padding(.bottom, 2)

            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .tracking(-0.3)
                    .foregroundStyle(Color.Wellness.adaptivePrimaryText)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
                }
            }

            Text(label)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText)

            if let delta {
                Text(delta)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .tracking(0.2)
                    .foregroundStyle(deltaGood ? Color.stressRelaxed : Color.Wellness.adaptiveSecondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Sleep renders as "6h 50" + "m" (hours + remaining minutes) per the spec,
    /// or "7" + "h" when the minutes are zero.
    private func sleepParts(_ hours: Double) -> (value: String, unit: String) {
        let total = Int((hours * 60).rounded())
        let h = total / 60
        let m = total % 60
        return m == 0 ? ("\(h)", "h") : ("\(h)h \(m)", "m")
    }

    private func sleepSpoken(_ hours: Double) -> String {
        let total = Int((hours * 60).rounded())
        return "\(total / 60) hours \(total % 60) minutes"
    }
}

// MARK: - Preview

#Preview("HealthDataSection") {
    VStack {
        HealthDataSection(
            exerciseMinutes: 23,
            exerciseDelta: "yesterday",
            sleepHours: 6.83,
            sleepDelta: "+12m vs avg",
            daylightMinutes: 42,
            daylightDelta: "on target"
        )
        Spacer()
    }
    .padding()
    .background(HomeCharacterDesignTokens.homeBackground)
}

#Preview("HealthDataSection — No Data") {
    VStack {
        HealthDataSection()
        Spacer()
    }
    .padding()
    .background(HomeCharacterDesignTokens.homeBackground)
}
