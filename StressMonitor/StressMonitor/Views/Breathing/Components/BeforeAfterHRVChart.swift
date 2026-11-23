import SwiftUI

/// Before/after HRV comparison chart matching the `.hrv-diff-chart` from
/// `14-breathing-summary.html`.
///
/// Renders a smooth ascending path from `before` to `after` with a gradient
/// fill underneath, a dashed baseline at the "before" level, and labelled
/// endpoints. The delta (e.g. "+16 ms · +31%") is surfaced as a parameter
/// so the parent view controls the exact wording.
struct BeforeAfterHRVChart: View {
    var before: Double
    var after: Double

    private let beforeColor = Color(hex: "#34D399")    // --hrv-color / success
    private let mutedLabel = Color(hex: "#8E8E93")      // --muted-2
    private let separatorColor = Color(red: 60/255, green: 60/255, blue: 67/255).opacity(0.12)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header row
            HStack {
                Text("HRV across session")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: "#3C3C43"))
                Spacer()
                Text("live")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(0.4)
                    .textCase(.uppercase)
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
                    Text("before \(Int(before))ms")
                        .font(.system(size: 9))
                        .foregroundStyle(mutedLabel)
                        .position(x: 36, y: beforeY - 8)

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
                    Text("\(Int(after))ms after")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(beforeColor)
                        .position(x: w - 40, y: clampedAfterY - 10)
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
    BeforeAfterHRVChart(before: 52, after: 68)
        .padding(16)
        .background(Color.white)
        .cornerRadius(18)
        .padding(40)
        .background(Color(hex: "#F2F2F7"))
}
