import SwiftUI

/// Selectable capsule chip: 32 pt visible height, 44 pt hit area. Selected
/// uses `accentTint` in light mode and `accent` in dark mode.
struct V2Chip: View {
    let title: String
    var systemImage: String? = nil
    var isSelected: Bool = false
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var fill: Color {
        guard isSelected else { return Color.V2.surface2 }
        return colorScheme == .dark ? Color.V2.accent : Color.V2.accentTint
    }

    private var foreground: Color {
        guard isSelected else { return Color.V2.ink2 }
        return colorScheme == .dark ? Color.V2.onAccent : Color.V2.ink
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage).imageScale(.small)
                }
                Text(title)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 14)
            .frame(minHeight: 32)
            .background(Capsule().fill(fill))
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// "PLUS" pill: `plusBg` with `plus` text and an optional lock.
struct V2PlusPill: View {
    var showsLock: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            if showsLock {
                Image(systemName: "lock.fill").imageScale(.small)
            }
            Text("PLUS")
        }
        .font(.caption.weight(.bold))
        .tracking(0.6)
        .foregroundStyle(Color.V2.plus)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.V2.plusBg))
        .overlay(Capsule().strokeBorder(Color.V2.plusLine, lineWidth: 0.5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(showsLock ? "Plus feature, locked" : "Plus feature")
    }
}

#Preview("Chips and pill") {
    VStack(spacing: 16) {
        HStack {
            V2Chip(title: "7D", isSelected: true) {}
            V2Chip(title: "30D") {}
            V2Chip(title: "90D", systemImage: "lock.fill") {}
        }
        HStack { V2PlusPill(); V2PlusPill(showsLock: true) }
    }
    .padding()
    .background(Color.V2.bg)
}
