import SwiftUI

/// Confirmation view for data deletion operations
/// Requires user to type "DELETE" to confirm, shows affected data and consequences
struct DeleteConfirmationView: View {
    let deleteScope: DataDeleteScope
    let dateRange: DateRange?
    let affectedDataCounts: AffectedDataCounts
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @State private var confirmationText = ""
    @FocusState private var isTextFieldFocused: Bool

    private let requiredConfirmationText = "DELETE"

    var isConfirmationValid: Bool {
        confirmationText.uppercased() == requiredConfirmationText
    }

    @ScaledMetric(relativeTo: .largeTitle) private var heroTile: CGFloat = 64

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header

                    // What will be deleted
                    section("What will be deleted") {
                        VStack(alignment: .leading, spacing: 12) {
                            DeleteConfirmationItem(
                                icon: "heart.slash.fill",
                                title: "Stress Measurements",
                                count: affectedDataCounts.stressMeasurements,
                                color: Color.V2.danger
                            )

                            if deleteScope.includesBaseline {
                                DeleteConfirmationItem(
                                    icon: "chart.line.flattrend.xyaxis",
                                    title: "Personal Baseline",
                                    count: affectedDataCounts.baseline ? 1 : 0,
                                    color: Color.V2.danger
                                )
                            }

                            if let range = dateRange {
                                DeleteConfirmationItem(
                                    icon: "calendar.badge.exclamationmark",
                                    title: "Date Range",
                                    subtitle: range.displayText,
                                    count: nil,
                                    color: Color.V2.ink2
                                )
                            }
                        }
                    }

                    // Consequences
                    section("Important") {
                        VStack(alignment: .leading, spacing: 10) {
                            ConsequenceRow(
                                icon: "xmark.circle.fill",
                                text: "This action cannot be undone"
                            )

                            ConsequenceRow(
                                icon: "xmark.circle.fill",
                                text: deleteScope.includesCloud ? "Data will be removed from all devices" : "Only local data will be affected"
                            )

                            ConsequenceRow(
                                icon: "info.circle.fill",
                                text: "HealthKit data will not be affected"
                            )
                        }
                    }

                    // Confirmation requirement
                    section("Type DELETE to confirm") {
                        TextField("Enter DELETE", text: $confirmationText)
                            .font(.v2Number(.body))
                            .foregroundStyle(Color.V2.ink)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .focused($isTextFieldFocused)
                            .padding(.horizontal, 14)
                            .frame(minHeight: V2Metrics.minTouchTarget)
                            .background(
                                RoundedRectangle(cornerRadius: V2Metrics.radiusSM, style: .continuous)
                                    .fill(Color.V2.surface2)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: V2Metrics.radiusSM, style: .continuous)
                                    .strokeBorder(
                                        isConfirmationValid ? Color.V2.danger : Color.V2.line2,
                                        lineWidth: isConfirmationValid ? 1.5 : 1
                                    )
                            )
                            .accessibilityLabel("Confirmation text field")
                            .accessibilityHint("Type \(requiredConfirmationText) to enable the delete button")
                    }

                    // Action buttons
                    VStack(spacing: 10) {
                        Button(action: onConfirm) {
                            HStack(spacing: 8) {
                                Image(systemName: AppIconSystem.System.delete.sfSymbol)
                                Text("Delete Everything")
                            }
                        }
                        .buttonStyle(.v2(.destructiveFill))
                        .disabled(!isConfirmationValid)
                        .accessibilityLabel("Delete all data")
                        .accessibilityHint(isConfirmationValid ? "Double tap to permanently delete data" : "Type DELETE to enable")

                        Button(action: onCancel) {
                            Text("Cancel")
                        }
                        .buttonStyle(.v2(.ghost))
                        .accessibilityLabel("Cancel and return")
                    }
                }
                .padding(.horizontal, V2Metrics.margin)
                .padding(.bottom, 24)
            }
            .background(Color.V2.bg.ignoresSafeArea())
            .navigationTitle("Confirm Deletion")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            isTextFieldFocused = true
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: AppIconSystem.System.warning.sfSymbol)
                .font(.title.weight(.semibold))
                .foregroundStyle(Color.V2.danger)
                .frame(width: heroTile, height: heroTile)
                .background(
                    RoundedRectangle(cornerRadius: V2Metrics.radiusMD, style: .continuous)
                        .fill(Color.V2.dangerSoft)
                )
                .accessibilityHidden(true)

            Text(deleteScope.title)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.V2.ink)
                .accessibilityAddTraits(.isHeader)

            Text(deleteScope.warningMessage)
                .font(.body)
                .foregroundStyle(Color.V2.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        let inner = content()
        return VStack(alignment: .leading, spacing: 6) {
            ActionGroupHeader(title: title)
            V2Card {
                inner
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// Individual item showing what will be deleted
struct DeleteConfirmationItem: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    let count: Int?
    let color: Color

    @ScaledMetric(relativeTo: .body) private var tileSize: CGFloat = 30

    var body: some View {
        HStack(spacing: 12) {
            SettingsIconView(
                systemName: icon,
                color: count == nil ? Color.V2.surface2 : Color.V2.dangerSoft,
                foreground: color,
                size: tileSize
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(Color.V2.ink)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(Color.V2.ink3)
                }
            }

            Spacer()

            if let count = count {
                Text("\(count)")
                    .font(.v2Number(.body))
                    .foregroundStyle(color)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(count.map { $0 == 1 ? "1 item" : "\($0) items" } ?? (subtitle ?? ""))
    }
}

/// Row displaying a consequence
struct ConsequenceRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundStyle(icon.contains("xmark") ? Color.V2.danger : Color.V2.ink3)
                .accessibilityHidden(true)

            Text(text)
                .font(.callout)
                .foregroundStyle(Color.V2.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Data deletion scope
enum DataDeleteScope {
    case localOnly
    case cloudOnly
    case everything

    var title: String {
        switch self {
        case .localOnly: return "Delete Local Data"
        case .cloudOnly: return "Delete Cloud Data"
        case .everything: return "Delete All Data"
        }
    }

    var warningMessage: String {
        switch self {
        case .localOnly:
            return "This will permanently delete all stress measurements stored on this device. Your cloud data will not be affected."
        case .cloudOnly:
            return "This will permanently delete all data from iCloud. Your local data will remain on this device."
        case .everything:
            return "This will permanently delete all your stress measurements from both this device and iCloud. This action cannot be undone."
        }
    }

    var includesBaseline: Bool {
        switch self {
        case .localOnly, .everything: return true
        case .cloudOnly: return false
        }
    }

    var includesCloud: Bool {
        switch self {
        case .localOnly: return false
        case .cloudOnly, .everything: return true
        }
    }
}

/// Date range for deletion
struct DateRange {
    let startDate: Date
    let endDate: Date

    var displayText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
}

/// Counts of affected data
struct AffectedDataCounts {
    let stressMeasurements: Int
    let baseline: Bool
}

#Preview {
    DeleteConfirmationView(
        deleteScope: .everything,
        dateRange: DateRange(
            startDate: Date().addingTimeInterval(-30 * 24 * 60 * 60),
            endDate: Date()
        ),
        affectedDataCounts: AffectedDataCounts(
            stressMeasurements: 1247,
            baseline: true
        ),
        onConfirm: {},
        onCancel: {}
    )
}
