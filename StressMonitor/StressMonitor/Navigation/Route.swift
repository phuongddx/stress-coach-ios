import Foundation
import SwiftData

/// Value-based navigation destinations for the app's `NavigationStack`s.
///
/// Every pushable screen is represented by a `Route` case. Views push a route
/// via `NavigationLink(value:)` or by appending to the bound `NavigationPath`.
/// A single `.navigationDestination(for: Route.self)` block (see
/// `View.stressNavigationDestinations()`) resolves routes to screens, so the
/// same destination set is available in every tab.
///
/// Associated values must be `Hashable`. SwiftData `@Model` types (e.g.
/// `StressMeasurement`) conform to `Hashable` via `PersistentModel`.
/// Associated values must be `Hashable`. `PersistentIdentifier` (SwiftData)
/// is `Hashable` & `Codable`, so routes remain restoration-friendly.
enum Route: Hashable, Codable {
    // Data management
    case dataExport
    case dataManage
    case dataDelete

    // Characters
    case characters

    case appearance
    case about
    case watchFace

    // History
    /// History Timeline screen (`HistoryTimelineView`).
    case history
    case measurement(id: PersistentIdentifier)

    // Action tab destinations
    /// Box Breathing intro screen (`BreathingExerciseView`), which pushes the
    /// active session via `.breathingSession`.
    case boxBreathing
    /// Mini Walk screen.
    case miniWalk
    /// Active box-breathing session.
    case breathingSession
    /// Post-session summary. Requires `BreathingSessionResult: Hashable`.
    case breathingSummary(BreathingSessionResult)

    // Health
    /// Health Coach chat over `POST /agent/chat`. Entry gated behind
    /// `FeatureFlags.agentChatEnabled` — ships true ahead of the backend
    /// Phase B deploy; sends surface a typed 404 until it lands.
    case agentChat
}
