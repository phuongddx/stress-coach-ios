import Foundation
import Testing
@testable import StressMonitor

/// State that has to survive the iPhone Duo folding and unfolding. The two
/// displays have different size classes, so the screens are rebuilt; the
/// chat and the running breathing session live in `SceneContinuity` and
/// must come through unchanged.
///
/// Serialized: the Live Activity buttons reach the session through a
/// process-wide notification, which would pause sessions in parallel tests.
@MainActor
@Suite("Duo fold/unfold continuity", .serialized)
struct SceneContinuityTests {

    private final class FakeHealthKitService: HealthKitServiceProtocol {
        func requestAuthorization() async throws {}
        func fetchLatestHRV() async throws -> HRVMeasurement? { nil }
        func fetchHeartRate(samples: Int) async throws -> [HeartRateSample] { [] }
        func fetchHRVHistory(since date: Date) async throws -> [HRVMeasurement] { [] }
        func observeHeartRateUpdates() -> AsyncStream<HeartRateSample?> {
            AsyncStream { $0.finish() }
        }
    }

    private func makeContinuity(grace: Duration = .milliseconds(100)) -> SceneContinuity {
        let continuity = SceneContinuity(liveActivity: nil)
        continuity.breathingDetachGrace = grace
        return continuity
    }

    private func attach(_ continuity: SceneContinuity) -> BreathingSessionViewModel {
        continuity.attachBreathing(make: { BreathingSessionViewModel(healthKit: FakeHealthKitService()) })
    }

    // MARK: - Breathing

    @Test("fold/unfold mid-session keeps the same session and its timer running")
    func testBreathing_FoldUnfold_KeepsSessionAndTimer() async throws {
        let continuity = makeContinuity(grace: .milliseconds(300))
        let before = attach(continuity)
        let startRemaining = before.remainingTime

        // The outer-display screen goes away, the inner-display one appears.
        continuity.detachBreathing()
        let after = attach(continuity)

        #expect(after === before)
        #expect(after.isActive)

        // Past the grace period the session is still running and counting.
        try await Task.sleep(for: .milliseconds(1300))
        #expect(continuity.breathingSession === before)
        #expect(before.isActive)
        #expect(before.remainingTime < startRemaining)
        continuity.endBreathing()
    }

    @Test("fold/unfold keeps a paused session paused")
    func testBreathing_FoldUnfold_KeepsPause() async throws {
        let continuity = makeContinuity()
        let session = attach(continuity)
        session.pauseSession()
        let remaining = session.remainingTime

        continuity.detachBreathing()
        _ = attach(continuity)
        try await Task.sleep(for: .milliseconds(1200))

        #expect(session.isActive)
        #expect(session.isPaused)
        #expect(session.remainingTime == remaining)
        continuity.endBreathing()
    }

    @Test("leaving the session screen ends the session after the grace period")
    func testBreathing_DetachWithoutReattach_Ends() async throws {
        let continuity = makeContinuity()
        let session = attach(continuity)

        continuity.detachBreathing()
        try await Task.sleep(for: .milliseconds(400))

        #expect(continuity.breathingSession == nil)
        #expect(session.isActive == false)
    }

    @Test("a new screen after the session ended starts a fresh session")
    func testBreathing_AttachAfterEnd_StartsNewSession() {
        let continuity = makeContinuity()
        let first = attach(continuity)
        continuity.endBreathing()
        let second = attach(continuity)

        #expect(second !== first)
        #expect(second.isActive)
        continuity.endBreathing()
    }

    @Test("Pause and End from the Live Activity reach the running session")
    func testLiveActivityCommands_ReachSession() {
        let continuity = makeContinuity()
        let session = attach(continuity)

        continuity.handle(.togglePause)
        #expect(session.isPaused)
        continuity.handle(.togglePause)
        #expect(session.isPaused == false)

        continuity.handle(.end)
        #expect(continuity.breathingSession == nil)
        #expect(session.isActive == false)
    }

    @Test("a Live Activity button posted through NotificationCenter is handled")
    func testLiveActivityCommand_ViaNotification() {
        let continuity = makeContinuity()
        let session = attach(continuity)

        BreathingActivityCommand.togglePause.post()
        #expect(session.isPaused)
        continuity.endBreathing()
    }

    // MARK: - Chat

    private func makeChat(_ continuity: SceneContinuity) -> ChatViewModel {
        continuity.chat(stressResult: nil, baseline: nil) {
            ChatViewModel(stressResult: $0, baseline: $1, llmService: FakeLLMService(tokens: []))
        }
    }

    @Test("the conversation and the draft carry over between the sheet and the pane")
    func testChat_LayoutSwitch_KeepsConversationAndDraft() {
        let continuity = makeContinuity()
        continuity.isChatRequested = true

        // Outer display: the sheet creates the conversation; the person types.
        let sheetModel = makeChat(continuity)
        continuity.chatDraft = "I can't switch off after work"

        // Unfold: the sheet goes away (not a close) and the pane reads the same state.
        let paneModel = makeChat(continuity)

        #expect(paneModel === sheetModel)
        #expect(continuity.chatDraft == "I can't switch off after work")
        #expect(continuity.isChatRequested)
    }

    @Test("closing the chat keeps the draft and starts a fresh conversation next time")
    func testChat_Close_KeepsDraftDropsConversation() {
        let continuity = makeContinuity()
        continuity.isChatRequested = true
        let first = makeChat(continuity)
        continuity.chatDraft = "draft"

        continuity.closeChat()

        #expect(continuity.isChatRequested == false)
        #expect(continuity.chatViewModel == nil)
        #expect(continuity.chatDraft == "draft")
        #expect(makeChat(continuity) !== first)
    }

    // MARK: - Live Activity state

    @Test("the Live Activity shows the phase, the cycle and the time left")
    func testLiveActivityState_MapsSession() {
        let session = BreathingSessionViewModel(healthKit: FakeHealthKitService())
        session.startSession()
        defer { session.endSession() }
        session.remainingTime = 84.4
        session.cyclesCompleted = 2
        session.boxPhase = .exhale
        let now = Date(timeIntervalSince1970: 1_000)

        let state = BreathingLiveActivityController.state(for: session, now: now)

        #expect(state.phaseLabel == "Exhale")
        #expect(state.cycle == 3)
        #expect(state.totalCycles == session.totalCycles)
        #expect(state.secondsLeft == 84)
        #expect(state.endDate == now.addingTimeInterval(84))
        #expect(state.isPaused == false)
    }
}
