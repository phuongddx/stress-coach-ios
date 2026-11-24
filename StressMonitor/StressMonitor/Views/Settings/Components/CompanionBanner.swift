import SwiftUI

/// Active-companion card (UI V2): the selected Ripple character on a soft
/// tile, an "Active companion" eyebrow, the name, and a "Switch" link to the
/// character collection. Character art is unchanged.
struct CompanionBanner: View {
    var companionName: String
    var companionSubtitle: String
    var mood: RippleMood = .serene
    var onSwitch: (() -> Void)? = nil

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        SettingsCard(padding: 14) {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                : AnyLayout(HStackLayout(spacing: 14))
            layout {
                ZStack {
                    RoundedRectangle(cornerRadius: V2Metrics.radiusSM, style: .continuous)
                        .fill(Color.V2.accentSoft)
                    StressBuddyIllustration(mood: mood, size: 44)
                }
                .frame(width: 60, height: 60)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Active companion")
                        .v2Eyebrow()

                    Text(companionSubtitle.isEmpty ? companionName : "\(companionName) · \(companionSubtitle)")
                        .font(.headline)
                        .foregroundStyle(Color.V2.ink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    HapticManager.shared.buttonPress()
                    onSwitch?()
                } label: {
                    Text("Switch")
                }
                .buttonStyle(.v2(.secondary, compact: true, fullWidth: false))
                .accessibilityLabel("Switch active companion")
            }
            .accessibilityElement(children: .combine)
        }
    }
}

#Preview {
    CompanionBanner(companionName: "Ripple", companionSubtitle: "Water Otter")
        .padding()
        .background(Color.V2.bg)
}
