import SwiftUI

// MARK: - Chat Bottom Sheet View

/// AI Chat bottom sheet (UI V2 `S.chat`).
///
/// Shows a chat header with a mood-reactive Ripple avatar (serene when stress
/// is Mild, worried when High), a message stream, quick reply chips, and a
/// composer with a send button. The Ripple avatar's expression reflects
/// the user's current stress level.
struct ChatBottomSheetView: View {
    /// Where the chat is shown.
    enum Presentation {
        /// A sheet (compact width): Close dismisses it.
        case sheet
        /// Inline beside the Action list (regular width, the iPhone Duo
        /// inner display). Always on screen, so there is no Close.
        case pane
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(PaywallController.self) private var paywall
    @Environment(CreditService.self) private var creditService
    @Environment(PreferencesService.self) private var preferencesService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel: ChatViewModel
    @State private var localDraft = ""

    /// Draft owned by the caller (`SceneContinuity`), so it survives the chat
    /// moving between the sheet and the pane. Nil keeps the draft local.
    private let sharedDraft: Binding<String>?
    private let presentation: Presentation
    /// A caller-owned view model outlives this view, so leaving the screen
    /// must not cancel its reply; the owner does that on close.
    private let ownsViewModel: Bool
    private let onClose: (() -> Void)?

    private var inputText: String {
        get { sharedDraft?.wrappedValue ?? localDraft }
        nonmutating set {
            if let sharedDraft { sharedDraft.wrappedValue = newValue } else { localDraft = newValue }
        }
    }

    private var inputBinding: Binding<String> {
        sharedDraft ?? $localDraft
    }

    // MARK: - Initialization

    init(
        stressResult: StressResult?,
        baseline: PersonalBaseline?,
        recentHistory: [StressMeasurement] = []
    ) {
        _viewModel = State(initialValue: ChatViewModel(
            stressResult: stressResult,
            baseline: baseline,
            recentHistory: recentHistory
        ))
        sharedDraft = nil
        presentation = .sheet
        ownsViewModel = true
        onClose = nil
    }

    /// Chat whose conversation and draft are kept by the caller, for the
    /// Action tab where the chat moves between a sheet and an inline pane as
    /// the iPhone Duo folds and unfolds.
    init(
        viewModel: ChatViewModel,
        draft: Binding<String>,
        presentation: Presentation,
        onClose: (() -> Void)? = nil
    ) {
        _viewModel = State(initialValue: viewModel)
        sharedDraft = draft
        self.presentation = presentation
        ownsViewModel = false
        self.onClose = onClose
    }

    /// Close: the caller's handler (it ends the conversation), then dismiss
    /// the sheet.
    private func close() {
        onClose?()
        if presentation == .sheet { dismiss() }
    }

    // MARK: - Body

    var body: some View {
        Group {
            if #available(iOS 27.1, *), presentation == .sheet {
                // System bar: on the iPhone Duo it moves to the side of the
                // outer display, with Close at the top of that column.
                NavigationStack {
                    chatBody
                        .toolbar { systemToolbar }
                        .toolbarTitleDisplayMode(.inline)
                }
            } else {
                chatBody
            }
        }
        // Wire the view model to app-scope services from the environment:
        // the 402 paywall presentation and the credits convergence sink.
        // The environment is not reachable in `init`, so this happens on
        // first appear, before any message can be sent.
        .onAppear {
            viewModel.presentPaywall = { paywall.present(reason: $0) }
            viewModel.setCreditsConvergenceSink { [weak creditService] remaining in
                creditService?.apply(creditsRemaining: remaining)
            }
            // Server-authoritative history restore (derived-SES-01): the
            // VM is fresh per presentation, and restoreHistory guards
            // re-appear within one presentation.
            viewModel.apiClient = StressAPIClient()
            Task { await viewModel.restoreHistory() }
            // Server-suggested chips swap over the instant local set once
            // the GET lands (derived-QA-01); preferences seed first so
            // the query carries the server pair, not install defaults
            // (WR-02 — COVERAGE row 14's chat-open seed).
            viewModel.preferencesService = preferencesService
            Task { await viewModel.hydratePreferencesAndFetchQuickActions() }
        }
        // Covers swipe-to-dismiss too, not just the Close button — without
        // this the SSE stream and its owning objects outlive the sheet. A
        // caller-owned view model is cancelled by its owner instead.
        .onDisappear {
            if ownsViewModel { viewModel.cancelResponse() }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.V2.bg)
    }

    private var chatBody: some View {
        VStack(spacing: 0) {
            chatHeader

            if viewModel.isAvailable {
                chatContent
            } else {
                unavailableView
            }
        }
        .background(Color.V2.bg.ignoresSafeArea())
    }

    /// iOS 27.1: Close leads (`.cancellationAction`), Clear follows.
    @available(iOS 27.1, *)
    @ToolbarContentBuilder
    private var systemToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(action: close) {
                Label("Close", systemImage: "xmark")
            }
        }
        if !viewModel.messages.isEmpty {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.clearConversation()
                } label: {
                    Label("Clear conversation", systemImage: "arrow.counterclockwise")
                }
            }
        }
    }

    /// The header keeps its own buttons only where the system bar does not
    /// carry them: below iOS 27.1, and in the inline pane.
    private var showsHeaderButtons: Bool {
        if #available(iOS 27.1, *) { return presentation == .pane }
        return true
    }

    // MARK: - Chat Content

    private var chatContent: some View {
        VStack(spacing: 0) {
            // Message stream (welcome, messages, typing, streaming reply)
            messageList

            // Error card
            if let error = viewModel.errorMessage {
                V2ErrorCard(title: "Message didn't send", message: error)
                    .padding(.horizontal, V2Metrics.margin)
                    .padding(.bottom, 8)
            }

            // Out of free messages: the same paywall trigger as the pill.
            if showsOutOfCreditsCard {
                outOfCreditsCard
            } else if !viewModel.isLoading {
                quickRepliesSection
            }

            ChatComposer(
                placeholder: "Message Ripple",
                text: inputBinding,
                canSend: canSend,
                onSend: sendMessage
            )
        }
    }

    // MARK: - Chat Header

    /// Avatar, name, subtitle, balance pill and the clear/close buttons.
    /// DEC-2 placement-a: the live balance pill is informational while the
    /// user still has credits and tappable straight to the paywall when the
    /// remaining count hits zero. Hidden while purchases are postponed — a
    /// zero balance would otherwise offer no way out. The pill sits inline
    /// when everything fits on one line, otherwise under the subtitle.
    private var chatHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                headerAvatar
                headerTitle(subtitleOnOneLine: true)
                Spacer(minLength: 0)
                if PurchaseAvailability.isEnabled { balancePill }
                headerButtons
            }
            HStack(alignment: .top, spacing: 12) {
                headerAvatar
                VStack(alignment: .leading, spacing: 4) {
                    headerTitle(subtitleOnOneLine: false)
                    if PurchaseAvailability.isEnabled { balancePill }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                headerButtons
            }
        }
        .padding(.leading, V2Metrics.margin)
        .padding(.trailing, V2Metrics.margin - 6)
        .padding(.top, 18)
        .padding(.bottom, 8)
        .background(alignment: .bottom) {
            Rectangle()
                .fill(Color.V2.line)
                .frame(height: 0.5)
                .ignoresSafeArea(edges: .horizontal)
        }
    }

    private var headerAvatar: some View {
        // Head crop on the teal chip in light mode; the soft disc shows
        // behind it in dark mode, where the chip is clear.
        StressBuddyIllustration(
            mood: viewModel.companionMood,
            size: 40,
            pose: .base,
            crop: .head,
            lightChip: true
        )
        .frame(width: 40, height: 40)
        .background(Circle().fill(Color.V2.Companion.ripple.opacity(0.18)))
        .accessibilityHidden(true)
    }

    private func headerTitle(subtitleOnOneLine: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Ripple")
                .font(.headline)
                .foregroundStyle(Color.V2.ink)
                .accessibilityAddTraits(.isHeader)

            Text("AI coach · sees your scores, never raw health data")
                .font(.caption)
                .foregroundStyle(Color.V2.ink3)
                .fixedSize(horizontal: subtitleOnOneLine, vertical: true)
        }
    }

    @ViewBuilder
    private var headerButtons: some View {
        if showsHeaderButtons {
            HStack(spacing: 0) {
                if !viewModel.messages.isEmpty {
                    headerIconButton(systemImage: "arrow.counterclockwise", label: "Clear conversation") {
                        viewModel.clearConversation()
                    }
                }

                if presentation == .sheet {
                    headerIconButton(systemImage: "xmark", label: "Close") {
                        close()
                    }
                }
            }
        }
    }

    private func headerIconButton(
        systemImage: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.footnote.weight(.bold))
                .foregroundStyle(Color.V2.ink2)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.V2.surface2))
                .frame(width: V2Metrics.minTouchTarget, height: V2Metrics.minTouchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Balance Pill

    private var isOutOfCredits: Bool {
        guard let balance = creditService.balance else { return false }
        return !balance.isUnlimited && balance.remaining <= 0
    }

    /// The out-of-credits card only shows where the pill would: a paywall
    /// route has to exist for it to offer one.
    private var showsOutOfCreditsCard: Bool {
        PurchaseAvailability.isEnabled && isOutOfCredits
    }

    @ViewBuilder
    private var balancePill: some View {
        if isOutOfCredits {
            Button {
                paywall.present(reason: .outOfCredits)
            } label: {
                ChatTag(
                    text: CreditBalanceFormatter.balanceText(creditService.balance),
                    systemImage: "exclamationmark.circle.fill",
                    foreground: StressCategory.moderate.color,
                    background: Color.V2.warnSoft
                )
                .frame(minHeight: V2Metrics.minTouchTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("No free messages left this month. Tap to see Plus.")
        } else {
            ChatTag(
                text: CreditBalanceFormatter.balanceText(creditService.balance),
                systemImage: "bubble.left.fill",
                foreground: Color.V2.accent,
                background: Color.V2.accentSoft
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Credit balance: \(CreditBalanceFormatter.balanceText(creditService.balance))")
        }
    }

    // MARK: - Message List

    private static let bottomAnchor = "chat-bottom"

    private var showsTypingDots: Bool {
        viewModel.isLoading && viewModel.currentStreamingText.isEmpty
    }

    private var showsStreamingBubble: Bool {
        viewModel.isLoading && !viewModel.currentStreamingText.isEmpty
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if viewModel.messages.isEmpty {
                        welcomeBubble
                    }

                    ForEach(viewModel.messages) { message in
                        MessageBubbleView(message: message)
                            .id(message.id)
                    }

                    if showsTypingDots {
                        ChatBubbleRow(isUser: false) {
                            ChatBubble(isUser: false) {
                                ChatTypingDots(accessibilityLabel: "Ripple is thinking", showsThinkingHead: true)
                            }
                        }
                    }

                    if showsStreamingBubble {
                        ChatBubbleRow(isUser: false) {
                            ChatBubble(isUser: false) {
                                Text(viewModel.currentStreamingText)
                            }
                        }
                    }

                    Color.clear
                        .frame(height: 1)
                        .id(Self.bottomAnchor)
                }
                .padding(.vertical, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToBottom(proxy)
            }
            .onChange(of: viewModel.currentStreamingText) { _, _ in
                scrollToBottom(proxy)
            }
            .onChange(of: viewModel.isLoading) { _, _ in
                scrollToBottom(proxy)
            }
        }
    }

    // MARK: - Welcome Bubble

    private var welcomeBubble: some View {
        ChatBubbleRow(isUser: false) {
            ChatBubble(isUser: false) {
                Text(welcomeText)
            }
        }
    }

    private var welcomeText: String {
        guard let result = viewModel.stressResult else {
            return "Hi, I'm Ripple. Ask me about your stress readings, or pick a suggestion below."
        }
        return "Hi, I'm Ripple. Your latest score is \(Int(result.level.rounded())) · \(result.category.displayName). What's on your mind?"
    }

    // MARK: - Quick Replies Section

    @ViewBuilder
    private var quickRepliesSection: some View {
        if !viewModel.quickReplies.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.quickReplies) { reply in
                        // Sends the chip's resolved prompt directly — the
                        // long prompt must not echo into the composer.
                        V2Chip(title: reply.title) {
                            viewModel.send(reply.prompt)
                        }
                    }
                }
                .padding(.horizontal, V2Metrics.margin)
            }
            .padding(.bottom, 2)
        }
    }

    // MARK: - Out of Credits

    private var outOfCreditsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Out of free messages")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.V2.ink)
            Text(CreditBalanceFormatter.outOfFreeMessagesText)
                .font(.footnote)
                .foregroundStyle(Color.V2.ink2)
                .fixedSize(horizontal: false, vertical: true)
            if let reset = CreditBalanceFormatter.resetDateText(creditService.balance) {
                Text(reset)
                    .font(.footnote)
                    .foregroundStyle(Color.V2.ink3)
            }
            HStack(spacing: 8) {
                Button("Get Plus") {
                    paywall.present(reason: .outOfCredits)
                }
                .buttonStyle(.v2(.primary, compact: true, fullWidth: false))
                Button("Not now") { close() }
                    .buttonStyle(.v2(.ghost, compact: true, fullWidth: false))
            }
            .padding(.top, 4)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: V2Metrics.radiusMD, style: .continuous)
                .fill(Color.V2.plusBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: V2Metrics.radiusMD, style: .continuous)
                .strokeBorder(Color.V2.plusLine, lineWidth: 1)
        )
        .padding(.horizontal, V2Metrics.margin)
        .padding(.bottom, 8)
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isLoading
    }

    // MARK: - Unavailable View

    private var unavailableView: some View {
        ScrollView {
            VStack(spacing: 14) {
                // "Ripple is resting" below says the state.
                StressBuddyIllustration(mood: .tired, size: 80, pose: .sleeping)
                    .frame(width: 112, height: 112)
                    .background(Circle().fill(Color.V2.Companion.ripple.opacity(0.18)))
                    .accessibilityHidden(true)

                Text("Ripple is resting")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.V2.ink)
                    .multilineTextAlignment(.center)

                Text("Chat isn't available right now. Your stress readings and breathing exercises still work as usual.")
                    .font(.callout)
                    .foregroundStyle(Color.V2.ink2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)
            .padding(.top, 56)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Helpers

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        viewModel.send(text)
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        if WellnessMotion.isMotionReduced(reduceMotionEnvironment: reduceMotion) {
            proxy.scrollTo(Self.bottomAnchor, anchor: .bottom)
        } else {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(Self.bottomAnchor, anchor: .bottom)
            }
        }
    }
}

// MARK: - Message Bubble View

/// Single message bubble in the chat stream (v2.css `.bubble`): assistant on
/// `surface` to the left, user on `accent` to the right, time underneath.
private struct MessageBubbleView: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == .user }

    /// A reply that streamed only whitespace has nothing to show; drawing it
    /// would leave an empty bubble in the stream.
    private var hasVisibleText: Bool {
        !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        if hasVisibleText {
            bubble
        }
    }

    private var bubble: some View {
        ChatBubbleRow(isUser: isUser) {
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                ChatBubble(isUser: isUser) {
                    Text(message.content)
                }
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(Color.V2.ink3)
                    .padding(.horizontal, 4)
            }
        }
    }
}
