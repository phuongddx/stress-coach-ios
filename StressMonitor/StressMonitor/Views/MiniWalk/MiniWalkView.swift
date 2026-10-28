import SwiftUI

/// Mini Walk active session screen — redesigned per `15-walk.html`.
///
/// Light green-tinted background with:
/// - Header row (mode label + LIVE indicator)
/// - Circular timer ring (WalkTimer) with walk icon, time, target
/// - Target line (goal + percent)
/// - Stats tiles (steps / heart rate at start / estimated distance)
/// - Pause / End Session buttons
struct MiniWalkView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = MiniWalkViewModel()

    // Design tokens from app.css / 15-walk.html
    private let success = Color(hex: "#34C759")
    private let blossom = Color(hex: "#A5D6A7")
    private let hrColor = Color(hex: "#F87171")
    private let surface = Color.white
    private let fg = Color(hex: "#101223")
    private let fgSecondary = Color(hex: "#3C3C43")
    private let muted = Color(hex: "#777986")
    private let separator = Color(red: 60/255, green: 60/255, blue: 67/255).opacity(0.12)
    private let danger = Color(hex: "#FF3B30")

    var body: some View {
        ZStack {
            // Gradient background matching .walk-stage
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.957, green: 0.984, blue: 0.957),  // #F4FBF4
                        Color.white
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
                RadialGradient(
                    colors: [blossom.opacity(0.30), Color.clear],
                    center: .bottom,
                    startRadius: 50,
                    endRadius: 300
                )
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header row
                walkHead
                    .padding(.top, 16)

                Spacer()

                // Timer ring
                WalkTimer(
                    progress: viewModel.progress,
                    timeDisplay: viewModel.timeDisplay,
                    targetDisplay: targetTimeLabel,
                    stepCount: viewModel.stepCount
                )

                // Target line
                targetLine
                    .padding(.top, 12)

                // Live stats
                liveStats
                    .padding(.top, 20)

                // Buttons
                actionButtons
                    .padding(.top, 16)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)

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
        .animation(.easeInOut(duration: 0.3), value: viewModel.showComplete)
        .navigationBarHidden(true)
        .accessibleDynamicType()
        .onDisappear { viewModel.cleanup() }
    }

    // MARK: - Walk Head

    private var walkHead: some View {
        HStack {
            Text("Mini walk")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(muted)
            Spacer()
            HStack(spacing: 6) {
                Circle()
                    .fill(success)
                    .frame(width: 6, height: 6)
                    .opacity(viewModel.isRunning ? 1 : 0.4)
                    .scaleEffect(viewModel.isRunning ? 1.0 : 0.8)
                    .animateIfMotionAllowed(
                        .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: viewModel.isRunning
                    )
                Text(viewModel.isRunning ? "LIVE" : "PAUSED")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(success)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(success.opacity(0.14))
            .clipShape(Capsule())
        }
    }

    // MARK: - Target Line

    private var targetLine: some View {
        HStack {
            Text("Goal · \(viewModel.targetSteps) steps · \(targetTimeLabel)")
                .font(.system(size: 13))
                .foregroundStyle(fgSecondary)
            Spacer()
            Text("\(Int((viewModel.progress * 100).rounded()))%")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(fg)
        }
        .frame(maxWidth: 260)
    }

    // MARK: - Live Stats

    private var liveStats: some View {
        HStack(spacing: 8) {
            liveStatTile(
                value: "\(viewModel.stepCount)",
                suffix: nil,
                label: "STEPS",
                color: blossom
            )
            liveStatTile(
                value: viewModel.bpmDisplay,
                suffix: viewModel.hasBPM ? "bpm" : nil,
                label: "HR AT START",
                color: hrColor
            )
            liveStatTile(
                value: distanceLabel,
                suffix: "mi",
                label: "EST. DIST.",
                color: success
            )
        }
        .frame(maxWidth: 260)
    }

    private func liveStatTile(value: String, suffix: String?, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                if let suffix {
                    Text(suffix)
                        .font(.system(size: 11))
                        .foregroundStyle(muted)
                }
            }
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(0.4)
                .foregroundStyle(muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(surface.opacity(0.8))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(separator, lineWidth: 1))
        )
    }

    // MARK: - Buttons

    private var actionButtons: some View {
        HStack(spacing: 10) {
            // Pause / Resume
            Button(action: {
                if viewModel.isPaused {
                    viewModel.start()
                } else if !viewModel.isRunning {
                    viewModel.start()
                } else {
                    viewModel.pause()
                }
            }) {
                Text(viewModel.isRunning ? "Pause" : (viewModel.isPaused ? "Resume" : "Start"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(fg)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(red: 60/255, green: 60/255, blue: 67/255).opacity(0.08))
                    )
            }

            // End Session
            Button(action: {
                viewModel.reset()
                dismiss()
            }) {
                Text("End Session")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(danger)
                    )
            }
        }
        .frame(maxWidth: 260)
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

#Preview {
    NavigationStack {
        MiniWalkView()
    }
}
