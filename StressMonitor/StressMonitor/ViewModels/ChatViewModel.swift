import Foundation
import Observation

// MARK: - Chat ViewModel

/// Manages chat message state, streaming responses, and LLM interaction.
@Observable
@MainActor
final class ChatViewModel {

    // MARK: - State

    var messages: [ChatMessage] = []
    var currentStreamingText: String = ""
    var isLoading = false
    var errorMessage: String?
    var isAvailable: Bool = false

    /// True while a streaming Task is alive. Exposed for tests and for any
    /// UI that needs to distinguish "idle" from "actively streaming".
    var isStreaming: Bool { streamingTask != nil }

    /// Presents the paywall when a send is rejected for insufficient credits
    /// (HTTP 402). Injected by the owning view from the environment so this
    /// view model never constructs UI; tests inject a recording closure.
    var presentPaywall: ((PaywallReason) -> Void)?

    // MARK: - Quick Action Chips

    /// Chip row state: renders the local fallback instantly at init and is
    /// swapped for server suggestions when `fetchQuickActions()` lands
    /// (derived-QA-01). Swap replaces chip data only — messages and the
    /// composer are never touched.
    private(set) var quickReplies: [ChatQuickAction]

    /// One chips fetch per presentation — mirrors `restoredHistory`. A
    /// failure keeps the fallback set; there is no loading or empty state.
    private var fetchedQuickActions = false

    /// Ripple avatar mood derived from the current stress level, so the chat
    /// companion reacts visibly to the user's state.
    var companionMood: RippleMood {
        let level = stressResult?.level ?? recentHistory.first?.stressLevel ?? 0
        return RippleMood.from(stressLevel: level)
    }

    /// API client for server-side chat history. Set by the owning view on
    /// appear (mirrors the `presentPaywall` injection seam); unset in unit
    /// tests unless a test injects one.
    var apiClient: StressAPIClient?

    /// App-scope preferences (language + coaching style) feeding both the
    /// chips query and the stress-context payload — one source of truth
    /// (derived-PREF-02). Set by the owning view on appear; unset in unit
    /// tests, which get the `"en"`/`"supportive"` defaults.
    var preferencesService: PreferencesService?

    // MARK: - Private State

    /// One history fetch per presentation — `onAppear` can fire more than
    /// once per sheet presentation, and a second fetch could duplicate or
    /// clobber messages.
    private var restoredHistory = false

    private let llmService: LLMServiceProtocol
    private var streamingTask: Task<Void, Never>?
    private let contextBuilder = ChatContextBuilder.self

    private(set) var stressResult: StressResult?
    private var baseline: PersonalBaseline?
    private var recentHistory: [StressMeasurement] = []

    /// Max messages before proactive trim to avoid context overflow
    private let maxMessages = 20

    // MARK: - Initialization

    convenience init(
        stressResult: StressResult?,
        baseline: PersonalBaseline?,
        recentHistory: [StressMeasurement] = []
    ) {
        self.init(
            stressResult: stressResult,
            baseline: baseline,
            recentHistory: recentHistory,
            llmService: StressLLMService()
        )
    }

    /// Test-injectable initializer. Existing call sites use the convenience
    /// init above, which defaults to a real `StressLLMService`. Tests pass a
    /// controllable double so cancellation and partial-text preservation are
    /// observable without a live network session.
    init(
        stressResult: StressResult?,
        baseline: PersonalBaseline?,
        recentHistory: [StressMeasurement] = [],
        llmService: LLMServiceProtocol
    ) {
        self.stressResult = stressResult
        self.baseline = baseline
        self.recentHistory = recentHistory
        self.llmService = llmService
        self.isAvailable = llmService.isAvailable()
        // Instant local chips — the server suggestions swap in later.
        self.quickReplies = ChatQuickActions.actions(for: stressResult?.category)
    }

    // MARK: - Send Message

    /// Send a user message and stream the AI response
    func send(_ text: String) {
        // Cancel any in-flight streaming before starting new one
        cancelResponse()

        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        errorMessage = nil

        // Proactive context trim
        trimOldMessagesIfNeeded()

        streamingTask = Task { [weak self] in
            guard let self else { return }
            await self.streamResponse()
        }
    }

    // MARK: - Quick Actions Fetch

    /// Chat-open startup for the chips seam: seed the preference pair
    /// (seed-once, best-effort) so the suggestions query carries the
    /// server's language/coaching style rather than install defaults, then
    /// swap the local fallback chips for server suggestions. Order matters —
    /// seeding after the fetch would query with the wrong pair (WR-02).
    func hydratePreferencesAndFetchQuickActions() async {
        await preferencesService?.seedIfNeeded()
        await fetchQuickActions()
    }

    /// Swaps the chip row for server-suggested actions (derived-QA-01).
    /// One fetch per presentation; a failure keeps the local fallback set —
    /// no loading state, no empty state. Rows whose id has no local prompt
    /// are dropped rather than rendered as dead chips. Chip taps resolve
    /// prompts on-device and send through the credit-metered `/chat` path —
    /// never the backend's unmetered completion route. If NO id resolves
    /// (backend drift ahead of an app update), the fallback set stays — the
    /// row never goes empty.
    func fetchQuickActions() async {
        guard !fetchedQuickActions else { return }
        fetchedQuickActions = true
        // The endpoint needs a stress level; without a reading the local
        // fallback chips stay rather than querying with an invented one.
        guard let apiClient, let stressResult else { return }

        do {
            let serverActions = try await apiClient.getQuickActions(
                stressLevel: Int(stressResult.level),
                language: preferencesService?.language ?? "en",
                coachingStyle: preferencesService?.coachingStyle ?? "supportive"
            )
            let resolved: [ChatQuickAction] = serverActions.compactMap { action in
                guard let prompt = ChatQuickActions.prompt(forServerActionId: action.id) else {
                    return nil
                }
                // The live chip surface renders the title only; the icon is
                // required by the model but never shown.
                return ChatQuickAction(title: action.title, icon: "sparkles", prompt: prompt)
            }
            // Backend drift — every id unknown to the local mirror — must
            // not blank the chip row; the local fallback stays (WR-03).
            if !resolved.isEmpty {
                quickReplies = resolved
            }
        } catch {
            // Keep the fallback set — suggestions are best-effort.
        }
    }

    // MARK: - Streaming

    private func streamResponse() async {
        isLoading = true
        currentStreamingText = ""
        defer {
            if !Task.isCancelled {
                isLoading = false
                currentStreamingText = ""
            }
        }

        // Build stress context for the backend (backend builds system prompt
        // from this). Language/coaching style come from PreferencesService —
        // one source of truth (derived-PREF-02); the defaults only cover the
        // unset injection seam (tests, previews).
        let stressContext = StressContextPayload.build(
            stressResult: stressResult,
            baseline: baseline,
            recentHistory: recentHistory,
            language: preferencesService?.language ?? "en",
            coachingStyle: preferencesService?.coachingStyle ?? "supportive"
        )

        // systemPrompt is ignored by StressLLMService — backend builds it
        let systemPrompt = contextBuilder.buildSystemPrompt(
            stressResult: stressResult,
            baseline: baseline,
            recentHistory: recentHistory
        )

        do {
            let stream = try await llmService.send(
                messages: messages,
                systemPrompt: systemPrompt,
                stressContext: stressContext
            )

            for try await token in stream {
                if Task.isCancelled { break }
                currentStreamingText += token
            }

            if !currentStreamingText.isEmpty {
                let sessionId = (llmService as? StressLLMService)?.currentSessionId
                if let lastUserIndex = messages.lastIndex(where: { $0.role == .user }) {
                    messages[lastUserIndex].sessionId = sessionId
                    messages[lastUserIndex].isSynced = sessionId != nil
                }
                let response = ChatMessage(
                    role: .assistant,
                    content: currentStreamingText,
                    sessionId: sessionId,
                    isSynced: sessionId != nil
                )
                messages.append(response)
            }

        } catch let error as LLMServiceError {
            if case .insufficientCredits = error {
                // The paywall carries the detail (DEC-1: subscription-led) —
                // the in-chat message stays a one-line nudge.
                errorMessage = error.localizedDescription
                presentPaywall?(.outOfCredits)
            } else if case .exceededContext = error {
                // Intentionally discards any partial text — the whole
                // conversation is being cleared to recover from overflow.
                messages.removeAll()
                errorMessage = error.localizedDescription
            } else {
                preservePartialResponseIfNeeded()
                errorMessage = error.localizedDescription
            }
        } catch {
            preservePartialResponseIfNeeded()
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - History Restore

    /// Renders the persisted rolling session's server-side history into the
    /// conversation (derived-SES-01). The server is the authoritative message
    /// store — nothing is cached locally. A 404 means the stored session is
    /// gone server-side: clear the id and keep the chat empty rather than
    /// surfacing an error. Never clobbers messages the user already sent
    /// while the fetch was in flight.
    func restoreHistory() async {
        // One fetch per presentation (Pitfall 2), and never over a
        // conversation that already has content.
        guard !restoredHistory, messages.isEmpty else { return }
        restoredHistory = true

        guard let service = llmService as? StressLLMService,
              let sessionId = service.currentSessionId,
              let apiClient else { return }

        do {
            let dtos = try await apiClient.fetchMessages(sessionId: sessionId)
            // Re-check after the async gap: the user may have sent a message
            // while the fetch was in flight — live content wins.
            guard messages.isEmpty else { return }
            messages = dtos
                .filter { $0.role != .system }
                .map(Self.restoredMessage(from:))
        } catch SessionsAPIError.notFound {
            // Dangling stored id (session deleted server-side or a pre-Phase-3
            // install): start fresh instead of bricking chat open.
            service.resetSession()
        } catch {
            // Auth/network failures leave the chat usable but empty — the
            // next send re-establishes a session server-side.
        }
    }

    /// Maps a server history row to the display model. `timestamp` is
    /// cosmetic (the bubble shows wall-clock time only); ordering comes from
    /// the server's `created_at asc` delivery order.
    private static func restoredMessage(from dto: ChatSessionMessage) -> ChatMessage {
        ChatMessage(
            role: dto.role,
            content: dto.content,
            remoteId: dto.id,
            sessionId: dto.sessionId,
            isSynced: true,
            tokensUsed: dto.tokensUsed
        )
    }

    /// Mirrors the partial-text preservation `cancelResponse()` already does —
    /// a network drop mid-stream shouldn't lose the tokens received so far.
    private func preservePartialResponseIfNeeded() {
        guard !currentStreamingText.isEmpty else { return }
        let partial = ChatMessage(role: .assistant, content: currentStreamingText)
        messages.append(partial)
    }

    // MARK: - Context Management

    /// Trim oldest messages to stay within budget, keeping system context fresh
    private func trimOldMessagesIfNeeded() {
        guard messages.count > maxMessages else { return }
        // Keep last N messages (remove oldest user/assistant pairs)
        let trimCount = messages.count - maxMessages
        messages.removeFirst(trimCount)
    }

    // MARK: - Cancellation

    /// Cancel the current streaming response
    func cancelResponse() {
        guard streamingTask != nil else { return }
        streamingTask?.cancel()
        streamingTask = nil

        if !currentStreamingText.isEmpty {
            let partial = ChatMessage(role: .assistant, content: currentStreamingText)
            messages.append(partial)
        }
        currentStreamingText = ""
        isLoading = false
    }

    /// Clear all messages and start fresh
    func clearConversation() {
        cancelResponse()
        messages.removeAll()
        errorMessage = nil
        (llmService as? StressLLMService)?.resetSession()
    }

    // MARK: - Credit Balance Convergence

    /// Routes metadata `credits_remaining` values from the chat stream into
    /// the app's credit-balance convergence sink (`CreditService`). Optional —
    /// unset in unit tests, which inject doubles instead.
    func setCreditsConvergenceSink(_ sink: (@MainActor (_ remaining: Int) -> Void)?) {
        (llmService as? StressLLMService)?.onCreditsRemainingChange = sink
    }
}
