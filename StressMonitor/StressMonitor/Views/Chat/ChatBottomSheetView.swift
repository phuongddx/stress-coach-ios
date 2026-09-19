import SwiftUI

// MARK: - Chat Bottom Sheet View

/// AI Chat bottom sheet matching `09-chat.html`.
///
/// Shows a chat header with a mood-reactive Ripple avatar (serene when stress
/// is Mild, worried when High), a message stream, quick reply chips, and a
/// composer with mic + send buttons. The Ripple avatar's expression reflects
/// the user's current stress level.
struct ChatBottomSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PaywallController.self) private var paywall
    @Environment(CreditService.self) private var creditService
    @Environment(PreferencesService.self) private var preferencesService
    @State private var viewModel: ChatViewModel
    @State private var inputText = ""

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
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.isAvailable {
                    chatContent
                } else {
                    unavailableView
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
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
            // this the SSE stream and its owning objects outlive the sheet.
            .onDisappear { viewModel.cancelResponse() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !viewModel.messages.isEmpty {
                        Button {
                            viewModel.clearConversation()
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityLabel("Clear conversation")
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Chat Content

    private var chatContent: some View {
        VStack(spacing: 0) {
            // Chat header (Ripple avatar + name + subtitle)
            chatHeader

            // Message stream
            messageList

            // Streaming indicator
            if viewModel.isLoading && !viewModel.currentStreamingText.isEmpty {
                streamingBubble
            }

            // Error banner
            if let error = viewModel.errorMessage {
                errorBanner(error)
            }

            // Quick replies (label + chips)
            if !viewModel.isLoading {
                quickRepliesSection
            }

            // Composer
            chatComposer
        }
    }

    // MARK: - Chat Header

    private var chatHeader: some View {
        HStack(spacing: 12) {
            // Ripple avatar with online dot
            ZStack(alignment: .bottomTrailing) {
                StressBuddyIllustration(
                    mood: viewModel.companionMood,
                    size: 36
                )
                .background(
                    Circle()
                        .fill(Color(hex: "#4FC3F7").opacity(0.12))
                )

                // Online indicator dot
                Circle()
                    .fill(Color(hex: "#34C759"))
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle().stroke(.white, lineWidth: 2)
                    )
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Ripple")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.Wellness.adaptivePrimaryText)

                Text(companionSubtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
            }

            Spacer()

            // DEC-2 placement-a: live balance pill. Informational while the
            // user still has credits; tappable straight to the paywall when
            // the remaining count hits zero. Hidden while purchases are
            // postponed — a zero balance would otherwise offer no way out.
            if PurchaseAvailability.isEnabled {
                balancePill
            }

            // Overflow menu
            Image(systemName: "ellipsis")
                .font(.system(size: 20))
                .foregroundStyle(Color(hex: "#0288D1"))
                .accessibilityLabel("More options")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    // MARK: - Balance Pill

    private var isOutOfCredits: Bool {
        guard let balance = creditService.balance else { return false }
        return !balance.isUnlimited && balance.remaining <= 0
    }

    @ViewBuilder
    private var balancePill: some View {
        if isOutOfCredits {
            Button {
                paywall.present(reason: .outOfCredits)
            } label: {
                pillLabel(systemImage: "exclamationmark.circle.fill", tint: Color(hex: "#FF9500"))
            }
            .buttonStyle(.plain)
            .frame(minHeight: 44)
            .accessibilityLabel("Out of credits. Tap to view options.")
        } else {
            pillLabel(
                systemImage: "circlebadge.2",
                tint: Color.Wellness.adaptiveSecondaryText
            )
            .accessibilityLabel("Credit balance: \(CreditBalanceFormatter.balanceText(creditService.balance))")
        }
    }

    private func pillLabel(systemImage: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
            Text(CreditBalanceFormatter.balanceText(creditService.balance))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.Wellness.adaptiveCardBackground)
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(Color.Wellness.adaptiveSecondaryText.opacity(0.15), lineWidth: 1)
        )
    }

    /// Subtitle reflecting current stress state.
    private var companionSubtitle: String {
        let level = Int(viewModel.companionMood == .serene ? 30 : 50)
        switch viewModel.companionMood {
        case .relaxed, .serene: return "Water Otter · reading your morning"
        case .focused:          return "Water Otter · noticing your focus"
        case .worried:          return "Water Otter · sensing your stress"
        case .tired:            return "Water Otter · you seem tired"
        case .determined:       return "Water Otter · feeling your intensity"
        default:                return "Water Otter · stress level ~\(level)"
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if viewModel.messages.isEmpty {
                        welcomeBubble
                    }

                    ForEach(viewModel.messages) { message in
                        MessageBubbleView(message: message, mood: viewModel.companionMood)
                            .id(message.id)
                    }

                    // Typing indicator
                    if viewModel.isLoading && viewModel.currentStreamingText.isEmpty {
                        HStack {
                            typingIndicator
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                    }
                }
                .padding(.vertical, 16)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToLast(proxy)
            }
            .onChange(of: viewModel.currentStreamingText) { _, _ in
                scrollToLast(proxy)
            }
        }
    }

    // MARK: - Welcome Bubble

    private var welcomeBubble: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Hi, I'm Ripple — your water otter companion.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.Wellness.adaptivePrimaryText)

            Text("I track your stress patterns and suggest quick resets. Ask me anything about your readings, or pick a quick reply below.")
                .font(.system(size: 14))
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
                .lineSpacing(3)
        }
        .frame(maxWidth: 260, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.Wellness.adaptiveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
    }

    // MARK: - Streaming Bubble

    private var streamingBubble: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.currentStreamingText)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.Wellness.adaptivePrimaryText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.Wellness.adaptiveCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .frame(maxWidth: 260, alignment: .leading)

            Spacer()
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Typing Indicator

    private var typingIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.Wellness.adaptiveSecondaryText.opacity(0.6))
                    .frame(width: 6, height: 6)
                    .modifier(TypingDotAnimation(delay: Double(index) * 0.2))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.Wellness.adaptiveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Quick Replies Section

    private var quickRepliesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(viewModel.quickReplies) { reply in
                        Button {
                            // Sends the chip's resolved prompt directly — the
                            // long prompt must not echo into the composer.
                            viewModel.send(reply.prompt)
                        } label: {
                            Text(reply.title)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color(hex: "#0288D1"))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Color.Wellness.adaptiveCardBackground)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Color.Wellness.adaptiveSecondaryText.opacity(0.15), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 12))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.red.cornerRadius(8))
            .padding(.horizontal, 16)
    }

    // MARK: - Composer

    private var chatComposer: some View {
        HStack(spacing: 8) {
            // Input shell
            HStack(spacing: 4) {
                TextField("Message Ripple…", text: $inputText, axis: .vertical)
                    .font(.system(size: 15))
                    .lineLimit(1...4)
                    .padding(.leading, 10)
                    .padding(.trailing, 4)
                    .padding(.vertical, 8)
                    .onSubmit { sendMessage() }

                // Mic button
                Button {
                    // Voice input not yet implemented
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
                        .frame(width: 32, height: 32)
                        .background(Color.Wellness.adaptiveSecondaryText.opacity(0.08))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Voice input")
            }
            .background(Color.Wellness.adaptiveCardBackground)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.Wellness.adaptiveSecondaryText.opacity(0.15), lineWidth: 1)
            )

            // Send button
            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(canSend ? Color(hex: "#0288D1") : Color.Wellness.adaptiveSecondaryText.opacity(0.3))
                    .clipShape(Circle())
            }
            .disabled(!canSend)
            .accessibilityLabel("Send message")
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(Color.Wellness.adaptiveBackground.opacity(0.92))
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isLoading
    }

    // MARK: - Unavailable View

    private var unavailableView: some View {
        VStack(spacing: 20) {
            Image(systemName: "brain.head.profile.fill")
                .font(.system(size: 48))
                .foregroundStyle(HomeCharacterDesignTokens.Ripple.primary.opacity(0.6))

            Text("AI Coaching is coming soon")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.Wellness.adaptivePrimaryText)

            Text("Ripple's conversations arrive in our next update. Meanwhile, your stress readings and breathing exercises are fully available.")
                .font(.system(size: 15))
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
        .padding(.top, 60)
    }

    // MARK: - Helpers

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        viewModel.send(text)
    }

    private func scrollToLast(_ proxy: ScrollViewProxy) {
        if let lastMessage = viewModel.messages.last {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
}

// MARK: - Message Bubble View

/// Single message bubble in the chat stream. Matching `09-chat.html`:
/// - Assistant (from-them): surface bg, left-aligned, bottom-left small radius
/// - User (from-me): gradient blue bg, right-aligned, bottom-right small radius
private struct MessageBubbleView: View {
    let message: ChatMessage
    let mood: RippleMood

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 60) }

            VStack(
                alignment: message.role == .user ? .trailing : .leading,
                spacing: 4
            ) {
                Text(message.content)
                    .font(.system(size: 14))
                    .foregroundStyle(message.role == .user ? .white : Color.Wellness.adaptivePrimaryText)
                    .lineSpacing(2)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        message.role == .user
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [Color(hex: "#4FC3F7"), Color(hex: "#0288D1")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        : AnyShapeStyle(Color.Wellness.adaptiveCardBackground)
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                    .frame(maxWidth: 260, alignment: message.role == .user ? .trailing : .leading)

                // Timestamp
                Text(timestampText)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.Wellness.adaptiveSecondaryText.opacity(0.7))
                    .padding(.horizontal, 4)
            }

            if message.role == .assistant { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 16)
    }

    private var timestampText: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: message.timestamp)
    }
}

// MARK: - Typing Dot Animation

private struct TypingDotAnimation: ViewModifier {
    let delay: Double
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .offset(y: isAnimating ? -4 : 4)
            .animation(
                .easeInOut(duration: 0.5)
                    .repeatForever(autoreverses: true)
                    .delay(delay),
                value: isAnimating
            )
            .startMotionIfAllowed { isAnimating = true }
    }
}
