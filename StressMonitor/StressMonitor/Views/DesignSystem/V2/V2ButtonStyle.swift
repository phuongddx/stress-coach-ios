import SwiftUI

/// UI V2 buttons: capsule, 50 pt minimum height (44 pt compact), headline
/// weight, 0.38 opacity when disabled, press scale off under Reduce Motion.
struct V2ButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, ghost, destructive, destructiveFill, lime }

    var kind: Kind = .primary
    var compact: Bool = false
    var fullWidth: Bool = true

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var foreground: Color {
        switch kind {
        case .primary: return Color.V2.onAccent
        case .secondary: return Color.V2.accent
        case .ghost: return Color.V2.accent
        case .destructive: return Color.V2.danger
        case .destructiveFill: return Color.V2.bg
        case .lime: return Color.V2.onLime
        }
    }

    private var background: Color {
        switch kind {
        case .primary: return Color.V2.accent
        case .secondary: return Color.V2.accentSoft
        case .ghost: return .clear
        case .destructive: return Color.V2.dangerSoft
        case .destructiveFill: return Color.V2.danger
        case .lime: return Color.V2.lime
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .multilineTextAlignment(.center)
            .foregroundStyle(foreground)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(minHeight: compact ? V2Metrics.compactButtonHeight : V2Metrics.buttonHeight)
            .background(Capsule().fill(background))
            .contentShape(Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.38)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == V2ButtonStyle {
    static func v2(_ kind: V2ButtonStyle.Kind = .primary, compact: Bool = false, fullWidth: Bool = true) -> V2ButtonStyle {
        V2ButtonStyle(kind: kind, compact: compact, fullWidth: fullWidth)
    }
}

#Preview("Buttons") {
    VStack(spacing: 12) {
        Button("Start breathing") {}.buttonStyle(.v2(.primary))
        Button("Log mood") {}.buttonStyle(.v2(.secondary))
        Button("Not now") {}.buttonStyle(.v2(.ghost))
        Button("Delete data") {}.buttonStyle(.v2(.destructive))
        Button("Delete everything") {}.buttonStyle(.v2(.destructiveFill))
        Button("Done") {}.buttonStyle(.v2(.lime))
        Button("Disabled") {}.buttonStyle(.v2(.primary)).disabled(true)
        Button("Compact") {}.buttonStyle(.v2(.secondary, compact: true, fullWidth: false))
    }
    .padding()
    .background(Color.V2.bg)
}
