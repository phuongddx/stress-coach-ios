import SwiftUI

/// Behavioral metrics row — Exercise / Sleep / Daylight.
///
/// Separate from the vitals triplet: these are behaviors, not bio-signals.
/// Each item shows an outline icon, a rounded numeric value with unit, a label,
/// and a small delta context line. Daylight is the novel signal that gives the
/// app character.
///
/// Spec reference: ui-v2-design/screens.js `S.home` (V2 card, tiles stack at
/// accessibility text sizes).
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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        V2Card {
            layout {
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
        }
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
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: symbol)
                .font(.body)
                .foregroundStyle(Color.V2.accent)
                .accessibilityHidden(true)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.v2Number(.headline))
                    .foregroundStyle(value == "—" ? Color.V2.ink3 : Color.V2.ink)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(Color.V2.ink2)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            Text(label)
                .font(.footnote)
                .foregroundStyle(Color.V2.ink3)
            if let delta {
                Text(delta)
                    .font(.caption)
                    .foregroundStyle(deltaGood ? StressCategory.relaxed.color : Color.V2.ink3)
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
    .background(Color.V2.bg)
}

#Preview("HealthDataSection — No Data") {
    VStack {
        HealthDataSection()
        Spacer()
    }
    .padding()
    .background(Color.V2.bg)
}
