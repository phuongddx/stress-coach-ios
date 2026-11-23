import SwiftUI

/// Shared row layout for the Settings screens (UI V2 `li()`): a 30 pt icon
/// tile, a body title with an optional footnote subtitle, an optional value
/// and a trailing accessory (chevron, toggle, picker, radio mark).
///
/// At accessibility text sizes the value drops under the title so nothing
/// clips. Rows are at least 44 pt tall. Lives inside an `ActionGroupCard`;
/// separate rows with `ActionRowDivider()` (the 58 pt inset matches the tile).
struct SettingsRowLabel<Trailing: View>: View {
    let icon: String
    var setting: AppIconSystem.Setting?
    var tint: Color
    var glyph: Color
    let title: String
    var titleColor: Color
    var subtitle: String?
    var value: String?
    var valueColor: Color
    let trailing: Trailing

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var tileSize: CGFloat = 30

    init(
        icon: String,
        setting: AppIconSystem.Setting? = nil,
        tint: Color = Color.V2.accentSoft,
        glyph: Color = Color.V2.accent,
        title: String,
        titleColor: Color = Color.V2.ink,
        subtitle: String? = nil,
        value: String? = nil,
        valueColor: Color = Color.V2.ink3,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.icon = icon
        self.setting = setting
        self.tint = tint
        self.glyph = glyph
        self.title = title
        self.titleColor = titleColor
        self.subtitle = subtitle
        self.value = value
        self.valueColor = valueColor
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 12) {
            iconTile

            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 2) {
                    titleBlock
                    valueText
                }
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                titleBlock
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                valueText
            }

            trailing
        }
        .padding(.horizontal, V2Metrics.margin)
        .padding(.vertical, 4)
        .frame(minHeight: V2Metrics.minTouchTarget)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var iconTile: some View {
        if let setting {
            SettingsIconView(setting, color: tint, foreground: glyph, size: tileSize)
        } else {
            SettingsIconView(systemName: icon, color: tint, foreground: glyph, size: tileSize)
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.body)
                .foregroundStyle(titleColor)
            if let subtitle {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(Color.V2.ink3)
            }
        }
    }

    @ViewBuilder
    private var valueText: some View {
        if let value {
            Text(value)
                .font(.subheadline)
                .foregroundStyle(valueColor)
                .multilineTextAlignment(dynamicTypeSize.isAccessibilitySize ? .leading : .trailing)
        }
    }
}

extension SettingsRowLabel where Trailing == EmptyView {
    init(
        icon: String,
        setting: AppIconSystem.Setting? = nil,
        tint: Color = Color.V2.accentSoft,
        glyph: Color = Color.V2.accent,
        title: String,
        titleColor: Color = Color.V2.ink,
        subtitle: String? = nil,
        value: String? = nil,
        valueColor: Color = Color.V2.ink3
    ) {
        self.init(
            icon: icon, setting: setting, tint: tint, glyph: glyph,
            title: title, titleColor: titleColor, subtitle: subtitle,
            value: value, valueColor: valueColor
        ) { EmptyView() }
    }
}

/// Radio indicator for single-choice rows (UI V2 `.radio`): an accent
/// filled circle with a check when selected, a hairline ring otherwise.
struct SettingsRadioMark: View {
    let isSelected: Bool

    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 22

    var body: some View {
        ZStack {
            if isSelected {
                Circle().fill(Color.V2.accent)
                Image(systemName: "checkmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.V2.onAccent)
            } else {
                Circle().strokeBorder(Color.V2.line2, lineWidth: 1.5)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Plain text row inside a grouped card (no icon tile), e.g. radio options
/// or info lines. At least 44 pt tall.
struct SettingsPlainRow<Trailing: View>: View {
    let title: String
    var subtitle: String?
    let trailing: Trailing

    init(title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(Color.V2.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(Color.V2.ink3)
                }
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .padding(.horizontal, V2Metrics.margin)
        .padding(.vertical, 4)
        .frame(minHeight: V2Metrics.minTouchTarget)
        .contentShape(Rectangle())
    }
}

/// Hairline between plain rows (no icon tile), inset by the row margin.
struct SettingsPlainDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.V2.line)
            .frame(height: 0.5)
            .padding(.leading, V2Metrics.margin)
            .accessibilityHidden(true)
    }
}

#Preview("Settings rows") {
    ScrollView {
        VStack(spacing: 6) {
            ActionGroupHeader(title: "Health & devices")
            ActionGroupCard {
                SettingsRowLabel(
                    icon: "heart.fill",
                    tint: StressCategory.high.fillColor,
                    glyph: StressCategory.high.onFillColor,
                    title: "Apple Health",
                    value: "Connected"
                ) { ActionRowChevron() }
                ActionRowDivider()
                SettingsRowLabel(icon: "applewatch", title: "Apple Watch", subtitle: "Not paired")
                ActionRowDivider()
                SettingsPlainRow(title: "CSV", subtitle: "Spreadsheet") {
                    SettingsRadioMark(isSelected: true)
                }
            }
        }
        .padding(16)
    }
    .background(Color.V2.bg)
}
