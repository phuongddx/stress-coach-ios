import SwiftUI

/// Sources behind every health claim the app makes.
///
/// Reachable two ways, as App Review Guideline 1.4.1 asks for citations the user
/// can find easily: from Settings, and from the info control beside each number
/// that carries medical meaning. When opened from one of those controls,
/// `focusedTopic` scrolls its section into view.
struct ScienceSourcesView: View {
    /// Section to scroll to on appear. Nil when opened from Settings.
    var focusedTopic: ScienceTopic?

    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollViewReader { proxy in
            List {
                disclaimerSection

                ForEach(ScienceTopic.allCases) { topic in
                    topicSection(topic)
                        .id(topic)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Science & Sources")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                guard let focusedTopic else { return }
                // Landing directly on the relevant section is the point of the
                // deep link; anchoring to .top keeps its header visible.
                withAnimation(.easeInOut) {
                    proxy.scrollTo(focusedTopic, anchor: .top)
                }
            }
        }
    }

    // MARK: - Sections

    private var disclaimerSection: some View {
        Section {
            Text("Stress AI Coach is a wellness app. It does not diagnose, treat or prevent any medical condition, and it is not a medical device. Talk to a healthcare professional about any health concern.")
                .font(.system(size: 14))
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
        }
    }

    @ViewBuilder
    private func topicSection(_ topic: ScienceTopic) -> some View {
        Section {
            Text(topic.summary)
                .font(.system(size: 14))
                .foregroundStyle(Color.Wellness.adaptivePrimaryText)

            ForEach(ScienceCitation.citations(for: topic)) { citation in
                citationRow(citation)
            }

            limitationRow(topic)
        } header: {
            Text(topic.title)
        }
    }

    private func citationRow(_ citation: ScienceCitation) -> some View {
        Button {
            openURL(citation.url)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(citation.claim)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.Wellness.adaptivePrimaryText)

                Text(citation.reference)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 4) {
                    Text("Read the source")
                    Image(systemName: "arrow.up.right.square")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(HomeCharacterDesignTokens.Ripple.deep)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .minimumTouchTarget(DesignTokens.Layout.minTouchTarget)
        .accessibilityLabel("\(citation.claim). \(citation.reference)")
        .accessibilityHint("Opens the source in your browser")
    }

    private func limitationRow(_ topic: ScienceTopic) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 13))
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
                .accessibilityHidden(true)

            Text(topic.limitation)
                .font(.system(size: 13))
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Limitation. \(topic.limitation)")
    }
}

#Preview {
    NavigationStack {
        ScienceSourcesView(focusedTopic: .biologicalAge)
    }
}
