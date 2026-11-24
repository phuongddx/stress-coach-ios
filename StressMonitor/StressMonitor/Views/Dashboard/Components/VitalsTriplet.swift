import SwiftUI

// MARK: - VitalsTriplet

/// Three-column vitals row: HRV / Heart Rate / Respiratory Rate.
///
/// Each tile shows a label, the value with its unit, and a small trend line.
/// Tiles stack vertically at accessibility text sizes.
///
/// Spec reference: ui-v2-design/screens.js `S.home` `.vit` tiles.
struct VitalsTriplet: View {
    let hrvValue: String
    let hrvUnit: String
    let hrvTrend: String?
    let hrvTrendGood: Bool

    let hrValue: String
    let hrUnit: String
    let hrTrend: String?
    let hrTrendGood: Bool

    let rrValue: String
    let rrUnit: String
    let rrTrend: String?
    let rrTrendGood: Bool

    init(
        hrvValue: String, hrvUnit: String = "ms", hrvTrend: String? = nil, hrvTrendGood: Bool = false,
        hrValue: String, hrUnit: String = "bpm", hrTrend: String? = nil, hrTrendGood: Bool = false,
        rrValue: String, rrUnit: String = "brpm", rrTrend: String? = nil, rrTrendGood: Bool = false
    ) {
        self.hrvValue = hrvValue
        self.hrvUnit = hrvUnit
        self.hrvTrend = hrvTrend
        self.hrvTrendGood = hrvTrendGood

        self.hrValue = hrValue
        self.hrUnit = hrUnit
        self.hrTrend = hrTrend
        self.hrTrendGood = hrTrendGood

        self.rrValue = rrValue
        self.rrUnit = rrUnit
        self.rrTrend = rrTrend
        self.rrTrendGood = rrTrendGood
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 8))
        layout {
            vitalTile(value: hrvValue, unit: hrvUnit, label: "HRV", trend: hrvTrend, trendGood: hrvTrendGood)
            vitalTile(value: hrValue, unit: hrUnit, label: "Heart rate", trend: hrTrend, trendGood: hrTrendGood)
            vitalTile(value: rrValue, unit: rrUnit, label: "Breath", trend: rrTrend, trendGood: rrTrendGood)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Vitals: HRV \(hrvValue) \(hrvUnit), Heart rate \(hrValue) \(hrUnit), Respiratory rate \(rrValue) \(rrUnit)")
    }

    // MARK: - Tile

    private func vitalTile(
        value: String, unit: String, label: String,
        trend: String?, trendGood: Bool
    ) -> some View {
        let isEmpty = value == "—" || value == "--"
        return VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.footnote)
                .foregroundStyle(Color.V2.ink3)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.v2Number(.title2))
                    .foregroundStyle(isEmpty ? Color.V2.ink3 : Color.V2.ink)
                if !isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(Color.V2.ink2)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            Text(trend ?? " ")
                .font(.caption)
                .foregroundStyle(trendGood ? StressCategory.relaxed.color : Color.V2.ink3)
                .lineLimit(1)
                .accessibilityHidden(trend == nil)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: V2Metrics.radiusMD, style: .continuous)
                .fill(Color.V2.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: V2Metrics.radiusMD, style: .continuous)
                .strokeBorder(Color.V2.line, lineWidth: 0.5)
        )
    }
}

// MARK: - Preview

#Preview("VitalsTriplet") {
    VStack {
        VitalsTriplet(
            hrvValue: "52", hrvTrend: "+8 vs avg", hrvTrendGood: true,
            hrValue: "68", hrTrend: "resting", hrTrendGood: false,
            rrValue: "14", rrTrend: "steady", rrTrendGood: false
        )
        Spacer()
    }
    .padding()
    .background(Color.V2.bg)
}

#Preview("VitalsTriplet — No Data") {
    VStack {
        VitalsTriplet(
            hrvValue: "--",
            hrValue: "--",
            rrValue: "--"
        )
        Spacer()
    }
    .padding()
    .background(Color.V2.bg)
}
