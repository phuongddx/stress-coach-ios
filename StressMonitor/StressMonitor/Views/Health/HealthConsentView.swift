import SwiftUI

/// Consent sheet for health-data syncing: explains what leaves the device
/// (daily averages only, never raw samples) and records the grant via
/// `PUT /health/consent` before the first upload. The server row is the
/// consent authority — "Allow" only persists after the PUT succeeds.
///
/// UI V2 layout: icon tile, title, explanation, a "Synced / Never synced"
/// group, a footnote, an inline error card, then Allow / Not now.
/// Spec reference: ui-v2-design/screens.js `S.consent`.
struct HealthConsentView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var working = false
    @State private var failed = false
    var onDecision: (Bool) -> Void = { _ in }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(.title, design: .rounded).weight(.semibold))
                    .foregroundStyle(StressCategory.relaxed.onFillColor)
                    .frame(width: 56, height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: V2Metrics.radiusMD, style: .continuous)
                            .fill(StressCategory.relaxed.fillColor)
                    )
                    .accessibilityHidden(true)

                Text("Sync Health Data?")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.V2.ink)
                    .accessibilityAddTraits(.isHeader)

                Text("Upload a daily summary of your heart-rate variability, average heart rate, and resting heart rate so your coach can track stress over time.")
                    .font(.callout)
                    .foregroundStyle(Color.V2.ink2)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 0) {
                    consentRow(
                        systemImage: "checkmark",
                        title: "Synced",
                        detail: "Daily averages of HRV, average heart rate and resting heart rate",
                        foreground: StressCategory.relaxed.onFillColor,
                        background: StressCategory.relaxed.fillColor
                    )
                    Rectangle()
                        .fill(Color.V2.line)
                        .frame(height: 0.5)
                        .padding(.leading, 60)
                    consentRow(
                        systemImage: "xmark",
                        title: "Never synced",
                        detail: "Raw heart-rate, HRV and sleep samples",
                        foreground: Color.V2.ink2,
                        background: Color.V2.surface3
                    )
                }
                .v2CardBackground()

                Text("Only daily averages leave your device. You can turn this off anytime in Settings.")
                    .font(.footnote)
                    .foregroundStyle(Color.V2.ink3)
                    .fixedSize(horizontal: false, vertical: true)

                if failed {
                    V2ErrorCard(
                        title: "Couldn't reach the server",
                        message: "Your choice wasn't saved. Try again later."
                    )
                }

                VStack(spacing: 8) {
                    Button {
                        working = true
                        Task {
                            do {
                                try await StressAPIClient().setHealthConsent(true)
                                HealthSyncService.shared.markConsentGranted()
                                // Consent just landed server-side — run the
                                // pending upload now instead of waiting for the
                                // next background→foreground transition.
                                Task { await HealthSyncService.shared.syncYesterdayIfNeeded() }
                                onDecision(true)
                                dismiss()
                            } catch {
                                failed = true
                                working = false
                            }
                        }
                    } label: {
                        if working {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .tint(Color.V2.onAccent)
                                Text("Saving…")
                            }
                        } else {
                            Text("Allow")
                        }
                    }
                    .buttonStyle(.v2(.primary))
                    .disabled(working)

                    Button("Not Now") { onDecision(false); dismiss() }
                        .buttonStyle(.v2(.ghost))
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 24)
        }
        .background(Color.V2.bg.ignoresSafeArea())
    }

    private func consentRow(
        systemImage: String,
        title: String,
        detail: String,
        foreground: Color,
        background: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(foreground)
                .frame(width: 32, height: 32)
                .background(Circle().fill(background))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.V2.ink)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Color.V2.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, V2Metrics.margin)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Consent") {
    HealthConsentView()
}
