import SwiftUI

/// 7-day stress bar chart.
///
/// Each bar's height encodes the peak stress for that day; the bar's color
/// encodes the stress tier. Subtle gridlines at 25 / 50 / 75 imply the 0–100
/// scale without needing axis labels. Today's bar gets a thin outline. A tier
/// legend summarizes the distribution across the week.
///
/// Spec reference: design/screens/04-home.html — `.stress-chart`.
struct StressOverTimeChart: View {
    let data: [StressDataPoint]
    var onUpgrade: (() -> Void)?
    var onOpenHistory: (() -> Void)?

    /// 7-day history is free (core monitoring). Kept on the card for the future
    /// 30/90-day paywall, currently a no-op hook.
    private var shouldLock: Bool { false }

    private let days = ["M", "T", "W", "T", "F", "S", "S"]

    init(
        data: [StressDataPoint],
        onUpgrade: (() -> Void)? = nil,
        onOpenHistory: (() -> Void)? = nil
    ) {
        self.data = data
        self.onUpgrade = onUpgrade
        self.onOpenHistory = onOpenHistory
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if shouldLock {
                chartArea
                    .overlay(PremiumLockOverlay(lockedFeatureLabel: "Unlock longer trends", onUpgrade: onUpgrade))
            } else {
                chartArea
            }

            legend
        }
        .padding(16)
        .background(Color.Wellness.adaptiveCardBackground.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Stress over time, last 7 days. \(legendVoiceover)")
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Stress over time")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.Wellness.adaptivePrimaryText)
            Spacer()
            HStack(spacing: 4) {
                Text("LAST 7 DAYS")
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .tracking(1.0)
                    .foregroundStyle(Color.Wellness.adaptiveSecondaryText)

                if let onOpenHistory {
                    Button {
                        HapticManager.shared.buttonPress()
                        onOpenHistory()
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.primaryBlue)
                    }
                    .buttonStyle(.plain)
                    .minimumTouchTarget(DesignTokens.Layout.minTouchTarget)
                    .accessibilityLabel("All history")
                }
            }
        }
    }

    // MARK: - Bars

    private var chartArea: some View {
        let display = paddedData
        return ZStack(alignment: .bottom) {
            gridlines
            HStack(alignment: .bottom, spacing: 7) {
                ForEach(Array(display.enumerated()), id: \.offset) { index, point in
                    barColumn(for: point, isToday: index == display.count - 1, dayLabel: dayLabel(at: index))
                }
            }
        }
        .frame(height: 116)
    }

    private var gridlines: some View {
        VStack {
            Spacer()
            gridline(at: 0.75)
            gridline(at: 0.50)
            gridline(at: 0.25)
            Rectangle()
                .fill(Color(hex: "#3C3C43").opacity(0.12))
                .frame(height: 1)
        }
    }

    private func gridline(at fraction: CGFloat) -> some View {
        Rectangle()
            .fill(Color(hex: "#3C3C43").opacity(0.10))
            .frame(height: 1)
            .padding(.leading, 2)
            .offset(y: -fraction * 104)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func barColumn(for point: StressDataPoint, isToday: Bool, dayLabel: String) -> some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let height = max(2, CGFloat(point.value) / 100.0 * geo.size.height)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.stressColor(for: point.category))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(Color.Wellness.adaptivePrimaryText, lineWidth: isToday ? 1.5 : 0)
                    )
                    .frame(height: height)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .frame(height: 100)

            Text(dayLabel)
                .font(.system(size: 9, weight: isToday ? .bold : .regular, design: .monospaced))
                .tracking(0.4)
                .foregroundStyle(isToday ? Color.Wellness.adaptivePrimaryText : Color.Wellness.adaptiveSecondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Legend

    private var legend: some View {
        let distribution = tierDistribution
        return FlowLayout(spacing: 12, lineSpacing: 6) {
            ForEach(StressCategory.allCases, id: \.self) { tier in
                legendPill(tier: tier, percent: distribution[tier] ?? 0)
            }
        }
    }

    private func legendPill(tier: StressCategory, percent: Int) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.stressColor(for: tier))
                .frame(width: 8, height: 8)
            Text(tier.displayName)
                .font(.system(size: 10.5, weight: .regular))
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
            Text("\(percent)%")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.Wellness.adaptivePrimaryText)
        }
    }

    // MARK: - Data shaping

    /// Pad/truncate to exactly 7 entries; fill missing trailing days with the
    /// today entry so the grid never collapses.
    private var paddedData: [StressDataPoint] {
        if data.count >= 7 {
            return Array(data.suffix(7))
        }
        var result = data
        let today = data.last ?? StressDataPoint(day: "TODAY", value: 0, category: .relaxed)
        while result.count < 7 { result.append(today) }
        return result
    }

    private func dayLabel(at index: Int) -> String {
        index == 6 ? "TODAY" : days[index]
    }

    private var tierDistribution: [StressCategory: Int] {
        guard !data.isEmpty else {
            return [:]
        }
        var counts: [StressCategory: Int] = [:]
        for point in data { counts[point.category, default: 0] += 1 }
        let total = data.count
        return StressCategory.allCases.reduce(into: [:]) { result, tier in
            let raw = Double(counts[tier] ?? 0) / Double(total) * 100
            result[tier] = Int(raw.rounded())
        }
    }

    private var legendVoiceover: String {
        tierDistribution
            .filter { $0.value > 0 }
            .map { "\($0.value) percent \($0.key.displayName)" }
            .joined(separator: ", ")
    }
}

// MARK: - StressDataPoint

struct StressDataPoint: Identifiable {
    let id = UUID()
    let day: String
    let value: Int
    let category: StressCategory
}

// MARK: - FlowLayout (legend wrapping)

/// Lightweight wrapping layout for the tier legend so pills reflow on narrow
/// widths instead of clipping.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                y += lineHeight + lineSpacing
                x = 0
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            totalWidth = max(totalWidth, x - spacing)
        }
        return CGSize(width: totalWidth, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.minX + maxWidth, x > bounds.minX {
                y += lineHeight + lineSpacing
                x = bounds.minX
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

// MARK: - Preview

#Preview("StressOverTimeChart") {
    let data: [StressDataPoint] = [
        .init(day: "M", value: 24, category: .relaxed),
        .init(day: "T", value: 58, category: .moderate),
        .init(day: "W", value: 38, category: .mild),
        .init(day: "T", value: 72, category: .moderate),
        .init(day: "F", value: 81, category: .high),
        .init(day: "S", value: 22, category: .relaxed),
        .init(day: "TODAY", value: 42, category: .mild)
    ]
    return VStack {
        StressOverTimeChart(data: data)
            .padding()
        Spacer()
    }
    .background(HomeCharacterDesignTokens.homeBackground)
}
