import Observation
import SwiftUI

/// Central, observable navigation state for the whole app.
///
/// Owns:
/// - the selected tab (`selectedTab`)
/// - one `NavigationPath` per primary tab, bound to that tab's `NavigationStack`
///
/// Injected once at the app root via `.environment(AppRouter())`. Any view can
/// drive navigation by reading the router from the environment — this is what
/// makes programmatic navigation, deep links, and cross-tab routing possible
/// without scattering `@State` booleans through leaf views.
@MainActor
@Observable
final class AppRouter {
    /// Currently active tab.
    var selectedTab: TabItem = .home

    /// Per-tab navigation paths. Bound to each tab's `NavigationStack(path:)`.
    var homePath = NavigationPath()
    var actionPath = NavigationPath()
    var trendsPath = NavigationPath()
    var settingsPath = NavigationPath()

    /// Switch the visible tab.
    func switchTab(_ tab: TabItem) {
        selectedTab = tab
    }

    /// Push `route` onto the path of `tab`, switching to that tab first.
    /// Use this for deep links (notifications, widgets, URL schemes) and any
    /// "go to X from anywhere" flow.
    func deepLink(to route: Route, in tab: TabItem) {
        selectedTab = tab
        switch tab {
        case .home:     homePath.append(route)
        case .action:   actionPath.append(route)
        case .trend:    trendsPath.append(route)
        case .settings: settingsPath.append(route)
        }
    }

    /// Binding-friendly mutator used by `NavigationStack(path:)`.
    func binding(for tab: TabItem) -> Binding<NavigationPath> {
        switch tab {
        case .home:     return Binding(get: { self.homePath },     set: { self.homePath = $0 })
        case .action:   return Binding(get: { self.actionPath },   set: { self.actionPath = $0 })
        case .trend:    return Binding(get: { self.trendsPath },   set: { self.trendsPath = $0 })
        case .settings: return Binding(get: { self.settingsPath }, set: { self.settingsPath = $0 })
        }
    }

    // MARK: - State restoration
    //
    // `Route` is `Codable`, so each `NavigationPath` can be serialized via its
    // `codable` representation. The snapshot is a single `Data` blob per tab,
    // stored in `@SceneStorage` by the host (see `MainTabView`). Decoding is
    // defensive: corrupt or schema-shifted data is dropped rather than
    // crashed (Axiom nav.md CRITICAL #8).

    /// Encodes a path to `Data`, or `nil` if the path is empty.
    static func encodePath(_ path: NavigationPath) -> Data? {
        guard !path.isEmpty else { return nil }
        return try? JSONEncoder().encode(path.codable)
    }

    /// Decodes a path from `Data`. Returns an empty path on any failure
    /// (missing data, schema change, deleted referenced item).
    static func decodePath(_ data: Data?) -> NavigationPath {
        guard let data,
              let codable = try? JSONDecoder().decode(
                  NavigationPath.CodableRepresentation.self,
                  from: data
              )
        else { return NavigationPath() }
        return NavigationPath(codable)
    }

    /// Decodes a path and cuts it at the first `Route` that `isAllowed`
    /// rejects, dropping that screen and every screen pushed above it.
    /// Used on restore so a screen hidden in this build (see
    /// `CharactersAvailability.allows(_:)`) can't come back from a path saved
    /// by an earlier version.
    ///
    /// `NavigationPath.CodableRepresentation` encodes as a flat JSON array of
    /// (type name, JSON value) string pairs, top of the stack first.
    static func decodePath(_ data: Data?, keeping isAllowed: (Route) -> Bool) -> NavigationPath {
        guard let data,
              let items = try? JSONDecoder().decode([String].self, from: data),
              items.count % 2 == 0
        else { return decodePath(data) }

        let topFirst = stride(from: 0, to: items.count, by: 2).map { (type: items[$0], value: items[$0 + 1]) }
        var keptBottomFirst: [(type: String, value: String)] = []
        for item in topFirst.reversed() {
            if item.type.hasSuffix("Route"),
               let route = try? JSONDecoder().decode(Route.self, from: Data(item.value.utf8)),
               !isAllowed(route) {
                break
            }
            keptBottomFirst.append(item)
        }
        guard keptBottomFirst.count < topFirst.count else { return decodePath(data) }

        let flat = keptBottomFirst.reversed().flatMap { [$0.type, $0.value] }
        return decodePath(try? JSONEncoder().encode(flat))
    }
}
