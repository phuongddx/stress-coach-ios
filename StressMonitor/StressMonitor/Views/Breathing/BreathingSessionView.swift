import SwiftUI

/// Active box-breathing session screen — redesigned per `08-breathing-active.html`.
///
/// Light gradient background with:
/// - Meta row (remaining time / cycles completed)
/// - Breathing arena (BreathingCircle + PhaseLabel inside core)
/// - Phase track (4 dots showing inhale→hold→exhale→hold progress)
/// - Progress bar + End early / Skip cycle buttons
struct BreathingSessionView: View {
    @State private var viewModel: BreathingSessionViewModel?
    @State private var motionReduced = false
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router

    // Design tokens
    private let accent = Color(hex: "#4FC3F7")
    private let accentStrong = Color(hex: "#0288D1")
    private let fg = Color(hex: "#101223")
    private let fgSecondary = Color(hex: "#3C3C43")
    private let muted = Color(hex: "#777986")
    private let separator = Color(red: 60/255, green: 60/255, blue: 67/255).opacity(0.12)

    var body: some View {
        ZStack {
            // Radial gradient background matching .breath-stage
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.925, green: 0.969, blue: 0.996),  // #ECF8FE
                        Color.white
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                RadialGradient(
                    colors: [accent.opacity(0.22), Color.clear],
                    center: .center,
                    startRadius: 50,
                    endRadius: 200
                )
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                if let vm = viewModel {
                    // Top meta row (remaining + cycles)
                    metaRow(vm: vm)
                        .padding(.top, 16)

                    Spacer()

                    // Breathing arena (circle + phase label inside)
                    ZStack {
                        BreathingCircle(
                            phase: vm.boxPhase,
                            size: 280,
                            isAnimated: vm.isAnimationEnabled
                        )
                        if vm.isAnimationEnabled {
                            PhaseLabel(
                                phase: vm.boxPhase,
                                secondsRemaining: vm.secondsRemaining,
                                tint: .white
                            )
                        } else {
                            fallbackStatusLine(vm: vm)
                        }
                    }
                    .frame(height: 300)

                    Spacer()

                    // Phase track (4 dots)
                    phaseTrack(vm: vm)
                        .padding(.top, 8)

                    // Progress bar + buttons
                    VStack(spacing: 12) {
                        progressBar(fraction: vm.sessionProgressFraction)

                        HStack(spacing: 10) {
                            Button(action: {
                                HapticManager.shared.buttonPress()
                                dismiss()
                            }) {
                                Text("End early")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(fg)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(Color(red: 60/255, green: 60/255, blue: 67/255).opacity(0.08))
                                    )
                            }

                            Button(action: {
                                HapticManager.shared.buttonPress()
                                vm.skipCycle()
                            }) {
                                Text("Skip cycle")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(fg)
                                    )
                            }
                        }

                        Toggle(isOn: animationToggleBinding(vm: vm)) {
                            Text("Breathing animation")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(fgSecondary)
                        }
                        .toggleStyle(.switch)
                        .tint(accentStrong)

                        Text("Haptic + heartbeat on each transition")
                            .font(.system(size: 12))
                            .foregroundStyle(muted)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
        }
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
        .onChange(of: viewModel?.completedResult) { _, result in
            if let result {
                router.actionPath.append(Route.breathingSummary(result))
            }
        }
    }

    // MARK: - D-11 Fallback (motion-reduced session presentation)

    /// Text countdown status line shown when the animated guide is off —
    /// haptic pulses carry the phase rhythm from the view model.
    private func fallbackStatusLine(vm: BreathingSessionViewModel) -> some View {
        Text(countdownLine(for: vm.boxPhase, seconds: vm.secondsRemaining))
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
            .accessibilityLabel("\(vm.boxPhase.label), \(vm.secondsRemaining) seconds remaining")
    }

    /// Contract copy: phase word + seconds ("Inhale — 3"), vocabulary matching
    /// the box-breathing step words.
    private func countdownLine(for phase: BoxBreathingPhase, seconds: Int) -> String {
        switch phase {
        case .inhale:  return "Inhale — \(seconds)"
        case .holdIn:  return "Hold — \(seconds)"
        case .exhale:  return "Exhale — \(seconds)"
        case .holdOut: return "Hold — \(seconds)"
        }
    }

    private func animationToggleBinding(vm: BreathingSessionViewModel) -> Binding<Bool> {
        Binding(
            get: { vm.isAnimationEnabled },
            set: { vm.setAnimationEnabled($0) }
        )
    }

    // MARK: - Meta Row

    private func metaRow(vm: BreathingSessionViewModel) -> some View {
        HStack(spacing: 24) {
            VStack(spacing: 2) {
                Text(vm.remainingTimeString)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(fg)
                    .monospacedDigit()
                Text("REMAINING")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(muted)
            }
            // Vertical separator
            Rectangle()
                .fill(separator)
                .frame(width: 1, height: 36)

            VStack(spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(vm.cyclesCompleted)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(fg)
                    Text("/\(vm.totalCycles)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(muted)
                }
                Text("CYCLES")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(muted)
            }
        }
        .frame(maxWidth: 280)
    }

    // MARK: - Phase Track

    private func phaseTrack(vm: BreathingSessionViewModel) -> some View {
        let phases: [BoxBreathingPhase] = [.inhale, .holdIn, .exhale, .holdOut]
        let currentIndex = phases.firstIndex(of: vm.boxPhase) ?? 0

        return HStack(spacing: 14) {
            ForEach(0..<4, id: \.self) { i in
                let phase = phases[i]
                let isActive = i == currentIndex
                let isDone = i < currentIndex

                VStack(spacing: 4) {
                    Circle()
                        .fill(dotColor(isActive: isActive, isDone: isDone))
                        .frame(width: 10, height: 10)
                        .scaleEffect(isActive ? 1.4 : 1.0)
                        .animation(vm.isAnimationEnabled ? .easeInOut(duration: 0.3) : .none, value: vm.boxPhase)
                    Text("\(phase.label) 4")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .tracking(0.4)
                        .textCase(.uppercase)
                        .foregroundStyle(isActive ? accentStrong : muted)
                        .animation(vm.isAnimationEnabled ? .easeInOut(duration: 0.3) : .none, value: vm.boxPhase)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: 280)
        .padding(.horizontal, 24)
    }

    private func dotColor(isActive: Bool, isDone: Bool) -> Color {
        if isActive { return accentStrong }
        if isDone { return accent }
        return Color(red: 60/255, green: 60/255, blue: 67/255).opacity(0.18)
    }

    // MARK: - Progress Bar

    private func progressBar(fraction: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 999)
                    .fill(Color(red: 60/255, green: 60/255, blue: 67/255).opacity(0.10))
                    .frame(height: 4)
                RoundedRectangle(cornerRadius: 999)
                    .fill(accent)
                    .frame(width: geo.size.width * min(1, max(0, fraction)), height: 4)
                    .animation(.easeInOut(duration: 0.3), value: fraction)
            }
        }
        .frame(height: 4)
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
