import SwiftUI

/// Time-in-each-tier stacked bar (UI V2, ui-v2-design/screens.js `S.trends` tierDist).
///
/// Four segments (Relaxed / Mild / Elevated / High) in the tier fill colours,
/// whose widths always sum to 100%. Below the bar sits a 2×2 legend with the
/// tier shape, name and day count, plus an editorial comment.
struct DistributionBar: View {
    let relaxedDays: Int
    let mildDays: Int
    let moderateDays: Int
    let highDays: Int
    var comment: String? = nil
    /// Card title shown above the bar; nil hides the header.
    var title: String? = nil
    /// Window shown next to the title (e.g. "7 days").
    var windowLabel: String? = nil

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // MARK: - Derived

    private var totalDays: Int {
        relaxedDays + mildDays + moderateDays + highDays
    }

    /// Exact percentages that always sum to 100. The last tier with
    /// nonzero days absorbs the rounding residual — a tier with 0 days
    /// must never receive a nonzero percentage (it would contradict its
    /// own dimmed "0 days" legend and VoiceOver label).
    private var segments: (relaxed: Int, mild: Int, moderate: Int, high: Int) {
        guard totalDays > 0 else { return (0, 0, 0, 0) }
        let t = Double(totalDays)
        let days = [relaxedDays, mildDays, moderateDays, highDays]
        var pcts = days.map { Int((Double($0) / t * 100).rounded()) }
        let residual = 100 - pcts.reduce(0, +)
        if let lastNonZero = days.lastIndex(where: { $0 > 0 }) {
            pcts[lastNonZero] += residual
        }
        return (pcts[0], pcts[1], pcts[2], pcts[3])
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title {
                header(title)
            }
            bar
            legend
            if let comment {
                Text(comment)
                    .font(.footnote)
                    .foregroundStyle(Color.V2.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(V2Metrics.margin)
        .frame(maxWidth: .infinity, alignment: .leading)
        .v2CardBackground()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "Time spent by tier. Relaxed \(segments.relaxed) percent. " +
            "Mild \(segments.mild) percent. Moderate \(segments.moderate) percent. " +
            "High \(segments.high) percent."
        )
    }

    private func header(_ title: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.V2.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            if let windowLabel {
                Text(windowLabel)
                    .font(.footnote)
                    .foregroundStyle(Color.V2.ink3)
            }
        }
    }

    // MARK: - Bar

    private var bar: some View {
        GeometryReader { proxy in
            let total = max(proxy.size.width, 1)
            let s = segments
            HStack(spacing: 0) {
                if s.relaxed > 0 {
                    barSegment(
                        color: StressCategory.relaxed.fillColor,
                        width: total * CGFloat(s.relaxed) / 100,
                        label: "\(s.relaxed)%",
                        textColor: StressCategory.relaxed.onFillColor
                    )
                }
                if s.mild > 0 {
                    barSegment(
                        color: StressCategory.mild.fillColor,
                        width: total * CGFloat(s.mild) / 100,
                        label: "\(s.mild)%",
                        textColor: StressCategory.mild.onFillColor
                    )
                }
                if s.moderate > 0 {
                    barSegment(
                        color: StressCategory.moderate.fillColor,
                        width: total * CGFloat(s.moderate) / 100,
                        label: "\(s.moderate)%",
                        textColor: StressCategory.moderate.onFillColor
                    )
                }
                if s.high > 0 {
                    barSegment(
                        color: StressCategory.high.fillColor,
                        width: total * CGFloat(s.high) / 100,
                        label: "\(s.high)%",
                        textColor: StressCategory.high.onFillColor
                    )
                }
            }
        }
        .frame(height: 24)
        .clipShape(RoundedRectangle(cornerRadius: V2Metrics.radiusXS, style: .continuous))
    }

    private func barSegment(color: Color, width: CGFloat, label: String, textColor: Color) -> some View {
        ZStack {
            Rectangle().fill(color)
            if width > 36 {
                Text(label)
                    .font(.v2Number(.caption2))
                    .foregroundStyle(textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(width: max(0, width))
    }

    // MARK: - Legend

    private var legend: some View {
        let columns = dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            legendItem(tier: .relaxed, days: relaxedDays)
            legendItem(tier: .mild, days: mildDays)
            legendItem(tier: .moderate, days: moderateDays)
            legendItem(tier: .high, days: highDays)
        }
    }

    private func legendItem(tier: StressCategory, days: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: tier.icon)
                .font(.caption2)
                .foregroundStyle(tier.fillColor)
                .accessibilityHidden(true)
            Text(tier.displayName)
                .font(.footnote)
                .foregroundStyle(Color.V2.ink2)
            Spacer(minLength: 4)
            Text("\(days) day\(days == 1 ? "" : "s")")
                .font(.v2Number(.footnote))
                .foregroundStyle(days == 0 ? Color.V2.ink3 : Color.V2.ink)
        }
    }
}

#Preview("DistributionBar") {
    VStack(spacing: 20) {
        DistributionBar(
            relaxedDays: 2,
            mildDays: 3,
            moderateDays: 2,
            highDays: 0,
            comment: "Most days landed in Mild — your baseline is shifting in the right direction."
        )
        Spacer()
    }
    .padding()
    .background(Color.V2.bg)
}
