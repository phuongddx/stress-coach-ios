import CloudKit
import SwiftUI
import SwiftData

/// Data deletion view with options for local, cloud, or complete deletion
struct DataDeleteView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: DataDeleteViewModel
    @State private var showingConfirmation = false
    @State private var showingError = false
    @State private var errorMessage = ""

    init(viewModel: DataDeleteViewModel = DataDeleteViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let scopeOptions: [(scope: DataDeleteScope, label: String)] = [
        (.localOnly, "Local Only"),
        (.cloudOnly, "Cloud Only"),
        (.everything, "Everything")
    ]

    private let rangeOptions: [(range: DeleteDateRange, label: String)] = [
        (.all, "All Time"),
        (.threeMonths, "Last 3 Months"),
        (.month, "Last Month"),
        (.week, "Last Week")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                scopeSection
                dateRangeSection

                if viewModel.isDeleting {
                    progressSection
                } else {
                    affectedSection
                    deleteButton
                    infoSection
                }
            }
            .padding(.horizontal, V2Metrics.margin)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color.V2.bg.ignoresSafeArea())
        .navigationTitle("Delete Data")
        .navigationBarTitleDisplayMode(.inline)
        .accessibleDynamicType()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    if viewModel.isDeleting {
                        viewModel.cancelDelete()
                    } else {
                        dismiss()
                    }
                }
                .accessibilityLabel(viewModel.isDeleting ? "Stop deletion" : "Cancel")
            }
        }
        .sheet(isPresented: $showingConfirmation) {
            DeleteConfirmationView(
                deleteScope: viewModel.deleteScope,
                dateRange: viewModel.getDateRange(),
                affectedDataCounts: AffectedDataCounts(
                    stressMeasurements: viewModel.affectedMeasurementCount,
                    baseline: viewModel.affectedBaselineCount > 0
                ),
                onConfirm: {
                    showingConfirmation = false
                    Task {
                        await performDelete()
                    }
                },
                onCancel: {
                    showingConfirmation = false
                }
            )
        }
        .alert("Deletion Failed", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            Task {
                await viewModel.loadAffectedCounts(modelContext: modelContext)
            }
        }
        .onChange(of: viewModel.deleteScope) { _, _ in
            Task {
                await viewModel.loadAffectedCounts(modelContext: modelContext)
            }
        }
        .onChange(of: viewModel.dateRange) { _, _ in
            Task {
                await viewModel.loadAffectedCounts(modelContext: modelContext)
            }
        }
        .onChange(of: viewModel.useCustomDateRange) { _, _ in
            Task {
                await viewModel.loadAffectedCounts(modelContext: modelContext)
            }
        }
    }

    // MARK: - Sections

    private var scopeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            ActionGroupHeader(title: "What to delete")
            ActionGroupCard {
                VStack(spacing: 0) {
                    ForEach(Array(scopeOptions.enumerated()), id: \.offset) { index, option in
                        if index > 0 { SettingsPlainDivider() }
                        radioRow(option.label, isSelected: viewModel.deleteScope == option.scope) {
                            viewModel.deleteScope = option.scope
                        }
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Delete scope selection")
            ActionGroupFooter(text: viewModel.deleteScopeDescription)
        }
    }

    private var dateRangeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            ActionGroupHeader(title: "Range")
            ActionGroupCard {
                VStack(spacing: 0) {
                    SettingsPlainRow(title: "Custom Date Range") {
                        Toggle("Custom Date Range", isOn: $viewModel.useCustomDateRange)
                            .labelsHidden()
                            .tint(Color.V2.accent)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Use custom date range")

                    if viewModel.useCustomDateRange {
                        SettingsPlainDivider()
                        datePickerRow("Start Date", selection: $viewModel.customStartDate, label: "Start date")
                        SettingsPlainDivider()
                        datePickerRow("End Date", selection: $viewModel.customEndDate, label: "End date")
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(rangeOptions.enumerated()), id: \.offset) { _, option in
                                SettingsPlainDivider()
                                radioRow(option.label, isSelected: viewModel.dateRange == option.range) {
                                    viewModel.dateRange = option.range
                                }
                            }
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("Date range selection")
                    }
                }
            }
            if let description = viewModel.dateRangeDescription {
                ActionGroupFooter(text: description)
            }
        }
    }

    private var affectedSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            ActionGroupHeader(title: "This will remove")
            V2Card {
                VStack(spacing: 12) {
                    AffectedDataRow(
                        icon: "heart.slash.fill",
                        label: "Stress Measurements",
                        count: viewModel.affectedMeasurementCount
                    )

                    if viewModel.deleteScope.includesBaseline {
                        AffectedDataRow(
                            icon: "chart.line.flattrend.xyaxis",
                            label: "Personal Baseline",
                            count: viewModel.affectedBaselineCount
                        )
                    }

                    Rectangle()
                        .fill(Color.V2.line)
                        .frame(height: 0.5)
                        .accessibilityHidden(true)

                    HStack {
                        Text("Total")
                            .font(.subheadline)
                            .foregroundStyle(Color.V2.ink2)
                        Spacer()
                        Text("\(viewModel.totalAffectedCount) items")
                            .font(.v2Number(.headline))
                            .foregroundStyle(Color.V2.danger)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private var progressSection: some View {
        V2Card {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color.V2.surface3, lineWidth: 8)
                        .frame(width: 80, height: 80)

                    Circle()
                        .trim(from: 0, to: viewModel.deleteProgress)
                        .stroke(
                            Color.V2.danger,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: viewModel.deleteProgress)

                    Text("\(Int(viewModel.deleteProgress * 100))%")
                        .font(.v2Number(.headline, weight: .bold))
                        .foregroundStyle(Color.V2.ink)
                }

                Text(viewModel.currentOperation)
                    .font(.callout)
                    .foregroundStyle(Color.V2.ink3)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Delete progress: \(Int(viewModel.deleteProgress * 100)) percent")
        }
    }

    private var deleteButton: some View {
        Button(action: {
            showingConfirmation = true
        }) {
            HStack(spacing: 8) {
                Image(systemName: AppIconSystem.System.delete.sfSymbol)
                Text("Delete Data")
            }
        }
        .buttonStyle(.v2(.destructiveFill))
        .disabled(viewModel.totalAffectedCount == 0)
        .accessibilityLabel("Delete data")
        .accessibilityHint(viewModel.totalAffectedCount == 0 ? "No data to delete" : "Double tap to confirm deletion")
    }

    private var infoSection: some View {
        V2Card(style: .flat) {
            VStack(alignment: .leading, spacing: 12) {
                InfoRow(
                    icon: "checkmark.circle.fill",
                    text: viewModel.deleteScope.includesCloud ? "Data will be removed from all devices" : "Only local data will be affected",
                    color: Color.V2.accent
                )

                InfoRow(
                    icon: "xmark.circle.fill",
                    text: "This action cannot be undone",
                    color: Color.V2.danger
                )

                InfoRow(
                    icon: "info.circle.fill",
                    text: "HealthKit data will not be affected",
                    color: Color.V2.ink3
                )
            }
        }
    }

    // MARK: - Row helpers

    private func radioRow(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            HapticManager.shared.buttonPress()
        } label: {
            SettingsPlainRow(title: title) {
                SettingsRadioMark(isSelected: isSelected)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func datePickerRow(_ title: String, selection: Binding<Date>, label: String) -> some View {
        DatePicker(title, selection: selection, displayedComponents: .date)
            .font(.body)
            .foregroundStyle(Color.V2.ink)
            .tint(Color.V2.accent)
            .padding(.horizontal, V2Metrics.margin)
            .frame(minHeight: V2Metrics.minTouchTarget)
            .accessibilityLabel(label)
    }

    private func performDelete() async {
        do {
            try await viewModel.performDelete(modelContext: modelContext)
            HapticManager.shared.success()
            dismiss()
        } catch DeletionError.operationCancelled {
            return
        } catch let DeletionError.cloudKitError(cloudKitError) {
            await MainActor.run {
                errorMessage = "iCloud data couldn't be removed (\(cloudKitError.localizedDescription)). Resolve the iCloud issue and try again."
                showingError = true
                HapticManager.shared.error()
            }
        } catch let DeletionError.repositoryError(repositoryError) {
            await MainActor.run {
                errorMessage = "Delete failed: \(repositoryError.localizedDescription)"
                showingError = true
                HapticManager.shared.error()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
                HapticManager.shared.error()
            }
        }
    }
}

/// Row displaying affected data count
struct AffectedDataRow: View {
    let icon: String
    let label: String
    let count: Int

    @ScaledMetric(relativeTo: .body) private var tileSize: CGFloat = 30

    var body: some View {
        HStack(spacing: 12) {
            SettingsIconView(
                systemName: icon,
                color: Color.V2.dangerSoft,
                foreground: Color.V2.danger,
                size: tileSize
            )

            Text(label)
                .font(.body)
                .foregroundStyle(Color.V2.ink)

            Spacer()

            Text("\(count)")
                .font(.v2Number(.body))
                .foregroundStyle(Color.V2.danger)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(count) items")
    }
}

/// Information row
struct InfoRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
                .accessibilityHidden(true)

            Text(text)
                .font(.footnote)
                .foregroundStyle(Color.V2.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Date range for deletion
enum DeleteDateRange {
    case all
    case threeMonths
    case month
    case week

    var days: Int? {
        switch self {
        case .all: return nil
        case .threeMonths: return 90
        case .month: return 30
        case .week: return 7
        }
    }
}

/// View model for data deletion
@Observable
class DataDeleteViewModel {
    var deleteScope: DataDeleteScope = .localOnly
    var dateRange: DeleteDateRange = .all
    var useCustomDateRange: Bool = false
    var customStartDate: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    var customEndDate: Date = Date()

    var isDeleting: Bool = false
    var deleteProgress: Double = 0
    var currentOperation: String = ""
    private var cancellationToken: Task<Void, Error>?

    private(set) var affectedMeasurementCount: Int = 0
    private(set) var affectedBaselineCount: Int = 0

    var deleteScopeDescription: String {
        switch deleteScope {
        case .localOnly:
            return "Only data stored on this device will be deleted. Cloud data will remain intact."
        case .cloudOnly:
            return "Only iCloud data will be deleted. Local data on this device will remain."
        case .everything:
            return "All data will be permanently deleted from both this device and iCloud."
        }
    }

    var dateRangeDescription: String? {
        guard useCustomDateRange else {
            switch dateRange {
            case .all: return nil
            case .threeMonths: return "Data from the last 3 months"
            case .month: return "Data from the last month"
            case .week: return "Data from the last week"
            }
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return "From \(formatter.string(from: customStartDate)) to \(formatter.string(from: customEndDate))"
    }

    var totalAffectedCount: Int {
        affectedMeasurementCount + affectedBaselineCount
    }

    func getDateRange() -> DateRange? {
        guard useCustomDateRange else {
            if let days = dateRange.days {
                return DateRange(
                    startDate: Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date(),
                    endDate: Date()
                )
            }
            return nil
        }
        return DateRange(startDate: customStartDate, endDate: customEndDate)
    }

    func loadAffectedCounts(modelContext: ModelContext) async {
        await MainActor.run {
            currentOperation = "Calculating affected data..."
        }

        let (start, end) = getDateRangeBounds()
        let service = makeDeleterService(modelContext: modelContext)
        let count = await service.getDeletionStats(in: start...end)

        await MainActor.run {
            affectedMeasurementCount = count
            affectedBaselineCount = deleteScope.includesBaseline ? 1 : 0
            currentOperation = ""
        }
    }

    private func makeDeleterService(modelContext: ModelContext) -> DataDeleterService {
        DataDeleterService(
            modelContext: modelContext,
            cloudKitContainer: .default(),
            repository: StressRepository(modelContext: modelContext),
            logger: .default
        )
    }

    func performDelete(modelContext: ModelContext) async throws {
        let service = makeDeleterService(modelContext: modelContext)

        let (start, end) = getDateRangeBounds()
        let isAllTime = !useCustomDateRange && dateRange == .all

        isDeleting = true
        deleteProgress = 0
        currentOperation = "Preparing to delete..."

        let scope = deleteScope
        let deletionTask = Task {
            if scope == .everything && isAllTime {
                try await service.deleteAllMeasurements()
            } else {
                try await service.deleteMeasurements(
                    in: start...end,
                    includeLocal: scope != .cloudOnly,
                    includeCloud: scope.includesCloud
                )
            }
        }
        cancellationToken = deletionTask

        let progressMirror = Task { @MainActor in
            repeat {
                self.deleteProgress = service.deleteProgress
                self.currentOperation = service.currentOperation ?? ""
                try? await Task.sleep(for: .milliseconds(50))
            } while service.isDeleting
        }

        defer {
            progressMirror.cancel()
            cancellationToken = nil
            isDeleting = false
        }

        try await deletionTask.value

        deleteProgress = 1.0
        currentOperation = "Delete complete"
    }

    func cancelDelete() {
        cancellationToken?.cancel()
        cancellationToken = nil
    }

    private func getDateRangeBounds() -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()

        if useCustomDateRange {
            return (customStartDate, customEndDate)
        }

        guard let days = dateRange.days else {
            return (Date.distantPast, now)
        }

        let start = calendar.date(byAdding: .day, value: -days, to: now) ?? now
        return (start, now)
    }
}

enum DeleteError: LocalizedError {
    case noData
    case operationFailed

    var errorDescription: String? {
        switch self {
        case .noData: return "No data found to delete"
        case .operationFailed: return "Failed to complete deletion"
        }
    }
}

#Preview {
    NavigationStack {
        DataDeleteView()
    }
}
