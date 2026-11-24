import SwiftUI

/// Ripple's recommendation at the top of the Action tab (UI V2): a tinted
/// card with the companion, a "Ripple" label, one line of advice, a primary
/// "Start box breathing" link and, when Chat is available, a secondary
/// "Talk to Ripple" button.
///
/// Spec reference: ui-v2-design/screens.js `S.action` (`rippleCard` with
/// `tint:1`), states default / no-reading / chat-off.
struct RippleRecommendationCard: View {
    let stressLevel: Double?
    var isChatAvailable: Bool = true
    /// Opens the Chat sheet. Only offered when `isChatAvailable`.
    var onTalkToRipple: (() -> Void)? = nil

    var body: some View {
        V2Card(style: .tint) {
            HStack(alignment: .top, spacing: 12) {
                StressBuddyIllustration(mood: RippleMood.from(stressLevel: stressLevel ?? 0), size: 44)
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Ripple")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.V2.accent)

                    Text(voiceLine)
                        .font(.callout)
                        .foregroundStyle(Color.V2.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("Ripple says: \(voiceLine)")

                    buttons
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// Side by side when they fit; otherwise stacked at full width.
    private var buttons: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { buttonViews(fullWidth: false) }
                .fixedSize(horizontal: true, vertical: false)
            VStack(spacing: 8) { buttonViews(fullWidth: true) }
        }
    }

    @ViewBuilder
    private func buttonViews(fullWidth: Bool) -> some View {
        NavigationLink(value: Route.boxBreathing) {
            Text("Start box breathing")
        }
        .buttonStyle(.v2(.primary, compact: true, fullWidth: fullWidth))
        .accessibilityHint("Opens box breathing")

        if isChatAvailable, let onTalkToRipple {
            // Ghost on a surface capsule: the secondary fill would vanish on
            // the accentSoft card.
            Button("Talk to Ripple") {
                HapticManager.shared.buttonPress()
                onTalkToRipple()
            }
            .buttonStyle(.v2(.ghost, compact: true, fullWidth: fullWidth))
            .background(Capsule().fill(Color.V2.surface))
            .accessibilityIdentifier("action.card.talkToRipple")
        }
    }

    /// Says nothing about the user's data until a reading exists.
    private var voiceLine: String {
        guard let level = stressLevel else {
            return "No reading yet today. Any of these is a good reset while we wait."
        }
        switch StressResult.category(for: level) {
        case .relaxed:
            return "Stress is low. You're settled. A slow breath keeps you here."
        case .mild:
            return isChatAvailable
                ? "Stress is mild. You're settled. A slow breath keeps you here."
                : "Stress is mild. A slow breath keeps you steady."
        case .moderate:
            return "Stress is building. A 2-minute box breath helps bring it down."
        case .high:
            return "Stress is high. Box breathing first, then a short walk."
        case .severe:
            return "Stress is running hot. Start with a slow breath, then step away for a few minutes."
        }
    }
}

#Preview("RippleRecommendationCard") {
    NavigationStack {
        VStack(spacing: 16) {
            RippleRecommendationCard(stressLevel: 42, onTalkToRipple: {})
            RippleRecommendationCard(stressLevel: nil, onTalkToRipple: {})
            RippleRecommendationCard(stressLevel: 32, isChatAvailable: false)
            Spacer()
        }
        .padding()
        .background(Color.V2.bg)
        .stressNavigationDestinations()
    }
}
