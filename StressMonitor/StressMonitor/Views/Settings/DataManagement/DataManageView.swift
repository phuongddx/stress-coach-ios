import CloudKit
import SwiftData
import SwiftUI

/// Hub screen for data management: export, delete by range, delete all, and
/// reset. Quick destructive actions use ``DeleteConfirmationSheet`` for a
/// two-step confirmation; the detailed delete flow routes to ``DataDeleteView``.
struct DataManageView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router

    @State private var showingDeleteAll = false
    @State private var showingFactoryReset = false
    @State private var resultMessage: String?
    @State private var showingResult = false
    @State private var snapshotCount = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                recordsSection
                exportSection
                deleteSection
                resetSection
            }
            .padding(.horizontal, V2Metrics.margin)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color.V2.bg.ignoresSafeArea())
        .navigationTitle("Manage Data")
        .navigationBarTitleDisplayMode(.inline)
        .accessibleDynamicType()
        .task {
            await refreshSnapshotCount()
        }
        .alert("Done", isPresented: $showingResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(resultMessage ?? "")
        }
        .background(
            DeleteConfirmationSheet(
                title: "Delete all snapshots?",
                message: "Every locally stored stress measurement will be removed.",
                confirmLabel: "Delete all",
                requiresSecondaryConfirm: true,
                onConfirm: { Task { await performDeleteAll() } },
                isPresented: $showingDeleteAll
            )
        )
        .background(
            DeleteConfirmationSheet(
                title: "Factory reset?",
                message: "This wipes all data, character unlocks, and preferences.",
                confirmLabel: "Reset everything",
                requiresSecondaryConfirm: true,
                onConfirm: { Task { await performFactoryReset() } },
                isPresented: $showingFactoryReset
            )
        )
    }

    // MARK: - Records

    private var recordsSection: some View {
        group("Your data") {
            SettingsRowLabel(
                icon: "waveform.path.ecg",
                tint: Color.V2.accentSoft,
                glyph: Color.V2.accent,
                title: "Stress snapshots"
            ) {
                Text("\(snapshotCount)")
                    .font(.v2Number(.body))
                    .foregroundStyle(Color.V2.ink2)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(snapshotCount) stress snapshots stored")
        }
    }

    // MARK: - Export

    private var exportSection: some View {
        group("Export", footer: "Share a file via the iOS share sheet. Habits export is coming soon.") {
            Button {
                router.settingsPath.append(Route.dataExport)
            } label: {
                rowLabel(
                    icon: "square.and.arrow.up",
                    tint: StressCategory.relaxed.fillColor,
                    glyph: StressCategory.relaxed.onFillColor,
                    title: "Export data",
                    subtitle: "CSV or JSON, with date range"
                )
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Export data. CSV or JSON, with date range")
        }
    }

    // MARK: - Delete

    private var deleteSection: some View {
        group("Danger zone", footer: "Deletions are permanent and cannot be undone. Export first if you want a copy.") {
            Button {
                router.settingsPath.append(Route.dataDelete)
            } label: {
                rowLabel(
                    icon: "calendar.badge.minus",
                    tint: Color.V2.dangerSoft,
                    glyph: Color.V2.danger,
                    title: "Delete by range",
                    subtitle: "Remove snapshots from a window of time"
                )
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Delete by range. Remove snapshots from a window of time")
            ActionRowDivider()
            Button {
                showingDeleteAll = true
            } label: {
                rowLabel(
                    icon: "trash.fill",
                    tint: Color.V2.dangerSoft,
                    glyph: Color.V2.danger,
                    title: "Delete all snapshots",
                    titleColor: Color.V2.danger,
                    subtitle: "Removes every locally stored measurement"
                )
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Delete all snapshots. Removes every locally stored measurement")
        }
    }

    // MARK: - Reset

    private var resetSection: some View {
        group(nil, footer: "Factory reset also clears character unlocks and preferences.") {
            Button {
                showingFactoryReset = true
            } label: {
                rowLabel(
                    icon: "arrow.counterclockwise",
                    tint: Color.V2.danger,
                    glyph: Color.V2.onAccent,
                    title: "Factory reset",
                    titleColor: Color.V2.danger,
                    subtitle: "Wipe all data and return the app to first launch"
                )
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Factory reset. Wipe all data and return the app to first launch")
        }
    }

    // MARK: - Layout helpers

    /// Header + inset grouped card + optional footnote (UI V2 `group()`).
    private func group<Content: View>(
        _ title: String?,
        footer: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let rows = content()
        return VStack(alignment: .leading, spacing: 6) {
            if let title {
                ActionGroupHeader(title: title)
            }
            ActionGroupCard {
                VStack(spacing: 0) {
                    rows
                }
            }
            if let footer {
                ActionGroupFooter(text: footer)
            }
        }
    }

    private func rowLabel(
        icon: String,
        tint: Color,
        glyph: Color,
        title: String,
        titleColor: Color = Color.V2.ink,
        subtitle: String
    ) -> some View {
        SettingsRowLabel(
            icon: icon,
            tint: tint,
            glyph: glyph,
            title: title,
            titleColor: titleColor,
            subtitle: subtitle
        ) {
            ActionRowChevron()
        }
    }

    // MARK: - Actions

    private func makeDeleterService() -> DataDeleterService {
        DataDeleterService(
            modelContext: modelContext,
            cloudKitContainer: .default(),
            repository: StressRepository(modelContext: modelContext),
            logger: .default
        )
    }

    private func refreshSnapshotCount() async {
        snapshotCount = await makeDeleterService().getTotalCount()
    }

    private func performDeleteAll() async {
        let service = makeDeleterService()
        do {
            try await service.deleteAllMeasurements()
            resultMessage = "All stress snapshots were deleted."
            await refreshSnapshotCount()
        } catch let DeletionError.cloudKitError(cloudKitError) {
            resultMessage = "iCloud data couldn't be removed (\(cloudKitError.localizedDescription)). Local snapshots were not deleted — resolve the iCloud issue and try again."
        } catch DeletionError.operationCancelled {
            return
        } catch {
            resultMessage = "Delete failed: \(error.localizedDescription)"
        }
        showingResult = true
    }

    private func performFactoryReset() async {
        let service = makeDeleterService()
        do {
            try await service.performFactoryReset()
            resultMessage = "Local data cleared. Relaunch the app to begin setup."
            await refreshSnapshotCount()
        } catch let DeletionError.cloudKitError(cloudKitError) {
            resultMessage = "iCloud reset failed (\(cloudKitError.localizedDescription)). Local data, sign-in, and shared caches were not cleared — resolve the iCloud issue and try again."
        } catch DeletionError.operationCancelled {
            return
        } catch {
            resultMessage = "Reset failed: \(error.localizedDescription)"
        }
        showingResult = true
    }
}

#Preview {
    NavigationStack {
        DataManageView()
            .stressNavigationDestinations()
    }
    .environment(AppRouter())
    .modelContainer(for: [StressMeasurement.self, CharacterUnlock.self], inMemory: true)
}
