import SwiftUI

// MARK: - Permissions Screen (Screen 1)
// Says what each Health type is for before the iOS sheet appears, then
// "Continue" triggers HealthKit authorization via the shared VM.
// UI V2 `S.onbHealth`.
struct OnboardingHealthSyncView: View {
    @State private var viewModel = OnboardingHealthSyncViewModel()

    var onAuthorize: (() -> Void)?
    var onBack: (() -> Void)?
    var onSelectStep: ((Int) -> Void)?

    /// What `HealthKitManager.requestAuthorization()` reads, grouped the way
    /// the iOS sheet lists them, each with the reason the app needs it.
    private static let dataTypes: [(icon: String, title: String, purpose: String)] = [
        ("waveform.path.ecg", "Heart rate variability", "The main signal in your score"),
        ("heart", "Heart rate & resting heart rate", "How hard your body is working"),
        ("bed.double", "Sleep", "How well you recovered"),
        ("figure.walk", "Steps, activity & workouts", "Movement lowers stress"),
        ("lungs", "Breathing, blood oxygen, water & daylight", "Extra context for recovery and daily habits"),
        ("calendar", "Date of birth", "Your biological age estimate"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                OnboardingBackButton { onBack?() }
                Spacer()
            }
            .frame(minHeight: V2Metrics.minTouchTarget)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Image(systemName: "heart.fill")
                        .font(.title.weight(.semibold))
                        .foregroundStyle(Color.V2.onAccent)
                        .frame(width: 56, height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: V2Metrics.radiusMD, style: .continuous)
                                .fill(Color.V2.accent)
                        )
                        .accessibilityHidden(true)

                    Text("Connect Apple Health")
                        .font(.title.weight(.bold))
                        .foregroundStyle(Color.V2.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 16)
                        .accessibilityAddTraits(.isHeader)

                    Text("Next, iOS asks which data Stress AI Coach can read. Here is what each one is for.")
                        .font(.callout)
                        .foregroundStyle(Color.V2.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                        .padding(.bottom, 16)

                    dataTypeList

                    privacyNote
                        .padding(.top, 12)
                }
                .padding(.bottom, 16)
            }

            VStack(spacing: 0) {
                OnboardingStepDots(current: 1, onSelect: onSelectStep)

                Button(action: { Task { await authorizeAndContinue() } }) {
                    HStack(spacing: 8) {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(Color.V2.onAccent)
                            Text("Waiting for iOS…")
                        } else {
                            Text("Continue")
                        }
                    }
                }
                .buttonStyle(.v2(.primary))
                .disabled(viewModel.isLoading)
                .padding(.bottom, 24)
            }
        }
        .padding(.horizontal, V2Metrics.margin)
        .background(Color.V2.bg.ignoresSafeArea())
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

    // MARK: - Data types

    private var dataTypeList: some View {
        VStack(spacing: 0) {
            ForEach(Array(Self.dataTypes.enumerated()), id: \.offset) { index, item in
                OnboardingInfoRow(systemImage: item.icon, title: item.title, subtitle: item.purpose)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                if index < Self.dataTypes.count - 1 {
                    Rectangle()
                        .fill(Color.V2.line)
                        .frame(height: 0.5)
                        .padding(.leading, 58)
                }
            }
        }
        .v2CardBackground(.standard)
    }

    // MARK: - Privacy note

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.shield")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.V2.accent)
                .accessibilityHidden(true)

            Text("\(Text("Scored on your iPhone.").fontWeight(.semibold).foregroundStyle(Color.V2.ink)) Ripple only sees your scores, never raw health data. You can revoke access in Settings.")
                .font(.footnote)
                .foregroundStyle(Color.V2.ink2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .v2CardBackground(.flat)
        .accessibilityElement(children: .combine)
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

#Preview {
    OnboardingHealthSyncView()
}
