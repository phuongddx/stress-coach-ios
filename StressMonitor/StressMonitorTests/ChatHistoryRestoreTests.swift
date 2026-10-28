import Foundation
import Testing
@testable import StressMonitor

/// Pins the derived-SES-01/02 tracer path end-to-end at unit level:
/// - the first send of a new conversation creates a titled session BEFORE
///   `/chat` carries its id, so the backend can never auto-create an untitled
///   twin session (Pitfall 5)
/// - a failed session creation is fail-soft: `/chat` still sends, minus
///   `session_id`
/// - the created id survives service reconstruction (UserDefaults write-through)
/// - reopening restores the server history (server order, `isSynced`, no
///   system rows)
/// - a 404 restore clears the stored id and renders an empty chat (Pitfall 3)
/// - a restore landing after the user already sent a message never clobbers
///   the live conversation (Pitfall 4)
@MainActor
struct ChatHistoryRestoreTests {

    private static let sessionIdDefaultsKey = "stressChatSessionId"

    // MARK: - Helpers

    private func makeStubbedClient(
        responseByPath: [String: (statusCode: Int, body: Data?)]
    ) -> StressAPIClient {
        RequestCaptureURLProtocol.lastRequest = nil
        RequestCaptureURLProtocol.statusCode = 200
        RequestCaptureURLProtocol.responseBody = nil
        RequestCaptureURLProtocol.responseByPath = responseByPath
        RequestCaptureURLProtocol.capturedRequests = []
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [RequestCaptureURLProtocol.self]
        return StressAPIClient(
            authService: MockAuthService(token: "fake-token"),
            baseURL: URL(string: "https://api.test")!,
            session: URLSession(configuration: config)
        )
    }

    /// URLProtocol delivers the request body as a stream, not `httpBody`.
    private func body(of request: URLRequest) -> Data {
        if let data = request.httpBody { return data }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let capacity = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: capacity)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }

    private func jsonBody(of request: URLRequest) throws -> [String: Any] {
        try #require(
            JSONSerialization.jsonObject(with: body(of: request)) as? [String: Any]
        )
    }

    /// SSE stream shaped like the backend's `/chat` response: one content
    /// token event, a terminal metadata event, and `[DONE]` (SSEParserTests
    /// fixture shape).
    private func chatSSEBody(sessionId: UUID?) -> Data {
        var lines = [
            #"data: {"choices":[{"delta":{"content":"Hello"}}]}"#,
        ]
        if let sessionId {
            lines.append(#"data: {"type":"metadata","session_id":"\#(sessionId.uuidString)","credits_remaining":42,"model_used":"test-model"}"#)
        }
        lines.append("data: [DONE]")
        return Data(lines.joined(separator: "\n").utf8)
    }

    private func sessionRowFixture(id: UUID) -> Data {
        Data("""
        {"id":"\(id.uuidString)","user_id":"uid-1","title":"Why is my HRV low?","stress_context":{},"model_used":null,"is_archived":false,"created_at":"2026-08-23T07:39:53.953Z","updated_at":"2026-08-23T07:39:53.953Z"}
        """.utf8)
    }

    @discardableResult
    private func consume(_ stream: AsyncThrowingStream<String, Error>) async throws -> [String] {
        var tokens: [String] = []
        for try await token in stream { tokens.append(token) }
        return tokens
    }

    // MARK: - Titled-session creation ordering (derived-SES-02, Pitfall 5)

    @Test("first send of a new conversation creates a titled session before /chat carries its id")
    func firstSendCreatesTitledSessionBeforeChat() async throws {
        UserDefaults.standard.removeObject(forKey: Self.sessionIdDefaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: Self.sessionIdDefaultsKey) }

        let createdId = UUID(uuidString: "12345678-1234-1234-1234-123456789012")!
        let client = makeStubbedClient(responseByPath: [
            "/sessions": (201, sessionRowFixture(id: createdId)),
            "/chat": (200, chatSSEBody(sessionId: createdId)),
        ])
        let service = StressLLMService(stressAPIClient: client)

        // Newlines and repeated spaces must collapse; the title truncates to
        // 50 characters with an ellipsis (this message is 51 chars collapsed).
        let longMessage = "Why is my HRV low\nafter a rough   night of fragmented sleep and too much screen time before bed?"
        let stream = try await service.send(
            messages: [ChatMessage(role: .user, content: longMessage)],
            systemPrompt: "",
            stressContext: nil
        )
        let tokens = try await consume(stream)
        #expect(tokens == ["Hello"])

        let requests = RequestCaptureURLProtocol.capturedRequests
        #expect(requests.count == 2)
        #expect(requests[0].httpMethod == "POST")
        #expect(requests[0].url?.path == "/sessions")
        #expect(requests[1].httpMethod == "POST")
        #expect(requests[1].url?.path == "/chat")

        let createJSON = try jsonBody(of: requests[0])
        #expect(createJSON["title"] as? String == "Why is my HRV low after a rough night of fragmente…")

        let chatJSON = try jsonBody(of: requests[1])
        #expect(chatJSON["session_id"] as? String == createdId.uuidString)
    }

    @Test("failed session creation is fail-soft: /chat still sends without session_id")
    func failedSessionCreationFailsSoft() async throws {
        UserDefaults.standard.removeObject(forKey: Self.sessionIdDefaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: Self.sessionIdDefaultsKey) }

        let client = makeStubbedClient(responseByPath: [
            "/sessions": (500, Data("{}".utf8)),
            "/chat": (200, chatSSEBody(sessionId: nil)),
        ])
        let service = StressLLMService(stressAPIClient: client)

        let stream = try await service.send(
            messages: [ChatMessage(role: .user, content: "hi")],
            systemPrompt: "",
            stressContext: nil
        )
        let tokens = try await consume(stream)
        #expect(tokens == ["Hello"])

        let requests = RequestCaptureURLProtocol.capturedRequests
        #expect(requests.count == 2)
        #expect(requests[0].url?.path == "/sessions")
        #expect(requests[1].url?.path == "/chat")

        let chatJSON = try jsonBody(of: requests[1])
        #expect(chatJSON["session_id"] == nil)
    }

    @Test("created session id persists and survives service reconstruction")
    func createdSessionIdPersistsAcrossServiceReconstruction() async throws {
        UserDefaults.standard.removeObject(forKey: Self.sessionIdDefaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: Self.sessionIdDefaultsKey) }

        let createdId = UUID(uuidString: "12345678-1234-1234-1234-123456789012")!
        let client = makeStubbedClient(responseByPath: [
            "/sessions": (201, sessionRowFixture(id: createdId)),
            "/chat": (200, chatSSEBody(sessionId: createdId)),
        ])
        let service = StressLLMService(stressAPIClient: client)

        let stream = try await service.send(
            messages: [ChatMessage(role: .user, content: "hello")],
            systemPrompt: "",
            stressContext: nil
        )
        _ = try await consume(stream)

        #expect(UserDefaults.standard.string(forKey: Self.sessionIdDefaultsKey) == createdId.uuidString)

        let reconstructed = StressLLMService(stressAPIClient: client)
        #expect(reconstructed.currentSessionId == createdId)
    }

    // MARK: - History restore (derived-SES-01)

    private func messagesEnvelope(sessionId: UUID) -> Data {
        Data("""
        {"messages":[
        {"id":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","session_id":"\(sessionId.uuidString)","role":"system","content":"internal system prompt row","tokens_used":null,"created_at":"2026-08-23T07:30:00.000Z"},
        {"id":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb","session_id":"\(sessionId.uuidString)","role":"user","content":"Why is my HRV low?","tokens_used":12,"created_at":"2026-08-23T07:39:53.953Z"},
        {"id":"cccccccc-cccc-cccc-cccc-cccccccccccc","session_id":"\(sessionId.uuidString)","role":"assistant","content":"Your HRV dip likely reflects short sleep.","tokens_used":48,"created_at":"2026-08-23T07:40:01.123Z"}
        ]}
        """.utf8)
    }

    @Test("restoreHistory renders server history in order, synced, without system rows")
    func restoreHistoryRendersServerHistory() async throws {
        let sessionId = UUID()
        UserDefaults.standard.set(sessionId.uuidString, forKey: Self.sessionIdDefaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: Self.sessionIdDefaultsKey) }

        let client = makeStubbedClient(responseByPath: [
            "/sessions/\(sessionId.uuidString)/messages": (200, messagesEnvelope(sessionId: sessionId)),
        ])
        let service = StressLLMService(stressAPIClient: client)
        let viewModel = ChatViewModel(stressResult: nil, baseline: nil, llmService: service)
        viewModel.apiClient = client

        await viewModel.restoreHistory()

        #expect(viewModel.messages.count == 2)
        #expect(viewModel.messages[0].role == .user)
        #expect(viewModel.messages[0].content == "Why is my HRV low?")
        #expect(viewModel.messages[0].isSynced)
        #expect(viewModel.messages[0].remoteId == UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"))
        #expect(viewModel.messages[0].sessionId == sessionId)
        #expect(viewModel.messages[0].tokensUsed == 12)
        #expect(viewModel.messages[1].role == .assistant)
        #expect(viewModel.messages[1].content == "Your HRV dip likely reflects short sleep.")
        #expect(viewModel.messages[1].isSynced)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("404 restore clears the stored session id and leaves the chat empty")
    func restoreOn404ClearsStoredIdAndStaysEmpty() async throws {
        let sessionId = UUID()
        UserDefaults.standard.set(sessionId.uuidString, forKey: Self.sessionIdDefaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: Self.sessionIdDefaultsKey) }

        let client = makeStubbedClient(responseByPath: [
            "/sessions/\(sessionId.uuidString)/messages": (404, Data(#"{"error":"Session not found"}"#.utf8)),
        ])
        let service = StressLLMService(stressAPIClient: client)
        let viewModel = ChatViewModel(stressResult: nil, baseline: nil, llmService: service)
        viewModel.apiClient = client

        await viewModel.restoreHistory()

        #expect(viewModel.messages.isEmpty)
        #expect(viewModel.errorMessage == nil)
        #expect(UserDefaults.standard.string(forKey: Self.sessionIdDefaultsKey) == nil)
        #expect(service.currentSessionId == nil)
    }

    @Test("restore landing after a live message never clobbers the live conversation")
    func restoreDoesNotClobberLiveMessages() async throws {
        let sessionId = UUID()
        UserDefaults.standard.set(sessionId.uuidString, forKey: Self.sessionIdDefaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: Self.sessionIdDefaultsKey) }

        // A stub that holds the messages response back long enough for the
        // test to append a live message while the fetch is in flight — pins
        // the post-await `messages.isEmpty` re-check, not just the entry guard.
        DelayedResponseURLProtocol.statusCode = 200
        DelayedResponseURLProtocol.responseBody = messagesEnvelope(sessionId: sessionId)
        DelayedResponseURLProtocol.delayMS = 200
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [DelayedResponseURLProtocol.self]
        let client = StressAPIClient(
            authService: MockAuthService(token: "fake-token"),
            baseURL: URL(string: "https://api.test")!,
            session: URLSession(configuration: config)
        )
        let service = StressLLMService(stressAPIClient: client)
        let viewModel = ChatViewModel(stressResult: nil, baseline: nil, llmService: service)
        viewModel.apiClient = client

        let restoreTask = Task { await viewModel.restoreHistory() }
        // Let the restore pass its entry guard and reach the in-flight fetch.
        try await Task.sleep(for: .milliseconds(40))
        viewModel.messages.append(ChatMessage(role: .user, content: "live message sent during restore"))
        await restoreTask.value

        #expect(viewModel.messages.count == 1)
        #expect(viewModel.messages.first?.content == "live message sent during restore")
        #expect(viewModel.messages.first?.isSynced == false)
    }

    // MARK: - Quick-action chips (derived-QA-01)

    private func waitFor(_ predicate: @MainActor () -> Bool, timeoutMS: Int = 2000) async throws {
        let ticks = timeoutMS / 10
        for _ in 0..<ticks {
            if predicate() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        Issue.record("waitFor timed out waiting for condition")
    }

    @Test("a fresh ChatViewModel renders the local fallback chips with zero network")
    func freshViewModelRendersLocalFallbackChips() {
        let stress = StressResult(level: 70, category: .moderate, confidence: 0.9, hrv: 40, heartRate: 70)
        let viewModel = ChatViewModel(stressResult: stress, baseline: nil, llmService: FakeLLMService(tokens: []))

        let expected = ChatQuickActions.actions(for: .moderate)
        #expect(viewModel.quickReplies.map(\.title) == expected.map(\.title))
        #expect(viewModel.quickReplies.map(\.prompt) == expected.map(\.prompt))
        #expect(!viewModel.quickReplies.isEmpty)
    }

    @Test("fetchQuickActions swaps chips for server titles, drops unknown ids, and GETs once per presentation")
    func fetchQuickActionsSwapsChipsForServerSuggestions() async throws {
        let fixture = """
        {"quick_actions":[{"id":"breathing","title":"Box Breathing","type":"exercise"},{"id":"future_action","title":"Mystery Chip","type":"brand_new_kind"},{"id":"talk","title":"Tell Me More","type":"conversation"}]}
        """
        let client = makeStubbedClient(responseByPath: [
            "/quick-actions": (200, Data(fixture.utf8)),
        ])
        let stress = StressResult(level: 70, category: .moderate, confidence: 0.9, hrv: 40, heartRate: 70)
        let viewModel = ChatViewModel(stressResult: stress, baseline: nil, llmService: FakeLLMService(tokens: []))
        viewModel.apiClient = client

        await viewModel.fetchQuickActions()

        // Unknown server id row dropped; known ids carry server titles with
        // locally resolved prompts.
        #expect(viewModel.quickReplies.count == 2)
        #expect(viewModel.quickReplies[0].title == "Box Breathing")
        #expect(viewModel.quickReplies[0].prompt == ChatQuickActions.prompt(forServerActionId: "breathing"))
        #expect(viewModel.quickReplies[1].title == "Tell Me More")

        // The fetch carries the live stress level with the unset-seam
        // preference defaults — one GET, never re-fetched in the same
        // presentation.
        let request = try #require(RequestCaptureURLProtocol.lastRequest)
        #expect(request.httpMethod == "GET")
        #expect(
            request.url?.absoluteString
                == "https://api.test/quick-actions?stress_level=70&language=en&coaching_style=supportive"
        )
        #expect(RequestCaptureURLProtocol.capturedRequests.count == 1)
        await viewModel.fetchQuickActions()
        #expect(RequestCaptureURLProtocol.capturedRequests.count == 1)
    }

    @Test("chat open seeds preferences before the chips query so it carries the server pair")
    func chatOpenSeedsPreferencesBeforeChipsFetch() async throws {
        // Clear the /preferences stub so later suites' single-response
        // stubbing isn't overridden by this suite's per-path responses.
        defer { RequestCaptureURLProtocol.responseByPath = nil }
        let preferencesFixture = """
        {"user_id":"00000000-0000-0000-0000-000000000001","language":"vi","coaching_style":"direct","display_name":null,"theme":"system","notification_enabled":true,"stress_alert_threshold":75,"custom_settings":{}}
        """
        let quickActionsFixture = """
        {"quick_actions":[{"id":"breathing","title":"Box Breathing","type":"exercise"}]}
        """
        let client = makeStubbedClient(responseByPath: [
            "/preferences": (200, Data(preferencesFixture.utf8)),
            "/quick-actions": (200, Data(quickActionsFixture.utf8)),
        ])
        let preferences = PreferencesService(apiClient: client)
        let stress = StressResult(level: 70, category: .moderate, confidence: 0.9, hrv: 40, heartRate: 70)
        let viewModel = ChatViewModel(stressResult: stress, baseline: nil, llmService: FakeLLMService(tokens: []))
        viewModel.apiClient = client
        viewModel.preferencesService = preferences

        await viewModel.hydratePreferencesAndFetchQuickActions()

        // The pair hydrated before anything queried with it — without the
        // chat-open seed the query would carry the install defaults (WR-02).
        #expect(preferences.hasSeeded)
        #expect(preferences.language == "vi")
        #expect(preferences.coachingStyle == "direct")

        // GET /preferences strictly precedes GET /quick-actions, and the
        // chips query carries the seeded pair.
        let paths = RequestCaptureURLProtocol.capturedRequests.map(\.url?.path)
        #expect(paths == ["/preferences", "/quick-actions"])
        let chipsRequest = try #require(RequestCaptureURLProtocol.capturedRequests.last)
        #expect(
            chipsRequest.url?.absoluteString
                == "https://api.test/quick-actions?stress_level=70&language=vi&coaching_style=direct"
        )
    }

    @Test("a failed chips fetch keeps the local fallback set untouched")
    func failedChipsFetchKeepsFallbackSet() async throws {
        let client = makeStubbedClient(responseByPath: [
            "/quick-actions": (500, Data(#"{"error":"boom"}"#.utf8)),
        ])
        let stress = StressResult(level: 70, category: .moderate, confidence: 0.9, hrv: 40, heartRate: 70)
        let viewModel = ChatViewModel(stressResult: stress, baseline: nil, llmService: FakeLLMService(tokens: []))
        viewModel.apiClient = client
        let fallbackTitles = viewModel.quickReplies.map(\.title)

        await viewModel.fetchQuickActions()

        #expect(viewModel.quickReplies.map(\.title) == fallbackTitles)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.messages.isEmpty)
    }

    @Test("a chips page whose ids are all unknown keeps the fallback row (no empty state)")
    func allUnknownChipsKeepFallbackSet() async throws {
        defer { RequestCaptureURLProtocol.responseByPath = nil }
        let fixture = """
        {"quick_actions":[{"id":"future_one","title":"Mystery A","type":"brand_new"},{"id":"future_two","title":"Mystery B","type":"also_new"}]}
        """
        let client = makeStubbedClient(responseByPath: [
            "/quick-actions": (200, Data(fixture.utf8)),
        ])
        let stress = StressResult(level: 70, category: .moderate, confidence: 0.9, hrv: 40, heartRate: 70)
        let viewModel = ChatViewModel(stressResult: stress, baseline: nil, llmService: FakeLLMService(tokens: []))
        viewModel.apiClient = client
        let fallback = ChatQuickActions.actions(for: .moderate)

        await viewModel.fetchQuickActions()

        // Full backend drift (every id unknown to the local mirror) must not
        // blank the chip row — the fallback stays (WR-03).
        #expect(!viewModel.quickReplies.isEmpty)
        #expect(viewModel.quickReplies.map(\.title) == fallback.map(\.title))
        #expect(viewModel.quickReplies.map(\.prompt) == fallback.map(\.prompt))
    }

    @Test("chip tap sends its resolved prompt with the preferences-fed payload and query")
    func chipTapSendsPromptWithPrefsFedPayload() async throws {
        let fake = FakeLLMService(tokens: [])
        let preferencesFixture = """
        {"user_id":"00000000-0000-0000-0000-000000000001","language":"vi","coaching_style":"direct","display_name":null,"theme":"system","notification_enabled":true,"stress_alert_threshold":75,"custom_settings":{}}
        """
        let quickActionsFixture = """
        {"quick_actions":[{"id":"talk","title":"Tell Me More","type":"conversation"}]}
        """
        let client = makeStubbedClient(responseByPath: [
            "/preferences": (200, Data(preferencesFixture.utf8)),
            "/quick-actions": (200, Data(quickActionsFixture.utf8)),
        ])
        let preferences = PreferencesService(apiClient: client)
        await preferences.seedIfNeeded()
        let stress = StressResult(level: 82, category: .high, confidence: 0.9, hrv: 25, heartRate: 95)
        let viewModel = ChatViewModel(stressResult: stress, baseline: nil, llmService: fake)
        viewModel.apiClient = client
        viewModel.preferencesService = preferences

        await viewModel.fetchQuickActions()
        let chipsRequest = try #require(RequestCaptureURLProtocol.capturedRequests.first { $0.url?.path == "/quick-actions" })
        #expect(
            chipsRequest.url?.absoluteString
                == "https://api.test/quick-actions?stress_level=82&language=vi&coaching_style=direct"
        )

        let reply = viewModel.quickReplies[0]
        viewModel.send(reply.prompt)
        try await waitFor { fake.receivedStressContexts.count == 1 }

        #expect(viewModel.messages.first?.content == reply.prompt)
        #expect(fake.receivedStressContexts.first??.language == "vi")
        #expect(fake.receivedStressContexts.first??.coachingStyle == "direct")
    }

    @Test("without a preferences service the send payload falls back to en/supportive")
    func unsetPreferencesFallBackToPayloadDefaults() async throws {
        let fake = FakeLLMService(tokens: [])
        let viewModel = ChatViewModel(stressResult: nil, baseline: nil, llmService: fake)

        viewModel.send("hello")
        try await waitFor { fake.receivedStressContexts.count == 1 }

        #expect(fake.receivedStressContexts.first??.language == "en")
        #expect(fake.receivedStressContexts.first??.coachingStyle == "supportive")
    }
}

// MARK: - Delayed Response URLProtocol

/// Single-response `URLProtocol` double whose response is held back by a fixed
/// delay, so a test can act between a request's dispatch and its delivery.
/// Used only by the no-clobber restore test; the shared
/// `RequestCaptureURLProtocol` responds immediately.
final class DelayedResponseURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var statusCode: Int = 200
    nonisolated(unsafe) static var responseBody: Data?
    nonisolated(unsafe) static var delayMS: Int = 0

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let delay = Self.delayMS
        if delay > 0 {
            Thread.sleep(forTimeInterval: TimeInterval(delay) / 1000)
        }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: Self.statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseBody ?? Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
