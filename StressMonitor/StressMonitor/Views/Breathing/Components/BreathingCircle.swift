import SwiftUI

/// Animated breathing arena (UI V2 `.breath`): two `accentSoft` aura rings
/// and an accent core with a soft `accentTint` highlight.
///
/// - r1: outer aura (100% width, scale 0.85 ↔ 1.05)
/// - r2: mid aura (78% width, scale 0.85 ↔ 1.10)
/// - r3: core (56% width, accent with a radial highlight, scale 0.85 ↔ 1.15)
///
/// All rings scale over a 4-second easeInOut per phase, synced to the
/// 4-4-4-4 box-breathing cycle. When the caller disables animation (the
/// D-11 Reduce Motion fallback), the rings hold static mid-scale positions
/// and no animation runs.
struct BreathingCircle: View {
    let phase: BoxBreathingPhase
    var size: CGFloat = 280
    var isAnimated: Bool = true

    @State private var animate = false

    /// Target scale for the core (r3) per phase — 0.85 (contracted) ↔ 1.15 (expanded)
    private var coreScale: CGFloat {
        guard isAnimated else { return 0.95 }
        switch phase {
        case .inhale:  return animate ? 1.15 : 0.85
        case .holdIn:  return 1.15
        case .exhale:  return animate ? 0.85 : 1.15
        case .holdOut: return 0.85
        }
    }

    /// Target scale for mid aura (r2)
    private var midScale: CGFloat {
        guard isAnimated else { return 0.95 }
        switch phase {
        case .inhale:  return animate ? 1.10 : 0.85
        case .holdIn:  return 1.10
        case .exhale:  return animate ? 0.85 : 1.10
        case .holdOut: return 0.85
        }
    }

    /// Target scale for outer aura (r1)
    private var outerScale: CGFloat {
        guard isAnimated else { return 0.95 }
        switch phase {
        case .inhale:  return animate ? 1.05 : 0.85
        case .holdIn:  return 1.05
        case .exhale:  return animate ? 0.85 : 1.05
        case .holdOut: return 0.85
        }
    }

    var body: some View {
        ZStack {
            // r1 — outer aura
            Circle()
                .fill(Color.V2.accentSoft.opacity(0.55))
                .frame(width: size, height: size)
                .scaleEffect(outerScale)

            // r2 — mid aura
            Circle()
                .fill(Color.V2.accentSoft)
                .frame(width: size * 0.78, height: size * 0.78)
                .scaleEffect(midScale)

            // r3 — core: accent with a soft top-left highlight
            Circle()
                .fill(Color.V2.accent)
                .overlay(
                    Circle().fill(
                        RadialGradient(
                            colors: [Color.V2.accentTint.opacity(0.55), Color.V2.accent.opacity(0)],
                            center: UnitPoint(x: 0.32, y: 0.28),
                            startRadius: 0,
                            endRadius: size * 0.3
                        )
                    )
                )
                .frame(width: size * 0.56, height: size * 0.56)
                .scaleEffect(coreScale)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Breathing guide, \(phase.label)")
        .onAppear { beginCycle() }
        .onChange(of: phase) { _, _ in beginCycle() }
    }

    private func beginCycle() {
        guard isAnimated else { return }
        animate = false
        withAnimation(.easeInOut(duration: 4)) {
            animate = true
        }
    }
}

/// Four-phase box-breathing cycle (4-4-4-4).
enum BoxBreathingPhase: String, CaseIterable, Sendable {
    case inhale, holdIn, exhale, holdOut

    var label: String {
        switch self {
        case .inhale:  return "Inhale"
        case .holdIn:  return "Hold"
        case .exhale:  return "Exhale"
        case .holdOut: return "Hold"
        }
    }

    var instruction: String {
        switch self {
        case .inhale:  return "Breathe in through your nose"
        case .holdIn:  return "Gently hold"
        case .exhale:  return "Breathe out through your mouth"
        case .holdOut: return "Hold empty"
        }
    }

    var durationSeconds: Int { 4 }
}

#Preview {
    VStack(spacing: 24) {
        BreathingCircle(phase: .inhale, size: 280)
        BreathingCircle(phase: .exhale, size: 200, isAnimated: false)
    }
    .padding()
    .background(Color.V2.bg)
}
