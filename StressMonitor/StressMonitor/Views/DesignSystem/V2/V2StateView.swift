import SwiftUI

/// Shared empty / error / Health-denied block: symbol, title, one sentence and
/// an optional primary action such as Retry or Open Settings.
struct V2StateView: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var tint: Color = Color.V2.accent

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color.V2.surface2))
                .accessibilityHidden(true)
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.V2.ink)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.V2.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.v2(.primary, compact: true, fullWidth: false))
                    .padding(.top, 4)
            }
        }
        .padding(V2Metrics.margin)
        .frame(maxWidth: .infinity)
    }
}

/// Rounded `surface2` placeholder. Shimmers only when Reduce Motion is off.
struct V2Skeleton: View {
    var width: CGFloat? = nil
    var height: CGFloat = 16
    var cornerRadius: CGFloat = V2Metrics.radiusXS

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dimmed = false

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.V2.surface2)
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
            .opacity(dimmed ? 0.55 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { dimmed = true }
            }
            .accessibilityHidden(true)
    }
}

#Preview("States") {
    VStack(spacing: 16) {
        V2Card {
            V2StateView(systemImage: "heart.slash", title: "Health access is off",
                        message: "Turn on Health access to see your stress score.",
                        actionTitle: "Open Settings") {}
        }
        V2Card {
            VStack(alignment: .leading, spacing: 8) {
                V2Skeleton(width: 120, height: 20)
                V2Skeleton(height: 120, cornerRadius: V2Metrics.radiusMD)
            }
        }
    }
    .padding()
    .background(Color.V2.bg)
}
