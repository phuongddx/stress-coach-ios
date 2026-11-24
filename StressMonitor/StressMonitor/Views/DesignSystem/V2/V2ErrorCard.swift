import SwiftUI

/// Inline error row (UI V2): a cloud-off icon in `danger` on a `dangerSoft`
/// tile, a bold title, a message, and optional "Try again" / dismiss actions.
///
/// Spec reference: ui-v2-design/screens.js `errorCard`, v2.css `.err`.
struct V2ErrorCard: View {
    let title: String
    let message: String
    var retryTitle: String = "Try again"
    var onRetry: (() -> Void)? = nil
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "icloud.slash")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.V2.danger)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.V2.ink)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Color.V2.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                if let onRetry {
                    Button(retryTitle, action: onRetry)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.V2.accent)
                        .frame(minHeight: V2Metrics.minTouchTarget)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Color.V2.ink3)
                        .frame(width: V2Metrics.minTouchTarget, height: V2Metrics.minTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, -12)
                .padding(.trailing, -12)
                .accessibilityLabel("Dismiss")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: V2Metrics.radiusMD, style: .continuous)
                .fill(Color.V2.dangerSoft)
        )
        .accessibilityElement(children: .contain)
    }
}

#Preview("Error card") {
    VStack(spacing: 12) {
        V2ErrorCard(title: "Couldn't load health data", message: "The operation couldn't be completed.",
                    onRetry: {}, onDismiss: {})
        V2ErrorCard(title: "Couldn't load history", message: "Try again later.")
    }
    .padding()
    .background(Color.V2.bg)
}
