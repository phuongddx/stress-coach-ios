import Foundation
import Testing
@testable import StressMonitor

/// The summary screen opens on `completedResult`. It used to watch
/// `remainingTime <= 0` and read `sessionResult` in the same instant, but the
/// result is only written after the post-session HRV read, so it was always
/// nil and the summary never opened.
@MainActor
@Suite("Breathing session completion")
struct BreathingSessionCompletionTests {

    private final class FakeHealthKitService: HealthKitServiceProtocol {
        let hrv: Double?
        init(hrv: Double?) { self.hrv = hrv }

        func requestAuthorization() async throws {}
        func fetchLatestHRV() async throws -> HRVMeasurement? {
            hrv.map { HRVMeasurement(value: $0) }
        }
        func fetchHeartRate(samples: Int) async throws -> [HeartRateSample] { [] }
        func fetchHRVHistory(since date: Date) async throws -> [HRVMeasurement] { [] }
        func observeHeartRateUpdates() -> AsyncStream<HeartRateSample?> {
            AsyncStream { $0.finish() }
        }
    }

    private func makeSession(hrv: Double? = 52) -> BreathingSessionViewModel {
        let viewModel = BreathingSessionViewModel(healthKit: FakeHealthKitService(hrv: hrv))
        // One box cycle, so a single Skip cycle runs the session to its end.
        viewModel.sessionDuration = BreathingSessionViewModel.cycleDuration
        return viewModel
    }

    @Test("a session that runs to the end publishes a completed result for the summary")
    func testSessionReachingEnd_PublishesCompletedResult() async throws {
        let viewModel = makeSession()
        viewModel.startSession()

        viewModel.skipCycle()
        #expect(viewModel.isActive == false)
        await viewModel.finishTask?.value

        let result = try #require(viewModel.completedResult)
        #expect(result.postSessionHRV == 52)
        #expect(result.cyclesCompleted == 1)
        #expect(result.duration == BreathingSessionViewModel.cycleDuration)
        #expect(viewModel.sessionResult == result)
    }

    @Test("a completed result is published even when HealthKit has no HRV sample")
    func testSessionReachingEnd_WithoutHRV_StillPublishesCompletedResult() async {
        let viewModel = makeSession(hrv: nil)
        viewModel.startSession()

        viewModel.skipCycle()
        await viewModel.finishTask?.value

        #expect(viewModel.completedResult != nil)
        #expect(viewModel.completedResult?.improvement == nil)
    }

    @Test("ending early does not open the summary")
    func testEndingEarly_DoesNotPublishCompletedResult() async {
        let viewModel = makeSession()
        viewModel.startSession()

        viewModel.endSession()
        await viewModel.finishTask?.value

        #expect(viewModel.sessionResult != nil)
        #expect(viewModel.completedResult == nil)
    }

    @Test("leaving the screen after completion does not overwrite the result")
    func testEndSessionAfterCompletion_IsIgnored() async {
        let viewModel = makeSession()
        viewModel.startSession()
        viewModel.skipCycle()
        await viewModel.finishTask?.value
        let completed = viewModel.completedResult

        // The session screen calls endSession() from onDisappear when the
        // summary is pushed over it.
        viewModel.endSession()
        await viewModel.finishTask?.value

        #expect(viewModel.completedResult == completed)
        #expect(viewModel.sessionResult == completed)
    }
}
