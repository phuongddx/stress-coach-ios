import SwiftUI

/// Before/after HRV comparison chart (UI V2 `S.summary`), drawn in
/// `Color.V2` tokens for light and dark.
///
/// Renders a smooth ascending path from `before` to `after` with a gradient
/// fill underneath, a dashed baseline at the "before" level, and labelled
/// endpoints. The delta (e.g. "+16 ms · +31%") is surfaced as a parameter
/// so the parent view controls the exact wording.
struct BeforeAfterHRVChart: View {
    var before: Double
    var after: Double

    private let beforeColor = Color.V2.accent
    private let mutedLabel = Color.V2.ink3
    private let separatorColor = Color.V2.line2

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header row
            HStack {
                Text("HRV across session")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.V2.ink)
                Spacer()
                Text("Live")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(mutedLabel)
            }

            // SVG-like chart
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let maxVal = max(before, after, 1)
                let minVal = min(before, after, 0)
                let range = max(maxVal - minVal, 1)
                // Normalise: before at 80% down, after at ~25% down (inverted)
                let beforeY = h * 0.70
                let afterY = h * (0.70 - 0.45 * (after - before) / range)
                let clampedAfterY = max(h * 0.15, min(h * 0.85, afterY))

                ZStack {
                    // Dashed baseline
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: beforeY))
                        p.addLine(to: CGPoint(x: w, y: beforeY))
                    }
                    .stroke(separatorColor, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

                    // Before label
                    Text("before \(Int(before)) ms")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(mutedLabel)
                        .fixedSize()
                        .position(x: 40, y: beforeY - 10)

                    // Gradient fill under the curve
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: beforeY))
                        p.addCurve(
                            to: CGPoint(x: w, y: clampedAfterY),
                            control1: CGPoint(x: w * 0.35, y: beforeY - (beforeY - clampedAfterY) * 0.3),
                            control2: CGPoint(x: w * 0.65, y: clampedAfterY + (beforeY - clampedAfterY) * 0.25)
                        )
                        p.addLine(to: CGPoint(x: w, y: h))
                        p.addLine(to: CGPoint(x: 0, y: h))
                        p.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [beforeColor.opacity(0.35), beforeColor.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    // Curve stroke
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: beforeY))
                        p.addCurve(
                            to: CGPoint(x: w, y: clampedAfterY),
                            control1: CGPoint(x: w * 0.35, y: beforeY - (beforeY - clampedAfterY) * 0.3),
                            control2: CGPoint(x: w * 0.65, y: clampedAfterY + (beforeY - clampedAfterY) * 0.25)
                        )
                    }
                    .stroke(beforeColor, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))

                    // Endpoint dot
                    Circle()
                        .fill(beforeColor)
                        .frame(width: 7, height: 7)
                        .position(x: w - 2, y: clampedAfterY)

                    // After label
                    Text("\(Int(after)) ms after")
                        .font(.caption2.weight(.bold).monospacedDigit())
                        .foregroundStyle(beforeColor)
                        .fixedSize()
                        .position(x: w - 44, y: clampedAfterY - 12)
                }
            }
            .frame(height: 120)
            // Attached here rather than in BreathingSummaryView so the summary
            // screen stays untouched; the header row above stays readable.
            .plusLocked(.breathingBeforeAfter)
        }
    }
}

#Preview("BeforeAfterHRVChart") {
    V2Card {
        BeforeAfterHRVChart(before: 52, after: 68)
    }
    .padding(40)
    .background(Color.V2.bg)
}
