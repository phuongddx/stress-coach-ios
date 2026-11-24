import SwiftUI

/// The one locked-content pattern (spec §4): the real content blurred behind
/// a lock tile, a one-line reason and a "Try Plus free" button. Visual only:
/// `PlusLockedModifier` and `PlusAccess` decide when it shows and what the
/// tap does.
struct V2PlusLockOverlay: View {
    let message: String
    let buttonTitle: String
    let accessibilityLabel: String
    let accessibilityHint: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            // Short charts (the tier bar) only fit the compact row.
            ViewThatFits(in: .vertical) {
                fullLayout
                compactLayout
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(.isButton)
    }

    private var fullLayout: some View {
        VStack(spacing: 10) {
            lockTile(size: 40)
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.V2.ink)
                .multilineTextAlignment(.center)
            pill
        }
        .padding(V2Metrics.margin)
    }

    private var compactLayout: some View {
        HStack(spacing: 8) {
            lockTile(size: 28)
            pill
        }
    }

    private func lockTile(size: CGFloat) -> some View {
        Image(systemName: "lock.fill")
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(Color.V2.plus)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: V2Metrics.radiusSM, style: .continuous).fill(Color.V2.plusBg))
            .overlay(
                RoundedRectangle(cornerRadius: V2Metrics.radiusSM, style: .continuous)
                    .strokeBorder(Color.V2.plusLine, lineWidth: 0.5)
            )
    }

    /// Looks like a compact secondary button; the whole overlay is the tap target.
    private var pill: some View {
        Text(buttonTitle)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.V2.accent)
            .padding(.horizontal, V2Metrics.margin)
            .frame(minHeight: 36)
            .background(Capsule().fill(Color.V2.accentSoft))
    }
}

#Preview("Plus lock overlay") {
    RoundedRectangle(cornerRadius: 16)
        .fill(Color.V2.surface2)
        .frame(height: 180)
        .overlay {
            V2PlusLockOverlay(
                message: "See your full chart with Plus",
                buttonTitle: "Try Plus free",
                accessibilityLabel: "HRV trend chart locked",
                accessibilityHint: "Double-tap to unlock Plus"
            ) {}
        }
        .padding()
        .background(Color.V2.bg)
}
