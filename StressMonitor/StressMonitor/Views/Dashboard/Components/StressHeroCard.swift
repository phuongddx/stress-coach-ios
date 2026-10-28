import SwiftUI

/// Hero stress card for the Home tab.
///
/// Semicircle half-arc gauge carries the progress burden (track + gradient fill +
/// endpoint tick). Ripple sits INSIDE the arc opening — the character's
/// expression IS the status. Below the gauge: the state label, substate, and
/// confidence line.
///
/// Spec reference: design/screens/04-home.html — `.hero` + `.arc-stage`.
struct StressHeroCard: View {
    let level: Double
    let category: StressCategory
    let confidence: Double?
    let measuredAt: Date?
    let substate: String
    /// Number of factors that fed the score. Nil leaves the factor count off the confidence line.
    let factorCount: Int?

    init(
        level: Double,
        category: StressCategory,
        confidence: Double? = nil,
        measuredAt: Date? = nil,
        substate: String = "Steady",
        factorCount: Int? = nil
    ) {
        self.level = level
        self.category = category
        self.confidence = confidence
        self.measuredAt = measuredAt
        self.substate = substate
        self.factorCount = factorCount
    }

    private var hasData: Bool { level > 0 }

    var body: some View {
        VStack(spacing: 0) {
            eyebrowRow
            arcStage
            stateRow
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .background(
            LinearGradient(
                colors: [
                    Color.Wellness.adaptiveCardBackground,
                    HomeCharacterDesignTokens.Ripple.light.opacity(0.28)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(HomeCharacterDesignTokens.Ripple.primary.opacity(0.20), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Eyebrow

    private var eyebrowRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("CURRENT STRESS")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
            Spacer()
            if let measuredAt {
                Text("measured \(measuredAt, format: .dateTime.hour().minute())")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
            }
        }
    }

    // MARK: - Arc stage

    private var arcStage: some View {
        let stageWidth: CGFloat = 220
        let stageHeight: CGFloat = 116
        let characterSize: CGFloat = 111
        return ZStack {
            // Track
            SemicircleArc(progress: 1.0)
                .stroke(Color(hex: "#3C3C43").opacity(0.10), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .frame(width: stageWidth, height: stageHeight)

            // Fill
            SemicircleArc(progress: hasData ? min(1, level / 100.0) : 0)
                .stroke(
                    LinearGradient(
                        colors: [fillColor.opacity(0.85), fillColor],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .frame(width: stageWidth, height: stageHeight)

            // Endpoint tick
            TickMarker(progress: hasData ? min(1, level / 100.0) : 0, color: fillColor)
                .frame(width: stageWidth, height: stageHeight)

            // Ripple — anchored to the arc baseline, inside the bowl
            StressBuddyIllustration(mood: mood, size: characterSize)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 2)
                .accessibilityHidden(true)
        }
        .frame(width: stageWidth, height: stageHeight + characterSize * 0.45)
    }

    // MARK: - State row

    private var stateRow: some View {
        VStack(spacing: 4) {
            if hasData {
                Text(category.displayName)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .tracking(-0.8)
                    .foregroundStyle(category.color)
                    .stressDualCoding(category, showsCaption: false)
            } else {
                Text("No Data")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .tracking(-0.8)
                    .foregroundStyle(fillColor)
            }

            Text(hasData ? substate : "Waiting for a reading")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText)

            if hasData, let confidence {
                Text(confidenceLine(confidence))
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .tracking(0.5)
                    .foregroundStyle(Color.Wellness.adaptiveSecondaryText.opacity(0.85))
                    .padding(.top, 4)
            }
        }
        .padding(.top, 12)
    }

    // MARK: - Helpers

    private func confidenceLine(_ confidence: Double) -> String {
        let percent = "\(Int((confidence * 100).rounded()))% confidence"
        guard let factorCount else { return percent }
        return "\(percent) · \(factorCount)-factor analysis"
    }

    private var fillColor: Color {
        hasData ? Color.stressColor(for: category) : Color(hex: "#8E8E93")
    }

    private var mood: RippleMood {
        hasData ? RippleMood.from(stressLevel: level) : .serene
    }

    private var accessibilityLabel: String {
        guard hasData else { return "Current stress: no data yet." }
        return "Current stress, \(category.displayName). \(substate)."
    }
}

// MARK: - SemicircleArc

/// Top-half semicircle arc drawn from the left baseline over the top to the
/// right baseline. `progress` (0…1) draws a prefix of the arc from the left.
/// Built as a sampled polyline so the fill direction and the tick position
/// share one parametrization.
struct SemicircleArc: Shape {
    var progress: Double
    var samples: Int = 64

    func path(in rect: CGRect) -> Path {
        let thickness: CGFloat = 12
        let radius = (min(rect.width, rect.height * 2) - thickness) / 2
        let cx = rect.midX
        let cy = rect.maxY - thickness / 2
        var path = Path()
        let n = max(2, samples)
        for i in 0...n {
            let t = progress * Double(i) / Double(n)
            let angle = Double.pi * (1 - t)
            let x = cx + radius * cos(angle)
            let y = cy - radius * sin(angle)
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        return path
    }
}

// MARK: - TickMarker

/// Endpoint marker at the fill tip — small filled circle with a white ring,
/// positioned at `progress` along the same arc parametrization.
private struct TickMarker: View {
    let progress: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let thickness: CGFloat = 12
            let radius = (min(geo.size.width, geo.size.height * 2) - thickness) / 2
            let cx = geo.size.width / 2
            let cy = geo.size.height - thickness / 2
            let angle = Double.pi * (1 - progress)
            let x = cx + radius * cos(angle)
            let y = cy - radius * sin(angle)
            Circle()
                .fill(color)
                .overlay(Circle().stroke(.white, lineWidth: 2))
                .frame(width: 10, height: 10)
                .position(x: x, y: y)
        }
    }
}

// MARK: - Preview

#Preview("StressHeroCard — Mild") {
    StressHeroCard(level: 42, category: .mild, confidence: 0.96, measuredAt: Date(), substate: "Focused · steady morning", factorCount: 5)
        .padding()
        .background(HomeCharacterDesignTokens.homeBackground)
}

#Preview("StressHeroCard — High") {
    StressHeroCard(level: 82, category: .high, confidence: 0.91, measuredAt: Date(), substate: "Racing · push back lunch")
        .padding()
        .background(HomeCharacterDesignTokens.homeBackground)
}

#Preview("StressHeroCard — No Data") {
    StressHeroCard(level: 0, category: .relaxed, confidence: nil, measuredAt: nil)
        .padding()
        .background(HomeCharacterDesignTokens.homeBackground)
}
