import SwiftUI

// MARK: - MoodPickerRow

/// Grid of the 5 mood buttons used on the Today screen (UI V2).
///
/// Each mood is a 32 pt circular well with its SF Symbol, and the mood name
/// beneath it; the whole cell is the tap target (at least 44 × 44 pt). Three
/// per row so every hit area keeps its full 44 pt width on a 41–45 mm
/// display. The selected mood gets an accent well, an accent ring and a
/// bold name — colour is never the only signal.
struct MoodPickerRow: View {
    @Binding var selectedMood: WatchMood?
    let onSelected: (WatchMood) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let columns = Array(
        repeating: GridItem(.flexible(minimum: WatchV2.minHitTarget), spacing: 2),
        count: 3
    )

    var body: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(WatchMood.allCases) { mood in
                moodButton(mood)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Subviews

    private func moodButton(_ mood: WatchMood) -> some View {
        let isSelected = selectedMood == mood
        return Button {
            selectedMood = mood
            onSelected(mood)
        } label: {
            VStack(spacing: 2) {
                Image(systemName: mood.icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isSelected ? WatchV2.onAccent : WatchV2.ink)
                    .frame(width: WatchV2.minVisibleTarget, height: WatchV2.minVisibleTarget)
                    .background(Circle().fill(isSelected ? WatchV2.accent : WatchV2.surface))
                    .overlay(
                        Circle().stroke(isSelected ? WatchV2.ink : .clear, lineWidth: 1.5)
                    )
                Text(mood.displayName)
                    .font(isSelected ? .caption2.weight(.bold) : .caption2)
                    .foregroundStyle(isSelected ? WatchV2.ink : WatchV2.ink3)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: WatchV2.minHitTarget)
            .contentShape(Rectangle())
            .animation(
                WatchDesignTokens.motion(WatchDesignTokens.Motion.fast, reduceMotion: reduceMotion),
                value: isSelected
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(mood.displayName) mood\(isSelected ? ", selected" : "")")
    }
}

#if DEBUG
#Preview("Mood picker") {
    struct PreviewWrapper: View {
        @State private var mood: WatchMood?
        var body: some View {
            MoodPickerRow(selectedMood: $mood) { _ in }
                .padding()
                .background(WatchV2.canvas)
        }
    }
    return PreviewWrapper()
}
#endif
