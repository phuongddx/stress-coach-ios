import SwiftUI

/// Scene-owned state that has to survive the iPhone Duo opening and closing.
///
/// Folding switches between the outer display (compact width) and the inner
/// display (regular width). The layouts differ, so views may be rebuilt; the
/// state the person is in the middle of lives here instead of in those
/// views:
/// - the chat conversation and the unsent draft (the chat moves between a
///   sheet and an inline pane),
/// - the running breathing session and its timer, and its Live Activity.
///
/// The selected tab and each tab's navigation path already live in
/// `AppRouter` and are restored through `@SceneStorage`.
@MainActor
@Observable
final class SceneContinuity {

    /// Mirrors the breathing session on the Lock Screen, the Dynamic Island
    /// and the Duo outer display. Nil turns it off (tests).
    @ObservationIgnored var liveActivity: BreathingLiveActivityController?
    @ObservationIgnored private var commandObserver: (any NSObjectProtocol)?

    init(liveActivity: BreathingLiveActivityController? = BreathingLiveActivityController()) {
        self.liveActivity = liveActivity
        commandObserver = NotificationCenter.default.addObserver(
            forName: BreathingActivityCommand.notification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let raw = note.userInfo?[BreathingActivityCommand.userInfoKey] as? String,
                  let command = BreathingActivityCommand(rawValue: raw) else { return }
            MainActor.assumeIsolated {
                self?.handle(command)
            }
        }
    }

    deinit {
        if let commandObserver {
            NotificationCenter.default.removeObserver(commandObserver)
        }
    }

    // MARK: - Chat

    /// Unsent text in the chat composer, shared by the sheet and the pane.
    var chatDraft = ""

    /// The person asked for chat. Compact width shows it as a sheet; regular
    /// width shows it inline beside the Action list.
    var isChatRequested = false

    /// The Action tab's conversation, kept while the layout changes.
    private(set) var chatViewModel: ChatViewModel?

    /// Returns the kept conversation, creating it on first use.
    func chat(
        stressResult: StressResult?,
        baseline: PersonalBaseline?,
        make: @MainActor (StressResult?, PersonalBaseline?) -> ChatViewModel = { ChatViewModel(stressResult: $0, baseline: $1) }
    ) -> ChatViewModel {
        if let chatViewModel { return chatViewModel }
        let created = make(stressResult, baseline)
        chatViewModel = created
        return created
    }

    /// The person closed the chat: stop any reply that is still streaming.
    /// The next open starts a fresh view model with the latest reading, as
    /// before (history comes back from the server); the unsent draft stays.
    /// Moving between the sheet and the pane never calls this.
    func closeChat() {
        isChatRequested = false
        chatViewModel?.cancelResponse()
        chatViewModel = nil
    }

    // MARK: - Breathing

    /// The running session, if any. Survives the session screen being
    /// rebuilt when the layout changes.
    private(set) var breathingSession: BreathingSessionViewModel?

    /// Bumped on every attach, so a detach that was followed by a re-attach
    /// (the same screen, rebuilt for the other display) never ends the
    /// session.
    private var breathingAttachGeneration = 0

    /// How long a detached session waits for its screen to come back before
    /// it ends. Long enough to cover a fold or unfold, short enough that
    /// leaving the screen still ends the session right away for the person.
    var breathingDetachGrace: Duration = .milliseconds(800)

    /// Returns the running session, or starts a new one.
    func attachBreathing(
        make: @MainActor () -> BreathingSessionViewModel = { BreathingSessionViewModel() },
        configure: @MainActor (BreathingSessionViewModel) -> Void = { _ in }
    ) -> BreathingSessionViewModel {
        breathingAttachGeneration += 1
        if let session = breathingSession, session.isActive {
            return session
        }
        let session = make()
        configure(session)
        session.startSession()
        breathingSession = session
        liveActivity?.start(for: session)
        return session
    }

    /// The state last sent to the Live Activity (kept for tests).
    @ObservationIgnored private(set) var lastBreathingState: BreathingActivityAttributes.ContentState?

    /// The session changed phase, paused or resumed: refresh the Live
    /// Activity.
    func breathingDidChange() {
        guard let breathingSession else { return }
        lastBreathingState = BreathingLiveActivityController.state(for: breathingSession)
        liveActivity?.update(for: breathingSession)
    }

    /// Skip cycle on the session screen. A skip from inhale runs all four
    /// phases back to inhale, so no phase change is observed: refresh the
    /// Live Activity here, as the cycle and the time left did change.
    func skipBreathingCycle() {
        breathingSession?.skipCycle()
        breathingDidChange()
    }

    /// Pause / Resume and End from the Live Activity.
    func handle(_ command: BreathingActivityCommand) {
        switch command {
        case .togglePause:
            breathingSession?.togglePause()
            breathingDidChange()
        case .end:
            endBreathing()
        }
    }

    /// The session screen went away. Ends the session unless the screen is
    /// back within `breathingDetachGrace`.
    func detachBreathing() {
        let generation = breathingAttachGeneration
        let grace = breathingDetachGrace
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: grace)
            guard let self, self.breathingAttachGeneration == generation else { return }
            self.endBreathing()
        }
    }

    /// Ends the session now (End early, or End from the Live Activity).
    func endBreathing() {
        let session = breathingSession
        session?.endSession()
        breathingSession = nil
        liveActivity?.end(for: session)
    }
}
