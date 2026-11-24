import SwiftUI

// MARK: - Box Breathing Intro View

/// Box Breathing (4-4-4-4) intro / launcher screen (UI V2).
///
/// Static box illustration, title and one-line explainer, the 4-step
/// pattern, a "before HRV" readout, the session settings (read-only), and a
/// primary "Begin session" button that navigates to `BreathingSessionView`.
/// Light and dark built from `Color.V2` tokens.
///
/// Spec reference: ui-v2-design/screens.js `S.breatheIntro`. The session
/// length picker and sound toggle are deferred (spec §8).
struct BreathingExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var currentHRV: Double?
    @State private var hrvTimestamp: Date?

    var body: some View {
        content
        .background(Color.V2.bg.ignoresSafeArea())
        .accessibleDynamicType()
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
                Text("Box breathing")
                    .font(.headline)
                    .foregroundStyle(Color.V2.ink)
            }
        }
        .task { await fetchCurrentHRV() }
    }

    // MARK: - Layout

    @ViewBuilder
    private var content: some View {
        switch DuoLayout.mode(for: horizontalSizeClass) {
        case .singleColumn:
            ScrollView {
                VStack(spacing: 16) {
                    introHero
                    details
                }
                .padding(.horizontal, V2Metrics.margin)
                .padding(.bottom, 24)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(DuoLayoutID.singleColumn)
        case .twoColumns:
            // Duo inner display: the box and the explainer on one side of
            // the fold, the steps, settings and Begin on the other.
            FoldAwareSplit(axis: nil) {
                ScrollView {
                    introHero
                        .padding(.horizontal, V2Metrics.margin)
                        .padding(.vertical, 24)
                }
                .defaultScrollAnchor(.center, for: .alignment)
                .scrollBounceBehavior(.basedOnSize)
            } trailing: {
                ScrollView {
                    details
                        .padding(.horizontal, V2Metrics.margin)
                        .padding(.vertical, 24)
                }
                .defaultScrollAnchor(.center, for: .alignment)
                .scrollBounceBehavior(.basedOnSize)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(DuoLayoutID.twoColumns)
        }
    }

    private var details: some View {
        VStack(spacing: 16) {
            patternExplain
            beforeCard
            sessionConfig
            ctaRow
            footnote
        }
    }

    // MARK: - Intro Hero

    private var introHero: some View {
        VStack(spacing: 16) {
            BoxBreathingIllustration()
                .padding(.top, 8)

            VStack(spacing: 8) {
                Text("Box breathing")
                    .font(.title.weight(.bold))
                    .foregroundStyle(Color.V2.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("Breathe in, hold, out and hold for 4 seconds each. A steady rhythm that slows your heart rate.")
                    .font(.callout)
                    .foregroundStyle(Color.V2.ink2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Pattern Explain (4-step grid)

    private var patternExplain: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 8))

        return V2Card {
            layout {
                ForEach(Array(BoxBreathingStep.steps.enumerated()), id: \.offset) { i, step in
                    stepCell(index: i, step: step)
                }
            }
        }
    }

    @ViewBuilder
    private func stepCell(index i: Int, step: BoxBreathingStep) -> some View {
        let number = Text("\(i + 1)")
            .font(.v2Number(.callout, weight: .bold))
            .foregroundStyle(Color.V2.accent)
            .frame(minWidth: 36, minHeight: 36)
            .background(Circle().fill(Color.V2.accentSoft))

        if dynamicTypeSize.isAccessibilitySize {
            HStack(spacing: 12) {
                number
                Text("\(step.shortName), 4 sec")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.V2.ink)
            }
            .accessibilityElement(children: .combine)
        } else {
            VStack(spacing: 6) {
                number
                Text(step.shortName)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.V2.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("4 sec")
                    .font(.v2Number(.caption, weight: .medium))
                    .foregroundStyle(Color.V2.ink3)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Before Card (Current HRV)

    private var beforeCard: some View {
        V2Card {
            HStack(spacing: 12) {
                Image(systemName: AppIconSystem.Metric.hrv.sfSymbol)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.V2.accent)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: V2Metrics.radiusSM, style: .continuous)
                            .fill(Color.V2.accentSoft)
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("HRV before you start")
                        .font(.subheadline)
                        .foregroundStyle(Color.V2.ink2)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(currentHRV.map { "\(Int($0))" } ?? "—")
                            .font(.v2Number(.title2, weight: .bold))
                            .foregroundStyle(Color.V2.ink)
                        Text("ms")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.V2.ink3)
                        Text("· \(hrvTimeLabel)")
                            .font(.footnote)
                            .foregroundStyle(Color.V2.ink3)
                    }
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var hrvTimeLabel: String {
        guard let hrvTimestamp else { return "no recent reading" }
        return hrvTimestamp.formatted(date: .omitted, time: .shortened)
    }

    // MARK: - Session Config

    private var sessionConfig: some View {
        ActionGroupCard {
            VStack(spacing: 0) {
                configRow(icon: "timer", label: "Length", value: durationLabel)
                ActionRowDivider()
                configRow(icon: "iphone.radiowaves.left.and.right", label: "Haptic cues", value: "On")
            }
        }
    }

    private var durationLabel: String {
        let duration = BreathingSessionViewModel.defaultSessionDuration
        let cycles = BreathingSessionViewModel.cycleCount(forDuration: duration)
        return "\(Int(duration) / 60) min · \(cycles) cycles"
    }

    private func configRow(icon: String, label: String, value: String) -> some View {
        ActionRowLabel(
            icon: icon,
            title: label,
            subtitle: nil,
            tint: Color.V2.surface2,
            iconForeground: Color.V2.ink2
        ) {
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.V2.ink2)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - CTA Row

    private var ctaRow: some View {
        VStack(spacing: 4) {
            Button(action: { router.actionPath.append(Route.breathingSession) }) {
                Text("Begin session")
            }
            .buttonStyle(.v2(.primary))
            .accessibilityLabel("Begin breathing session")

            Button(action: { dismiss() }) {
                Text("Cancel")
            }
            .buttonStyle(.v2(.ghost, compact: true))
        }
        .padding(.top, 4)
    }

    // MARK: - Footnote

    private var footnote: some View {
        Text("Find a comfortable seat. Sit upright, soften your shoulders.")
            .font(.footnote)
            .foregroundStyle(Color.V2.ink3)
            .multilineTextAlignment(.center)
            .padding(.horizontal, V2Metrics.margin)
    }

    // MARK: - HRV Fetch

    private func fetchCurrentHRV() async {
        let manager = HealthKitManager()
        if let hrv = try? await manager.fetchLatestHRV() {
            currentHRV = hrv.value
            hrvTimestamp = hrv.timestamp
        }
    }
}

// MARK: - Box illustration

/// Static box-breathing mark (UI V2 `S.breatheIntro` box): a rounded square
/// traced in accent on an `accentSoft` tile with "4·4·4·4" in the middle and
/// a dot on each corner. No animation, so nothing to gate for Reduce Motion.
private struct BoxBreathingIllustration: View {
    @ScaledMetric(relativeTo: .title) private var size: CGFloat = 168

    var body: some View {
        let inner = size * 0.58
        ZStack {
            RoundedRectangle(cornerRadius: V2Metrics.radiusXL, style: .continuous)
                .fill(Color.V2.accentSoft)

            RoundedRectangle(cornerRadius: V2Metrics.radiusSM, style: .continuous)
                .stroke(Color.V2.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                .frame(width: inner, height: inner)

            ForEach(0..<4, id: \.self) { i in
                Circle()
                    .fill(Color.V2.accent)
                    .frame(width: 10, height: 10)
                    .offset(
                        x: (i % 2 == 0 ? -1 : 1) * inner / 2,
                        y: (i < 2 ? -1 : 1) * inner / 2
                    )
            }

            Text("4·4·4·4")
                .font(.v2Number(.headline, weight: .bold))
                .foregroundStyle(Color.V2.accent)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Box Breathing Step Info

private struct BoxBreathingStep {
    let shortName: String

    static let steps: [BoxBreathingStep] = [
        BoxBreathingStep(shortName: "Inhale"),
        BoxBreathingStep(shortName: "Hold"),
        BoxBreathingStep(shortName: "Exhale"),
        BoxBreathingStep(shortName: "Hold"),
    ]
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BreathingExerciseView()
            .stressNavigationDestinations()
    }
    .environment(AppRouter())
}

#Preview("Dark") {
    NavigationStack {
        BreathingExerciseView()
            .stressNavigationDestinations()
    }
    .environment(AppRouter())
    .preferredColorScheme(.dark)
}
