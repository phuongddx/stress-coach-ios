import SwiftUI

// MARK: - Mood Preview Grid

/// 5-cell mood grid (UI V2, `S.charDetail` "Moods").
///
/// Shows the five stress tiers, each as a tier-filled face with its shape
/// and score range. Tapping a cell previews that mood on the character hero.
struct MoodPreviewGrid: View {
    let creature: CharacterCreature
    @Binding var selectedMood: RippleMood

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let columns = dynamicTypeSize.isAccessibilitySize
            ? Array(repeating: GridItem(.flexible(), spacing: 6), count: 2)
            : Array(repeating: GridItem(.flexible(), spacing: 6), count: 5)
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(StressMoodCell.allCases, id: \.self) { cell in
                moodCell(cell)
            }
        }
    }

    @ViewBuilder
    private func moodCell(_ cell: StressMoodCell) -> some View {
        let isSelected = cell.mood == selectedMood

        Button {
            if reduceMotion {
                selectedMood = cell.mood
            } else {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                    selectedMood = cell.mood
                }
            }
            HapticManager.shared.buttonPress()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: cell.symbol)
                    .font(.subheadline)
                    .foregroundStyle(cell.category.onFillColor)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(cell.category.fillColor))

                Text(cell.label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.V2.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(cell.rangeLabel)
                    .font(.v2Number(.caption2))
                    .foregroundStyle(Color.V2.ink3)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 72)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: V2Metrics.radiusSM, style: .continuous)
                    .fill(isSelected ? Color.V2.accentSoft : Color.V2.surface2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: V2Metrics.radiusSM, style: .continuous)
                    .strokeBorder(isSelected ? Color.V2.accent : Color.clear, lineWidth: 1.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: V2Metrics.radiusSM))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(cell.label), range \(cell.rangeLabel)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Stress Mood Cell

/// Maps stress categories to mood display metadata, matching the HTML grid.
enum StressMoodCell: String, CaseIterable {
    case relaxed    // 0–25
    case mild       // 26–50
    case moderate   // 51–75
    case high       // 76–90
    case severe     // 91+

    var mood: RippleMood {
        switch self {
        case .relaxed:  return .relaxed
        case .mild:     return .serene
        case .moderate: return .focused
        case .high:     return .worried
        case .severe:   return .determined
        }
    }

    /// Stress tier this cell previews; colours come from the V2 tier tokens.
    var category: StressCategory {
        switch self {
        case .relaxed:  return .relaxed
        case .mild:     return .mild
        case .moderate: return .moderate
        case .high:     return .high
        case .severe:   return .severe
        }
    }

    /// SF Symbol face expression matching the HTML SVG paths.
    var symbol: String {
        switch self {
        case .relaxed:  return "face.smiling"           // smile, eyes
        case .mild:     return "face.dashed"             // neutral
        case .moderate: return "face.dashed.fill"        // flat
        case .high:     return "face.touched"            // worried
        case .severe:   return "face.touched.fill"       // frown
        }
    }

    var rangeLabel: String {
        switch self {
        case .relaxed:  return "0–25"
        case .mild:     return "26–50"
        case .moderate: return "51–75"
        case .high:     return "76–90"
        case .severe:   return "91+"
        }
    }

    var label: String { category.displayName }
}
