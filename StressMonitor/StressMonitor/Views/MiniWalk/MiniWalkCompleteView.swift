import SwiftUI

/// Completion overlay shown when the Mini Walk timer runs out (UI V2).
///
/// - Happy Ripple, "Walk complete" and one line of encouragement
/// - Vitals: Time, Steps, kcal (est.)
/// - Done (primary) and See trends (ghost)
///
/// Spec reference: ui-v2-design/screens.js `S.walk` state `complete`.
struct MiniWalkCompleteView: View {
    let viewModel: MiniWalkViewModel
    var onDone: () -> Void
    var onTrends: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(viewModel: MiniWalkViewModel, onDone: @escaping () -> Void, onTrends: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onDone = onDone
        self.onTrends = onTrends
    }

    var body: some View {
        ZStack {
            Color.V2.bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    StressBuddyIllustration(mood: .happy, size: 104)
                        .frame(width: 104, height: 104)
                        .padding(.top, 32)
                        .accessibilityHidden(true)

                    VStack(spacing: 8) {
                        Text("Walk complete")
                            .font(.title.weight(.bold))
                            .foregroundStyle(Color.V2.ink)
                            .accessibilityAddTraits(.isHeader)
                        Text("Fresh air and movement both help bring stress down.")
                            .font(.callout)
                            .foregroundStyle(Color.V2.ink2)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    statsRow
                        .padding(.top, 8)

                    VStack(spacing: 4) {
                        Button(action: onDone) {
                            Text("Done")
                        }
                        .buttonStyle(.v2(.primary))

                        Button(action: onTrends) {
                            Text("See trends")
                        }
                        .buttonStyle(.v2(.ghost, compact: true))
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, V2Metrics.margin)
                .padding(.bottom, 32)
            }
        }
    }

    private var statsRow: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 8))
        return layout {
            WalkVital(icon: "clock", label: "Time", value: "\(viewModel.elapsedMinutes)", unit: "min")
            WalkVital(icon: "figure.walk", label: "Steps", value: viewModel.stepDisplay, unit: nil)
            WalkVital(icon: "flame.fill", label: "kcal (est.)", value: viewModel.calorieDisplay, unit: nil)
        }
    }
}

#Preview {
    MiniWalkCompleteView(
        viewModel: MiniWalkViewModel(),
        onDone: {},
        onTrends: {}
    )
}

#Preview("Dark") {
    MiniWalkCompleteView(
        viewModel: MiniWalkViewModel(),
        onDone: {},
        onTrends: {}
    )
    .preferredColorScheme(.dark)
}
