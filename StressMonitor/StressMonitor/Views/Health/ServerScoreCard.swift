import SwiftUI

/// Server-computed daily stress score (GET /stress/scores) shown on the
/// dashboard right below the local on-device reading. Fetches once per
/// appearance and renders the newest row only; stays graceful while the
/// endpoint is empty or unreachable.
struct ServerScoreCard: View {
    @State private var score: ServerStressScore?
    @State private var failed = false
    @State private var loading = true

    /// Server levels mapped onto the V2 tier text colours.
    private var levelColor: Color {
        switch score?.level {
        case "low": return StressCategory.relaxed.color
        case "moderate": return StressCategory.moderate.color
        case "high": return StressCategory.high.color
        default: return Color.V2.ink2
        }
    }

    var body: some View {
        V2Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Coach Score")
                        .font(.headline)
                        .foregroundStyle(Color.V2.ink)
                    Spacer()
                    if loading { ProgressView() }
                }
                if let score {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("\(score.score)")
                            .font(.v2Number(.largeTitle, weight: .bold))
                            .foregroundStyle(Color.V2.ink)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(score.level.capitalized)
                                .font(.headline)
                                .foregroundStyle(levelColor)
                            Text(score.localDate)
                                .font(.caption)
                                .foregroundStyle(Color.V2.ink3)
                        }
                    }
                    if !score.factors.isEmpty {
                        ForEach(score.factors, id: \.self) { factor in
                            Label(factor, systemImage: "circle.fill")
                                .font(.footnote)
                                .foregroundStyle(Color.V2.ink2)
                        }
                    }
                } else if failed {
                    Text("Server score unavailable.")
                        .font(.footnote)
                        .foregroundStyle(Color.V2.ink2)
                } else if !loading {
                    Text("No server score yet — sync starts after you allow health data.")
                        .font(.footnote)
                        .foregroundStyle(Color.V2.ink2)
                }
            }
        }
        .task {
            do {
                score = try await StressAPIClient().fetchStressScores().first
            } catch {
                failed = true
            }
            loading = false
        }
    }
}
