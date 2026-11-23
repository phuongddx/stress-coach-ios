import SwiftUI

/// Active box-breathing session screen (UI V2).
///
/// - Top row: "Box breathing" title and the time remaining
/// - Breathing arena: the growing accent circle, or, when the animated guide
///   is off (Reduce Motion by default, or the in-session toggle), a ring that
///   fills one quarter per phase, with a note explaining why
/// - Phase strip (In 4 / Hold 4 / Out 4 / Hold 4), "Cycle N of M", progress
/// - End early / Skip cycle, the animation toggle and the haptics note
///
/// Spec reference: ui-v2-design/screens.js `S.session` (default and
/// Reduce Motion). Timing, haptics and HRV capture live in
/// `BreathingSessionViewModel` and are unchanged.
struct BreathingSessionView: View {
    @State private var viewModel: BreathingSessionViewModel?
    @State private var motionReduced = false
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                if let vm = viewModel {
                    content(vm: vm)
                        .frame(minHeight: proxy.size.height)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(Color.V2.bg.ignoresSafeArea())
        .accessibleDynamicType()
        .navigationBarHidden(true)
        .onMotionDecision { decision in
            motionReduced = decision
            viewModel?.configureAnimation(motionReduced: decision)
        }
        .onAppear {
            let vm = BreathingSessionViewModel()
            vm.configureAnimation(motionReduced: motionReduced)
            vm.startSession()
            viewModel = vm
        }
        .onDisappear {
            viewModel?.endSession()
        }
        .onChange(of: viewModel?.sessionComplete ?? false) { _, completed in
            if completed, let result = viewModel?.sessionResult {
                router.actionPath.append(Route.breathingSummary(result))
            }
        }
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
        Button(action: {
            HapticManager.shared.buttonPress()
            dismiss()
        }) {
            Text("End early")
        }
        .buttonStyle(.v2(.secondary))

        Button(action: {
            HapticManager.shared.buttonPress()
            vm.skipCycle()
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
    /// seconds of the current one (secondsRemaining counts 4 → 1).
    private var fraction: CGFloat {
        let elapsed = CGFloat(min(4, max(0, 5 - secondsRemaining)))
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

    var sessionComplete: Bool {
        remainingTime <= 0
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
