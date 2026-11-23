import SwiftUI

/// Loading placeholder block (UI V2). Wraps `V2Skeleton`, which pulses its
/// opacity and stays static under Reduce Motion.
struct SkeletonBlock: View {
    var height: CGFloat = 60

    var body: some View {
        V2Skeleton(
            height: height,
            cornerRadius: height < 40 ? V2Metrics.radiusXS : V2Metrics.radiusLG
        )
        .frame(maxWidth: .infinity)
    }
}
