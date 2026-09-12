import SwiftData
import SwiftUI

extension View {
    /// Attaches the app-wide set of `Route` → screen destinations.
    ///
    /// Apply this **once** to the root content of every tab's `NavigationStack`.
    /// Co-locating destinations at the stack root (rather than in leaf views)
    /// keeps them evaluated once, enables value-based `NavigationLink(value:)`,
    /// and gives every tab the ability to push any `Route`.
    @ViewBuilder
    func stressNavigationDestinations() -> some View {
        self.navigationDestination(for: Route.self) { route in
            switch route {
            case .dataExport:
                DataExportView()

            case .dataManage:
                DataManageView()

            case .dataDelete:
                DataDeleteView()

            case .characters:
                CharacterCollectionView()

            case .appearance:
                AppearanceSettingsView()

            case .about:
                AboutView()

            case .watchFace:
                WatchFacePreferencesView()

            case .history:
                HistoryTimelineView()

            case .measurementResult(let result):
                MeasurementResultView(result: result)

            case .measurement(let id):
                MeasurementDetailDestination(id: id)

            case .boxBreathing:
                BreathingExerciseView()

            case .miniWalk:
                MiniWalkView()

            case .breathingSession:
                BreathingSessionView()

            case .breathingSummary(let result):
                BreathingSummaryView(result: result)

            case .bioAge:
                BiologicalAgeView()

            case .agentChat:
                AgentChatView()
            }
        }
    }
}

/// Resolves a `PersistentIdentifier` to a live `StressMeasurement` and renders
/// `MeasurementDetailView`, or an "item deleted" placeholder if the measurement
/// no longer exists (deleted elsewhere). Used by `Route.measurement(id:)` so
/// the navigation path stores only IDs — never stale full model objects.
private struct MeasurementDetailDestination: View {
    let id: PersistentIdentifier
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        if let measurement = resolved {
            MeasurementDetailView(measurement: measurement)
        } else {
            ContentUnavailableView(
                "Measurement unavailable",
                systemImage: "tray",
                description: Text("This measurement may have been deleted.")
            )
        }
    }

    /// Fetches the live measurement for `id`. Returns nil if it was deleted,
    /// so restoration can never surface a stale object.
    private var resolved: StressMeasurement? {
        let descriptor = FetchDescriptor<StressMeasurement>(
            predicate: #Predicate<StressMeasurement> { $0.persistentModelID == id }
        )
        return try? modelContext.fetch(descriptor).first
    }
}
