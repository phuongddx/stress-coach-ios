import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Live Activity Widget

/// Live Activity for a running box-breathing session: the Ripple v2 head and
/// the time left everywhere; the phase, the cycle and Pause / End on the Lock
/// Screen and in the expanded Dynamic Island. The attributes and the button
/// intents live in `StressMonitor/LiveActivity/BreathingActivityShared.swift`,
/// compiled into both targets.
struct StressMonitorWidgetLiveActivity: Widget {
    /// Breathing is the calm pose the widget has a head for.
    private static let pose = WidgetRipplePose.relaxed

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BreathingActivityAttributes.self) { context in
            lockScreen(context)
                .padding(16)
                .activityBackgroundTint(Color.V2.bg)
                .activitySystemActionForegroundColor(Color.V2.accent)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    rippleHead(size: 44)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    timeLeft(context)
                        .font(.title2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Color.V2.accent)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text("Box breathing")
                            .font(.headline)
                        Text(statusLine(context))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    controls(context)
                }
            } compactLeading: {
                rippleHead(size: 24)
            } compactTrailing: {
                timeLeft(context)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Color.V2.accent)
                    .frame(maxWidth: 44)
            } minimal: {
                rippleHead(size: 22)
            }
        }
    }

    // MARK: - Pieces

    private func lockScreen(_ context: ActivityViewContext<BreathingActivityAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                rippleHead(size: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Box breathing")
                        .font(.headline)
                        .foregroundStyle(Color.V2.ink)
                    Text(statusLine(context))
                        .font(.subheadline)
                        .foregroundStyle(Color.V2.ink2)
                }
                Spacer(minLength: 8)
                timeLeft(context)
                    .font(.title2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Color.V2.accent)
            }
            controls(context)
        }
    }

    private func rippleHead(size: CGFloat) -> some View {
        Image(Self.pose.headAssetName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel(Self.pose.accessibilityLabel)
    }

    /// Counts down by itself while running; a still value while paused.
    @ViewBuilder
    private func timeLeft(_ context: ActivityViewContext<BreathingActivityAttributes>) -> some View {
        let state = context.state
        if state.isPaused {
            Text(Self.clock(state.secondsLeft))
                .accessibilityLabel("\(Self.clock(state.secondsLeft)) left, paused")
        } else {
            let start = state.endDate.addingTimeInterval(-TimeInterval(context.attributes.sessionDuration))
            Text(timerInterval: min(start, state.endDate)...state.endDate, countsDown: true)
                .multilineTextAlignment(.trailing)
                .accessibilityLabel("Time left")
        }
    }

    private func statusLine(_ context: ActivityViewContext<BreathingActivityAttributes>) -> String {
        let state = context.state
        let cycle = "Cycle \(state.cycle) of \(state.totalCycles)"
        return state.isPaused ? "Paused · \(cycle)" : "\(state.phaseLabel) · \(cycle)"
    }

    private func controls(_ context: ActivityViewContext<BreathingActivityAttributes>) -> some View {
        HStack(spacing: 10) {
            Button(intent: ToggleBreathingPauseIntent()) {
                Label(
                    context.state.isPaused ? "Resume" : "Pause",
                    systemImage: context.state.isPaused ? "play.fill" : "pause.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .tint(Color.V2.accentSoft)
            .foregroundStyle(Color.V2.accent)

            Button(intent: EndBreathingIntent()) {
                Label("End", systemImage: "xmark")
                    .frame(maxWidth: .infinity)
            }
            .tint(Color.V2.accent)
            .foregroundStyle(.white)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .font(.subheadline.weight(.semibold))
    }

    private static func clock(_ seconds: Int) -> String {
        let s = max(0, seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - Previews

#Preview("Running", as: .content, using: BreathingActivityAttributes(sessionDuration: 120)) {
    StressMonitorWidgetLiveActivity()
} contentStates: {
    BreathingActivityAttributes.ContentState(
        phaseLabel: "Breathe in", cycle: 3, totalCycles: 7,
        endDate: .now.addingTimeInterval(84), secondsLeft: 84, isPaused: false
    )
    BreathingActivityAttributes.ContentState(
        phaseLabel: "Hold", cycle: 3, totalCycles: 7,
        endDate: .now.addingTimeInterval(84), secondsLeft: 84, isPaused: true
    )
}
