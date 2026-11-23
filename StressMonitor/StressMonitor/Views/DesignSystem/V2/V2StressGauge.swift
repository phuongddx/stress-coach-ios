import SwiftUI

/// UI V2 hero gauge: a 240° arc (150° → 30°, clockwise) with ticks at the
/// tier boundaries, the score in the centre and the tier shape + name below.
/// VoiceOver reads it as one element: "Stress score 32 of 100, Mild".
struct V2StressGauge: View {
    /// 0–100, or nil when there is no reading yet.
    let score: Double?
    var lineWidth: CGFloat = 12
    var showsTier: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var scoreSize: CGFloat = 56
    @State private var shownFraction: Double = 0

    static let startAngle: Double = 150
    static let sweep: Double = 240
    static let tickValues: [Double] = [25, 50, 75, 90]

    private var category: StressCategory? { score.map { StressCategory(from: $0) } }
    private var targetFraction: Double { min(max((score ?? 0) / 100, 0), 1) }

    var body: some View {
        ZStack {
            arc(fraction: 1)
                .stroke(Color.V2.surface2, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            if let category {
                arc(fraction: shownFraction)
                    .stroke(category.fillColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            }
            ticks
            centre
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .onAppear { update(animated: true) }
        .onChange(of: score) { _, _ in update(animated: true) }
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
                    .fill(Color.V2.bg)
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

    private var centre: some View {
        VStack(spacing: 4) {
            Text(score.map { "\(Int($0.rounded()))" } ?? "—")
                .font(.system(size: scoreSize, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(Color.V2.ink)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            if showsTier {
                if let category {
                    V2TierBadge(category: category)
                } else {
                    Text("No reading yet")
                        .font(.subheadline)
                        .foregroundStyle(Color.V2.ink3)
                }
            }
        }
        .padding(lineWidth * 2)
    }

    private var accessibilityText: String {
        guard let score, let category else { return "Stress score, no reading yet" }
        return "Stress score \(Int(score.rounded())) of 100, \(category.displayName)"
    }

    private func update(animated: Bool) {
        if animated && !reduceMotion {
            withAnimation(.easeOut(duration: 0.8)) { shownFraction = targetFraction }
        } else {
            shownFraction = targetFraction
        }
    }
}

#Preview("Gauge") {
    VStack(spacing: 24) {
        V2StressGauge(score: 32).frame(width: 220)
        HStack {
            V2StressGauge(score: 82).frame(width: 140)
            V2StressGauge(score: nil).frame(width: 140)
        }
    }
    .padding()
    .background(Color.V2.bg)
}
