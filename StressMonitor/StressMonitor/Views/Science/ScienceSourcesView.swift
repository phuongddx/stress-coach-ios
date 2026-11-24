import SwiftUI

/// Sources behind every health claim the app makes.
///
/// Reachable two ways, as App Review Guideline 1.4.1 asks for citations the user
/// can find easily: from Settings, and from the info control beside each number
/// that carries medical meaning. When opened from one of those controls,
/// `focusedTopic` scrolls its section into view.
///
/// UI V2 (`S.science`): a `warnSoft` disclaimer card, then one card per
/// topic with an eyebrow, title, summary, flat citation cards and the
/// limitation line.
struct ScienceSourcesView: View {
    /// Section to scroll to on appear. Nil when opened from Settings.
    var focusedTopic: ScienceTopic?

    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    disclaimerCard

                    ForEach(ScienceTopic.allCases) { topic in
                        topicCard(topic)
                            .id(topic)
                    }
                }
                .padding(.horizontal, V2Metrics.margin)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color.V2.bg.ignoresSafeArea())
            .navigationTitle("Science & Sources")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                guard let focusedTopic else { return }
                // Landing directly on the relevant section is the point of the
                // deep link; anchoring to .top keeps its header visible.
                if reduceMotion {
                    proxy.scrollTo(focusedTopic, anchor: .top)
                } else {
                    withAnimation(.easeInOut) {
                        proxy.scrollTo(focusedTopic, anchor: .top)
                    }
                }
            }
        }
    }

    // MARK: - Sections

    private var disclaimerCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle.fill")
                .font(.title3)
                .foregroundStyle(Color.V2.ink2)
                .accessibilityHidden(true)

            Text("Stress AI Coach is a wellness app. It does not diagnose, treat or prevent any medical condition, and it is not a medical device. Talk to a healthcare professional about any health concern.")
                .font(.subheadline)
                .foregroundStyle(Color.V2.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(V2Metrics.margin)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: V2Metrics.radiusLG, style: .continuous)
                .fill(Color.V2.warnSoft)
        )
        .accessibilityElement(children: .combine)
    }

    private func topicCard(_ topic: ScienceTopic) -> some View {
        V2Card {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(topic.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.V2.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text(topic.summary)
                        .font(.subheadline)
                        .foregroundStyle(Color.V2.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(ScienceCitation.citations(for: topic)) { citation in
                    citationRow(citation)
                }

                limitationRow(topic)
            }
        }
    }

    private func citationRow(_ citation: ScienceCitation) -> some View {
        Button {
            openURL(citation.url)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(citation.claim)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.V2.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(citation.reference)
                    .font(.footnote)
                    .foregroundStyle(Color.V2.ink3)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 4) {
                    Text("Read the source")
                    Image(systemName: "arrow.up.right")
                        .imageScale(.small)
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.V2.accent)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: V2Metrics.radiusSM, style: .continuous)
                    .fill(Color.V2.surface2)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .minimumTouchTarget(DesignTokens.Layout.minTouchTarget)
        .accessibilityLabel("\(citation.claim). \(citation.reference)")
        .accessibilityHint("Opens the source in your browser")
    }

    private func limitationRow(_ topic: ScienceTopic) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle")
                .font(.footnote)
                .foregroundStyle(Color.V2.ink3)
                .accessibilityHidden(true)

            Text(topic.limitation)
                .font(.footnote)
                .foregroundStyle(Color.V2.ink3)
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
