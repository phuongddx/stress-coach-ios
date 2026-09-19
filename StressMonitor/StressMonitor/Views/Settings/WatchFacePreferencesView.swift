import SwiftUI
import SwiftData

/// Watch face & complication preferences. Surfaces the paired-watch state
/// from ``PhoneConnectivityManager`` and lets the user pick the complication
/// background style plus the active companion that syncs to the watch.
struct WatchFacePreferencesView: View {
    @StateObject private var connectivity = PhoneConnectivityManager.shared
    @State private var backgroundStyle: WatchFaceBackground = .minimal
    @State private var activeCompanionId: String = UserDefaults.standard.string(forKey: "watchface.activeCompanionId") ?? "ripple"

    /// Latest stress reading so character previews reflect the user's actual mood.
    @Query(sort: \StressMeasurement.timestamp, order: .reverse)
    private var latestMeasurements: [StressMeasurement]

    private var currentMood: RippleMood {
        RippleMood.from(stressLevel: latestMeasurements.first?.stressLevel ?? 0)
    }

    var body: some View {
        Form {
            syncStatusSection
            companionSection
            backgroundSection
            installHintSection
        }
        .navigationTitle("Watch Face")
        .navigationBarTitleDisplayMode(.inline)
        .accessibleDynamicType()
        .onAppear {
            // Refresh the persisted selection when the screen appears.
            activeCompanionId = UserDefaults.standard.string(forKey: "watchface.activeCompanionId") ?? "ripple"
        }
    }

    // MARK: - Sync status

    private var syncStatusSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: connectivity.isWatchAppInstalled ? "applewatch.connectivity" : "applewatch.slash")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(connectivity.isWatchAppInstalled ? Color.primaryGreen : Color.Wellness.adaptiveSecondaryText)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(connectivity.isWatchAppInstalled ? "Watch connected" : "No watch installed")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.Wellness.adaptivePrimaryText)
                    Text(connectivity.isReachable ? "Reachable now" : "Out of reach")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
                }
                Spacer()
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
        } header: {
            Text("Status")
        } footer: {
            Text(connectivity.isWatchAppInstalled
                 ? "Changes sync automatically while the watch is reachable."
                 : "Install StressMonitor on your Apple Watch from the Watch app on iPhone.")
        }
    }

    // MARK: - Active companion

    private var companionSection: some View {
        Section {
            ForEach(CharacterCreature.offeredCharacters) { creature in
                Button {
                    activeCompanionId = creature.id
                    UserDefaults.standard.set(creature.id, forKey: "watchface.activeCompanionId")
                    CharacterSelectionSync.shared.saveActiveCharacter(
                        characterId: creature.id,
                        evolution: .droplet
                    )
                    HapticManager.shared.buttonPress()
                } label: {
                    HStack(spacing: 12) {
                        CharacterAssetResolver.characterView(for: creature.id, mood: currentMood, size: 36)
                            .frame(width: 36, height: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(creature.displayName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.Wellness.adaptivePrimaryText)
                            Text(creature.subtitle)
                                .font(.system(size: 12))
                                .foregroundStyle(creature.element.accentColor)
                        }
                        Spacer()
                        if activeCompanionId == creature.id {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.primaryGreen)
                        }
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Active companion \(creature.displayName)")
                .accessibilityAddTraits(activeCompanionId == creature.id ? .isSelected : [])
            }
        } header: {
            Text("Active companion")
        } footer: {
            Text("The selected creature appears in your watch complications.")
        }
    }

    // MARK: - Background

    private var backgroundSection: some View {
        Section {
            ForEach(WatchFaceBackground.allCases, id: \.self) { style in
                Button {
                    backgroundStyle = style
                    HapticManager.shared.buttonPress()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: style.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.primaryBlue)
                            .frame(width: 26)
                        Text(style.label)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.Wellness.adaptivePrimaryText)
                        Spacer()
                        if backgroundStyle == style {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.primaryGreen)
                        }
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(style.label)
                .accessibilityAddTraits(backgroundStyle == style ? .isSelected : [])
            }
        } header: {
            Text("Background style")
        }
    }

    private var installHintSection: some View {
        Section {
            Link(destination: URL(string: "itms-watch://")!) {
                HStack {
                    Image(systemName: "arrow.up.right.square")
                    Text("Open the Watch app")
                    Spacer()
                }
                .foregroundStyle(Color.primaryBlue)
            }
            .accessibilityLabel("Open the Apple Watch app on iPhone")
        }
    }
}

// MARK: - Watch Face Background

enum WatchFaceBackground: String, CaseIterable {
    case minimal
    case gradient
    case stressTinted

    var label: String {
        switch self {
        case .minimal:      return "Minimal"
        case .gradient:     return "Gradient"
        case .stressTinted: return "Stress-tinted"
        }
    }

    var icon: String {
        switch self {
        case .minimal:      return "circle.dashed"
        case .gradient:     return "circle.lefthalf.filled"
        case .stressTinted: return "circle.grid.2x1.fill"
        }
    }
}

#Preview {
    NavigationStack {
        WatchFacePreferencesView()
    }
    .modelContainer(for: StressMeasurement.self, inMemory: true)
}
