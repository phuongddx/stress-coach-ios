import SwiftUI

/// Paywall nav row (UI V2): Restore on the leading side, a circular Close on
/// the trailing side. Pinned above the scroll so both are always visible.
struct IAPNavBar: View {
    var isRestoreDisabled: Bool = false
    let onRestore: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack {
            Button("Restore", action: onRestore)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.V2.accent)
                .frame(minWidth: V2Metrics.minTouchTarget, minHeight: V2Metrics.minTouchTarget)
                .contentShape(Rectangle())
                .disabled(isRestoreDisabled)
                .accessibilityLabel("Restore purchases")

            Spacer()

            Button(action: onClose) {
                Image(systemName: AppIconSystem.Nav.close.sfSymbol)
                    .font(.body.weight(.bold))
                    .foregroundStyle(Color.V2.ink2)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.V2.surface2))
                    .frame(width: V2Metrics.minTouchTarget, height: V2Metrics.minTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, V2Metrics.margin - 4)
        .padding(.vertical, 2)
        .background(Color.V2.bg.ignoresSafeArea(edges: .top))
    }
}

#Preview {
    IAPNavBar(onRestore: {}, onClose: {})
        .background(Color.V2.bg)
}
