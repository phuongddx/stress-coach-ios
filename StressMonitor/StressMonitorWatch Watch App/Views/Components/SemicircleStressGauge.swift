import SwiftUI

// MARK: - SemicircleStressGauge

/// 180° stress gauge — the Home-screen hero primitive (iOS DS §10).
///
/// A semicircular arc (open at the bottom) with a multi-stop gradient
/// stroke that reveals more of the spectrum as the score climbs.  The
/// numeric score sits in the gap in SF Pro Rounded; the tier glyph+label
/// rides below in SF Mono.  Math (matches the watch design output):
///
///   arc length = π · r   (≈ 172.78 at r = 55)
///   dashoffset = arcLength × (1 − score/100)
///
/// Accent budget: this is one of the two Ripple-blue-adjacent accents
/// allowed per screen — but the stroke uses the *stress scale* gradient,
/// not pure accent, so the budget is preserved.
struct SemicircleStressGauge: View {
    /// `nil` draws the empty track.
    let score: Double?
    var radius: CGFloat = 55
    var strokeWidth: CGFloat = 10

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let category: StressCategory?

    init(score: Double?, radius: CGFloat = 55, strokeWidth: CGFloat = 10) {
        self.score = score.map { max(0, min(150, $0)) }
        self.radius = radius
        self.strokeWidth = strokeWidth
        self.category = score.map(StressCategory.category(for:))
    }

    var body: some View {
        let dim = (radius + strokeWidth) * 2
        return ZStack {
            // Track
            Semicircle(radius: radius)
                .stroke(WatchDesignTokens.separator, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))

            // Progress (gradient reveals as score climbs)
            Semicircle(radius: radius)
                .trim(from: 0, to: progress)
                .stroke(
                    gradientForProgress,
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .animation(WatchDesignTokens.motion(WatchDesignTokens.Motion.default, reduceMotion: reduceMotion), value: progress)

            // Tick marks at the ends + apex
            SemicircleTicks(radius: radius)
                .stroke(WatchDesignTokens.separatorStrong.opacity(0.6), lineWidth: 1)
        }
        .frame(width: dim, height: dim * 0.58)
        .accessibilityElement()
        .accessibilityLabel(score.flatMap { level in category?.accessibilityValue(level: level) } ?? "No stress reading yet")
    }

    private var progress: CGFloat {
        CGFloat(min(score ?? 0, 100) / 100.0)
    }

    /// Multi-stop gradient that reveals the stress spectrum as the score
    /// climbs: green → blue → yellow → orange → red.  Tied to the 5-tier
    /// scale so the visible portion always matches the displayed tier.
    private var gradientForProgress: AngularGradient {
        AngularGradient(
            stops: [
                .init(color: Color.stressRelaxed,  location: 0.00),
                .init(color: Color.stressMild,     location: 0.25),
                .init(color: Color.stressModerate, location: 0.50),
                .init(color: Color.stressHigh,     location: 0.75),
                .init(color: Color.stressSevere,   location: 1.00)
            ],
            center: .bottom,
            startAngle: .degrees(180),
            endAngle: .degrees(360)
        )
    }
}

// MARK: - Semicircle Shape

/// A top half-circle arc (open at the bottom).  Drawn from the left
/// endpoint (π) clockwise over the top to the right endpoint (0).
private struct Semicircle: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.maxY)
        var p = Path()
        p.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(360),
            clockwise: false
        )
        return p
    }
}

/// Hairline tick marks at the two ends and the apex of the semicircle.
private struct SemicircleTicks: Shape {
    let radius: CGFloat
    let tickLength: CGFloat = 7

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cy = rect.maxY
        let cx = rect.midX
        // Left end tick
        p.move(to: CGPoint(x: cx - radius, y: cy))
        p.addLine(to: CGPoint(x: cx - radius, y: cy - tickLength))
        // Apex tick
        p.move(to: CGPoint(x: cx, y: cy - radius))
        p.addLine(to: CGPoint(x: cx, y: cy - radius + tickLength))
        // Right end tick
        p.move(to: CGPoint(x: cx + radius, y: cy))
        p.addLine(to: CGPoint(x: cx + radius, y: cy - tickLength))
        return p
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Gauge · 3 tiers") {
    VStack(spacing: 24) {
        SemicircleStressGauge(score: 18)
        SemicircleStressGauge(score: 42)
        SemicircleStressGauge(score: 78)
    }
    .padding()
    .background(WatchDesignTokens.canvas)
}
#endif
