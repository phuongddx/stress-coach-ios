import SwiftUI

/// Post-session summary screen (UI V2).
///
/// - Happy Ripple, "Nice and steady" and a one-line recap
/// - Vitals: Time and Cycles
/// - HRV before / after with the change, the HRV across-session chart (Plus;
///   the lock lives inside `BeforeAfterHRVChart`) and a "Why HRV changes
///   after breathing" sources row — only when HealthKit returned both
///   samples
/// - Ripple note
/// - Done (primary) and Share (ghost)
///
/// Spec reference: ui-v2-design/screens.js `S.summary`.
struct BreathingSummaryView: View {
    let result: BreathingSessionResult
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Sheet, not a push: this screen hides its back button and owns its own
    /// dismissal, so it must not append to a navigation path it does not own.
    @State private var showsSources = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                hero

                vitalsRow

                if let before = result.preSessionHRV, let after = result.postSessionHRV {
                    statGrid(before: before, after: after)

                    V2Card {
                        BeforeAfterHRVChart(before: before, after: after)
                    }

                    sourcesRow
                }

                rippleNote

                ctaRow
                    .padding(.top, 4)
            }
            .padding(.horizontal, V2Metrics.margin)
            .padding(.vertical, 16)
        }
        .background(Color.V2.bg.ignoresSafeArea())
        .accessibleDynamicType()
        .onAppear { HapticManager.shared.success() }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: AppIconSystem.Nav.back.sfSymbol)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.V2.accent)
                        .frame(minWidth: V2Metrics.minTouchTarget, minHeight: V2Metrics.minTouchTarget)
                }
                .accessibilityLabel("Back")
            }
            ToolbarItem(placement: .principal) {
                Text("Session complete")
                    .font(.headline)
                    .foregroundStyle(Color.V2.ink)
            }
        }
        .sheet(isPresented: $showsSources) {
            NavigationStack {
                ScienceSourcesView(focusedTopic: .breathing)
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 8) {
            StressBuddyIllustration(mood: .happy, size: 96)
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)

            Text("Nice and steady")
                .font(.title.weight(.bold))
                .foregroundStyle(Color.V2.ink)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text(heroDetail)
                .font(.callout)
                .foregroundStyle(Color.V2.ink2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }

    private var heroDetail: String {
        let cycles = result.cyclesCompleted == 1 ? "1 cycle" : "\(result.cyclesCompleted) cycles"
        guard let improvement = result.improvement, improvement > 0 else {
            return "You finished \(cycles) of box breathing."
        }
        return "You finished \(cycles) of box breathing. Your HRV rose during the session."
    }

    /// Signed change, e.g. "+12 ms · +23%" or "-4 ms · -6%".
    private var hrvDeltaText: String? {
        guard let improvement = result.improvement else { return nil }
        let delta = String(format: "%+d ms", Int(improvement.rounded()))
        guard let percent = result.percentageImprovement else { return delta }
        return delta + String(format: " · %+d%%", Int(percent.rounded()))
    }

    // MARK: - Vitals

    private var vitalsRow: some View {
        adaptiveRow {
            SummaryVital(label: "Time", value: durationLabel, unit: nil)
            SummaryVital(label: "Cycles", value: "\(result.cyclesCompleted)", unit: nil)
        }
    }

    private var durationLabel: String {
        let mins = Int(result.duration) / 60
        let secs = Int(result.duration) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    // MARK: - Stat Grid (Before / After)

    private func statGrid(before: Double, after: Double) -> some View {
        adaptiveRow {
            SummaryVital(label: "HRV before", value: "\(Int(before))", unit: "ms")
            SummaryVital(label: "HRV after", value: "\(Int(after))", unit: "ms") {
                if let hrvDeltaText {
                    V2DeltaPill(text: hrvDeltaText, isUp: after >= before, isGood: after >= before)
                }
            }
        }
    }

    /// Side by side, stacked at accessibility sizes.
    @ViewBuilder
    private func adaptiveRow<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 8) { content() }
        } else {
            HStack(alignment: .top, spacing: 8) { content() }
        }
    }

    // MARK: - Sources

    private var sourcesRow: some View {
        Button {
            showsSources = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "info.circle")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.V2.accent)
                    .accessibilityHidden(true)
                Text("Why HRV changes after breathing")
                    .font(.subheadline)
                    .foregroundStyle(Color.V2.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Sources")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.V2.accent)
            }
            .padding(.horizontal, V2Metrics.margin)
            .frame(minHeight: V2Metrics.minTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .v2CardBackground(.flat)
        .accessibilityLabel("Why HRV changes after breathing. Sources")
    }

    // MARK: - Ripple Note

    private var rippleNote: some View {
        V2Card(style: .tint) {
            HStack(alignment: .top, spacing: 12) {
                StressBuddyIllustration(mood: .serene, size: 36)
                    .frame(width: 36, height: 36)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Ripple")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.V2.accent)
                    Text("Nice work taking a few minutes for yourself. Come back whenever you need a reset.")
                        .font(.callout)
                        .foregroundStyle(Color.V2.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - CTAs

    private var ctaRow: some View {
        VStack(spacing: 4) {
            Button(action: { dismiss() }) {
                Text("Done")
            }
            .buttonStyle(.v2(.primary))

            Button(action: { shareResult() }) {
                Text("Share")
            }
            .buttonStyle(.v2(.ghost, compact: true))
        }
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

// MARK: - Vital tile

/// UI V2 `.vit`: a surface card with a footnote label and a number.
private struct SummaryVital<Accessory: View>: View {
    let label: String
    let value: String
    let unit: String?
    let accessory: Accessory

    init(label: String, value: String, unit: String?, @ViewBuilder accessory: () -> Accessory = { EmptyView() }) {
        self.label = label
        self.value = value
        self.unit = unit
        self.accessory = accessory()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.footnote)
                .foregroundStyle(Color.V2.ink3)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.v2Number(.title2, weight: .bold))
                    .foregroundStyle(Color.V2.ink)
                if let unit {
                    Text(unit)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.V2.ink3)
                }
            }
            accessory
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: V2Metrics.radiusMD, style: .continuous)
                .fill(Color.V2.surface)
        )
        .accessibilityElement(children: .combine)
    }
}

#Preview("With HRV") {
    NavigationStack {
        BreathingSummaryView(result: BreathingSessionResult(preSessionHRV: 42, postSessionHRV: 51, duration: 120, cyclesCompleted: 7))
    }
}

#Preview("No HRV · dark") {
    NavigationStack {
        BreathingSummaryView(result: BreathingSessionResult(preSessionHRV: nil, postSessionHRV: nil, duration: 120, cyclesCompleted: 7))
    }
    .preferredColorScheme(.dark)
}
