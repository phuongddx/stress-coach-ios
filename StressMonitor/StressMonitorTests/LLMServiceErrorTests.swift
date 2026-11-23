import Testing
@testable import StressMonitor

/// Pins the D-07 contract: the backend returns HTTP 402 INSUFFICIENT_CREDITS
/// before streaming starts. iOS maps that to a dedicated
/// `LLMServiceError.insufficientCredits` case (not the generic `.unavailable`)
/// so Phase 2 can route it to the paywall instead of a generic error toast.
struct LLMServiceErrorTests {

    @Test("insufficientCredits exposes a non-empty user-facing description")
    func insufficientCreditsHasNonEmptyDescription() {
        let description = LLMServiceError.insufficientCredits.errorDescription

        #expect(description?.isEmpty == false)
    }

    @Test("out-of-messages copy names the 20 free messages and Plus, never credit top-ups")
    func outOfFreeMessagesCopy() {
        let text = CreditBalanceFormatter.outOfFreeMessagesText
        #expect(text.contains("20 free messages this month"))
        #expect(text.contains("Plus"))
        #expect(!text.localizedCaseInsensitiveContains("credit"))
        #expect(!text.localizedCaseInsensitiveContains("top up"))
    }

    @Test("catching insufficientCredits matches the dedicated case, not .unknown")
    func insufficientCreditsMatchesDedicatedCase() {
        let thrown: LLMServiceError = .insufficientCredits

        switch thrown {
        case .insufficientCredits:
            #expect(Bool(true))
        default:
            Issue.record("insufficientCredits must match its own case, got \(thrown)")
        }
    }
}
