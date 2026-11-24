import ActivityKit
import Foundation

/// Starts, updates and ends the breathing Live Activity (app side).
///
/// Shows on the Lock Screen and in the Dynamic Island, and stays visible on
/// the iPhone Duo outer display while the session runs on the inner one.
/// Fails quietly when Live Activities are off: the session never depends on
/// it.
@MainActor
final class BreathingLiveActivityController {
    private var activity: Activity<BreathingActivityAttributes>?

    nonisolated init() {}

    func start(for session: BreathingSessionViewModel) {
        guard activity == nil, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // A session left over from a process that was killed mid-session
        // (its activity outlives the app) is over: one session at a time.
        for orphan in Activity<BreathingActivityAttributes>.activities {
            Task { await orphan.end(nil, dismissalPolicy: .immediate) }
        }
        let attributes = BreathingActivityAttributes(sessionDuration: Int(session.sessionDuration))
        activity = try? Activity.request(
            attributes: attributes,
            content: ActivityContent(state: Self.state(for: session), staleDate: nil)
        )
    }

    func update(for session: BreathingSessionViewModel) {
        guard let activity else { return }
        let content = ActivityContent(state: Self.state(for: session), staleDate: nil)
        Task { await activity.update(content) }
    }

    func end(for session: BreathingSessionViewModel?) {
        guard let activity else { return }
        self.activity = nil
        let final = session.map { ActivityContent(state: Self.state(for: $0), staleDate: nil) }
        Task { await activity.end(final, dismissalPolicy: .immediate) }
    }

    static func state(for session: BreathingSessionViewModel, now: Date = .now) -> BreathingActivityAttributes.ContentState {
        let secondsLeft = max(0, Int(session.remainingTime.rounded()))
        return BreathingActivityAttributes.ContentState(
            phaseLabel: session.boxPhase.label,
            cycle: min(session.cyclesCompleted + 1, session.totalCycles),
            totalCycles: session.totalCycles,
            endDate: now.addingTimeInterval(TimeInterval(secondsLeft)),
            secondsLeft: secondsLeft,
            isPaused: session.isPaused
        )
    }
}
