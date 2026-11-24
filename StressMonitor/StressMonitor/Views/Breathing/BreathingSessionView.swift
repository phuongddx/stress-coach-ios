import SwiftUI

/// Active box-breathing session screen (UI V2).
///
/// - Top row: "Box breathing" title and the time remaining
/// - Breathing arena: the growing accent circle, or, when the animated guide
///   is off (Reduce Motion by default, or the in-session toggle), a ring that
///   fills one quarter per phase, with a note explaining why
/// - Phase strip (In 4 / Hold 4 / Out 4 / Hold 4), "Cycle N of M", progress
/// - End early / Pause / Skip cycle, the animation toggle and the haptics note
/// - iPhone Duo inner display: the guide and the controls on either side of
///   the fold (see `FoldAwareSplit`)
///
/// Spec reference: ui-v2-design/screens.js `S.session` (default and
/// Reduce Motion). Timing, haptics and HRV capture live in
/// `BreathingSessionViewModel`; the running session is kept by
/// `SceneContinuity`.
struct BreathingSessionView: View {
    @State private var viewModel: BreathingSessionViewModel?
    @State private var motionReduced = false
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(SceneContinuity.self) private var injectedContinuity: SceneContinuity?
    /// Used only where no scene injects one (previews).
    @State private var fallbackContinuity = SceneContinuity(liveActivity: nil)

    /// The session lives in `SceneContinuity`, not in this view, so the
    /// timer keeps running when the iPhone Duo folds or unfolds and this
    /// screen is rebuilt for the other display.
    private var continuity: SceneContinuity {
        injectedContinuity ?? fallbackContinuity
    }

    var body: some View {
        // Never empty: `onAppear` on an empty container does not fire, and
        // the session is attached from there.
        ZStack {
            Color.V2.bg.ignoresSafeArea()
            if let vm = viewModel {
                switch DuoLayout.mode(for: horizontalSizeClass) {
                case .singleColumn:
                    GeometryReader { proxy in
                        ScrollView {
                            content(vm: vm)
                                .frame(minHeight: proxy.size.height)
                        }
                        .scrollBounceBehavior(.basedOnSize)
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier(DuoLayoutID.singleColumn)
                case .twoColumns:
                    // Duo inner display: the guide on one side of the fold,
                    // everything to read and tap on the other. Along the
                    // longer side, so the laptop pose puts the ring on the
                    // top half and the controls on the bottom half.
                    FoldAwareSplit(axis: nil) {
                        arenaPane(vm: vm)
                    } trailing: {
                        ScrollView {
                            controlPane(vm: vm)
                        }
                        .defaultScrollAnchor(.center, for: .alignment)
                        .scrollBounceBehavior(.basedOnSize)
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier(DuoLayoutID.twoColumns)
                }
            }
        }
        .accessibleDynamicType()
        .navigationBarHidden(true)
        .onMotionDecision { decision in
            motionReduced = decision
            viewModel?.configureAnimation(motionReduced: decision)
        }
        .onAppear {
            let reduced = motionReduced
            viewModel = continuity.attachBreathing(configure: { vm in
                vm.configureAnimation(motionReduced: reduced)
            })
        }
        .onDisappear {
            continuity.detachBreathing()
        }
        .onChange(of: viewModel?.boxPhase) {
            continuity.breathingDidChange()
        }
        .onChange(of: viewModel?.isPaused) {
            continuity.breathingDidChange()
        }
        .onChange(of: viewModel?.completedResult) { _, result in
            if let result {
                router.actionPath.append(Route.breathingSummary(result))
                continuity.endBreathing()
            }
        }
        .onChange(of: continuity.breathingSession == nil) { _, ended in
            // Ended from the Live Activity: leave the screen too.
            if ended, viewModel?.completedResult == nil {
                dismiss()
            }
        }
    }

    private func endEarly() {
        HapticManager.shared.buttonPress()
        continuity.endBreathing()
    }

    // MARK: - Layout

    private func content(vm: BreathingSessionViewModel) -> some View {
        VStack(spacing: 16) {
            topRow(vm: vm)
                .padding(.top, 8)

            Spacer(minLength: 8)

            arena(vm: vm)

            if !vm.isAnimationEnabled {
                ringNote
            }

            Spacer(minLength: 8)

            VStack(spacing: 12) {
                phaseStrip(vm: vm)
                cycleLine(vm: vm)
                progressBar(fraction: vm.sessionProgressFraction, animated: vm.isAnimationEnabled)
            }

            controls(vm: vm)
                .padding(.bottom, 16)
        }
        .padding(.horizontal, V2Metrics.margin)
    }

    /// Two columns: the guide, centred in its half.
    private func arenaPane(vm: BreathingSessionViewModel) -> some View {
        VStack(spacing: 16) {
            arena(vm: vm)
            if !vm.isAnimationEnabled {
                ringNote
                    .frame(maxWidth: 360)
            }
        }
        .padding(.horizontal, V2Metrics.margin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Two columns: title, time, phase, progress and the controls.
    private func controlPane(vm: BreathingSessionViewModel) -> some View {
        VStack(spacing: 16) {
            topRow(vm: vm)
            VStack(spacing: 12) {
                phaseStrip(vm: vm)
                cycleLine(vm: vm)
                progressBar(fraction: vm.sessionProgressFraction, animated: vm.isAnimationEnabled)
            }
            controls(vm: vm)
        }
        .padding(.horizontal, V2Metrics.margin)
        .padding(.vertical, 16)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Top Row

    private func topRow(vm: BreathingSessionViewModel) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Box breathing")
                .font(.headline)
                .foregroundStyle(Color.V2.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            Text(vm.remainingTimeString)
                .font(.v2Number(.headline, weight: .semibold))
                .foregroundStyle(Color.V2.ink2)
                .accessibilityLabel("\(vm.remainingTimeString) remaining")
        }
        .frame(minHeight: V2Metrics.minTouchTarget)
    }

    // MARK: - Arena

    @ViewBuilder
    private func arena(vm: BreathingSessionViewModel) -> some View {
        if vm.isAnimationEnabled {
            ZStack {
                BreathingCircle(
                    phase: vm.boxPhase,
                    size: 280,
                    isAnimated: true
                )
                PhaseLabel(
                    phase: vm.boxPhase,
                    secondsRemaining: vm.secondsRemaining
                )
            }
            .frame(height: 300)
        } else {
            BreathingFillRing(phase: vm.boxPhase, secondsRemaining: vm.secondsRemaining)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(vm.boxPhase.label), \(vm.secondsRemaining) seconds remaining")
        }
    }

    /// D-11 fallback explainer, shown whenever the animated guide is off.
    private var ringNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "figure.mind.and.body")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.V2.accent)
                .accessibilityHidden(true)
            Text(motionReduced
                 ? "Reduce Motion is on, so the ring fills instead of growing. Haptics mark each change."
                 : "Animation is off, so the ring fills instead of growing. Haptics mark each change.")
                .font(.footnote)
                .foregroundStyle(Color.V2.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .v2CardBackground(.flat)
    }

    // MARK: - Phase Strip

    private func phaseStrip(vm: BreathingSessionViewModel) -> some View {
        let phases: [BoxBreathingPhase] = [.inhale, .holdIn, .exhale, .holdOut]
        let currentIndex = phases.firstIndex(of: vm.boxPhase) ?? 0

        return HStack(alignment: .top, spacing: 8) {
            ForEach(0..<4, id: \.self) { i in
                let isActive = i == currentIndex
                let isDone = i < currentIndex
                VStack(spacing: 6) {
                    Capsule()
                        .fill(isActive ? Color.V2.accent : (isDone ? Color.V2.accentTint : Color.V2.surface2))
                        .frame(height: 4)
                    Text("\(stripLabel(phases[i])) 4")
                        .font(isActive ? .footnote.weight(.bold) : .footnote)
                        .foregroundStyle(isActive ? Color.V2.accent : Color.V2.ink3)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Phase \(currentIndex + 1) of 4, \(vm.boxPhase.label)")
    }

    private func stripLabel(_ phase: BoxBreathingPhase) -> String {
        switch phase {
        case .inhale:  return "In"
        case .holdIn:  return "Hold"
        case .exhale:  return "Out"
        case .holdOut: return "Hold"
        }
    }

    private func cycleLine(vm: BreathingSessionViewModel) -> some View {
        let current = min(vm.cyclesCompleted + 1, vm.totalCycles)
        return Text("Cycle \(current) of \(vm.totalCycles)")
            .font(.v2Number(.subheadline, weight: .medium))
            .foregroundStyle(Color.V2.ink2)
    }

    // MARK: - Progress Bar

    private func progressBar(fraction: Double, animated: Bool) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.V2.surface2)
                Capsule()
                    .fill(Color.V2.accent)
                    .frame(width: geo.size.width * min(1, max(0, fraction)))
                    .animation(animated ? .easeInOut(duration: 0.3) : nil, value: fraction)
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }

    // MARK: - Controls

    private func controls(vm: BreathingSessionViewModel) -> some View {
        VStack(spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { controlButtons(vm: vm) }
                VStack(spacing: 10) { controlButtons(vm: vm) }
            }

            Toggle(isOn: animationToggleBinding(vm: vm)) {
                Text("Breathing animation")
                    .font(.subheadline)
                    .foregroundStyle(Color.V2.ink2)
            }
            .toggleStyle(.switch)
            .tint(Color.V2.accent)
            .frame(minHeight: V2Metrics.minTouchTarget)

            Text("Haptic and heartbeat cue on each change")
                .font(.footnote)
                .foregroundStyle(Color.V2.ink3)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private func controlButtons(vm: BreathingSessionViewModel) -> some View {
        Button(action: endEarly) {
            Text("End early")
        }
        .buttonStyle(.v2(.secondary))

        Button(action: {
            HapticManager.shared.buttonPress()
            vm.togglePause()
        }) {
            Label(vm.isPaused ? "Resume" : "Pause", systemImage: vm.isPaused ? "play.fill" : "pause.fill")
        }
        .buttonStyle(.v2(.secondary))

        Button(action: {
            HapticManager.shared.buttonPress()
            continuity.skipBreathingCycle()
        }) {
            Text("Skip cycle")
        }
        .buttonStyle(.v2(.primary))
    }

    private func animationToggleBinding(vm: BreathingSessionViewModel) -> Binding<Bool> {
        Binding(
            get: { vm.isAnimationEnabled },
            set: { vm.setAnimationEnabled($0) }
        )
    }
}

// MARK: - Reduce Motion ring

/// The D-11 still guide (UI V2 `S.session` Reduce Motion): a 240 pt ring
/// on `accentSoft` that fills one quarter per 4-second phase in one-second
/// steps, with tick marks between the quarters. No animation.
struct BreathingFillRing: View {
    let phase: BoxBreathingPhase
    let secondsRemaining: Int
    var size: CGFloat = 240

    private let lineWidth: CGFloat = 14

    private var phaseIndex: Int {
        BoxBreathingPhase.allCases.firstIndex(of: phase) ?? 0
    }

    /// Filled share of the whole ring: completed quarters plus the elapsed
    /// seconds of the current one. secondsRemaining counts 4 → 1, so a phase
    /// starts at 0 elapsed and its quarter completes at the next phase.
    private var fraction: CGFloat {
        let elapsed = CGFloat(min(4, max(0, 4 - secondsRemaining)))
        return (CGFloat(phaseIndex) + elapsed / 4) / 4
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.V2.accentSoft)
                .padding(lineWidth / 2)

            Circle()
                .stroke(Color.V2.surface2, lineWidth: lineWidth)
                .padding(lineWidth / 2)

            Circle()
                .trim(from: 0, to: fraction)
                .stroke(Color.V2.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                .rotationEffect(.degrees(-90))
                .padding(lineWidth / 2)

            ForEach(0..<4, id: \.self) { i in
                Rectangle()
                    .fill(Color.V2.bg)
                    .frame(width: 3, height: lineWidth + 2)
                    .offset(y: -(size / 2 - lineWidth / 2))
                    .rotationEffect(.degrees(Double(i) * 90))
            }

            VStack(spacing: 2) {
                Text(phase.label)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.V2.accent)
                Text("\(secondsRemaining)")
                    .font(.v2Number(.largeTitle, weight: .bold))
                    .foregroundStyle(Color.V2.ink)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - ViewModel Convenience

extension BreathingSessionViewModel {
    var remainingTimeString: String {
        let t = max(0, remainingTime)
        return String(format: "%d:%02d", Int(t) / 60, Int(t) % 60)
    }

    /// Fraction of session elapsed (0 → 1) for the progress bar.
    var sessionProgressFraction: Double {
        guard sessionDuration > 0 else { return 0 }
        return 1.0 - (remainingTime / sessionDuration)
    }
}

#Preview {
    NavigationStack {
        BreathingSessionView()
            .stressNavigationDestinations()
    }
    .environment(AppRouter())
}

#Preview("Fill ring") {
    HStack {
        BreathingFillRing(phase: .holdIn, secondsRemaining: 2, size: 160)
        BreathingFillRing(phase: .holdOut, secondsRemaining: 1, size: 160)
    }
    .padding()
    .background(Color.V2.bg)
}
