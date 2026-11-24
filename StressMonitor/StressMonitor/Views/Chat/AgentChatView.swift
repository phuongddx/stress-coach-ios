import SwiftUI

// MARK: - Agent Chat View

/// Health Coach chat (POST /agent/chat). Pushed from Settings' Sync & devices
/// card behind `FeatureFlags.agentChatEnabled`. Bubbles, typing dots and the
/// composer are the shared UI V2 chat components used by `ChatBottomSheetView`,
/// so the two chat surfaces read as one product.
struct AgentChatView: View {
    @StateObject private var vm = AgentChatViewModel()
    @State private var draft = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !vm.isStreaming
    }

    var body: some View {
        VStack(spacing: 0) {
            if vm.messages.isEmpty {
                emptyState
            } else {
                messageList
            }
            if let error = vm.errorText {
                V2ErrorCard(title: "Coach couldn't answer", message: error)
                    .padding(.horizontal, V2Metrics.margin)
                    .padding(.bottom, 8)
            }
            ChatComposer(
                placeholder: "Ask about sleep, stress or habits",
                text: $draft,
                canSend: canSend,
                onSend: send
            )
        }
        .background(Color.V2.bg.ignoresSafeArea())
        .navigationTitle("Health Coach")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Text("Health Coach")
                        .font(.headline)
                        .foregroundStyle(Color.V2.ink)
                    ChatTag(text: "Beta", foreground: Color.V2.accent, background: Color.V2.accentSoft)
                }
                .accessibilityElement(children: .combine)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("New") { vm.startNewConversation() }
                    .tint(Color.V2.accent)
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 14) {
                StressBuddyIllustration(mood: .happy, size: 80)
                    .frame(width: 112, height: 112)
                    .background(Circle().fill(Color.V2.accentSoft))
                    .accessibilityHidden(true)

                Text("Ask the Health Coach")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.V2.ink)
                    .multilineTextAlignment(.center)

                Text("Longer answers that look across your trends. It sees your derived scores only, and it can't diagnose.")
                    .font(.callout)
                    .foregroundStyle(Color.V2.ink2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)
            .padding(.top, 56)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Message stream

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(vm.messages) { message in
                        MessageBubble(message: message, isStreaming: vm.isStreaming)
                            .id(message.id)
                    }
                }
                .padding(.vertical, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: vm.messages.count) {
                scrollToLast(proxy)
            }
            .onChange(of: vm.messages.last?.text) {
                scrollToLast(proxy)
            }
        }
    }

    private func scrollToLast(_ proxy: ScrollViewProxy) {
        guard let last = vm.messages.last else { return }
        if WellnessMotion.isMotionReduced(reduceMotionEnvironment: reduceMotion) {
            proxy.scrollTo(last.id, anchor: .bottom)
        } else {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSend else { return }
        draft = ""
        Task { await vm.send(text) }
    }
}

// MARK: - Message Bubble

/// Single coach-chat bubble: user on `accent` to the right, assistant on
/// `surface` to the left. An in-flight empty assistant reply shows the
/// typing dots.
private struct MessageBubble: View {
    let message: AgentMessage
    let isStreaming: Bool

    private var isUser: Bool { message.role == "user" }

    var body: some View {
        ChatBubbleRow(isUser: isUser) {
            ChatBubble(isUser: isUser) {
                if !isUser && message.text.isEmpty && isStreaming {
                    ChatTypingDots(accessibilityLabel: "Coach is typing")
                } else {
                    Text(message.text)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        AgentChatView()
    }
}
