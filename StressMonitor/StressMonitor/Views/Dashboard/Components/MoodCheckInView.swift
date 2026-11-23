import SwiftUI

/// Subjective mood check-in for the Home tab (UI V2).
///
/// Five Ripple faces with the mood names. The selected face sits on an
/// accent-tinted tile; the others stay neutral. The selected entry is reported
/// via `onSelect` so the owning view model can store it. At accessibility text
/// sizes the choices become full-width rows.
///
/// Spec reference: ui-v2-design/screens.js `S.home` "How do you feel?".
struct MoodCheckInView: View {
    let selected: MoodLevel?
    let onSelect: (MoodLevel) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            V2SectionHeader(title: "How do you feel?")

            V2Card(padding: 8) {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 4) {
                        ForEach(MoodLevel.allCases) { level in
                            chip(for: level, stacked: true)
                        }
                    }
                } else {
                    HStack(spacing: 4) {
                        ForEach(MoodLevel.allCases) { level in
                            chip(for: level, stacked: false)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Mood check-in")
    }

    @ViewBuilder
    private func chip(for level: MoodLevel, stacked: Bool) -> some View {
        let isActive = selected == level
        Button {
            HapticManager.shared.buttonPress()
            onSelect(level)
        } label: {
            Group {
                if stacked {
                    HStack(spacing: 12) {
                        face(for: level)
                        Text(level.displayName)
                            .font(.body.weight(isActive ? .semibold : .regular))
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                } else {
                    VStack(spacing: 4) {
                        face(for: level)
                        Text(level.displayName)
                            .font(.caption.weight(isActive ? .semibold : .regular))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
            .foregroundStyle(isActive ? Color.V2.ink : Color.V2.ink2)
            .frame(maxWidth: .infinity, minHeight: 60)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: V2Metrics.radiusSM, style: .continuous)
                    .fill(isActive ? Color.V2.accentSoft : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: V2Metrics.radiusSM, style: .continuous)
                    .strokeBorder(isActive ? Color.V2.accent : Color.clear, lineWidth: 1.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Mood: \(level.displayName)")
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private func face(for level: MoodLevel) -> some View {
        StressBuddyIllustration(mood: rippleMood(for: level), size: 32)
            .frame(width: 32, height: 32)
            .accessibilityHidden(true)
    }

    private func rippleMood(for level: MoodLevel) -> RippleMood {
        switch level {
        case .veryCalm:  return .happy
        case .calm:      return .relaxed
        case .neutral:   return .focused
        case .tense:     return .worried
        case .veryTense: return .tired
        }
    }
}

#Preview("MoodCheckInView") {
    @Previewable @State var selected: MoodLevel? = .neutral
    return VStack {
        MoodCheckInView(selected: selected) { selected = $0 }
        Spacer()
    }
    .padding()
    .background(Color.V2.bg)
}
