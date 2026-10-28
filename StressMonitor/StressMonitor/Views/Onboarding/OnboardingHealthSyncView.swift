import SwiftUI

// MARK: - Permissions Screen (Screen 1)
// Frictionless: one screen, read-only data types list, privacy-first.
// "Connect Apple Health" CTA triggers HealthKit authorization via the shared VM.
struct OnboardingHealthSyncView: View {
    @State private var viewModel = OnboardingHealthSyncViewModel()
    @State private var appearAnimation = false

    var onAuthorize: (() -> Void)?
    var onBack: (() -> Void)?

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
            .padding(.bottom, 8)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Lock icon
                    Text("🔐")
                        .font(.system(size: 52))
                        .shadow(color: HomeCharacterDesignTokens.Ripple.primary.opacity(0.2), radius: 12)
                        .padding(.top, 32)
                        .padding(.bottom, 16)

                    // Title
                    Text("Connect Apple Health")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: "#E8E8F0"))
                        .multilineTextAlignment(.center)

                    // Subtitle
                    Text("Ripple reads these data types to calculate your stress on your device. Nothing is shared unless you turn on Health Data Sync or use AI coaching.")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(HomeCharacterDesignTokens.mutedInk)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 310)
                        .padding(.top, 8)
                        .padding(.bottom, 20)

                    // Read-only data types list
                    VStack(spacing: 8) {
                        PermissionDataTypeRow(
                            emoji: "📈",
                            iconBgColor: Color(hex: "#7986CB").opacity(0.1),
                            title: "Heart Rate Variability",
                            subtitle: "Primary stress indicator"
                        )

                        PermissionDataTypeRow(
                            emoji: "❤️",
                            iconBgColor: Color(hex: "#EF5350").opacity(0.1),
                            title: "Heart Rate",
                            subtitle: "Resting & active BPM"
                        )

                        PermissionDataTypeRow(
                            emoji: "😴",
                            iconBgColor: HomeCharacterDesignTokens.Ripple.primary.opacity(0.1),
                            title: "Sleep Analysis",
                            subtitle: "Recovery quality tracking"
                        )

                        PermissionDataTypeRow(
                            emoji: "👟",
                            iconBgColor: HomeCharacterDesignTokens.Blossom.primary.opacity(0.1),
                            title: "Steps",
                            subtitle: "Activity context for accuracy"
                        )
                    }
                    .padding(.bottom, 16)

                    // ON-DEVICE privacy pill
                    onDevicePill
                        .padding(.bottom, 20)
                }
            }

            // Authorize CTA — pinned to bottom
            Button(action: { Task { await authorizeAndContinue() } }) {
                HStack(spacing: 8) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "heart.text.square.fill")
                            .font(.system(size: 17, weight: .bold))
                        Text("Connect Apple Health")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    LinearGradient(
                        colors: [HomeCharacterDesignTokens.Ripple.primary, HomeCharacterDesignTokens.Ripple.deep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: HomeCharacterDesignTokens.Ripple.primary.opacity(0.28), radius: 12, y: 6)
            }
            .disabled(viewModel.isLoading)
            .padding(.bottom, 48)
        }
        .padding(.horizontal, 28)
        .background(HomeCharacterDesignTokens.darkCanvas)
        .alert("Authorization Error", isPresented: .constant(viewModel.authorizationError != nil)) {
            Button("OK") {
                viewModel.authorizationError = nil
            }
        } message: {
            if let error = viewModel.authorizationError {
                Text(error)
            }
        }
    }

    // MARK: - ON-DEVICE privacy pill

    private var onDevicePill: some View {
        HStack(spacing: 6) {
            Image(systemName: "iphone.gen3")
                .font(.system(size: 11, weight: .bold))
            Text("ON-DEVICE")
                .font(.system(size: 11, weight: .heavy))
                .kerning(0.8)
        }
        .foregroundStyle(HomeCharacterDesignTokens.Ripple.primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(HomeCharacterDesignTokens.Ripple.primary.opacity(0.1))
                .overlay(
                    Capsule()
                        .stroke(HomeCharacterDesignTokens.Ripple.primary.opacity(0.25), lineWidth: 1)
                )
        )
    }

    // MARK: - Actions

    /// Triggers HealthKit authorization via the shared service, then advances on success.
    private func authorizeAndContinue() async {
        await viewModel.requestSelectedPermissions()
        if viewModel.healthKitAuthorized {
            onAuthorize?()
        }
    }
}

// MARK: - Permission Data Type Row (read-only)

private struct PermissionDataTypeRow: View {
    let emoji: String
    let iconBgColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            Text(emoji)
                .font(.system(size: 20))
                .frame(width: 40, height: 40)
                .background(iconBgColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: "#E8E8F0"))
                Text(subtitle)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(HomeCharacterDesignTokens.mutedInk)
            }

            Spacer()

            // Read-only badge
            Image(systemName: AppIconSystem.System.success.sfSymbol)
                .font(.system(size: 16))
                .foregroundStyle(HomeCharacterDesignTokens.Ripple.primary.opacity(0.7))
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(HomeCharacterDesignTokens.darkCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
    }
}

#Preview {
    OnboardingHealthSyncView()
}
