import Testing
import Foundation
@testable import StressMonitor

/// Pins the AUTH-03 streaming lifecycle so it cannot regress before Chat
/// re-enables in v1.1:
/// - mid-stream dismissal cancels the in-flight Task and preserves partial text
/// - a network drop mid-stream preserves the partial text received so far
/// - cancelling with no partial text appends no phantom assistant message
///
/// Uses an injected `FakeLLMService` above the network layer (no URLSession),
/// mirroring the protocol-level substitution pattern in `PremiumViewModelTests`.
@MainActor
struct ChatLifecycleTests {

    private func waitFor(_ predicate: @MainActor () -> Bool, timeoutMS: Int = 2000) async throws {
        let ticks = timeoutMS / 10
        for _ in 0..<ticks {
            if predicate() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        Issue.record("waitFor timed out waiting for condition")
    }

    @Test("cancelResponse preserves partial text, clears state, and ends streaming")
    func cancelResponsePreservesPartialText() async throws {
        let fake = FakeLLMService(tokens: ["partial token text"], shouldThrow: false)
        let viewModel = ChatViewModel(
            stressResult: nil,
            baseline: nil,
            llmService: fake
        )

        viewModel.send("hello")

        try await waitFor { viewModel.currentStreamingText == "partial token text" }
        #expect(viewModel.isStreaming)

        viewModel.cancelResponse()

        let last = viewModel.messages.last
        #expect(last?.role == .assistant)
        #expect(last?.content == "partial token text")
        #expect(viewModel.currentStreamingText.isEmpty)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.isStreaming == false)
    }

    @Test("network error mid-stream preserves partial text and surfaces an error")
    func networkErrorPreservesPartialText() async throws {
        let fake = FakeLLMService(tokens: ["Hello "], shouldThrow: true)
        let viewModel = ChatViewModel(
            stressResult: nil,
            baseline: nil,
            llmService: fake
        )

        viewModel.send("hello")

        // Wait for the terminal state, not `isLoading == false`: isLoading is
        // still false in the gap between send() returning and the streaming
        // task setting it true, so that predicate can pass before the stream
        // starts. errorMessage is set only in the catch block, after the
        // stream has delivered its tokens and the error.
        try await waitFor { viewModel.errorMessage?.isEmpty == false }

        let assistantContents = viewModel.messages
            .filter { $0.role == .assistant }
            .map(\.content)
        #expect(assistantContents.contains("Hello "))
        #expect(viewModel.errorMessage?.isEmpty == false)
    }

    @Test("cancelResponse with no partial text appends no assistant message")
    func cancelResponseWithNoPartialTextAppendsNothing() async throws {
        let fake = FakeLLMService(tokens: [], shouldThrow: false)
        let viewModel = ChatViewModel(
            stressResult: nil,
            baseline: nil,
            llmService: fake
        )

        viewModel.send("hello")
        try await waitFor { viewModel.isStreaming }

        let countBefore = viewModel.messages.count
        viewModel.cancelResponse()

        #expect(viewModel.messages.count == countBefore)
        #expect(viewModel.messages.allSatisfy { $0.role == .user })
    }

    // MARK: - CR-01: stress context flows per-call through send()

    @Test("each send delivers its own freshly built stress context, not a leftover from a previous send")
    func eachSendDeliversItsOwnStressContext() async throws {
        let fake = FakeLLMService(tokens: [], shouldThrow: false)

        let lowStress = ChatViewModel(
            stressResult: StressResult(
                level: 20, category: .relaxed, confidence: 0.9, hrv: 70, heartRate: 55
            ),
            baseline: nil,
            llmService: fake
        )
        lowStress.send("hello")
        try await waitFor { fake.receivedStressContexts.count == 1 }

        let highStress = ChatViewModel(
            stressResult: StressResult(
                level: 85, category: .high, confidence: 0.9, hrv: 25, heartRate: 95
            ),
            baseline: nil,
            llmService: fake
        )
        highStress.send("hello")
        try await waitFor { fake.receivedStressContexts.count == 2 }

        #expect(fake.receivedStressContexts.first??.stressLevel == 20)
        #expect(fake.receivedStressContexts.last??.stressLevel == 85)
    }

    // MARK: - 402 out-of-credits routes to the paywall (derived-CR-03)

    @Test("a 402 insufficientCredits send sets a short message and presents the out-of-credits paywall")
    func insufficientCreditsPresentsOutOfCreditsPaywall() async throws {
        let fake = FakeLLMService(tokens: [], streamError: .insufficientCredits)
        var presentedReasons: [PaywallReason] = []
        let viewModel = ChatViewModel(
            stressResult: nil,
            baseline: nil,
            llmService: fake
        )
        viewModel.presentPaywall = { presentedReasons.append($0) }

        viewModel.send("hello")

        try await waitFor { viewModel.errorMessage?.isEmpty == false }

        #expect(presentedReasons == [.outOfCredits])
    }
}

/// Pins the PaywallController guard semantics for the out-of-credits reason
/// (threat T-2-03): a server-side 402 means the backend does NOT consider
/// this user premium, so the out-of-credits paywall must present regardless
/// of local premium state — a locally-premium user hitting 402 is in a
/// divergence state where the resubscribe-led paywall is the correct path.
@MainActor
struct PaywallOutOfCreditsGuardTests {

    @Test("outOfCredits bypasses the premium guard; other reasons still respect it")
    func outOfCreditsBypassesPremiumGuard() {
        let suite = "PaywallGuard-\(UUID().uuidString)"
        let state = PremiumState(defaults: UserDefaults(suiteName: suite)!, key: "isPremiumUser")
        state.isPremiumUser = true
        let paywall = PaywallController(premiumState: state, availability: .enabled)

        paywall.present(reason: .outOfCredits)
        #expect(paywall.presentation?.reason == .outOfCredits)

        paywall.dismiss()
        paywall.present(reason: .general)
        #expect(paywall.presentation == nil)
    }

    @Test("postponed purchases suppress every paywall reason")
    func postponedPurchasesSuppressPaywall() {
        let suite = "PaywallPostponed-\(UUID().uuidString)"
        let state = PremiumState(defaults: UserDefaults(suiteName: suite)!, key: "isPremiumUser")
        let paywall = PaywallController(
            premiumState: state,
            availability: .postponed(reason: .awaitingAppStoreProducts)
        )

        paywall.present(reason: .general)
        #expect(paywall.presentation == nil)

        paywall.present(reason: .outOfCredits)
        #expect(paywall.presentation == nil)
    }

    @Test("shipping build postpones purchases")
    func shippingBuildPostponesPurchases() {
        #expect(!PurchaseAvailability.isEnabled)
    }
}

// MARK: - Fake LLM Service

/// Protocol-level double for `LLMServiceProtocol`. Yields `tokens` then either
/// blocks (simulating an in-flight stream, so cancellation is observable) or
/// throws (simulating a network drop). Sets `onTermination` so the consumer's
/// cancellation propagates to the producer, mirroring `StressLLMService.send`.
/// Records the stress context each `send` call receives so tests can pin that
/// context travels per-call, not through shared mutable state (CR-01).
@MainActor
final class FakeLLMService: LLMServiceProtocol {
    let tokens: [String]
    let shouldThrow: Bool
    let streamError: LLMServiceError?
    private(set) var receivedStressContexts: [StressContextPayload?] = []

    init(tokens: [String], shouldThrow: Bool = false, streamError: LLMServiceError? = nil) {
        self.tokens = tokens
        self.shouldThrow = shouldThrow
        self.streamError = streamError
    }

    func isAvailable() -> Bool { true }

    func send(
        messages: [ChatMessage],
        systemPrompt: String,
        stressContext: StressContextPayload?
    ) async throws -> AsyncThrowingStream<String, Error> {
        receivedStressContexts.append(stressContext)
        let tokens = self.tokens
        let shouldThrow = self.shouldThrow
        let streamError = self.streamError
        return AsyncThrowingStream { continuation in
            let producer = Task { @MainActor in
                for token in tokens {
                    continuation.yield(token)
                }
                if let streamError {
                    continuation.finish(throwing: streamError)
                } else if shouldThrow {
                    continuation.finish(throwing: LLMServiceError.unavailable(reason: "network dropped"))
                } else {
                    try? await Task.sleep(for: .seconds(60))
                    continuation.finish(throwing: CancellationError())
                }
            }
            continuation.onTermination = { _ in producer.cancel() }
        }
    }
}
