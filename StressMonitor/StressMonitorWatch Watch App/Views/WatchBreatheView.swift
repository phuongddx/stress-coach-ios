import SwiftUI

/// Watch **Breathe** screen — 4-7-8 guided breathing (UI V2).
///
/// True-black canvas. A teal disc breathes inside a fixed progress ring;
/// the phase name and countdown sit in the centre, and a three-part phase
/// strip ("In 4 · Hold 7 · Out 8") fills as each phase runs. With Reduce
/// Motion the disc stays still and progress is carried by the ring and
/// strip alone.
struct WatchBreatheView: View {
    private enum Phase: String, Hashable {
        case idle, inhale, hold, exhale
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: Phase = .idle
    @State private var ringScale: CGFloat = 0.55
    @State private var secondsLeft: Int = 0
    @State private var cycleCount: Int = 0
    @State private var timer: Timer?

    private let inhaleSec = 4
    private let holdSec   = 7
    private let exhaleSec = 8

    private var isRunning: Bool { phase != .idle }

    var body: some View {
        VStack(spacing: 6) {
            Spacer(minLength: 0)

            breathingRing

            phaseStrip

            Text(isRunning ? "Cycle \(cycleCount + 1)" : "4-7-8 breathing")
                .font(.caption2)
                .foregroundStyle(WatchV2.ink3)

            Spacer(minLength: 0)

            pillButton
        }
        .padding(.horizontal, WatchDesignTokens.contentSidePadding)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WatchDesignTokens.canvas.ignoresSafeArea())
        .onDisappear { stop() }
    }

    // MARK: - Subviews

    /// Fixed progress ring around a breathing disc. Only the disc scales,
    /// so the phase name and countdown stay full size.
    private var breathingRing: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [WatchV2.accentSoft, WatchV2.accentTint],
                        center: .center,
                        startRadius: 0,
                        endRadius: 52
                    )
                )
                .padding(9)
                .scaleEffect(reduceMotion ? 1 : ringScale)

            Circle()
                .stroke(WatchV2.surface2, lineWidth: 5)
                .padding(2.5)

            Circle()
                .trim(from: 0, to: phaseProgress(for: phase))
                .stroke(WatchV2.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(2.5)
                .animation(tickAnimation, value: secondsLeft)

            countdownBlock
        }
        .frame(width: 104, height: 104)
    }

    private var countdownBlock: some View {
        VStack(spacing: 0) {
            Text(phaseTitle)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(WatchV2.ink)
                .contentTransition(.opacity)
                .animation(WatchDesignTokens.motion(WatchDesignTokens.Motion.fast, reduceMotion: reduceMotion), value: phase)
            if isRunning {
                Text("\(secondsLeft)")
                    .font(.v2Number(.title, weight: .semibold))
                    .foregroundStyle(WatchV2.ink)
                    .contentTransition(.numericText(value: Double(secondsLeft)))
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.horizontal, 14)
        .accessibilityElement(children: .combine)
    }

    /// "In 4 · Hold 7 · Out 8" — each segment fills while its phase runs.
    private var phaseStrip: some View {
        HStack(spacing: 4) {
            stripSegment(.inhale, label: "In \(inhaleSec)")
            stripSegment(.hold, label: "Hold \(holdSec)")
            stripSegment(.exhale, label: "Out \(exhaleSec)")
        }
        .accessibilityElement(children: .combine)
    }

    private func stripSegment(_ p: Phase, label: String) -> some View {
        VStack(spacing: 3) {
            Capsule()
                .fill(WatchV2.surface2)
                .frame(height: 4)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(WatchV2.accent)
                            .frame(width: proxy.size.width * phaseProgress(for: p))
                    }
                }
                .animation(tickAnimation, value: secondsLeft)
            Text(label)
                .font(.caption2)
                .foregroundStyle(dotStatus(for: p) == .active ? WatchV2.ink : WatchV2.ink3)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private enum DotStatus { case upcoming, active, done }

    private func dotStatus(for p: Phase) -> DotStatus {
        let order: [Phase] = [.inhale, .hold, .exhale]
        guard let current = order.firstIndex(of: phase),
              let target = order.firstIndex(of: p) else { return .upcoming }
        if target < current { return .done }
        if target == current { return .active }
        return .upcoming
    }

    /// 0…1 fill for a phase segment, derived from the countdown.
    ///
    /// With motion, each tick animates linearly over the next second
    /// (`tickAnimation`), so the target leads by one tick and the bar lands
    /// on it as that second ends. With Reduce Motion the fill steps, so it
    /// shows elapsed seconds only and the segment fills when the phase ends.
    private func phaseProgress(for p: Phase) -> CGFloat {
        switch dotStatus(for: p) {
        case .upcoming: return 0
        case .done:     return 1
        case .active:
            let total = Double(duration(of: p))
            guard total > 0 else { return 0 }
            let lead: Double = reduceMotion ? 0 : 1
            return CGFloat(min(1, max(0, (total - Double(secondsLeft) + lead) / total)))
        }
    }

    private func duration(of p: Phase) -> Int {
        switch p {
        case .inhale: return inhaleSec
        case .hold:   return holdSec
        case .exhale: return exhaleSec
        case .idle:   return 0
        }
    }

    /// One-second linear fill per countdown tick; stepped with Reduce Motion.
    private var tickAnimation: Animation? {
        WatchDesignTokens.motion(.linear(duration: 1), reduceMotion: reduceMotion)
    }

    private var pillButton: some View {
        Button {
            isRunning ? stop() : start()
        } label: {
            Text(isRunning ? "End" : "Begin")
                .font(.headline)
                .foregroundStyle(isRunning ? WatchV2.ink : WatchV2.onAccent)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 36)
                .background(
                    Capsule(style: .continuous)
                        .fill(isRunning ? WatchV2.surface2 : WatchV2.accent)
                )
                .padding(.vertical, 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - State machine

    private var phaseTitle: String {
        switch phase {
        case .inhale: return "Breathe In"
        case .hold:   return "Hold"
        case .exhale: return "Breathe Out"
        case .idle:   return "Breathe"
        }
    }

    private func start() {
        cycleCount = 0
        beginInhale()
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
        phase = .idle
        ringScale = 0.55
        secondsLeft = 0
    }

    private func beginInhale() {
        phase = .inhale
        secondsLeft = inhaleSec
        if !reduceMotion {
            withAnimation(.easeInOut(duration: Double(inhaleSec))) { ringScale = 1.0 }
        }
        runPhase(duration: inhaleSec) { beginHold() }
    }

    private func beginHold() {
        phase = .hold
        secondsLeft = holdSec
        runPhase(duration: holdSec) { beginExhale() }
    }

    private func beginExhale() {
        phase = .exhale
        secondsLeft = exhaleSec
        if !reduceMotion {
            withAnimation(.easeInOut(duration: Double(exhaleSec))) { ringScale = 0.55 }
        }
        runPhase(duration: exhaleSec) {
            cycleCount += 1
            beginInhale() // loop until the user stops
        }
    }

    /// Drives the per-second countdown (the ring and strip fill from it).
    private func runPhase(duration: Int, onZero: @escaping () -> Void) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { t in
            if secondsLeft > 1 {
                secondsLeft -= 1
            } else {
                t.invalidate()
                onZero()
            }
        }
    }
}

#if DEBUG
#Preview {
    WatchBreatheView()
}
#endif
