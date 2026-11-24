import SwiftUI

// MARK: - WatchStressGauge

/// UI V2 hero gauge, sized for the watch. Same geometry as the iPhone
/// `V2StressGauge`: a 240° arc starting at 150° and sweeping clockwise,
/// ticks at the tier boundaries (25 / 50 / 75 / 90), a `surface2` track and
/// a value arc in the tier fill colour. Content (companion) sits in the
/// centre; the score readout lives outside the gauge on Home.
struct WatchStressGauge<Center: View>: View {
    /// 0–100, or `nil` for the empty track.
    let score: Double?
    var lineWidth: CGFloat = 10
    @ViewBuilder var center: Center

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static var startAngle: Double { 150 }
    static var sweep: Double { 240 }
    static var tickValues: [Double] { [25, 50, 75, 90] }

    private var category: StressCategory? { score.map(StressCategory.category(for:)) }
    private var fraction: Double { min(max((score ?? 0) / 100, 0), 1) }

    var body: some View {
        ZStack {
            ZStack {
                arc(fraction: 1)
                    .stroke(WatchV2.surface2, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                if let category {
                    arc(fraction: fraction)
                        .stroke(category.fillColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        .animation(WatchDesignTokens.motion(WatchDesignTokens.Motion.slow, reduceMotion: reduceMotion), value: fraction)
                }
                ticks
            }
            .accessibilityElement()
            .accessibilityLabel(accessibilityText)

            center
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var accessibilityText: String {
        guard let score, let category else { return "No stress reading yet" }
        return category.accessibilityValue(level: min(max(score, 0), 150))
    }

    private func arc(fraction: Double) -> some Shape {
        Circle()
            .inset(by: lineWidth / 2)
            .trim(from: 0, to: Self.sweep / 360 * fraction)
            .rotation(.degrees(Self.startAngle))
    }

    private var ticks: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let radius = size / 2 - lineWidth / 2
            ForEach(Self.tickValues, id: \.self) { value in
                let angle = Angle.degrees(Self.startAngle + Self.sweep * value / 100)
                Capsule()
                    .fill(WatchV2.canvas)
                    .frame(width: 2, height: lineWidth)
                    .rotationEffect(angle + .degrees(90))
                    .position(
                        x: proxy.size.width / 2 + radius * cos(angle.radians),
                        y: proxy.size.height / 2 + radius * sin(angle.radians)
                    )
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Gauge · tiers") {
    HStack(spacing: 8) {
        WatchStressGauge(score: 18) { EmptyView() }.frame(width: 60)
        WatchStressGauge(score: 62) { EmptyView() }.frame(width: 60)
        WatchStressGauge(score: nil) { EmptyView() }.frame(width: 60)
    }
    .padding()
    .background(WatchV2.canvas)
}
#endif
