import SwiftUI

/// Appearance preferences: color scheme (Light / Dark / System), larger text
/// toggle, and haptics toggle. Color scheme is wired to the shared
/// ``AppearanceManager`` singleton that the app root observes.
struct AppearanceSettingsView: View {
    @State private var appearance = AppearanceManager.shared
    @State private var largerText: Bool = UserDefaults.standard.bool(forKey: "appearance.largerText")
    @State private var hapticsEnabled: Bool = HapticPreference.isEnabled()

    var body: some View {
        Form {
            colorSchemeSection
            textSizeSection
            hapticsSection
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
        .accessibleDynamicType()
    }

    // MARK: - Color scheme

    private var colorSchemeSection: some View {
        Section {
            ForEach(AppearanceManager.Mode.allCases, id: \.self) { mode in
                Button {
                    appearance.preferredScheme = mode
                    HapticManager.shared.buttonPress()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.primaryBlue)
                            .frame(width: 26)
                        Text(mode.rawValue)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.Wellness.adaptivePrimaryText)
                        Spacer()
                        if appearance.preferredScheme == mode {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.primaryGreen)
                        }
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Appearance \(mode.rawValue)")
                .accessibilityAddTraits(appearance.preferredScheme == mode ? .isSelected : [])
            }
        } header: {
            Text("Color scheme")
        } footer: {
            Text("System follows your device's light or dark mode.")
        }
    }

    // MARK: - Text size

    private var textSizeSection: some View {
        Section {
            Toggle(isOn: $largerText) {
                rowLabel(icon: "textformat.size.larger", title: "Larger text", subtitle: "Prioritizes Dynamic Type's larger accessibility sizes")
            }
            .tint(Color.primaryGreen)
            .onChange(of: largerText) { _, newValue in
                UserDefaults.standard.set(newValue, forKey: "appearance.largerText")
            }
        } header: {
            Text("Text size")
        } footer: {
            Text("StressMonitor supports Dynamic Type. Adjust the system slider in Settings > Display & Brightness > Text Size.")
        }
    }

    // MARK: - Haptics

    private var hapticsSection: some View {
        Section {
            Toggle(isOn: $hapticsEnabled) {
                rowLabel(icon: "hand.tap.fill", title: "Haptic feedback", subtitle: "Vibrations on stress changes and button taps")
            }
            .tint(Color.primaryGreen)
            .onChange(of: hapticsEnabled) { _, newValue in
                HapticPreference.setEnabled(newValue)
            }
        } header: {
            Text("Feedback")
        }
    }

    // MARK: - Row helper

    private func rowLabel(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.primaryBlue)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
            }
        }
    }
}

#Preview {
    NavigationStack {
        AppearanceSettingsView()
    }
}
