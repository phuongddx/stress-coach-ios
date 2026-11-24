import SwiftUI

/// A stress factor: icon tile, name, one accent bar (0–1), value + unit and
/// a one-line sentence. A missing factor shows "No data" in `ink3`.
struct V2FactorRow: View {
    let systemImage: String
    let name: String
    /// 0–1, or nil when the factor has no data.
    let level: Double?
    var value: String? = nil
    var unit: String? = nil
    var sentence: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.V2.accent)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: V2Metrics.radiusSM, style: .continuous).fill(Color.V2.accentSoft))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.V2.ink)
                    Spacer(minLength: 8)
                    valueText
                }
                if let level {
                    bar(level: level)
                }
                if let sentence, level != nil {
                    Text(sentence)
                        .font(.footnote)
                        .foregroundStyle(Color.V2.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var valueText: some View {
        if level == nil {
            Text("No data")
                .font(.footnote)
                .foregroundStyle(Color.V2.ink3)
        } else if let value {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.v2Number(.subheadline))
                if let unit { Text(unit).font(.caption) }
            }
            .foregroundStyle(Color.V2.ink)
        }
    }

    private func bar(level: Double) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.V2.surface2)
                Capsule().fill(Color.V2.accent)
                    .frame(width: proxy.size.width * min(max(level, 0), 1))
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}

/// ▲/▼ with words, e.g. "4 lower than yesterday". Good uses the relaxed text
/// colour, bad uses the high text colour.
struct V2DeltaPill: View {
    let text: String
    let isUp: Bool
    let isGood: Bool

    private var tint: Color { isGood ? StressCategory.relaxed.color : StressCategory.high.color }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isUp ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                .imageScale(.small)
                .accessibilityHidden(true)
            Text(text)
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.V2.surface2))
    }
}

#Preview("Factor rows") {
    V2Card {
        VStack(spacing: 16) {
            V2FactorRow(systemImage: "waveform.path.ecg", name: "HRV", level: 0.7, value: "48", unit: "ms",
                        sentence: "Higher than your usual, a good sign.")
            V2FactorRow(systemImage: "bed.double.fill", name: "Sleep", level: nil)
            HStack {
                V2DeltaPill(text: "4 lower than yesterday", isUp: false, isGood: true)
                V2DeltaPill(text: "6 higher", isUp: true, isGood: false)
            }
        }
    }
    .padding()
    .background(Color.V2.bg)
}
