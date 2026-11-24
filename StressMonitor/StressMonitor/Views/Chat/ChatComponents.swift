import SwiftUI

// MARK: - Chat Bubble

/// UI V2 chat bubble shared by the Ripple sheet and the Health Coach chat.
/// Assistant: `surface` (`surface2` in dark mode) with the light-mode card
/// shadow and a small bottom-leading corner. User: `accent` with `onAccent`
/// text and a small bottom-trailing corner.
/// Spec reference: ui-v2-design/v2.css `.bubble`.
struct ChatBubble<Content: View>: View {
    let isUser: Bool
    let content: Content

    @Environment(\.colorScheme) private var colorScheme

    init(isUser: Bool, @ViewBuilder content: () -> Content) {
        self.isUser = isUser
        self.content = content()
    }

    private var fill: Color {
        if isUser { return Color.V2.accent }
        return colorScheme == .dark ? Color.V2.surface2 : Color.V2.surface
    }

    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 20,
            bottomLeadingRadius: isUser ? 20 : 6,
            bottomTrailingRadius: isUser ? 6 : 20,
            topTrailingRadius: 20,
            style: .continuous
        )
    }

    var body: some View {
        content
            .font(.body)
            .foregroundStyle(isUser ? Color.V2.onAccent : Color.V2.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(shape.fill(fill))
            .shadow(
                color: !isUser && colorScheme == .light ? Color.V2.ink.opacity(0.06) : .clear,
                radius: 1, x: 0, y: 1
            )
    }
}

/// Places a bubble on its side of the stream, leaving room on the other side.
struct ChatBubbleRow<Content: View>: View {
    let isUser: Bool
    let content: Content

    init(isUser: Bool, @ViewBuilder content: () -> Content) {
        self.isUser = isUser
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 0) {
            if isUser { Spacer(minLength: 56) }
            content
            if !isUser { Spacer(minLength: 56) }
        }
        .padding(.horizontal, V2Metrics.margin)
    }
}

// MARK: - Typing Dots

/// Three `ink3` dots that pulse while a reply is on its way, optionally led by
/// Ripple's small thinking head (spec §4.2). The dots are static under Reduce
/// Motion; the head never animates.
struct ChatTypingDots: View {
    var accessibilityLabel: String = "Ripple is thinking"
    /// Shows Ripple's thinking head before the dots.
    var showsThinkingHead: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            if showsThinkingHead {
                RippleV2Image(pose: .thinking, lightChip: true, size: 20)
            }
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.V2.ink3)
                        .frame(width: 7, height: 7)
                        .modifier(TypingDotAnimation(delay: Double(index) * 0.2))
                }
            }
            .padding(.vertical, 7)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// Pulses a dot's opacity. Under Reduce Motion the dot is drawn without the
/// modifier at all, so no repeating animation can keep running.
struct TypingDotAnimation: ViewModifier {
    let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false

    @ViewBuilder
    func body(content: Content) -> some View {
        if WellnessMotion.isMotionReduced(reduceMotionEnvironment: reduceMotion) {
            content
                .onAppear { isAnimating = false }
        } else {
            content
                .opacity(isAnimating ? 1 : 0.3)
                .animation(
                    .easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: true)
                        .delay(delay),
                    value: isAnimating
                )
                .onAppear { isAnimating = true }
        }
    }
}

// MARK: - Composer

/// Message field and send button on a `surface` bar with a top hairline.
struct ChatComposer: View {
    let placeholder: String
    @Binding var text: String
    let canSend: Bool
    let onSend: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField(
                placeholder,
                text: $text,
                prompt: Text(placeholder).foregroundStyle(Color.V2.ink3),
                axis: .vertical
            )
            .font(.body)
            .foregroundStyle(Color.V2.ink)
            .tint(Color.V2.accent)
            .lineLimit(1...4)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minHeight: V2Metrics.minTouchTarget)
            .background(
                RoundedRectangle(cornerRadius: V2Metrics.minTouchTarget / 2, style: .continuous)
                    .fill(Color.V2.surface2)
            )
            .onSubmit(onSend)

            Button(action: onSend) {
                Image(systemName: "arrow.up")
                    .font(.body.weight(.bold))
                    .foregroundStyle(canSend ? Color.V2.onAccent : Color.V2.ink3)
                    .frame(width: V2Metrics.minTouchTarget, height: V2Metrics.minTouchTarget)
                    .background(Circle().fill(canSend ? Color.V2.accent : Color.V2.surface3))
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .accessibilityLabel("Send message")
        }
        .padding(.horizontal, V2Metrics.margin)
        .padding(.vertical, 8)
        .background(alignment: .top) {
            // Runs edge to edge, under the home indicator and any side inset.
            ZStack(alignment: .top) {
                Color.V2.surface
                Rectangle().fill(Color.V2.line).frame(height: 0.5)
            }
            .ignoresSafeArea(edges: [.bottom, .horizontal])
        }
    }
}

// MARK: - Tag

/// Small capsule label ("Beta", credit balance). Spec: v2.css `.tag`.
struct ChatTag: View {
    let text: String
    var systemImage: String? = nil
    var foreground: Color = Color.V2.ink2
    var background: Color = Color.V2.surface2

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .imageScale(.small)
                    .accessibilityHidden(true)
            }
            Text(text)
                .lineLimit(1)
        }
        .fixedSize()
        .font(.v2Number(.caption))
        .foregroundStyle(foreground)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(background))
    }
}

#Preview("Chat components") {
    VStack(spacing: 10) {
        ChatBubbleRow(isUser: false) {
            ChatBubble(isUser: false) { Text("Hi, I'm Ripple. What's on your mind?") }
        }
        ChatBubbleRow(isUser: true) {
            ChatBubble(isUser: true) { Text("Why was I stressed this afternoon?") }
        }
        ChatBubbleRow(isUser: false) {
            ChatBubble(isUser: false) { ChatTypingDots(showsThinkingHead: true) }
        }
        HStack {
            ChatTag(text: "14 of 20 left", foreground: Color.V2.accent, background: Color.V2.accentSoft)
            ChatTag(text: "Beta")
        }
        Spacer()
        ChatComposer(placeholder: "Message Ripple", text: .constant(""), canSend: false) {}
    }
    .background(Color.V2.bg)
}
