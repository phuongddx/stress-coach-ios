import SwiftUI

/// Post-session summary screen — redesigned per `14-breathing-summary.html`.
///
/// Light surface with:
/// - Complete checkmark badge + hero text
/// - 2-card stat grid (HRV before / HRV after with delta)
/// - HRV across-session line chart (BeforeAfterHRVChart)
/// - 3-tile effect row (cycles / duration / in-rhythm)
/// - Streak banner
/// - Ripple serene note card
/// - CTAs: Back to Home + Add a Mini Walk
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
    private let danger = Color(hex: "#FF3B30")
    private let warn = Color(hex: "#FF9500")
    private let gold = Color(hex: "#FE9901")

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Complete mark + hero
                completeMark
                summaryHero

                // Stat grid (before/after)
                statGrid

                // HRV chart card
                BeforeAfterHRVChart(before: result.preSessionHRV, after: result.postSessionHRV)
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

                // Effect tiles
                effectRow

                // Streak banner
                streakBanner

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
            Text("You completed all \(result.cyclesCompleted) cycles without skipping. Your HRV jumped nicely.")
                .font(.system(size: 15))
                .foregroundStyle(fgSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Stat Grid (Before / After)

    private var statGrid: some View {
        HStack(spacing: 8) {
            // Before card
            VStack(alignment: .leading, spacing: 4) {
                Text("HRV BEFORE")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(muted)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(Int(result.preSessionHRV))")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(hrvColor)
                    Text("ms")
                        .font(.system(size: 13))
                        .foregroundStyle(muted)
                }
                Text(beforeTimeLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(fgSecondary)
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
                    Text("\(Int(result.postSessionHRV))")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(success)
                    Text("ms")
                        .font(.system(size: 13))
                        .foregroundStyle(muted)
                }
                Text("+\(Int(result.improvement)) ms · +\(Int(result.percentageImprovement))%")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(success)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(surface))
        }
        .padding(.horizontal, 24)
    }

    private var beforeTimeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: Date())
    }

    // MARK: - Effect Row

    private var effectRow: some View {
        HStack(spacing: 8) {
            effectTile(
                value: "\(result.cyclesCompleted)",
                suffix: "/\(result.cyclesCompleted)",
                label: "Cycles",
                color: accentStrong
            )
            effectTile(
                value: durationLabel,
                suffix: nil,
                label: "Duration",
                color: success
            )
            effectTile(
                value: "95",
                suffix: "%",
                label: "In-rhythm",
                color: gold
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

    // MARK: - Streak Banner

    private var streakBanner: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [warn, danger], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 36, height: 36)
                Image(systemName: AppIconSystem.Metric.streak.sfSymbol)
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("7 day streak")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(warn)
                Text("23 more days to unlock Lumi")
                    .font(.system(size: 12))
                    .foregroundStyle(fgSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [warn.opacity(0.10), danger.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(separator, lineWidth: 1))
        )
        .padding(.horizontal, 24)
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
                + Text("Your HRV is now in the top quartile of your week. You'll likely sleep better tonight — yesterday's pattern matches.")
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
        VStack(spacing: 8) {
            Button(action: { dismiss() }) {
                Text("Back to Home")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(RoundedRectangle(cornerRadius: 14).fill(accent))
            }

            Button(action: { dismiss() }) {
                Text("Add a Mini Walk")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(accentStrong)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(hex: "#FBFBFD"))
                    )
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Share

    private func shareResult() {
        let text = """
        Breathing Session Complete 🧘

        Duration: \(Int(result.duration / 60)) minutes
        Cycles: \(result.cyclesCompleted)

        HRV Improvement: +\(Int(result.improvement))ms (+\(Int(result.percentageImprovement))%)
        """

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
