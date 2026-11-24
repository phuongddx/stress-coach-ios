import SwiftUI

/// Hero stress card for the Home tab (UI V2).
///
/// A `V2StressGauge` carries the score and tier; Ripple sits in the gauge's
/// bottom opening so the companion's expression still mirrors the reading.
/// Below the gauge: the substate line and small tags for time, confidence and
/// factor count. At accessibility text sizes the companion moves below the
/// gauge and the tags stack.
///
/// Spec reference: ui-v2-design/screens.js `S.home` hero.
struct StressHeroCard: View {
    let level: Double
    let category: StressCategory
    let confidence: Double?
    let measuredAt: Date?
    let substate: String
    /// Number of factors that fed the score. Nil leaves the factor tag off.
    let factorCount: Int?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
    private var isLargeText: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        VStack(spacing: 12) {
            Text("Stress now")
                .v2Eyebrow()
                .frame(maxWidth: .infinity, alignment: .leading)
                // Leaves room for the science info button the dashboard overlays.
                .padding(.trailing, V2Metrics.minTouchTarget)

            gaugeStage

            if isLargeText {
                companion(size: 64)
            }

            stateRow
        }
        .padding(.horizontal, V2Metrics.margin)
        .padding(.top, 20)
        .padding(.bottom, V2Metrics.margin)
        .frame(maxWidth: .infinity)
        .v2CardBackground()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Gauge

    private var gaugeStage: some View {
        V2StressGauge(score: hasData ? level : nil)
            .frame(maxWidth: isLargeText ? 260 : 216)
            .overlay(alignment: .bottom) {
                if !isLargeText {
                    companion(size: 52)
                }
            }
            .accessibilityHidden(true)
    }

    private func companion(size: CGFloat) -> some View {
        // Adjacent text already says the level, so the drawing stays hidden.
        StressBuddyIllustration(mood: ambientMood, size: size, pose: pose, crop: .full)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    // MARK: - State row

    @ViewBuilder
    private var stateRow: some View {
        if hasData {
            VStack(spacing: 12) {
                Text(substate)
                    .font(.subheadline)
                    .foregroundStyle(Color.V2.ink2)
                    .multilineTextAlignment(.center)
                tags
            }
        } else {
            Text("Waiting for a reading. Wear your watch; HRV is recorded when you're still.")
                .font(.subheadline)
                .foregroundStyle(Color.V2.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var tags: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { tagItems }
            VStack(spacing: 6) { tagItems }
        }
    }

    @ViewBuilder
    private var tagItems: some View {
        if let measuredAt {
            HeroTag(systemImage: "clock", text: measuredAt.formatted(date: .omitted, time: .shortened))
        }
        if let confidence {
            HeroTag(text: "\(Int((confidence * 100).rounded()))% confidence")
        }
        if let factorCount {
            HeroTag(text: "\(factorCount) factors")
        }
    }

    // MARK: - Helpers

    /// Ripple v2 drawing: level pose from the category, `.base` with no data.
    private var pose: RipplePose {
        hasData ? RipplePose.from(category: category) : .base
    }

    /// Ambient animation only (breathe / fidget / shake / dizzy), keyed off the
    /// same category so it follows the drawing. Reduce Motion holds it still.
    private var ambientMood: RippleMood {
        guard hasData else { return .serene }
        switch category {
        case .relaxed:  return .relaxed
        case .mild:     return .focused
        case .moderate: return .worried
        case .high:     return .tired
        case .severe:   return .determined
        }
    }

    private var accessibilityLabel: String {
        guard hasData else { return "Current stress: no data yet." }
        var parts = ["Current stress \(Int(level.rounded())) of 100, \(category.displayName). \(substate)."]
        if let confidence { parts.append("\(Int((confidence * 100).rounded()))% confidence.") }
        return parts.joined(separator: " ")
    }
}

/// Small neutral tag used under the hero gauge.
private struct HeroTag: View {
    var systemImage: String? = nil
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .imageScale(.small)
                    .accessibilityHidden(true)
            }
            Text(text)
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(Color.V2.ink2)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.V2.surface2))
        .lineLimit(1)
        .fixedSize()
    }
}

// MARK: - Preview

#Preview("StressHeroCard — Mild") {
    StressHeroCard(level: 32, category: .mild, confidence: 0.92, measuredAt: Date(), substate: "Focused · steady", factorCount: 5)
        .padding()
        .background(Color.V2.bg)
}

#Preview("StressHeroCard — High") {
    StressHeroCard(level: 82, category: .high, confidence: 0.91, measuredAt: Date(), substate: "Wired · ease off")
        .padding()
        .background(Color.V2.bg)
}

#Preview("StressHeroCard — No Data") {
    StressHeroCard(level: 0, category: .relaxed, confidence: nil, measuredAt: nil)
        .padding()
        .background(Color.V2.bg)
}
