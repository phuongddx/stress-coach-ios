import Foundation
import Testing
@testable import StressMonitor

/// Guards the citation catalog that satisfies App Review Guideline 1.4.1:
/// every health claim the app states must carry a findable source.
struct ScienceCitationTests {

    @Test("Every science topic carries at least one citation")
    func everyTopicHasACitation() {
        for topic in ScienceTopic.allCases {
            #expect(!ScienceCitation.citations(for: topic).isEmpty, "No citation for \(topic.rawValue)")
        }
    }

    @Test("Citation identifiers are unique")
    func citationIdentifiersAreUnique() {
        let ids = ScienceCitation.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("Every citation resolves to a secure, non-empty source link")
    func citationsCarryResolvableLinks() {
        for citation in ScienceCitation.all {
            #expect(citation.url.scheme == "https", "Insecure link for \(citation.id)")
            #expect(!citation.authors.isEmpty)
            #expect(!citation.title.isEmpty)
            #expect(!citation.publication.isEmpty)
            #expect(citation.reference.contains(citation.title))
        }
    }

    @Test("Every topic states its own limitation alongside the sources")
    func everyTopicStatesItsLimitation() {
        for topic in ScienceTopic.allCases {
            #expect(!topic.limitation.isEmpty, "No limitation stated for \(topic.rawValue)")
            #expect(!topic.summary.isEmpty)
        }
    }

    @Test("Biological age discloses the recording-length mismatch behind its norms")
    func biologicalAgeDisclosesRecordingLengthCaveat() {
        // The HRV norms are 24-hour ECG values; HealthKit supplies short windows.
        // Shaffer & Ginsberg (2017) are explicit that the two are not comparable,
        // so the caveat must stay user-visible.
        let limitation = ScienceTopic.biologicalAge.limitation
        #expect(limitation.localizedCaseInsensitiveContains("24-hour"))
        #expect(limitation.localizedCaseInsensitiveContains("not directly comparable"))
    }
}
