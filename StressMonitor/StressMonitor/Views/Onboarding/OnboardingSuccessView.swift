import SwiftData
import SwiftUI

// MARK: - Dashboard Preview Screen (Screen 2)
// Immediate value: ring progress + metrics + buddy card + tip + "Go to Dashboard" CTA.
struct OnboardingSuccessView: View {
    @State private var viewModel: OnboardingSuccessViewModel
    @State private var ringProgress: CGFloat = 0
    @State private var appearAnimation = false

    var onGoToDashboard: (() -> Void)?
    var onBack: (() -> Void)?

    init(repository: StressRepositoryProtocol, onGoToDashboard: (() -> Void)? = nil, onBack: (() -> Void)? = nil) {
        _viewModel = State(initialValue: OnboardingSuccessViewModel(repository: repository))
        self.onGoToDashboard = onGoToDashboard
        self.onBack = onBack
    }

    var body: some View {
        VStack(spacing: 0) {
            // Back button
            HStack {
                Button(action: { onBack?() }) {
                    HStack(spacing: 4) {
                        Image(systemName: AppIconSystem.Nav.back.sfSymbol)
                            .font(.system(size: 14, weight: .medium))
                        Text("Back")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(HomeCharacterDesignTokens.mutedInk)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
                Spacer()
            }
            .padding(.top, 20)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Measurement Ring with Ripple creature
                    measurementRing
                        .padding(.top, 16)
                        .padding(.bottom, 24)

                    // Title
                    Text("Your first reading is ready")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: "#E8E8F0"))
                        .multilineTextAlignment(.center)

                    Text("Ripple already sees your calm patterns. Here's your snapshot:")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(HomeCharacterDesignTokens.mutedInk)
                        .multilineTextAlignment(.center)
                        .padding(.top, 6)
                        .padding(.bottom, 16)

                    // Free trial banner
                    if PurchaseAvailability.isEnabled {
                        freeTrialBanner
                            .padding(.bottom, 16)
                    }

                    // Metric boxes row
                    metricsRow
                        .padding(.bottom, 16)

                    // Buddy card
                    buddyCard
                        .padding(.bottom, 16)

                    // Tip box
                    tipBox
                        .padding(.bottom, 20)
                }
            }

            // Start Tracking CTA — pinned bottom
            Button(action: {
                viewModel.completeOnboarding()
                onGoToDashboard?()
            }) {
                HStack(spacing: 8) {
                    Text("Start Tracking")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    LinearGradient(
                        colors: [HomeCharacterDesignTokens.Ripple.primary, HomeCharacterDesignTokens.Blossom.primary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: HomeCharacterDesignTokens.Ripple.primary.opacity(0.2), radius: 12, y: 6)
            }
            .padding(.bottom, 48)
        }
        .padding(.horizontal, 28)
        .background(HomeCharacterDesignTokens.darkCanvas)
        .onAppear {
            // Animate ring progress after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeInOut(duration: 1.5)) {
                    ringProgress = 0.72 // ~28/100 stress = 72% calm
                }
            }
        }
    }

    // MARK: - Free Trial Banner

    private var freeTrialBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(HomeCharacterDesignTokens.Blossom.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text("7-day free trial included")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(hex: "#E8E8F0"))
                Text("No charge until your trial ends. Cancel anytime.")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(HomeCharacterDesignTokens.mutedInk)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(HomeCharacterDesignTokens.Blossom.primary.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(HomeCharacterDesignTokens.Blossom.primary.opacity(0.2), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("7-day free trial included. No charge until your trial ends. Cancel anytime.")
    }

    // MARK: - Measurement Ring

    private var measurementRing: some View {
        ZStack {
            // Background glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            HomeCharacterDesignTokens.Ripple.primary.opacity(0.1),
                            HomeCharacterDesignTokens.Blossom.primary.opacity(0.05),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 100
                    )
                )
                .frame(width: 220, height: 220)

            // Track ring
            Circle()
                .stroke(HomeCharacterDesignTokens.darkCard, lineWidth: 6)
                .frame(width: 220, height: 220)

            // Progress ring
            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(
                    LinearGradient(
                        colors: [HomeCharacterDesignTokens.Ripple.primary, HomeCharacterDesignTokens.Blossom.primary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .frame(width: 220, height: 220)
                .rotationEffect(.degrees(-90))

            // Creature — celebrating mood for the success moment
            StressBuddyIllustration(mood: .celebrating, size: 96)
                .shadow(color: HomeCharacterDesignTokens.Ripple.primary.opacity(0.3), radius: 16)

            // Stress label badge
            VStack {
                Spacer()
                Text("Stress: 28 — Relaxed")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(HomeCharacterDesignTokens.Ripple.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(HomeCharacterDesignTokens.darkCanvas.opacity(0.8))
                            .overlay(
                                Capsule()
                                    .stroke(HomeCharacterDesignTokens.Ripple.primary.opacity(0.15), lineWidth: 1)
                            )
                    )
                    .offset(y: 10)
            }
        }
        .frame(width: 220, height: 220)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Stress measurement ring showing 28 out of 100 — Relaxed")
    }

    // MARK: - Metrics Row

    private var metricsRow: some View {
        HStack(spacing: 10) {
            MetricBox(value: "28", unit: "/ 100", label: "Stress Score", valueColor: HomeCharacterDesignTokens.Ripple.primary)
            MetricBox(value: "62", unit: "ms", label: "HRV", valueColor: HomeCharacterDesignTokens.Blossom.primary)
            MetricBox(value: "68", unit: "bpm", label: "Heart Rate", valueColor: HomeCharacterDesignTokens.Lumi.primary)
        }
    }

    // MARK: - Buddy Card

    private var buddyCard: some View {
        HStack(spacing: 14) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [HomeCharacterDesignTokens.Ripple.primary.opacity(0.2), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 24
                        )
                    )
                    .frame(width: 52, height: 52)
                    .overlay(
                        Circle()
                            .stroke(HomeCharacterDesignTokens.Ripple.primary.opacity(0.15), lineWidth: 2)
                    )
                StressBuddyIllustration(mood: .celebrating, size: 40)
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text("Ripple — Water Otter")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(hex: "#E8E8F0"))

                Text("Gentle, playful, shy · Calm waves today")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(HomeCharacterDesignTokens.mutedInk)

                Text("🌱 Evolution: Droplet → Ripple in 30 days")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(HomeCharacterDesignTokens.Blossom.primary)
                    .padding(.top, 2)
            }

            Spacer()
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(HomeCharacterDesignTokens.darkCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(HomeCharacterDesignTokens.Ripple.primary.opacity(0.1), lineWidth: 1)
                )
        )
    }

    // MARK: - Tip Box

    private var tipBox: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("💡 TODAY'S TIP")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(HomeCharacterDesignTokens.Blossom.primary)
                .kerning(0.5)

            Text("Your stress is low! Try a 3-minute breathing session to keep Ripple's waves calm all day.")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color(hex: "#E8E8F0"))
                .lineSpacing(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(HomeCharacterDesignTokens.Blossom.primary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(HomeCharacterDesignTokens.Blossom.primary.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Metric Box Component

private struct MetricBox: View {
    let value: String
    let unit: String
    let label: String
    let valueColor: Color

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(value)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(valueColor)
                Text(unit)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(HomeCharacterDesignTokens.mutedInk)
            }

            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(HomeCharacterDesignTokens.mutedInk)
                .kerning(0.5)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(HomeCharacterDesignTokens.darkCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

#Preview {
    let repository = StressRepository(
        modelContext: ModelContext((try? ModelContainer(for: StressMeasurement.self))!),
        baselineCalculator: BaselineCalculator()
    )
    OnboardingSuccessView(repository: repository)
}
