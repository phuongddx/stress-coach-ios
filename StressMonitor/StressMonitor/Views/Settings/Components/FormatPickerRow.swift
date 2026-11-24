import SwiftUI

/// Radio-style CSV / JSON format selector for the data export flow.
///
/// Tapping a row selects that format and fills its radio mark (UI V2).
/// Designed to drop into an `ActionGroupCard`.
struct FormatPickerRow: View {
    @Binding var format: ExportFormat

    var body: some View {
        VStack(spacing: 0) {
            row(.csv)
            divider
            row(.json)
        }
        .accessibilityElement(children: .contain)
    }

    private func row(_ option: ExportFormat) -> some View {
        Button {
            format = option
            HapticManager.shared.buttonPress()
        } label: {
            SettingsRowLabel(
                icon: option == .csv ? "tablecells" : "curlybraces",
                tint: format == option ? Color.V2.accentSoft : Color.V2.surface2,
                glyph: format == option ? Color.V2.accent : Color.V2.ink2,
                title: option.rawValue.uppercased(),
                subtitle: option.description
            ) {
                SettingsRadioMark(isSelected: format == option)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(option.rawValue) format")
        .accessibilityAddTraits(format == option ? .isSelected : [])
    }

    private var divider: some View {
        ActionRowDivider()
    }
}

private extension ExportFormat {
    var description: String {
        switch self {
        case .csv:  return "Comma-separated, opens in Excel or Numbers"
        case .json: return "Structured data, ideal for backups and devs"
        }
    }
}

#Preview {
    @Previewable @State var format: ExportFormat = .csv
    return ActionGroupCard {
        FormatPickerRow(format: $format)
    }
    .padding()
    .background(Color.V2.bg)
}
