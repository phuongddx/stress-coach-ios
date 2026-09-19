import Foundation

// MARK: - Agent Chat API Errors

/// Typed errors for `POST /agent/chat`. Mirrors `SessionsAPIError` (plus the
/// credit-metered 402 case shared with `/chat`); the localized strings are
/// what `AgentChatViewModel` surfaces verbatim.
enum AgentChatAPIError: Error, LocalizedError, Equatable, Sendable {
    case unauthorized
    case insufficientCredits
    case stream(String)
    case server(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Please sign in to chat with your coach."
        case .insufficientCredits:
            return PurchaseAvailability.isEnabled
                ? "You're out of credits. Top up to keep chatting."
                : "You've reached the coaching limit for now. Please try again later."
        case .stream(let message): return message
        case .server(let code): return "Coach chat failed (server error \(code))."
        }
    }
}

// MARK: - Agent Chat Events

/// The parsed SSE stream, reduced from `SSEEvent` to what the coach chat
/// consumes: content tokens, the terminal metadata snapshot, and done.
enum AgentChatEvent: Equatable, Sendable {
    case content(String)
    case metadata(UUID?, Int?, String?)
    case done
}

// MARK: - StressAPIClient + Agent Chat

extension StressAPIClient {

    /// POST /agent/chat — SSE stream with the same event contract as `/chat`
    /// (content chunks → terminal metadata → `[DONE]`), parsed by the SAME
    /// `SSEParser`. Returns the session id (first seen wins; reused for the
    /// conversation so the server keeps coach context).
    @discardableResult
    func streamAgentChat(
        sessionID: UUID?,
        message: String,
        onEvent: @escaping @Sendable (AgentChatEvent) -> Void
    ) async throws -> UUID? {
        var body: [String: Any] = ["message": message]
        if let sessionID { body["session_id"] = sessionID.uuidString }
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let request = try await authorizedRequest(
            path: "agent/chat", method: "POST", body: bodyData, accept: "text/event-stream")

        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            bytes.task.cancel()
            throw AgentChatAPIError.server(statusCode: 0)
        }
        switch http.statusCode {
        case 200...299: break
        case 401:
            bytes.task.cancel()
            throw AgentChatAPIError.unauthorized
        case 402:
            bytes.task.cancel()
            throw AgentChatAPIError.insufficientCredits
        default:
            bytes.task.cancel()
            throw AgentChatAPIError.server(statusCode: http.statusCode)
        }

        var returnedSession: UUID?
        for try await line in bytes.lines {
            guard let event = SSEParser.parse(line: line) else { continue }
            switch event {
            case .content(let text):
                onEvent(.content(text))
            case .metadata(let meta):
                if returnedSession == nil { returnedSession = meta.sessionId }
                onEvent(.metadata(meta.sessionId, meta.creditsRemaining, meta.modelUsed))
            case .done:
                onEvent(.done)
            case .error(let message):
                bytes.task.cancel()
                throw AgentChatAPIError.stream(message)
            }
        }
        return returnedSession
    }
}
