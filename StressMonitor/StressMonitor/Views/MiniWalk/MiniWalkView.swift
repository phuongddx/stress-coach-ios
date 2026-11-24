import SwiftUI

/// Mini Walk session screen (UI V2).
///
/// - Top row: "Mini walk" and a Ready / Walking / Paused status pill
/// - Timer ring (WalkTimer) with the time left
/// - Steps card (steps toward the target, relaxed-tier bar)
/// - Vitals: heart rate at start and estimated distance
/// - Ready: "Start walk"; walking/paused: Pause or Resume and End session
/// - Completion overlay (MiniWalkCompleteView) when the timer runs out
///
/// Spec reference: ui-v2-design/screens.js `S.walk` (not started, running,
/// paused, complete). Timer, pedometer and heart-rate logic live in
/// `MiniWalkViewModel` and are unchanged.
struct MiniWalkView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var viewModel = MiniWalkViewModel()

    private var isReady: Bool {
        !viewModel.isRunning && !viewModel.isPaused && !viewModel.isFinished
    }

    var body: some View {
        ZStack {
            Color.V2.bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    walkHead
                        .padding(.top, 8)

                    WalkTimer(
                        progress: viewModel.progress,
                        timeDisplay: viewModel.timeDisplay,
                        targetDisplay: targetTimeLabel,
                        stepCount: viewModel.stepCount,
                        stateLabel: stateWord
                    )
                    .padding(.vertical, 8)

                    stepsCard

                    vitalsRow

                    actionButtons
                        .padding(.top, 4)

                    Text("Heart rate shows when your Apple Watch is on.")
                        .font(.footnote)
                        .foregroundStyle(Color.V2.ink3)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, V2Metrics.margin)
                .padding(.bottom, 24)
            }

            // Completion overlay
            if viewModel.showComplete {
                MiniWalkCompleteView(viewModel: viewModel) {
                    viewModel.showComplete = false
                    viewModel.reset()
                    dismiss()
                } onTrends: {
                    viewModel.showComplete = false
                    dismiss()
                }
                .motionAwareTransition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animateIfMotionAllowed(.easeInOut(duration: 0.3), value: viewModel.showComplete)
        .navigationBarHidden(true)
        .accessibleDynamicType()
        .onDisappear { viewModel.cleanup() }
    }

    // MARK: - Walk Head

    private var walkHead: some View {
        HStack {
            Text("Mini walk")
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.V2.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            statusPill
        }
        .frame(minHeight: V2Metrics.minTouchTarget)
    }

    private var statusPill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(viewModel.isRunning ? StressCategory.relaxed.fillColor : Color.V2.ink3)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(statusText)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(viewModel.isRunning ? StressCategory.relaxed.color : Color.V2.ink2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.V2.surface2))
        .accessibilityElement(children: .combine)
    }

    private var statusText: String {
        if viewModel.isRunning { return "Walking" }
        if viewModel.isPaused { return "Paused" }
        if viewModel.isFinished { return "Done" }
        return "Ready"
    }

    private var stateWord: String {
        if viewModel.isRunning { return "left" }
        if viewModel.isPaused { return "Paused" }
        if viewModel.isFinished { return "Done" }
        return "Ready"
    }

    // MARK: - Steps

    private var stepProgress: Double {
        guard viewModel.targetSteps > 0 else { return 0 }
        return min(1, Double(viewModel.stepCount) / Double(viewModel.targetSteps))
    }

    private var stepsCard: some View {
        V2Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Steps")
                        .font(.subheadline)
                        .foregroundStyle(Color.V2.ink2)
                    Spacer(minLength: 8)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(viewModel.stepDisplay)
                            .font(.v2Number(.title2, weight: .bold))
                            .foregroundStyle(Color.V2.ink)
                        Text("/ \(viewModel.targetSteps.formatted())")
                            .font(.v2Number(.subheadline, weight: .medium))
                            .foregroundStyle(Color.V2.ink3)
                    }
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.V2.surface2)
                        Capsule()
                            .fill(StressCategory.relaxed.fillColor)
                            .frame(width: geo.size.width * stepProgress)
                    }
                }
                .frame(height: 8)
                .accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Steps: \(viewModel.stepDisplay) of \(viewModel.targetSteps.formatted())")
        }
    }

    // MARK: - Vitals

    private var vitalsRow: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 8))
        return layout {
            WalkVital(
                icon: "heart.fill",
                label: "Heart rate at start",
                value: viewModel.bpmDisplay,
                unit: viewModel.hasBPM ? "bpm" : nil
            )
            WalkVital(
                icon: "point.topleft.down.to.point.bottomright.curvepath",
                label: "Est. distance",
                value: distanceLabel,
                unit: "mi"
            )
        }
    }

    // MARK: - Buttons

    @ViewBuilder
    private var actionButtons: some View {
        if isReady {
            VStack(spacing: 4) {
                Button(action: { viewModel.start() }) {
                    Text("Start walk")
                }
                .buttonStyle(.v2(.primary))

                Button(action: endSession) {
                    Text("Not now")
                }
                .buttonStyle(.v2(.ghost, compact: true))
            }
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { runningButtons }
                VStack(spacing: 10) { runningButtons }
            }
        }
    }

    @ViewBuilder
    private var runningButtons: some View {
        Button(action: {
            if viewModel.isRunning {
                viewModel.pause()
            } else {
                viewModel.start()
            }
        }) {
            Text(viewModel.isRunning ? "Pause" : "Resume")
        }
        .buttonStyle(.v2(.secondary))

        Button(action: endSession) {
            Text("End session")
        }
        .buttonStyle(.v2(.destructive))
    }

    private func endSession() {
        viewModel.reset()
        dismiss()
    }

    // MARK: - Computed Helpers

    private var targetTimeLabel: String {
        let mins = viewModel.durationSeconds / 60
        return "\(mins):00"
    }

    /// Step-based estimate (~2.1 ft per step), not tracked distance.
    private var distanceLabel: String {
        guard viewModel.stepCount > 0 else { return "0.00" }
        let feet = Double(viewModel.stepCount) * 2.1
        let miles = feet / 5280.0
        return String(format: "%.2f", miles)
    }
}

// MARK: - Vital tile

/// UI V2 `.vit`: surface card with an icon, a footnote label and a number.
struct WalkVital: View {
    let icon: String
    let label: String
    let value: String
    let unit: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.V2.accent)
                    .accessibilityHidden(true)
                Text(label)
                    .font(.footnote)
                    .foregroundStyle(Color.V2.ink3)
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.v2Number(.title2, weight: .bold))
                    .foregroundStyle(Color.V2.ink)
                if let unit {
                    Text(unit)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.V2.ink3)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: V2Metrics.radiusMD, style: .continuous)
                .fill(Color.V2.surface)
        )
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        MiniWalkView()
    }
}

#Preview("Dark") {
    NavigationStack {
        MiniWalkView()
    }
    .preferredColorScheme(.dark)
}
