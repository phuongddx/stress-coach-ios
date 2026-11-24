import SwiftUI
import HealthKit

/// Card component for HealthKit permission denied/required state.
/// Provides CTAs to grant access (system prompt) or open Settings (deep link).
struct PermissionCardView: View {
    let permissionType: PermissionType
    var isLoading: Bool = false
    var embedded: Bool = false
    let onGrantAccess: () -> Void

    @Environment(\.openURL) private var openURL

    enum PermissionType: String {
        case healthKit
        case heartRate
        case hrv

        var icon: String {
            switch self {
            case .healthKit: return "heart.text.square.fill"
            case .heartRate: return "waveform.path.ecg"
            case .hrv: return "heart.circle.fill"
            }
        }

        var title: String {
            switch self {
            case .healthKit: return "Connect Apple Health to see your score"
            case .heartRate: return "Heart Rate Access Needed"
            case .hrv: return "HRV Access Needed"
            }
        }

        var description: String {
            switch self {
            case .healthKit:
                return "Your score is built from HRV, heart rate, sleep, activity and recovery. StressMonitor only reads your health data, and nothing leaves your iPhone without your consent."
            case .heartRate:
                return "Heart rate data is essential for accurate stress calculation. Grant access to enable monitoring."
            case .hrv:
                return "Heart Rate Variability is the primary indicator for stress levels. Allow access to continue."
            }
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Labelled by the pose ("Ripple, asleep").
            StressBuddyIllustration(mood: .tired, size: 72, pose: .sleeping)
                .frame(width: 72, height: 72)

            Text(permissionType.title)
                .font(.headline)
                .foregroundStyle(Color.V2.ink)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text(permissionType.description)
                .font(.subheadline)
                .foregroundStyle(Color.V2.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
                Button(action: onGrantAccess) {
                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView()
                                .tint(Color.V2.onAccent)
                        }
                        Text("Grant Access to Health")
                    }
                }
                .buttonStyle(.v2(.primary))
                .disabled(isLoading)
                .accessibilityLabel("Grant access to Health data")

                Button("Open Settings", action: openSettings)
                    .buttonStyle(.v2(.ghost))
                    .accessibilityLabel("Open device Settings")
            }
            .padding(.top, 8)
        }
        .padding(embedded ? 0 : 20)
        .frame(maxWidth: .infinity)
        .background {
            if !embedded {
                Color.clear.v2CardBackground()
            }
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }
}

// MARK: - Preview

#Preview("Permission Card - Default") {
    ZStack {
        Color.V2.bg.ignoresSafeArea()

        VStack(spacing: 20) {
            PermissionCardView(
                permissionType: .healthKit,
                onGrantAccess: {}
            )

            PermissionCardView(
                permissionType: .heartRate,
                onGrantAccess: {}
            )
        }
        .padding()
    }
}

#Preview("Permission Card - Loading") {
    ZStack {
        Color.V2.bg.ignoresSafeArea()

        PermissionCardView(
            permissionType: .healthKit,
            isLoading: true,
            onGrantAccess: {}
        )
        .padding()
    }
}
