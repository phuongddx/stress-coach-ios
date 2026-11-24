import SwiftUI

/// Circular walk timer (UI V2 `S.walk`): a 240 pt ring with a `surface2`
/// track and a relaxed-tier fill, the time left in large rounded numerals and
/// a state word ("left", "Paused", "Ready") under it.
///
/// The fill only animates when motion is allowed.
struct WalkTimer: View {
    var progress: Double
    var timeDisplay: String
    var targetDisplay: String
    var stepCount: Int
    /// Word under the time: "left" while walking, "Paused", "Ready".
    var stateLabel: String = "left"

    @ScaledMetric(relativeTo: .largeTitle) private var timeSize: CGFloat = 52
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var ringSize: CGFloat { dynamicTypeSize.isAccessibilitySize ? 280 : 240 }
    private let lineWidth: CGFloat = 14

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.V2.surface2, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: min(1, max(0, progress)))
                .stroke(
                    StressCategory.relaxed.fillColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animateIfMotionAllowed(.easeInOut(duration: 0.3), value: progress)

            VStack(spacing: 2) {
                Text(timeDisplay)
                    .font(.system(size: min(timeSize, 72), weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Color.V2.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(stateLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.V2.ink2)
                Text("of \(targetDisplay)")
                    .font(.footnote)
                    .foregroundStyle(Color.V2.ink3)
                    .monospacedDigit()
            }
            .padding(lineWidth * 2)
        }
        .frame(width: ringSize, height: ringSize)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(stepCount) steps, \(timeDisplay) of \(targetDisplay), \(Int((progress * 100).rounded())) percent complete")
    }
}

#Preview {
    VStack(spacing: 24) {
        WalkTimer(progress: 0.47, timeDisplay: "5:18", targetDisplay: "10:00", stepCount: 412)
        WalkTimer(progress: 0, timeDisplay: "10:00", targetDisplay: "10:00", stepCount: 0, stateLabel: "Ready")
    }
    .padding(40)
    .background(Color.V2.bg)
}
