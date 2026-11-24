import SwiftUI

/// Appearance preferences: color scheme (Light / Dark / System), larger text
/// toggle, and haptics toggle. Color scheme is wired to the shared
/// ``AppearanceManager`` singleton that the app root observes.
struct AppearanceSettingsView: View {
    @State private var appearance = AppearanceManager.shared
    @State private var largerText: Bool = UserDefaults.standard.bool(forKey: "appearance.largerText")
    @State private var hapticsEnabled: Bool = !UserDefaults.standard.bool(forKey: "appearance.hapticsDisabled")

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                colorSchemeSection
                textSizeSection
                hapticsSection
            }
            .padding(.horizontal, V2Metrics.margin)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color.V2.bg.ignoresSafeArea())
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
        .accessibleDynamicType()
    }

    // MARK: - Color scheme

    private var colorSchemeSection: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        return VStack(alignment: .leading, spacing: 6) {
            ActionGroupHeader(title: "Color scheme")
            layout {
                ForEach(AppearanceManager.Mode.allCases, id: \.self) { mode in
                    themeOption(mode)
                }
            }
            ActionGroupFooter(text: "System follows your device's light or dark mode.")
        }
    }

    private func themeOption(_ mode: AppearanceManager.Mode) -> some View {
        let isSelected = appearance.preferredScheme == mode
        return Button {
            appearance.preferredScheme = mode
            HapticManager.shared.buttonPress()
        } label: {
            VStack(spacing: 10) {
                ThemeThumbnail(mode: mode)
                    .overlay(
                        RoundedRectangle(cornerRadius: V2Metrics.radiusSM, style: .continuous)
                            .strokeBorder(isSelected ? Color.V2.accent : Color.V2.line, lineWidth: isSelected ? 2 : 1)
                    )
                HStack(spacing: 8) {
                    SettingsRadioMark(isSelected: isSelected)
                    Text(mode.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.V2.ink)
                }
                .frame(minHeight: V2Metrics.minTouchTarget)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Appearance \(mode.rawValue)")
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Text size

    private var textSizeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            ActionGroupHeader(title: "Text size")
            ActionGroupCard {
                SettingsRowLabel(
                    icon: "textformat.size.larger",
                    title: "Larger text",
                    subtitle: "Prioritizes Dynamic Type's larger accessibility sizes"
                ) {
                    Toggle("Larger text", isOn: $largerText)
                        .labelsHidden()
                        .tint(Color.V2.accent)
                }
                .accessibilityElement(children: .combine)
            }
            .onChange(of: largerText) { _, newValue in
                UserDefaults.standard.set(newValue, forKey: "appearance.largerText")
            }
            ActionGroupFooter(text: "StressMonitor supports Dynamic Type. Adjust the system slider in Settings > Display & Brightness > Text Size.")
        }
    }

    // MARK: - Haptics

    private var hapticsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            ActionGroupHeader(title: "Feedback")
            ActionGroupCard {
                SettingsRowLabel(
                    icon: "hand.tap.fill",
                    title: "Haptic feedback",
                    subtitle: "Vibrations on stress changes and button taps"
                ) {
                    Toggle("Haptic feedback", isOn: $hapticsEnabled)
                        .labelsHidden()
                        .tint(Color.V2.accent)
                }
                .accessibilityElement(children: .combine)
            }
            .onChange(of: hapticsEnabled) { _, newValue in
                UserDefaults.standard.set(!newValue, forKey: "appearance.hapticsDisabled")
            }
        }
    }
}

/// Mini screen preview for a colour-scheme option. Light and Dark render the
/// V2 tokens in that scheme; System shows both halves.
private struct ThemeThumbnail: View {
    let mode: AppearanceManager.Mode

    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 104

    var body: some View {
        Group {
            switch mode {
            case .light:
                ThemeMiniScreen().environment(\.colorScheme, .light)
            case .dark:
                ThemeMiniScreen().environment(\.colorScheme, .dark)
            case .system:
                HStack(spacing: 0) {
                    ThemeMiniScreen().environment(\.colorScheme, .light)
                    ThemeMiniScreen().environment(\.colorScheme, .dark)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: min(height, 140))
        .clipShape(RoundedRectangle(cornerRadius: V2Metrics.radiusSM, style: .continuous))
        .accessibilityHidden(true)
    }
}

private struct ThemeMiniScreen: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Capsule().fill(Color.V2.ink).frame(width: 28, height: 5)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.V2.surface)
                .frame(height: 30)
                .overlay(alignment: .leading) {
                    Circle().fill(Color.V2.accent).frame(width: 14, height: 14).padding(.leading, 8)
                }
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.V2.surface)
                .frame(height: 18)
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.V2.bg)
    }
}

#Preview {
    NavigationStack {
        AppearanceSettingsView()
    }
}
