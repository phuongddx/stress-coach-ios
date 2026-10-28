import SwiftUI
import SwiftData

/// Data export view with date range picker, format selection, and share sheet integration
struct DataExportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: DataExportViewModel
    @State private var showingShareSheet = false
    @State private var exportURL: URL?
    @State private var showingError = false
    @State private var errorMessage = ""

    init(viewModel: DataExportViewModel = DataExportViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Form {
            dateRangeSection
            dataSelectionSection
            formatSection
            previewSection
            exportProgressSection
            exportButtonSection
            recordsCountSection
        }
        .navigationTitle("Export Data")
        .navigationBarTitleDisplayMode(.inline)
        .accessibleDynamicType()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .accessibilityLabel("Cancel export")
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportURL {
                ShareSheet(items: [url]) {
                    DataExportViewModel.cleanupExportTempFile(at: url)
                    exportURL = nil
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        .alert("Export Failed", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            Task {
                await viewModel.loadPreviewData(modelContext: modelContext)
            }
        }
        .onChange(of: viewModel.dateRange) { _, _ in
            Task {
                await viewModel.loadPreviewData(modelContext: modelContext)
            }
        }
        .onChange(of: viewModel.format) { _, _ in
            Task {
                await viewModel.loadPreviewData(modelContext: modelContext)
            }
        }
        .onChange(of: viewModel.includeHRV) { _, _ in
            Task {
                await viewModel.loadPreviewData(modelContext: modelContext)
            }
        }
        .onChange(of: viewModel.includeHeartRate) { _, _ in
            Task {
                await viewModel.loadPreviewData(modelContext: modelContext)
            }
        }
        .onChange(of: viewModel.includeStressLevels) { _, _ in
            Task {
                await viewModel.loadPreviewData(modelContext: modelContext)
            }
        }
        .onChange(of: viewModel.includeBaseline) { _, _ in
            Task {
                await viewModel.loadPreviewData(modelContext: modelContext)
            }
        }
    }

    private var dateRangeSection: some View {
        Section("Date Range") {
            Picker("Range", selection: $viewModel.dateRange) {
                ForEach(ExportDateRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Date range selection")

            if viewModel.dateRange == .custom {
                DatePicker("Start Date", selection: $viewModel.customStartDate, displayedComponents: .date)
                    .accessibilityLabel("Start date")
                DatePicker("End Date", selection: $viewModel.customEndDate, displayedComponents: .date)
                    .accessibilityLabel("End date")
            }

            Text(viewModel.dateRangeDescription)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var dataSelectionSection: some View {
        Section("Data to Include") {
            Toggle("HRV Measurements", isOn: $viewModel.includeHRV)
                .accessibilityLabel("Include HRV measurements")

            Toggle("Heart Rate Data", isOn: $viewModel.includeHeartRate)
                .accessibilityLabel("Include heart rate data")

            Toggle("Stress Levels", isOn: $viewModel.includeStressLevels)
                .accessibilityLabel("Include stress levels")

            Toggle("Baseline Data", isOn: $viewModel.includeBaseline)
                .accessibilityLabel("Include baseline data")
        }
    }

    private var formatSection: some View {
        Section {
            FormatPickerRow(format: $viewModel.format)
        } header: {
            Text("Format")
        } footer: {
            Text(viewModel.formatDescription)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var previewSection: some View {
        if let preview = viewModel.previewData {
            Section("Preview") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("First \(preview.count) records will be exported")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(preview)
                        .font(.system(.caption, design: .monospaced))
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                        .lineLimit(5)
                }
            }
        }
    }

    @ViewBuilder
    private var exportProgressSection: some View {
        if viewModel.isExporting {
            Section {
                ExportProgressBarView(
                    progress: viewModel.exportProgress,
                    currentOperation: viewModel.currentOperation,
                    recordsProcessed: viewModel.recordsProcessed,
                    totalRecords: viewModel.totalRecords
                )
            }
        }
    }

    private var exportButtonSection: some View {
        Section {
            Button(action: {
                Task {
                    await performExport()
                }
            }) {
                HStack {
                    Spacer()
                    if viewModel.isExporting {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Exporting...")
                            .foregroundColor(.secondary)
                    } else {
                        Image(systemName: AppIconSystem.System.export_.sfSymbol)
                        Text("Export Data")
                    }
                    Spacer()
                }
            }
            .disabled(viewModel.isExporting || !viewModel.hasValidSelection)
            .accessibilityLabel(viewModel.isExporting ? "Exporting data" : "Export data")
            .accessibilityHint(!viewModel.hasValidSelection ? "Select at least one data type to export" : "Double tap to start export")
        }
    }

    @ViewBuilder
    private var recordsCountSection: some View {
        if !viewModel.isExporting {
            Section {
                HStack {
                    Text("Records to Export")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(viewModel.estimatedRecordCount)")
                        .fontWeight(.semibold)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func performExport() async {
        do {
            viewModel.isExporting = true
            defer { viewModel.isExporting = false }

            let url = try await viewModel.exportData(modelContext: modelContext)
            await MainActor.run {
                exportURL = url
                showingShareSheet = true
                HapticManager.shared.success()
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

/// View model for data export
@Observable
class DataExportViewModel {
    var dateRange: ExportDateRange = .month
    var customStartDate: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    var customEndDate: Date = Date()
    var includeHRV: Bool = true
    var includeHeartRate: Bool = true
    var includeStressLevels: Bool = true
    var includeBaseline: Bool = false
    var format: ExportFormat = .csv

    var isExporting: Bool = false
    var exportProgress: Double = 0
    var currentOperation: String = ""
    var recordsProcessed: Int = 0
    var totalRecords: Int = 0

    private(set) var previewData: String?
    private(set) var estimatedRecordCount: Int = 0

    var hasValidSelection: Bool {
        includeHRV || includeHeartRate || includeStressLevels || includeBaseline
    }

    var dateRangeDescription: String {
        switch dateRange {
        case .day:
            return "Last 24 hours"
        case .week:
            return "Last 7 days"
        case .month:
            return "Last 4 weeks"
        case .threeMonths:
            return "Last 3 months"
        case .all:
            return "All time"
        case .custom:
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return "\(formatter.string(from: customStartDate)) - \(formatter.string(from: customEndDate))"
        }
    }

    var formatDescription: String {
        switch format {
        case .csv:
            return "Comma-separated values, compatible with Excel and Numbers"
        case .json:
            return "Structured data format, suitable for developers and backups"
        }
    }

    private var dateRangeBounds: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()

        switch dateRange {
        case .day:
            let start = calendar.date(byAdding: .day, value: -1, to: now) ?? now
            return (start, now)
        case .week:
            let start = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return (start, now)
        case .month:
            let start = calendar.date(byAdding: .day, value: -28, to: now) ?? now
            return (start, now)
        case .threeMonths:
            let start = calendar.date(byAdding: .day, value: -90, to: now) ?? now
            return (start, now)
        case .all:
            return (Date.distantPast, now)
        case .custom:
            return (customStartDate, customEndDate)
        }
    }

    func loadPreviewData(modelContext: ModelContext) async {
        await MainActor.run {
            currentOperation = "Loading preview..."
        }

        // Simulate loading preview data
        let records = fetchRecords(modelContext: modelContext, limit: 3)
        estimatedRecordCount = fetchRecords(modelContext: modelContext, limit: nil).count
        let baseline = await fetchBaseline(modelContext: modelContext)

        await MainActor.run {
            if format == .csv {
                previewData = generateCSVPreview(records: records, baseline: baseline)
            } else {
                previewData = generateJSONPreview(records: records, baseline: baseline)
            }
            currentOperation = ""
        }
    }

    func exportData(modelContext: ModelContext) async throws -> URL {
        let records = fetchRecords(modelContext: modelContext, limit: nil)
        totalRecords = records.count
        recordsProcessed = 0
        exportProgress = 0

        try Self.validateExportSize(recordCount: records.count, format: format)

        let fileName = "stress_export_\(Int(Date().timeIntervalSince1970))"
        let fileExtension = format == .csv ? "csv" : "json"

        guard let tempDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            throw ExportError.fileAccessFailed
        }

        // Health-derived exports are short-lived (generated, shared, done) —
        // sweep anything left over from a previous export the user never
        // cleaned up, rather than letting them accumulate indefinitely.
        Self.removeStaleExports(in: tempDir)

        let fileURL = tempDir.appendingPathComponent("\(fileName).\(fileExtension)")

        await MainActor.run {
            currentOperation = "Generating \(fileExtension.uppercased())..."
        }

        let baseline = await fetchBaseline(modelContext: modelContext)

        let content: String
        if format == .csv {
            content = try await generateCSV(records: records, baseline: baseline)
        } else {
            content = try await generateJSON(records: records, baseline: baseline)
        }

        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: fileURL.path
        )

        await MainActor.run {
            exportProgress = 1.0
            currentOperation = "Export complete"
        }

        return fileURL
    }

    /// Deletes `stress_export_*` files older than one hour. Exports are
    /// meant to be generated, shared via the share sheet, and discarded —
    /// nothing else in this flow ever cleans them up.
    private static func removeStaleExports(in directory: URL) {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }

        let cutoff = Date().addingTimeInterval(-3600)
        for url in contents where url.lastPathComponent.hasPrefix("stress_export_") {
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            if let modified, modified < cutoff {
                try? fileManager.removeItem(at: url)
            }
        }
    }

    static let maxExportRecords = 10_000
    private static let maxExportBytes = 10 * 1024 * 1024

    static func validateExportSize(recordCount: Int, format: ExportFormat) throws {
        let avgBytesPerRow: Double = format == .csv ? 80 : 160
        let estimatedBytes = Double(recordCount) * avgBytesPerRow

        if recordCount > maxExportRecords {
            throw ExportError.exceedsSizeCap(
                limitDescription: "\(maxExportRecords) record"
            )
        }
        if estimatedBytes > Double(maxExportBytes) {
            throw ExportError.exceedsSizeCap(
                limitDescription: "\(maxExportBytes / 1024 / 1024) MB"
            )
        }
    }

    static func cleanupExportTempFile(at url: URL) {
        guard url.lastPathComponent.hasPrefix("stress_export_") else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private func fetchRecords(modelContext: ModelContext, limit: Int?) -> [StressMeasurement] {
        let (start, end) = dateRangeBounds

        let descriptor = FetchDescriptor<StressMeasurement>(
            predicate: #Predicate { measurement in
                measurement.timestamp >= start && measurement.timestamp <= end
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )

        do {
            var results = try modelContext.fetch(descriptor)
            if let limit = limit {
                results = Array(results.prefix(limit))
            }
            return results
        } catch {
            return []
        }
    }

    /// Fetches the personal baseline only when the caller asked to include it —
    /// avoids the repository round-trip otherwise.
    private func fetchBaseline(modelContext: ModelContext) async -> PersonalBaseline? {
        guard includeBaseline else { return nil }
        return try? await StressRepository(modelContext: modelContext).getBaseline()
    }

    private func csvHeaderColumns() -> [String] {
        var columns = ["Timestamp"]
        if includeHRV { columns.append("HRV") }
        if includeHeartRate { columns.append("Heart Rate") }
        if includeStressLevels {
            columns.append("Stress Level")
            columns.append("Confidence")
        }
        return columns
    }

    private func csvRow(for record: StressMeasurement) -> String {
        let formatter = ISO8601DateFormatter()
        var fields = [formatter.string(from: record.timestamp)]
        if includeHRV { fields.append(String(format: "%.1f", record.hrv)) }
        if includeHeartRate { fields.append(record.restingHeartRate > 0 ? String(format: "%.0f", record.restingHeartRate) : "") }
        if includeStressLevels {
            fields.append(String(format: "%.0f", record.stressLevel))
            fields.append(record.confidences?.first.map { String(format: "%.2f", $0) } ?? "")
        }
        return fields.joined(separator: ",")
    }

    private func csvBaselineSection(_ baseline: PersonalBaseline) -> String {
        "\nBaseline\nResting Heart Rate,\(String(format: "%.0f", baseline.restingHeartRate))\n"
            + "Baseline HRV,\(String(format: "%.1f", baseline.baselineHRV))\n"
    }

    private func jsonFields(for record: StressMeasurement) -> [String: Any] {
        var fields: [String: Any] = ["timestamp": ISO8601DateFormatter().string(from: record.timestamp)]
        if includeHRV { fields["hrv"] = record.hrv }
        if includeHeartRate { fields["heartRate"] = record.restingHeartRate > 0 ? record.restingHeartRate as Any : NSNull() }
        if includeStressLevels {
            fields["stressLevel"] = record.stressLevel
            fields["confidence"] = record.confidences?.first.map { $0 as Any } ?? NSNull()
        }
        return fields
    }

    private func jsonBaselineFields(_ baseline: PersonalBaseline) -> [String: Any] {
        [
            "restingHeartRate": baseline.restingHeartRate,
            "baselineHRV": baseline.baselineHRV
        ]
    }

    private func generateCSVPreview(records: [StressMeasurement], baseline: PersonalBaseline?) -> String {
        guard !records.isEmpty else { return "No data to export" }

        var csv = csvHeaderColumns().joined(separator: ",") + "\n"
        for record in records {
            csv += csvRow(for: record) + "\n"
        }
        if let baseline {
            csv += csvBaselineSection(baseline)
        }
        return csv
    }

    private func generateJSONPreview(records: [StressMeasurement], baseline: PersonalBaseline?) -> String {
        guard !records.isEmpty else { return "No data to export" }

        let previewRecords = Array(records.prefix(2))
        var payload: [String: Any] = ["measurements": previewRecords.map { jsonFields(for: $0) }]
        if let baseline {
            payload["baseline"] = jsonBaselineFields(baseline)
        }
        if let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted),
           let json = String(data: jsonData, encoding: .utf8) {
            return json
        }
        return "Error generating preview"
    }

    private func generateCSV(records: [StressMeasurement], baseline: PersonalBaseline?) async throws -> String {
        var csv = csvHeaderColumns().joined(separator: ",") + "\n"

        for (index, record) in records.enumerated() {
            await MainActor.run {
                recordsProcessed = index + 1
                exportProgress = Double(index + 1) / Double(records.count)
                currentOperation = "Processing record \(index + 1) of \(records.count)..."
            }

            csv += csvRow(for: record) + "\n"
        }

        if let baseline {
            csv += csvBaselineSection(baseline)
        }

        return csv
    }

    private func generateJSON(records: [StressMeasurement], baseline: PersonalBaseline?) async throws -> String {
        let measurements = records.map { jsonFields(for: $0) }

        var payload: [String: Any] = ["measurements": measurements]
        if let baseline {
            payload["baseline"] = jsonBaselineFields(baseline)
        }

        let jsonData = try JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted)
        guard let json = String(data: jsonData, encoding: .utf8) else {
            throw ExportError.encodingFailed
        }

        return json
    }
}

/// ShareSheet wrapper for SwiftUI
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var onDismiss: (() -> Void)?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in
            onDismiss?()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

enum ExportError: LocalizedError {
    case noData
    case encodingFailed
    case fileWriteFailed(Error)
    case invalidPath
    case fileAccessFailed
    case exceedsSizeCap(limitDescription: String)

    var errorDescription: String? {
        switch self {
        case .noData:
            return "No measurements available to export."
        case .encodingFailed:
            return "Failed to encode data for export."
        case .fileWriteFailed(let error):
            return "Failed to write file: \(error.localizedDescription)"
        case .invalidPath:
            return "Invalid file path for export."
        case .fileAccessFailed:
            return "Could not access file system"
        case .exceedsSizeCap(let limitDescription):
            return "Export exceeds the \(limitDescription) limit. Narrow the date range and try again."
        }
    }
}

#Preview {
    NavigationStack {
        DataExportView()
    }
}
