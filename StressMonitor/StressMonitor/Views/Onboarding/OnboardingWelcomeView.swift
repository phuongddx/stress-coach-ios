import SwiftUI

// MARK: - Welcome Screen (Screen 0)
// Meet Ripple, learn what the score is, then continue to Apple Health.
// UI V2 `S.onbWelcome`: token colours in light and dark, no breathing rings.
struct OnboardingWelcomeView: View {
    @State private var viewModel = OnboardingWelcomeViewModel()
    @State private var appearAnimation = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var onGetStarted: (() -> Void)?
    var onSelectStep: ((Int) -> Void)?

    private var motionAllowed: Bool {
        WellnessMotion.isMotionAllowed(reduceMotionEnvironment: reduceMotion)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    welcomeHero
                        .padding(.top, 16)
                        .padding(.bottom, 8)

                    Text("Meet Ripple, your calm companion")
                        .font(.title.weight(.bold))
                        .foregroundStyle(Color.V2.ink)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    Text("A stress score from 0 to 100, worked out on your iPhone from heart rate variability and four other signals in Apple Health.")
                        .font(.callout)
                        .foregroundStyle(Color.V2.ink2)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 8)
                        .padding(.top, 8)
                        .padding(.bottom, 20)

                    valueProps
                }
                .opacity(appearAnimation ? 1 : 0)
                .padding(.bottom, 16)
            }

            VStack(spacing: 0) {
                OnboardingStepDots(current: 0, onSelect: onSelectStep)

                Button("Get started") { onGetStarted?() }
                    .buttonStyle(.v2(.primary))

                Text("Wellness app, not a medical device.")
                    .font(.caption)
                    .foregroundStyle(Color.V2.ink3)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
            }
        }
        .padding(.horizontal, V2Metrics.margin)
        .background(Color.V2.bg.ignoresSafeArea())
        .onAppear {
            if motionAllowed {
                withAnimation(.easeOut(duration: 0.6)) { appearAnimation = true }
            } else {
                appearAnimation = true
            }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Text("Stress AI Coach")
                .v2Eyebrow()
            Spacer()
            Button("Sign in") { viewModel.handleSignIn() }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.V2.accent)
                .frame(minWidth: V2Metrics.minTouchTarget, minHeight: V2Metrics.minTouchTarget)
        }
        .frame(minHeight: V2Metrics.minTouchTarget)
    }

    // MARK: - Hero

    private var welcomeHero: some View {
        StressBuddyIllustration(mood: .happy, size: 124, pose: .mild)
            // Gentle float from the view model's loop; still under Reduce Motion.
            .offset(y: motionAllowed && viewModel.floatOffset ? -6 : 0)
            .frame(width: 168, height: 168)
            .background(Circle().fill(Color.V2.accentSoft))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Ripple the Water Otter")
    }

    // MARK: - Value props

    private var valueProps: some View {
        V2Card {
            VStack(alignment: .leading, spacing: 14) {
                OnboardingInfoRow(
                    systemImage: "waveform.path.ecg",
                    title: "A score you can trust",
                    subtitle: "HRV, heart rate, sleep, activity and recovery, with a confidence level."
                )
                OnboardingInfoRow(
                    systemImage: "wind",
                    title: "Calm in minutes",
                    subtitle: "Box breathing and mini walks when tension builds."
                )
                OnboardingInfoRow(
                    systemImage: "chart.xyaxis.line",
                    title: "See your patterns",
                    subtitle: "Weekly trends and what moves your score."
                )
            }
        }
    }
}

#Preview {
    OnboardingWelcomeView()
}
