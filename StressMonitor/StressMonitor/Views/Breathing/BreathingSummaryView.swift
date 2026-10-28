import SwiftUI

/// Post-session summary screen — redesigned per `14-breathing-summary.html`.
///
/// Light surface with:
/// - Complete checkmark badge + hero text
/// - 2-card stat grid (HRV before / HRV after with delta) and the HRV
///   across-session chart, shown only when HealthKit returned both samples
/// - 2-tile effect row (cycles / duration)
/// - Ripple serene note card
/// - CTA: Back to Home
struct BreathingSummaryView: View {
    let result: BreathingSessionResult
    @Environment(\.dismiss) private var dismiss
    /// Sheet, not a push: this screen hides its back button and owns its own
    /// dismissal, so it must not append to a navigation path it does not own.
    @State private var showsSources = false

    // Design tokens from app.css
    private let accent = Color(hex: "#4FC3F7")
    private let accentStrong = Color(hex: "#0288D1")
    private let surface = Color.white
    private let fg = Color(hex: "#101223")
    private let fgSecondary = Color(hex: "#3C3C43")
    private let muted = Color(hex: "#777986")
    private let separator = Color(red: 60/255, green: 60/255, blue: 67/255).opacity(0.12)
    private let success = Color(hex: "#34C759")
    private let hrvColor = Color(hex: "#34D399")
    private let warn = Color(hex: "#FF9500")

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Complete mark + hero
                completeMark
                summaryHero

                if let before = result.preSessionHRV, let after = result.postSessionHRV {
                    statGrid(before: before, after: after)

                    BeforeAfterHRVChart(before: before, after: after)
                        .padding(16)
                        .overlay(alignment: .topTrailing) {
                            ScienceInfoButton(topic: .breathing) { _ in
                                showsSources = true
                            }
                            .padding(.trailing, 10)
                            .padding(.top, 6)
                        }
                        .background(RoundedRectangle(cornerRadius: 18).fill(surface))
                        .padding(.horizontal, 24)
                }

                // Effect tiles
                effectRow

                // Ripple note
                rippleNote

                // CTAs
                ctaRow
                    .padding(.top, 4)
            }
            .padding(.vertical, 16)
        }
        .background(Color(hex: "#F2F2F7"))
        .onAppear { HapticManager.shared.success() }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: AppIconSystem.Nav.back.sfSymbol)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(accentStrong)
                }
            }
            ToolbarItem(placement: .principal) {
                Text("Session Complete")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(fg)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { shareResult() }) {
                    Text("Share")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(accentStrong)
                }
            }
        }
        .sheet(isPresented: $showsSources) {
            NavigationStack {
                ScienceSourcesView(focusedTopic: .breathing)
            }
        }
    }

    // MARK: - Complete Mark

    private var completeMark: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [accent, success], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 80, height: 80)
                .shadow(color: success.opacity(0.4), radius: 12, x: 0, y: 6)
            Image(systemName: "checkmark")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.top, 12)
    }

    // MARK: - Summary Hero

    private var summaryHero: some View {
        VStack(spacing: 6) {
            Text("Beautifully done.")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .tracking(-0.02 * 28)
                .foregroundStyle(fg)
            Text(heroDetail)
                .font(.system(size: 15))
                .foregroundStyle(fgSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var heroDetail: String {
        let cycles = result.cyclesCompleted == 1 ? "1 breathing cycle" : "\(result.cyclesCompleted) breathing cycles"
        guard let improvement = result.improvement, improvement > 0 else {
            return "You completed \(cycles)."
        }
        return "You completed \(cycles). Your HRV rose during the session."
    }

    /// Signed change, e.g. "+12 ms · +23%" or "-4 ms · -6%".
    private var hrvDeltaText: String? {
        guard let improvement = result.improvement else { return nil }
        let delta = String(format: "%+d ms", Int(improvement.rounded()))
        guard let percent = result.percentageImprovement else { return delta }
        return delta + String(format: " · %+d%%", Int(percent.rounded()))
    }

    // MARK: - Stat Grid (Before / After)

    private func statGrid(before: Double, after: Double) -> some View {
        HStack(spacing: 8) {
            // Before card
            VStack(alignment: .leading, spacing: 4) {
                Text("HRV BEFORE")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(muted)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(Int(before))")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(hrvColor)
                    Text("ms")
                        .font(.system(size: 13))
                        .foregroundStyle(muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(surface))

            // After card
            VStack(alignment: .leading, spacing: 4) {
                Text("HRV AFTER")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(muted)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(Int(after))")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(success)
                    Text("ms")
                        .font(.system(size: 13))
                        .foregroundStyle(muted)
                }
                if let hrvDeltaText {
                    Text(hrvDeltaText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(after >= before ? success : warn)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(surface))
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Effect Row

    private var effectRow: some View {
        HStack(spacing: 8) {
            effectTile(
                value: "\(result.cyclesCompleted)",
                suffix: nil,
                label: "Cycles",
                color: accentStrong
            )
            effectTile(
                value: durationLabel,
                suffix: nil,
                label: "Duration",
                color: success
            )
        }
        .padding(.horizontal, 24)
    }

    private func effectTile(value: String, suffix: String?, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                if let suffix {
                    Text(suffix)
                        .font(.system(size: 13))
                        .foregroundStyle(muted)
                }
            }
            Text(label.uppercased())
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14).fill(surface))
    }

    private var durationLabel: String {
        let mins = Int(result.duration) / 60
        let secs = Int(result.duration) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    // MARK: - Ripple Note

    private var rippleNote: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.14))
                    .frame(width: 36, height: 36)
                StressBuddyIllustration(mood: .serene, size: 28)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 0) {
                Text("Ripple says: ")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(accentStrong)
                + Text("Nice work taking a few minutes for yourself. Come back whenever you need a reset.")
                    .font(.system(size: 13))
                    .foregroundStyle(fgSecondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.10), Color(red: 165/255, green: 214/255, blue: 167/255).opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(separator, lineWidth: 1))
        )
        .padding(.horizontal, 24)
        .accessibilityElement(children: .combine)
    }

    // MARK: - CTAs

    private var ctaRow: some View {
        Button(action: { dismiss() }) {
            Text("Back to Home")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(RoundedRectangle(cornerRadius: 14).fill(accent))
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Share

    private func shareResult() {
        var text = """
        Breathing Session Complete 🧘

        Duration: \(Int(result.duration / 60)) minutes
        Cycles: \(result.cyclesCompleted)
        """
        if let hrvDeltaText {
            text += "\n\nHRV change: \(hrvDeltaText)"
        }

        let activityVC = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}
