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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                syncStatusSection
                companionSection
                backgroundSection
                installHintSection
            }
            .padding(.horizontal, V2Metrics.margin)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color.V2.bg.ignoresSafeArea())
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
        VStack(alignment: .leading, spacing: 6) {
            ActionGroupHeader(title: "Status")
            V2Card {
                HStack(spacing: 14) {
                    SettingsIconView(
                        systemName: connectivity.isWatchAppInstalled ? "applewatch.radiowaves.left.and.right" : "applewatch.slash",
                        color: connectivity.isWatchAppInstalled ? StressCategory.relaxed.fillColor : Color.V2.surface3,
                        foreground: connectivity.isWatchAppInstalled ? StressCategory.relaxed.onFillColor : Color.V2.ink2,
                        size: 44
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(connectivity.isWatchAppInstalled ? "Watch connected" : "No watch installed")
                            .font(.headline)
                            .foregroundStyle(Color.V2.ink)
                        Text(connectivity.isReachable ? "Reachable now" : "Out of reach")
                            .font(.subheadline)
                            .foregroundStyle(Color.V2.ink3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityElement(children: .combine)
            }
            ActionGroupFooter(text: connectivity.isWatchAppInstalled
                 ? "Changes sync automatically while the watch is reachable."
                 : "Install StressMonitor on your Apple Watch from the Watch app on iPhone.")
        }
    }

    // MARK: - Active companion

    private var companionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            ActionGroupHeader(title: "Active companion")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(CharacterCreature.offeredCharacters) { creature in
                        companionOption(creature)
                    }
                }
                .padding(.vertical, 2)
            }
            ActionGroupFooter(text: "The selected creature appears in your watch complications.")
        }
    }

    /// Ripple shows its v2 base pose; other companions keep their artwork.
    @ViewBuilder
    private func companionArt(for creature: CharacterCreature) -> some View {
        if creature.id == "ripple" {
            RippleV2Image(pose: .base, crop: .full, size: 48)
        } else {
            CharacterAssetResolver.characterView(for: creature.id, mood: currentMood, size: 48)
        }
    }

    private func companionOption(_ creature: CharacterCreature) -> some View {
        let isSelected = activeCompanionId == creature.id
        return Button {
            activeCompanionId = creature.id
            UserDefaults.standard.set(creature.id, forKey: "watchface.activeCompanionId")
            CharacterSelectionSync.shared.saveActiveCharacter(
                characterId: creature.id,
                evolution: .droplet
            )
            HapticManager.shared.buttonPress()
        } label: {
            VStack(spacing: 6) {
                companionArt(for: creature)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color.V2.surface2))
                Text(creature.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.V2.ink)
                    .lineLimit(1)
                Text(creature.subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.V2.ink3)
                    .lineLimit(1)
                SettingsRadioMark(isSelected: isSelected)
                    .padding(.top, 2)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 10)
            .frame(minWidth: 104)
            .background(
                RoundedRectangle(cornerRadius: V2Metrics.radiusMD, style: .continuous)
                    .fill(Color.V2.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: V2Metrics.radiusMD, style: .continuous)
                    .strokeBorder(isSelected ? Color.V2.accent : Color.V2.line, lineWidth: isSelected ? 2 : 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Active companion \(creature.displayName)")
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Background

    private var backgroundSection: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        return VStack(alignment: .leading, spacing: 6) {
            ActionGroupHeader(title: "Background style")
            layout {
                ForEach(WatchFaceBackground.allCases, id: \.self) { style in
                    backgroundOption(style)
                }
            }
        }
    }

    private func backgroundOption(_ style: WatchFaceBackground) -> some View {
        let isSelected = backgroundStyle == style
        return Button {
            backgroundStyle = style
            HapticManager.shared.buttonPress()
        } label: {
            VStack(spacing: 8) {
                WatchBackgroundThumbnail(style: style)
                    .overlay(
                        RoundedRectangle(cornerRadius: V2Metrics.radiusMD, style: .continuous)
                            .strokeBorder(isSelected ? Color.V2.accent : Color.V2.line, lineWidth: isSelected ? 2 : 1)
                    )
                HStack(spacing: 6) {
                    SettingsRadioMark(isSelected: isSelected)
                    Text(style.label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.V2.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
                .frame(minHeight: V2Metrics.minTouchTarget)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(style.label)
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var installHintSection: some View {
        Link(destination: URL(string: "itms-watch://")!) {
            Label("Open the Watch app", systemImage: "arrow.up.right")
        }
        .buttonStyle(.v2(.secondary))
        .accessibilityLabel("Open the Apple Watch app on iPhone")
    }
}

/// Small watch-face preview for a background option, drawn from V2 tokens.
private struct WatchBackgroundThumbnail: View {
    let style: WatchFaceBackground

    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 96

    var body: some View {
        RoundedRectangle(cornerRadius: V2Metrics.radiusMD, style: .continuous)
            .fill(fill)
            .overlay {
                Circle()
                    .strokeBorder(ringColor, lineWidth: 4)
                    .padding(22)
            }
            .frame(maxWidth: .infinity)
            .frame(height: min(height, 130))
            .accessibilityHidden(true)
    }

    private var fill: AnyShapeStyle {
        switch style {
        case .minimal:
            return AnyShapeStyle(Color.V2.ink)
        case .gradient:
            return AnyShapeStyle(LinearGradient(
                colors: [Color.V2.accent, Color.V2.Companion.ripple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        case .stressTinted:
            return AnyShapeStyle(StressCategory.relaxed.fillColor)
        }
    }

    private var ringColor: Color {
        switch style {
        case .minimal: return Color.V2.lime
        case .gradient: return Color.V2.onAccent
        case .stressTinted: return StressCategory.relaxed.onFillColor
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
