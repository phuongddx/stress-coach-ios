import SwiftUI

/// Compact circular stress indicator (UI V2): the shared 240° gauge with the
/// score in the centre and the tier as colour + shape + name.
struct CompactStressView: View {
    let stressLevel: Double
    var category: StressCategory { StressCategory.category(for: stressLevel) }
    var size: CGFloat = 120
    var showsScore: Bool = true
    var showsLabel: Bool = true

    var body: some View {
        WatchStressGauge(score: stressLevel, lineWidth: max(4, size * 0.08)) {
            VStack(spacing: 2) {
                if showsScore {
                    Text("\(Int(stressLevel))")
                        .font(.v2Number(.title3, weight: .bold))
                        .foregroundStyle(WatchV2.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                if showsLabel {
                    WatchTierBadge(category: category, font: .caption2.weight(.semibold))
                }
            }
        }
        .frame(width: size, height: size)
    }
}

#if DEBUG
#Preview {
    HStack(spacing: 12) {
        CompactStressView(stressLevel: 18, size: 80)
        CompactStressView(stressLevel: 42, size: 80)
        CompactStressView(stressLevel: 78, size: 80)
    }
    .padding()
    .background(WatchDesignTokens.canvas)
}
#endif
