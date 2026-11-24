import SwiftData
import SwiftUI

// MARK: - Dashboard Preview Screen (Screen 2)
// Ready state: check mark, when the first score arrives, the buddy card, a
// tip and "Start tracking". No reading is shown here — the first real one
// appears on the dashboard once Apple Health has data. UI V2 `S.onbSuccess`.
struct OnboardingSuccessView: View {
    @State private var viewModel: OnboardingSuccessViewModel

    var onGoToDashboard: (() -> Void)?
    var onBack: (() -> Void)?
    var onSelectStep: ((Int) -> Void)?

    init(
        repository: StressRepositoryProtocol,
        onGoToDashboard: (() -> Void)? = nil,
        onBack: (() -> Void)? = nil,
        onSelectStep: ((Int) -> Void)? = nil
    ) {
        _viewModel = State(initialValue: OnboardingSuccessViewModel(repository: repository))
        self.onGoToDashboard = onGoToDashboard
        self.onBack = onBack
        self.onSelectStep = onSelectStep
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                OnboardingBackButton { onBack?() }
                Spacer()
            }
            .frame(minHeight: V2Metrics.minTouchTarget)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark")
                            .font(.title.weight(.bold))
                            .foregroundStyle(StressCategory.relaxed.color)
                            .frame(width: 64, height: 64)
                            .background(Circle().fill(StressCategory.relaxed.fillColor.opacity(0.18)))
                            .accessibilityHidden(true)

                        Text("You're all set")
                            .font(.title.weight(.bold))
                            .foregroundStyle(Color.V2.ink)
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)

                        Text("Your first score appears once your Apple Watch records HRV, usually overnight or during a quiet moment.")
                            .font(.callout)
                            .foregroundStyle(Color.V2.ink2)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 12)
                    }
                    .padding(.top, 12)

                    buddyCard
                        .padding(.top, 24)

                    tipCard
                        .padding(.top, 12)
                }
                .padding(.bottom, 16)
            }

            VStack(spacing: 0) {
                OnboardingStepDots(current: 2, onSelect: onSelectStep)

                Button("Start tracking") {
                    viewModel.completeOnboarding()
                    onGoToDashboard?()
                }
                .buttonStyle(.v2(.primary))
                .padding(.bottom, 24)
            }
        }
        .padding(.horizontal, V2Metrics.margin)
        .background(Color.V2.bg.ignoresSafeArea())
    }

    // MARK: - Buddy Card

    private var buddyCard: some View {
        V2Card {
            HStack(spacing: 14) {
                StressBuddyIllustration(mood: .celebrating, size: 60)
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(Color.V2.Companion.ripple.opacity(0.18)))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Ripple")
                        .font(.headline)
                        .foregroundStyle(Color.V2.ink)
                    Text("Water Otter · your companion")
                        .font(.footnote)
                        .foregroundStyle(Color.V2.ink2)
                    Text("Grows as you keep a streak: Droplet → Ripple → Tidal.")
                        .font(.footnote)
                        .foregroundStyle(Color.V2.ink)
                        .padding(.top, 4)
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Tip Card

    private var tipCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.V2.accent)
                .accessibilityHidden(true)

            Text("\(Text("Tip").fontWeight(.semibold)) · Wear your watch to bed. Sleep and overnight HRV make your score more accurate.")
                .font(.subheadline)
                .foregroundStyle(Color.V2.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .v2CardBackground(.flat)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let repository = StressRepository(
        modelContext: ModelContext((try? ModelContainer(for: StressMeasurement.self))!),
        baselineCalculator: BaselineCalculator()
    )
    OnboardingSuccessView(repository: repository)
}
