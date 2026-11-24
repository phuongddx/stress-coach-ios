import SwiftUI

enum PlusPillMode {
    case labelOnly
    case tryFree
}

/// Plus pill on the Settings hero card (UI V2 `.pluspill`): `plusBg` capsule
/// with `plus` text and a `plusLine` hairline. A 44 pt hit area.
struct PlusPill: View {
    var mode: PlusPillMode = .labelOnly
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button {
            HapticManager.shared.buttonPress()
            onTap?()
        } label: {
            content
        }
        .buttonStyle(.plain)
        .minimumTouchTarget(DesignTokens.Layout.minTouchTarget)
        .accessibilityLabel(accessibility)
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .labelOnly:
            Text("PLUS")
                .font(.caption.weight(.bold))
                .tracking(0.6)
                .foregroundStyle(Color.V2.plus)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.V2.plusBg))
                .overlay(Capsule().strokeBorder(Color.V2.plusLine, lineWidth: 0.5))

        case .tryFree:
            HStack(spacing: 6) {
                Image(AppIconSystem.Setting.plusPillSparkleAsset)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 12, height: 12)
                    .accessibilityHidden(true)
                Text("Plus")
                    .font(.subheadline.weight(.bold))
                Text("Try free ›")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(Color.V2.plus)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(Color.V2.plusBg))
            .overlay(Capsule().strokeBorder(Color.V2.plusLine, lineWidth: 0.5))
        }
    }

    private var accessibility: String {
        switch mode {
        case .labelOnly:    return "Plus member"
        case .tryFree:      return "Plus. Try free."
        }
    }
}

#Preview {
    VStack(spacing: 10) {
        PlusPill(mode: .labelOnly)
        PlusPill(mode: .tryFree)
    }
    .padding()
    .background(Color.V2.bg)
}
