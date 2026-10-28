import SwiftUI

// MARK: - Box Breathing Intro View

/// Box Breathing (4-4-4-4) intro / launcher screen — redesigned per
/// `13-breathing-intro.html`.
///
/// Light surface with a 4-step pattern explainer card, a "before HRV" readout,
/// session configuration rows, and a "Begin Session" CTA that navigates to
/// `BreathingSessionView`.
struct BreathingExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router

    @State private var currentHRV: Double?
    @State private var hrvTimestamp: Date?

    // Design tokens from app.css
    private let accent = Color(hex: "#4FC3F7")           // --accent
    private let accentStrong = Color(hex: "#0288D1")     // --accent-strong
    private let accentSoft = Color(hex: "#4FC3F7").opacity(0.14) // --accent-soft
    private let surface = Color.white                     // --surface
    private let fg = Color(hex: "#101223")               // --fg
    private let fgSecondary = Color(hex: "#3C3C43")      // --fg-secondary
    private let muted = Color(hex: "#777986")            // --muted
    private let separator = Color(red: 60/255, green: 60/255, blue: 67/255).opacity(0.12)
    private let hrvColor = Color(hex: "#34D399")         // --hrv-color
    private let success = Color(hex: "#34C759")          // --success

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                introHero
                patternExplain
                beforeCard
                sessionConfig
                ctaRow
                footnote
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Color(hex: "#F2F2F7"))
        .accessibleDynamicType()
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: AppIconSystem.Nav.back.sfSymbol)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(accentStrong)
                }
                .minimumTouchTarget(DesignTokens.Layout.minTouchTarget)
                .accessibilityLabel("Back")
            }
            ToolbarItem(placement: .principal) {
                Text("Box Breathing")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(fg)
            }
        }
        .task { await fetchCurrentHRV() }
    }

    // MARK: - Intro Hero

    private var introHero: some View {
        VStack(spacing: 16) {
            // Animated box-breathing pattern icon (4 corner squares pulsing)
            boxPatternAnimation
                .frame(width: 200, height: 200)

            VStack(spacing: 6) {
                Text("Box Breathing")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .tracking(-0.02 * 32)
                    .foregroundStyle(fg)
                Text("Navy SEAL pattern. Lowers stress, sharpens focus.")
                    .font(.system(size: 15))
                    .foregroundStyle(fgSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 240)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Box Pattern Animation

    private var boxPatternAnimation: some View {
        ZStack {
            // 4 corner squares pulsing in sequence
            ForEach(0..<4, id: \.self) { i in
                let (dx, dy): (CGFloat, CGFloat) = {
                    switch i {
                    case 0: return (-50, -50)
                    case 1: return (50, -50)
                    case 2: return (-50, 50)
                    default: return (50, 50)
                    }
                }()
                RoundedRectangle(cornerRadius: 8)
                    .stroke(accentStrong, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 40, height: 40)
                    .offset(x: dx, y: dy)
                    .scaleEffect(boxScales[i])
                    .opacity(boxOpacities[i])
                    .animation(
                        .easeInOut(duration: 1)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i)),
                        value: animateBox
                    )
            }
            // Center dot with "4·4·4·4" label
            Circle()
                .fill(accentStrong)
                .frame(width: 40, height: 40)
                .overlay(
                    Text("4·4·4·4")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                )
        }
        .startMotionIfAllowed { animateBox = true }
    }

    @State private var animateBox = false
    @State private var boxScales: [CGFloat] = [0.85, 0.85, 0.85, 0.85]
    @State private var boxOpacities: [Double] = [0.6, 0.6, 0.6, 0.6]

    // MARK: - Pattern Explain (4-step grid)

    private var patternExplain: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { i in
                let step = BoxBreathingStep.steps[i]
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(accentSoft)
                            .frame(width: 36, height: 36)
                        Text("\(i + 1)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(accentStrong)
                    }
                    Text(step.shortName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(fg)
                    Text("4 sec")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(accentStrong)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18).fill(surface)
        )
    }

    // MARK: - Before Card (Current HRV)

    private var beforeCard: some View {
        HStack(spacing: 12) {
            // HRV icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(hrvColor)
                    .frame(width: 40, height: 40)
                Image(systemName: AppIconSystem.Metric.hrv.sfSymbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(currentHRV.map { "\(Int($0)) ms" } ?? "— ms")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(fg)
                Text("Current HRV · \(hrvTimeLabel)")
                    .font(.system(size: 12))
                    .foregroundStyle(muted)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18).fill(surface)
        )
    }

    private var hrvTimeLabel: String {
        guard let hrvTimestamp else { return "no recent reading" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: hrvTimestamp)
    }

    // MARK: - Session Config

    private var sessionConfig: some View {
        VStack(spacing: 0) {
            configRow(label: "Duration", value: durationLabel)
            divider
            configRow(label: "Haptic feedback", value: "On")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18).fill(surface)
        )
    }

    private var durationLabel: String {
        let duration = BreathingSessionViewModel.defaultSessionDuration
        let cycles = BreathingSessionViewModel.cycleCount(forDuration: duration)
        return "\(Int(duration) / 60) min · \(cycles) cycles"
    }

    private func configRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(fg)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(accentStrong)
        }
        .padding(.vertical, 5)
    }

    private var divider: some View {
        Rectangle()
            .fill(separator)
            .frame(height: 1)
            .padding(.vertical, 5)
    }

    // MARK: - CTA Row

    private var ctaRow: some View {
        VStack(spacing: 6) {
            Button(action: { router.actionPath.append(Route.breathingSession) }) {
                Text("Begin Session")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 14).fill(accent)
                    )
            }
            .accessibilityLabel("Begin breathing session")

            Button(action: { dismiss() }) {
                Text("Cancel")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(accentStrong)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
        }
    }

    // MARK: - Footnote

    private var footnote: some View {
        Text("Find a comfortable seat. Sit upright, soften your shoulders.")
            .font(.system(size: 13))
            .foregroundStyle(muted)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
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
