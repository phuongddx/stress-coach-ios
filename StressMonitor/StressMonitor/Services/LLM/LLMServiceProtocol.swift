import Foundation

// MARK: - LLM Service Errors

/// Errors that can occur during LLM interaction
enum LLMServiceError: Error, LocalizedError {
    case unavailable(reason: String)
    case exceededContext
    case guardrailViolation
    case rateLimited
    case refused
    case concurrentRequests
    case insufficientCredits
    case decodingFailure
    case cancelled
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .unavailable(let reason):
            return "AI is not available: \(reason)"
        case .exceededContext:
            return "Conversation too long. Starting a new session."
        case .guardrailViolation:
            return "I can't help with that topic. Let's focus on your wellness."
        case .rateLimited:
            return "Please wait a moment before sending another message."
        case .refused:
            return "I'd prefer to keep our chat focused on wellness topics."
        case .concurrentRequests:
            return "I'm still thinking. Please wait for my response."
        case .insufficientCredits:
            // No purchase path exists while purchases are postponed, so the
            // message must not send the user shopping.
            return PurchaseAvailability.isEnabled
                ? "Out of credits. Subscribe or buy more to keep chatting."
                : "You've reached the coaching limit for now. Please try again later."
        case .decodingFailure:
            return "Something went wrong processing that response."
        case .cancelled:
            return "Response was cancelled."
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - LLM Service Protocol

/// Protocol for LLM service implementations (cloud LLM, etc.)
protocol LLMServiceProtocol: Sendable {
    /// Whether the LLM service is available on this device
    func isAvailable() -> Bool

    /// Send messages to the LLM and receive a streaming response
    /// - Parameters:
    ///   - messages: Conversation history (user + assistant messages)
    ///   - systemPrompt: System-level instructions with health context
    ///   - stressContext: Stress context payload built for THIS call. Passed
    ///     per-call (not through shared state) so each send observes its own
    ///     payload — see CR-01.
    /// - Returns: Async stream of response tokens
    func send(
        messages: [ChatMessage],
        systemPrompt: String,
        stressContext: StressContextPayload?
    ) async throws -> AsyncThrowingStream<String, Error>
}
