import SwiftUI

/// Info control placed beside a number that carries medical meaning.
///
/// Deep-links to that claim's sources rather than a generic page, so the user
/// reaches the citation for the figure actually on screen.
struct ScienceInfoButton: View {
    let topic: ScienceTopic
    let onOpen: (ScienceTopic) -> Void

    var body: some View {
        Button {
            onOpen(topic)
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
        }
        .buttonStyle(.plain)
        .minimumTouchTarget(DesignTokens.Layout.minTouchTarget)
        .accessibilityLabel("About the \(topic.title.lowercased())")
        .accessibilityHint("Shows how this is calculated and the research behind it")
    }
}
