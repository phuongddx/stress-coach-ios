import SwiftUI

/// Completion screen shown when the Mini Walk finishes.
///
/// - Tired-happy Ripple (mood = .tired) with rosy cheeks and sweat drop
/// - Headline: "Nice walk!" + companion message
/// - 3-stat grid: Steps, Minutes, kcal
/// - Buttons: Done + View Full Trends
struct MiniWalkCompleteView: View {
    let viewModel: MiniWalkViewModel
    var onDone: () -> Void
    var onTrends: () -> Void

    init(viewModel: MiniWalkViewModel, onDone: @escaping () -> Void, onTrends: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onDone = onDone
        self.onTrends = onTrends
    }

    var body: some View {
        ZStack {
            HomeCharacterDesignTokens.darkCanvas.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Tired-happy Ripple
                    StressBuddyIllustration(mood: .tired, size: 100)
                        .padding(.top, 20)

                    // Headline
                    VStack(spacing: 6) {
                        Text("Nice walk! \u{1F6B6}")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: "#E0E0E8"))
                        Text("Ripple enjoyed every step with you!")
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundStyle(Color(hex: "#9CA3AF"))
                    }

                    // 3-stat grid
                    HStack(spacing: 12) {
                        CompletionStat(value: viewModel.stepDisplay, label: "Steps", icon: "figure.walk")
                        CompletionStat(value: "\(viewModel.elapsedMinutes)", label: "Minutes", icon: "clock")
                        CompletionStat(value: viewModel.calorieDisplay, label: "kcal (est.)", icon: "flame.fill")
                    }
                    .padding(.horizontal, 16)

                    Spacer(minLength: 16)

                    // Buttons
                    VStack(spacing: 12) {
                        Button(action: onDone) {
                            Text("Done")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    HomeCharacterDesignTokens.Ripple.primary,
                                                    HomeCharacterDesignTokens.Ripple.deep
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                )
                                .shadow(color: HomeCharacterDesignTokens.Ripple.primary.opacity(0.3), radius: 8, y: 4)
                        }

                        Button(action: onTrends) {
                            Text("View Full Trends")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color(hex: "#9CA3AF"))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(HomeCharacterDesignTokens.darkCard)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                                        )
                                )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

// MARK: - Completion Stat Cell

private struct CompletionStat: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(HomeCharacterDesignTokens.Ripple.primary)
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "#E0E0E8"))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color(hex: "#9CA3AF"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(HomeCharacterDesignTokens.darkCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

#Preview {
    MiniWalkCompleteView(
        viewModel: MiniWalkViewModel(),
        onDone: {},
        onTrends: {}
    )
}
